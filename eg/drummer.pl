#!/usr/bin/env perl
use strict;
use warnings;

use IO::Async::Loop ();
use MIDI::Drummer::Tiny ();
use MIDI::RtMidi::ScorePlayer ();
use Music::Scales qw(get_scale_MIDI);
use Term::TermKey::Async qw(FORMAT_VIM KEYMOD_CTRL);

my %common;
my $bpm  = 100;
my $loop = IO::Async::Loop->new;
my $tka  = Term::TermKey::Async->new(
  term   => \*STDIN,
  on_key => sub {
    my ($self, $key) = @_;
    my $pressed = $self->format_key($key, FORMAT_VIM);
    print "Got key: $pressed\n";
    if ($pressed eq 'b') {
      $bpm += 5;
    }
    elsif ($pressed eq 'B') {
      $bpm -= 5;
    }
    elsif ($pressed eq 'p') {
      my $d = MIDI::Drummer::Tiny->new(
        bpm    => $bpm,
        reverb => 15,
      );
      $common{drummer} = $d;
      MIDI::RtMidi::ScorePlayer->new(
        score    => $d->score,
        parts    => [ \&part ],
        common   => \%common,
        sleep    => 0,
        infinite => 0,
      )->play;
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

  my @pitches = (
    get_scale_MIDI('C', 4, 'major'),
    get_scale_MIDI('C', 5, 'major'),
  );

  my $part = sub {
warn __PACKAGE__,' L',__LINE__,' ',$args{drummer}->bpm,"\n";
    $args{drummer}->note(
      $args{drummer}->quarter,
      $args{drummer}->open_hh,
      $_ % 2 ? $args{drummer}->kick : $args{drummer}->snare
    ) for 1 .. $args{drummer}->beats;
  };

  return $part;
}
