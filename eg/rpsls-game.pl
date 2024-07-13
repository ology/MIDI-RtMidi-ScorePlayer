#!/usr/bin/env perl
use strict;
use warnings;

use Game::RockPaperScissorsLizardSpock qw(rpsls);
use MIDI::RtMidi::ScorePlayer ();
use MIDI::Util qw( setup_score set_chan_patch );
use Music::Scales qw( get_scale_MIDI );

my $choice = shift || die "Usage: perl $0 rock|paper|scissors|lizard|Spock\n";
 
if (my $result = rpsls($choice)) {
    if ($result == 3) {
        print "Its a tie!\n";
    }
    else {
        if ($result == 1) {
            print "Player 1 wins\n";
        }
        else {
            print "Player 2 wins\n";
        }
    }

    my $score = setup_score(lead_in => 0, bpm => 120);
    my %common = (score => $score, choice => $choice, result => $result);
    MIDI::RtMidi::ScorePlayer->new(
      score    => $score,
      parts    => [ \&part ],
      common   => \%common,
      sleep    => 0,
      infinite => 0,
    )->play;
}

sub part {
  my (%args) = @_;

  my @pitches = (
    get_scale_MIDI('C', 2, 'pentatonic'),
  );

  my $bass = sub {
    set_chan_patch( $args{score}, 0, 35 );

    for my $n (1 .. 4) {
      my $pitch = $pitches[ int rand @pitches ];
      $args{score}->n('qn', $pitch);
    }
  };

  return $bass;
}
