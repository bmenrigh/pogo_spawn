#!/usr/bin/perl

use strict;
use warnings;

my %atk = ();
my %def = ();
my %hp = ();

my %name = ();

my %ambiguous = ();

my @cpm_table = (0.094,
                 0.16639787,
                 0.21573247,
                 0.25572005,
                 0.29024988, # 5
                 0.3210876,
                 0.34921268,
                 0.3752356,
                 0.39956728,
                 0.4225,     # 10
                 0.44310755,
                 0.4627984,
                 0.48168495,
                 0.49985844,
                 0.51739395, # 15
                 0.5343543,
                 0.5507927,
                 0.5667545,
                 0.5822789,
                 0.5974,     # 20
                 0.6121573,
                 0.6265671,
                 0.64065295,
                 0.65443563,
                 0.667934,   # 25
                 0.6811649,
                 0.69414365,
                 0.7068842,
                 0.7193991,
                 0.7317,     # 30
                 0.7377695,
                 0.74378943,
                 0.74976104,
                 0.7556855,
                 0.76156384, # 35
                 0.76739717,
                 0.7731865,
                 0.77893275,
                 0.784637,
                 0.7903,     # 40
                 0.7953,
                 0.8003,
                 0.8053,
                 0.8103,
                 0.8153,     # 45
                 0.8203,
                 0.8253,
                 0.8303,
                 0.8353,
                 0.8403,     # 50
                 0.8453,
                 0.8503,
                 0.8553,
                 0.8603,
                 0.8653);    # 55


my $GM_PATH = '/home/brenrigh/projects/github/pogo_spawn/resources/gamemaster.json.xz';

my $data_cmd_fmt = 'cat "%s" | xz -d | jq -r \'.[] | if .templateId | test("^V[0-9]+_POKEMON_") == true then [(.templateId | capture("^V0*(?<num>[0-9]+)").num), .] | @text "\(.[0]) \(.[1].data.pokemonSettings.pokemonId) \(.[1].data.pokemonSettings.pokedexHeightM) \(.[1].data.pokemonSettings.pokedexWeightKg) \(.[1].data.pokemonSettings.stats.baseAttack) \(.[1].data.pokemonSettings.stats.baseDefense) \(.[1].data.pokemonSettings.stats.baseStamina)" else empty end\'';

my $cmd = sprintf($data_cmd_fmt, $GM_PATH);
my $ret = `$cmd`;

foreach my $line (split(/[\n\r]+/, $ret)) {
    if ($line =~ m/^(\d+)\s+([A-Z_]+)\s+([\d.]+)\s+([\d.]+)\s+(\d+)\s+(\d+)\s+(\d+)$/) {
        my ($dex, $namestr, $height, $weight, $a, $d, $h) = ($1, $2, $3, $4, $5, $6, $7);

        next if (exists $ambiguous{$dex});

        $name{$dex} = $namestr unless (exists $name{$dex});

        if ((exists $atk{$dex}) && ($atk{$dex} != $a)) {
            $ambiguous{$dex} = 1;
            next;
        }
        if ((exists $def{$dex}) && ($def{$dex} != $d)) {
            $ambiguous{$dex} = 1;
            next;
        }
        if ((exists $hp{$dex}) && ($hp{$dex} != $h)) {
            $ambiguous{$dex} = 1;
            next;
        }

        $atk{$dex} = $a unless (exists $atk{$dex});
        $def{$dex} = $d unless (exists $def{$dex});
        $hp{$dex} = $h unless (exists $hp{$dex});
    }
}



while (my $line = <STDIN>) {
    chomp($line);

    # 10000359756918218020	216	1265	TEDDIURSA	19	13	14	0	676
    # 10000413090936818248	562	2084	YAMASK	22	11	10	7	567

    my ($dex, $name, $l, $a, $d, $h, $cp);
    if ($line =~ m/^(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/) {
        ($dex, $name, $l, $a, $d, $h, $cp) = ($2, $4, $5, $6, $7, $8, $9);
    } else {
        next;
    }

    next unless (exists $name{$dex});
    next if (exists $ambiguous{$dex});

    # warn sprintf('%s (%d) @%d %d/%d/%d with %d CP', $name, $dex, $l, $a, $d, $h, $cp), "\n";

    my $calc_cp = cp($dex, $l, $a, $d, $h);

    if ($calc_cp != int($cp)) {
        warn sprintf('%s (%d) @%d %d/%d/%d with true CP %d but calculated CP %d', $name, $dex, $l, $a, $d, $h, $cp, $calc_cp), "\n";

        print sprintf('check_specific_cp(get_cpm(%d, 0), "%s %d/%d/%d @%d", %d, %d, %d, %d, %d, %d, %d);', $l, pretty_name($name), $a, $d, $h, $l, $cp, $atk{$dex}, $def{$dex}, $hp{$dex}, $a, $d, $h), "\n";
    }
}


sub get_cpm_by_level {
    my $lvl = shift;

    unless ($lvl =~ m/^\d+(\.5)?$/) {
        die 'Level malformed!', "\n";
    }

    if (($lvl < 1) || ($lvl > 55)) {
        die 'Level outside of 1-55 range', "\n";
    }

    # Handle whole numbers first
    if ($lvl =~ m/^\d+$/) {
        return $cpm_table[$lvl - 1];
    }
    else {
        # Half levels are the quadratic mean
        return sqrt(($cpm_table[int($lvl) - 1] ** 2.0 +
                     $cpm_table[int($lvl)] ** 2.0) / 2.0);
    }
}


sub cp {
    my $dex = shift;
    my $l = shift;

    my $a_iv = shift;
    my $d_iv = shift;
    my $h_iv = shift;

    my ($a, $d, $h) = ($atk{$dex} * 1.0, $def{$dex} * 1.0, $hp{$dex} * 1.0);

    my $cpm = get_cpm_by_level($l);

    return max(10, int(((($a + $a_iv) * sqrt(($h + $h_iv) * ($d + $d_iv)) * ($cpm * $cpm)) / 10.0)));
}


sub max {
    my $a = shift;
    my $b = shift;

    return ($a > $b)? $a : $b;
}


sub pretty_name {
    my $name = shift;

    my $pretty = lc($name);

    substr($pretty, 0, 1) = uc(substr($pretty, 0, 1));

    return $pretty;
}
