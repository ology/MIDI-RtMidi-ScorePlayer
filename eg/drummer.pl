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
    # PLAY
    if ($pressed eq 'p') {
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
      print "Play score\n" if $verbose;
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
    # RESET
    elsif ($pressed eq 'r') {
      %common = ();
      @parts  = ();
      print "Reset score\n" if $verbose;
    }
    # SNARE
    elsif ($pressed eq 's') {
      push @parts, 'snare';
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note('sn', $args{drummer}->snare)
          for 1 .. 4;
      };
      my $d = snippit($part, $bpm);
      $common{snare}   = $part;
      $common{drummer} = $d;
      $common{parts}   = \@parts;
      print "Snare\n" if $verbose;
    }
    # BEAT
    elsif ($pressed eq 'x') {
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
      print "Backbeat\n" if $verbose;
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
