#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

# INSERT INTO `pokemon` (`id`, `pokestop_id`, `spawn_id`, `lat`, `lon`, `weight`, `size`, `expire_timestamp`, `updated`, `pokemon_id`, `move_1`, `move_2`, `gender`, `cp`, `atk_iv`, `def_iv`, `sta_iv`, `form`, `level`, `weather`, `costume`, `first_seen_timestamp`, `changed`, `cell_id`, `expire_timestamp_verified`, `shiny`, `username`, `display_pokemon_id`, `is_ditto`, `seen_type`, `capture_1`, `capture_2`, `capture_3`, `pvp`, `pvp_rankings_great_league`, `pvp_rankings_ultra_league`, `is_event`) VALUES ('10000021849850713756',NULL,NULL,37.36504978683373,-122.11924598793581,NULL,NULL,1670832494,1670831174,198,NULL,NULL,1,NULL,NULL,NULL,NULL,855,NULL,0,0,1670831174,1670831174,9263817583893676032,0,NULL,'pogosj1AT0265',NULL,0,'nearby_cell',NULL,NULL,NULL,NULL,NULL,NULL,0),...


my %extract_fields = ('id' => 1,
                      'spawn_id' => 1,
                      'lat' => 1,
                      'lon' => 1,
                      'weight' => 1,
                      'height' => 1,
                      'size' => 1,
                      'pokemon_id' => 1,
                      'atk_id' => 1,
                      'def_id' => 1,
                      'sta_id' => 1,
                      'form' => 1,
                      'level' => 1,
                      'shiny' => 1,
                      'username' => 1,
                      'weather' => 1,
                      'cell_id' => 1,
                      'first_seen_timestamp' => 1,
                      'is_ditto', => 1,
                      'seen_type', => 1);


my $encounter_limit = 500000;
my $encounter_count = 0;
my $encounter_ids_ref;
my $encounter_ids_ref_old;

{
    my %tmp1 = ();
    my %tmp2 = ();
    $encounter_ids_ref = \%tmp1;
    $encounter_ids_ref_old = \%tmp2;
}

my %name = ();

my $GM_PATH = './resources/gamemaster.json.xz';

my $data_cmd_fmt = 'cat "%s" | xz -d | jq -r \'.[] | if .templateId | test("^V[0-9]+_POKEMON_") == true then [(.templateId | capture("^V0*(?<num>[0-9]+)").num), .] | @text "\(.[0]) \(.[1].data.pokemonSettings.pokemonId) \(.[1].data.pokemonSettings.pokedexHeightM) \(.[1].data.pokemonSettings.pokedexWeightKg)" else empty end\'';

my $cmd = sprintf($data_cmd_fmt, $GM_PATH);
my $ret = `$cmd`;

# 862 OBSTAGOON 1.6 46.0
foreach my $line (split(/[\n\r]+/, $ret)) {
    if ($line =~ m/^(\d+)\s+([A-Z_]+)\s+([\d.]+)\s+([\d.]+)$/) {
        my ($dex, $namestr, $h, $w) = ($1, $2, $3, $4);

        $name{$dex} = $namestr unless (exists $name{$dex});
    }
}


while (<STDIN>) {
    my $line = $_;
    chomp($line);

    if ($line =~ m/^INSERT\s+INTO\s+`pokemon`\s+\(([^)]*)\)\s+VALUES\s+(.*)/) {
        my $keys = $1;
        my $vlist = $2;

        my @klist = ();
        while ($keys =~ m/`([^`]+)`(?=(,|$))/g) {
            #print 'key: "', $1, '"', "\n";
            push @klist, $1;
        }

        #print 'keys: ', join(', ', @klist), "\n";

        # Check if there is a height field, if not size
        # needs to be renamed to height
        my $hasheight = 0;
        foreach my $f (@klist) {
            if ($f eq 'height') {
                $hasheight = 1;
                last;
            }
        }

        while ($vlist =~ m/\(([^)]+)\)/g) {
            my $enc = $1;

            # Parse each value in the encouter list
            my @enc_vals = ();
            while ($enc =~ m/((?:[NUL0-9.-]+|\'[^\']+\'))(?=(,|$))/g) {
                my $val = $1;
                if ($val =~ m/^'([^\']+)\'/) {
                    $val = $1;
                }

                push @enc_vals, $val;
            }

            my %spawn = ();
            for (my $i = 0; $i < scalar(@enc_vals); $i++) {
                my $fname = $klist[$i];
                my $fval = $enc_vals[$i];

                # Rename size to height if we don't have a height field
                if (($fname eq 'size') && ($hasheight == 0)) {
                    $fname = 'height';

                    $spawn{'size'} = 'NULL';
                }

                if (exists $extract_fields{$fname}) {
                    $spawn{$fname} = $fval;
                }
            }

            # Skip if we don't have basic encounter details (because it was seen on nearby for example)
            if (($spawn{'level'} eq 'NULL') || ($spawn{'weight'} eq 'NULL')) {
                next;
            }

            # Prevent reporting a spawn mulitple times
            next if (exists $encounter_ids_ref->{$spawn{'id'}});
            next if (exists $encounter_ids_ref_old->{$spawn{'id'}});
            $encounter_ids_ref->{$spawn{'id'}} = 1;
            $encounter_count += 1;

            if ($encounter_count >= $encounter_limit) {
                my %tmp = ();
                $encounter_ids_ref_old = $encounter_ids_ref;
                $encounter_ids_ref = \%tmp;
                $encounter_count = 0;
            }

            #if ($spawn{'height'} eq 'NULL') {
            #    print Data::Dumper->Dump([\%spawn], ['*spawn']), "\n";
            #    print $enc, "\n";
            #}

            # old height/weight study output
            #print sprintf("%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n", $spawn{'pokemon_id'}, $spawn{'form'}, $name{$spawn{'pokemon_id'}}, $spawn{'shiny'}, $spawn{'height'}, $spawn{'weight'}, $spawn{'size'}, $spawn{'first_seen_timestamp'});

            print join("\t", (
                           $spawn{'id'},
                           $spawn{'pokemon_id'},
                           $spawn{'form'},
                           $name{$spawn{'pokemon_id'}},
                           $spawn{'shiny'},
                           $spawn{'username'},
                           $spawn{'level'},
                           $spawn{'height'},
                           $spawn{'weight'},
                           $spawn{'size'},
                           $spawn{'first_seen_timestamp'},
                           $spawn{'cell_id'},
                           $spawn{'weather'},
                           $spawn{'lat'},
                           $spawn{'lon'}
                       )), "\n";
        }
    }
}
