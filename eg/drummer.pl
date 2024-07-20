#!/usr/bin/env perl
use strict;
use warnings;

# WORK IN PROGRESS. YMMV. Use The Source, Luke.

use IO::Async::Loop ();
use MIDI::Drummer::Tiny ();
use MIDI::RtMidi::ScorePlayer ();
use Term::TermKey::Async qw(FORMAT_VIM KEYMOD_CTRL);
use Time::HiRes qw(time);

my $verbose = shift || 0;

my %common;
my @parts;
my $bpm  = 100;
my $dura = 'qn';
my $loop = IO::Async::Loop->new;
my $tka  = Term::TermKey::Async->new(
  term   => \*STDIN,
  on_key => sub {
    my ($self, $key) = @_;
    my $pressed = $self->format_key($key, FORMAT_VIM);
    # print "Got key: $pressed\n" if $verbose;
    # PLAY
    if ($pressed eq 'p') {
      print "Play score\n" if $verbose;
      my $d = MIDI::Drummer::Tiny->new(bpm => $bpm);
      $common{drummer} = $d;
      $common{parts}   = \@parts;
      MIDI::RtMidi::ScorePlayer->new(
        score  => $d->score,
        common => \%common,
        parts  => [ sub {
          my (%args) = @_;
          return sub { $args{$_}->(%args) for $args{parts}->@* };
        }],
        sleep    => 0,
        infinite => 0,
      )->play;
    }
    # RESET
    elsif ($pressed eq 'r') {
      print "Reset score\n" if $verbose;
      %common = ();
      @parts  = ();
    }
    # FASTER
    elsif ($pressed eq 'b') {
      $bpm += 5;
      print "BPM: $bpm\n" if $verbose;
    }
    # SLOWER
    elsif ($pressed eq 'B') {
      $bpm -= 5;
      print "BPM: $bpm\n" if $verbose;
    }
    # SIXTEENTH
    elsif ($pressed eq '2') {
      $dura = 'sn';
      print "Duration: $dura\n" if $verbose;
    }
    # EIGHTH
    elsif ($pressed eq '3') {
      $dura = 'en';
      print "Duration: $dura\n" if $verbose;
    }
    # QUARTER
    elsif ($pressed eq '4') {
      $dura = 'qn';
      print "Duration: $dura\n" if $verbose;
    }
    # HIHAT
    elsif ($pressed eq 'h') {
      print "Hihat\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note($args{'hihat.duration.' . $id}, $args{drummer}->closed_hh)
          for 1 .. 4;
      };
      my $d = MIDI::Drummer::Tiny->new(bpm => $bpm);
      $common{drummer} = $d;
      $common{'hihat.duration.' . $id} = $dura;
      $common{'hihat.' . $id} = $part;
      push @parts, 'hihat.' . $id;
      snippit($part, \%common);
    }
    # KICK
    elsif ($pressed eq 'k') {
      print "Kick\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note($args{'kick.duration.' . $id}, $args{drummer}->kick)
          for 1 .. 2;
      };
      my $d = MIDI::Drummer::Tiny->new(bpm => $bpm);
      $common{drummer} = $d;
      $common{'kick.duration.' . $id} = $dura;
      $common{'kick.' . $id} = $part;
      push @parts, 'kick.' . $id;
      snippit($part, \%common);
    }
    # SNARE
    elsif ($pressed eq 's') {
      print "Snare\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note($args{'snare.duration.' . $id}, $args{drummer}->snare)
          for 1 .. 4;
      };
      my $d = MIDI::Drummer::Tiny->new(bpm => $bpm);
      $common{drummer} = $d;
      $common{'snare.duration.' . $id} = $dura;
      $common{'snare.' . $id} = $part;
      push @parts, 'snare.' . $id;
      snippit($part, \%common);
    }
    # BEAT
    elsif ($pressed eq 'x') {
      print "Backbeat\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note(
          $args{'backbeat.duration.' . $id},
          $args{drummer}->open_hh,
          $_ % 2 ? $args{drummer}->kick : $args{drummer}->snare
        ) for 1 .. $args{drummer}->beats;
      };
      my $d = MIDI::Drummer::Tiny->new(bpm => $bpm);
      $common{drummer} = $d;
      $common{'backbeat.duration.' . $id} = $dura;
      $common{'backbeat.' . $id} = $part;
      push @parts, 'backbeat.' . $id;
      snippit($part, \%common);
    }
    # FINISH
    $loop->loop_stop if $key->type_is_unicode and
                        $key->utf8 eq "C" and
                        $key->modifiers & KEYMOD_CTRL;
  },
);

$loop->add($tka);
$loop->loop_forever;

sub snippit {
  my ($part, $common) = @_;
  MIDI::RtMidi::ScorePlayer->new(
    score  => $common->{drummer}->score,
    common => $common,
    parts  => [ $part ],
    sleep    => 0,
    infinite => 0,
  )->play;
}
