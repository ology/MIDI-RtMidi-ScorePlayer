#!/usr/bin/env perl
use strict;
use warnings;

use Game::Life::Faster ();
use MIDI::RtMidi::ScorePlayer ();
use MIDI::Util qw(setup_score set_chan_patch);
use Music::Scales qw(get_scale_MIDI);
use Term::ANSIScreen qw(cls);

END {
    my $score = setup_score(lead_in => 0);
    my $part = sub { return sub { $score->r('wn') } };
    MIDI::RtMidi::ScorePlayer->new(
      score    => $score,
      parts    => $part,
      sleep    => 0,
      infinite => 0,
    )->play;
}

my $size = shift || 12;

die "Can't have a size greater than 12 (music notes)\n"
    if $size > 12;

my $game = Game::Life::Faster->new($size);

my $matrix = [ map { [ map { int(rand 2) } 1 .. $size ] } 1 .. $size ];
$game->place_points(0, 0, $matrix);

my @parts = (\&part) x $size;

while (1) {
    cls();
    my @grid = $game->get_text_grid;
    my $grid = $game->get_text_grid;

    my $score = setup_score(lead_in => 0);
    my %common = (score => $score, grid => \@grid, size => $size, seen => {});

    print scalar $grid, "\n";

    MIDI::RtMidi::ScorePlayer->new(
      score    => $score,
      parts    => \@parts,
      common   => \%common,
      sleep    => 0,
      infinite => 0,
    )->play;

    $game->process;
    last unless $game->get_used_text_grid;
}

sub part {
    my (%args) = @_;

    my $patch = 0;#int rand 20;
    my $track = $args{size} - $args{_part};
    my $channel = $args{_part} < 9 ? $args{_part} : $args{_part} + 1;
    my $octave = ($args{_part} % 5) + 1;
    my @scale = (
        get_scale_MIDI('C', $octave, 'chromatic'),
    );
    my @row = split //, $args{grid}->[$track];

    my $part = sub {
        set_chan_patch($args{score}, $channel, $patch);

        my @pitches;
        for my $i (0 .. $args{size} - 1) {
            if ($row[$i] eq 'X') {
                my $pitch = $scale[$i];
                push @pitches, $pitch
                    unless $args{seen}->{$pitch}++;
            }
        }
        if (@pitches) {
            $args{score}->n('qn', @pitches);
        }
    };

    return $part;
}
