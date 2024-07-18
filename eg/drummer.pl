#!/usr/bin/env perl
use strict;
use warnings;

use IO::Async::Loop ();
use MIDI::Drummer::Tiny ();
use MIDI::RtMidi::ScorePlayer ();
use Term::TermKey::Async qw(FORMAT_VIM KEYMOD_CTRL);

my $verbose = shift || 0;

my %common;
my @parts;
my $bpm  = 100;
my $dura = 1;
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
      print "BPM: $bpm\n" if $verbose;
      $bpm += 5;
    }
    # SLOWER
    elsif ($pressed eq 'B') {
      print "BPM: $bpm\n" if $verbose;
      $bpm -= 5;
    }
    # HIHAT
    elsif ($pressed eq 'h') {
      print "Hihat\n" if $verbose;
      push @parts, 'hihat';
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note('qn', $args{drummer}->closed_hh);
      };
      my $d = snippit($part, $bpm);
      $common{drummer} = $d;
      $common{hihat}   = $part;
    }
    # KICK
    elsif ($pressed eq 'k') {
      print "Kick\n" if $verbose;
      push @parts, 'kick';
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note('en', $args{drummer}->kick)
          for 1 .. 2;
      };
      my $d = snippit($part, $bpm);
      $common{drummer} = $d;
      $common{kick}   = $part;
    }
    # SNARE
    elsif ($pressed eq 's') {
      print "Snare\n" if $verbose;
      push @parts, 'snare';
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note('sn', $args{drummer}->snare)
          for 1 .. 4;
      };
      my $d = snippit($part, $bpm);
      $common{drummer} = $d;
      $common{snare}   = $part;
    }
    # BEAT
    elsif ($pressed eq 'x') {
      print "Backbeat\n" if $verbose;
      push @parts, 'backbeat';
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note(
          $args{drummer}->quarter,
          $args{drummer}->open_hh,
          $_ % 2 ? $args{drummer}->kick : $args{drummer}->snare
        ) for 1 .. $args{drummer}->beats;
      };
      my $d = snippit($part, $bpm);
      $common{backbeat} = $part;
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
  my ($part, $bpm) = @_;
  my $d = MIDI::Drummer::Tiny->new(bpm => $bpm);
  MIDI::RtMidi::ScorePlayer->new(
    score  => $d->score,
    common => { drummer => $d },
    parts  => [ $part ],
    sleep    => 0,
    infinite => 0,
  )->play;
  return $d;
}
