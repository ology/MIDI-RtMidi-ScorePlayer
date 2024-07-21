#!/usr/bin/env perl
use strict;
use warnings;

# WORK IN PROGRESS. YMMV.
# Use The Source, Luke.
# Patches welcome!

use IO::Async::Loop ();
use MIDI::Drummer::Tiny ();
use MIDI::RtMidi::ScorePlayer ();
use MIDI::Util qw(dura_size reverse_dump);
use Term::TermKey::Async qw(FORMAT_VIM KEYMOD_CTRL);
use Time::HiRes qw(time);

my $verbose = shift || 0;

my %common;
my @parts;
my $bpm  = 100;
my $dura = 'qn';
my $mode = 'serial';
my $loop = IO::Async::Loop->new;
my $tka  = Term::TermKey::Async->new(
  term   => \*STDIN,
  on_key => sub {
    my ($self, $key) = @_;
    my $pressed = $self->format_key($key, FORMAT_VIM);
    # print "Got key: $pressed\n" if $verbose;
    # PLAY SCORE
    if ($pressed eq ' ') {
      print "Play score\n" if $verbose;
      my $d = MIDI::Drummer::Tiny->new(
        bpm  => $bpm,
        file => 'rt-drummer.mid',
      );
      $common{drummer} = $d;
      $common{parts}   = \@parts;
      my $parts = [];
      if ($mode eq 'serial') {
        $parts = [ sub {
          my (%args) = @_;
          return sub { $args{$_}->(%args) for $args{parts}->@* };
        } ];
      }
      elsif ($mode eq 'parallel') {
        my %by_name;
        for my $part (@parts) {
          my ($name) = split /\./, $part;
          push $by_name{$name}->@*, $common{$part};
        }
        for my $part (keys %by_name) {
          my $p = sub {
            my (%args) = @_;
            return sub { $_->(%args) for $by_name{$part}->@* };
          };
          push @$parts, $p;
        }
      }
      MIDI::RtMidi::ScorePlayer->new(
        score    => $d->score,
        common   => \%common,
        parts    => $parts,
        sleep    => 0,
        infinite => 0,
        # dump     => 1,
      )->play;
    }
    # RESET SCORE
    elsif ($pressed eq 'r') {
      print "Reset score\n" if $verbose;
      %common = ();
      @parts  = ();
    }
    # WRITE SCORE TO FILE
    elsif ($pressed eq 'w') {
      my $file = $common{drummer}->file;
      $common{drummer}->write;
      print "Wrote to $file\n" if $verbose;
    }
    # SERIAL MODE
    elsif ($pressed eq 'm') {
      $mode = 'serial';
      print "Mode: $mode\n" if $verbose;
    }
    # PARALLEL MODE
    elsif ($pressed eq 'M') {
      $mode = 'parallel';
      print "Mode: $mode\n" if $verbose;
    }
    # FASTER
    elsif ($pressed eq 'b') {
      $bpm += 5 if $bpm < 127;
      print "BPM: $bpm\n" if $verbose;
    }
    # SLOWER
    elsif ($pressed eq 'B') {
      $bpm -= 5 if $bpm > 0;
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
        $args{drummer}->note(
          $args{'hihat.duration.' . $id},
          $args{drummer}->closed_hh
        );
      };
      $common{'hihat.duration.' . $id} = $dura;
      $common{'hihat.' . $id} = $part;
      push @parts, 'hihat.' . $id;
      snippit($part, \%common);
    }
    # HIHAT REST
    elsif ($pressed eq '<Backspace>') { # same key as <C-h>
      print "Hihat rest\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->rest($args{'hihat.duration.' . $id});
      };
      $common{'hihat.duration.' . $id} = $dura;
      $common{'hihat.' . $id} = $part;
      push @parts, 'hihat.' . $id;
    }
    # CRASH
    elsif ($pressed eq 'a') {
      print "Crash 1\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note(
          $args{'crash1.duration.' . $id},
          $args{drummer}->crash1
        );
      };
      $common{'crash1.duration.' . $id} = $dura;
      $common{'crash1.' . $id} = $part;
      push @parts, 'crash1.' . $id;
      snippit($part, \%common);
    }
    # CRASH1 REST
    elsif ($pressed eq '<C-a>') {
      print "Crash 1 rest\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->rest($args{'crash1.duration.' . $id});
      };
      $common{'crash1.duration.' . $id} = $dura;
      $common{'crash1.' . $id} = $part;
      push @parts, 'crash1.' . $id;
    }
    elsif ($pressed eq 'q') {
      print "Crash 2\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note(
          $args{'crash2.duration.' . $id},
          $args{drummer}->crash2
        );
      };
      $common{'crash2.duration.' . $id} = $dura;
      $common{'crash2.' . $id} = $part;
      push @parts, 'crash2.' . $id;
      snippit($part, \%common);
    }
    # CRASH2 REST
    elsif ($pressed eq '<C-q>') {
      print "Crash2 rest\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->rest($args{'crash2.duration.' . $id});
      };
      $common{'crash2.duration.' . $id} = $dura;
      $common{'crash2.' . $id} = $part;
      push @parts, 'crash2.' . $id;
    }
    # KICK
    elsif ($pressed eq 'k') {
      print "Kick\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note(
          $args{'kick.duration.' . $id},
          $args{drummer}->kick
        );
      };
      $common{'kick.duration.' . $id} = $dura;
      $common{'kick.' . $id} = $part;
      push @parts, 'kick.' . $id;
      snippit($part, \%common);
    }
    # KICK REST
    elsif ($pressed eq '<C-k>') {
      print "Kick rest\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->rest($args{'kick.duration.' . $id});
      };
      $common{'kick.duration.' . $id} = $dura;
      $common{'kick.' . $id} = $part;
      push @parts, 'kick.' . $id;
    }
    # SNARE
    elsif ($pressed eq 's') {
      print "Snare\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note(
          $args{'snare.duration.' . $id},
          $args{drummer}->snare
        );
      };
      $common{'snare.duration.' . $id} = $dura;
      $common{'snare.' . $id} = $part;
      push @parts, 'snare.' . $id;
      snippit($part, \%common);
    }
    # SNARE REST
    elsif ($pressed eq '<C-s>') {
      print "Snare rest\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->rest($args{'snare.duration.' . $id});
      };
      $common{'snare.duration.' . $id} = $dura;
      $common{'snare.' . $id} = $part;
      push @parts, 'snare.' . $id;
    }
    # BASIC BEAT
    elsif ($pressed eq 'x') {
      print "Basic backbeat\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        $args{drummer}->note(
          $args{'backbeat.duration.' . $id},
          $_ % 2 ? $args{drummer}->kick : $args{drummer}->snare
        ) for 1 .. int($args{drummer}->beats / 2);
      };
      $common{'backbeat.duration.' . $id} = $dura;
      $common{'backbeat.' . $id} = $part;
      push @parts, 'backbeat.' . $id;
      snippit($part, \%common);
    }
    # BASIC BEAT REST
    elsif ($pressed eq '<C-x>') {
      print "Basic backbeat rest\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        my $size = dura_size($args{'backbeat.duration.' . $id});
        my $x = $size * 2;
        my $twice = reverse_dump('length')->{$x};
        $args{drummer}->rest($twice);
      };
      $common{'backbeat.duration.' . $id} = $dura;
      $common{'backbeat.' . $id} = $part;
      push @parts, 'backbeat.' . $id;
    }
    # DOUBLE KICK BEAT
    elsif ($pressed eq 'X') {
      print "Double kick backbeat\n" if $verbose;
      my $id = time();
      my $part = sub {
        my (%args) = @_;
        my $size = dura_size($args{'backbeat.duration.' . $id});
        my $x = $size / 2;
        my $half = reverse_dump('length')->{$x};
        $args{drummer}->note($half, $args{drummer}->kick);
        $args{drummer}->note($half, $args{drummer}->kick);
        $args{drummer}->note($half, $args{drummer}->snare);
        $args{drummer}->rest($half);
      };
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
  my $d = MIDI::Drummer::Tiny->new(bpm => $bpm);
  $common{drummer} = $d;
  MIDI::RtMidi::ScorePlayer->new(
    score    => $d->score,
    common   => $common,
    parts    => [ $part ],
    sleep    => 0,
    infinite => 0,
  )->play;
}

sub rest_patch {
  my ($name) = @_;
  print ucfirst($name), " rest\n" if $verbose;
  my $id = time();
  my $part = sub {
    my (%args) = @_;
    $args{drummer}->rest($args{ "$name.duration.$id" });
  };
  $common{ "$name.duration.$id" } = $dura;
  $common{ "$name.$id" } = $part;
  push @parts, "$name.$id";
}
