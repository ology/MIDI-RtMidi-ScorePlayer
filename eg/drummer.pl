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
my $loop = IO::Async::Loop->new;
my $tka  = Term::TermKey::Async->new(
  term   => \*STDIN,
  on_key => sub {
    my ($self, $key) = @_;
    my $pressed = $self->format_key($key, FORMAT_VIM);
    # print "Got key: $pressed\n" if $verbose;
    if ($pressed eq 'p') {
      my $d = MIDI::Drummer::Tiny->new(
        bpm    => $bpm,
        reverb => 15,
      );
      $common{drummer} = $d;
      $common{parts}   = \@parts;
      MIDI::RtMidi::ScorePlayer->new(
        score    => $d->score,
        parts    => [ \&part ],
        common   => \%common,
        sleep    => 0,
        infinite => 0,
      )->play;
      print "Play score\n" if $verbose;
    }
    elsif ($pressed eq 'b') {
      $bpm += 5;
      print "BPM: $bpm\n" if $verbose;
    }
    elsif ($pressed eq 'B') {
      $bpm -= 5;
      print "BPM: $bpm\n" if $verbose;
    }
    elsif ($pressed eq 'r') {
      %common = ();
      @parts  = ();
      print "Reset score\n" if $verbose;
    }
    elsif ($pressed eq 's') {
      push @parts, 'snare';
      $common{snare} = sub {
        my (%args) = @_;
        $args{drummer}->note('sn', $args{drummer}->snare)
          for 1 .. 4;
      };
      print "Snare\n" if $verbose;
    }
    elsif ($pressed eq 'x') {
      push @parts, 'backbeat';
      $common{backbeat} = sub {
        my (%args) = @_;
        $args{drummer}->note(
          $args{drummer}->quarter,
          $args{drummer}->open_hh,
          $_ % 2 ? $args{drummer}->kick : $args{drummer}->snare
        ) for 1 .. $args{drummer}->beats;
      };
      print "Backbeat\n" if $verbose;
    }

    $loop->loop_stop if $key->type_is_unicode and
                        $key->utf8 eq "C" and
                        $key->modifiers & KEYMOD_CTRL;
  },
);

$loop->add($tka);
$loop->loop_forever;

sub part {
  my (%args) = @_;

  my $part = sub {
    $args{$_}->(%args) for $args{parts}->@*;
  };

  return $part;
}
