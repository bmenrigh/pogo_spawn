#!/usr/bin/perl

use strict;
use warnings;

my %id_bcr = ();
my %id_ambiguous = ();
my %id_warned = ();

# Manually determined BCRs for new releases
$id_bcr{906} = 0.2; # Sprigatito
$id_bcr{909} = 0.2; # Fuecoco
$id_bcr{912} = 0.2; # Quaxly
$id_bcr{915} = 0.5; # Lechonk

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
                 0.7903);    # 40

# 1 BULBASAUR 0.2
# 2 IVYSAUR 0.1
# 3 VENUSAUR 0.05
# 4 CHARMANDER 0.2
# 5 CHARMELEON 0.1

my $bcr_cmd = 'xzcat ./resources/gamemaster_bcr.json.xz | jq -r \'.[] | if (.templateId | test("^V[0-9]+_POKEMON_") == true) and .data.pokemonSettings.encounter.baseCaptureRate != null then [(.templateId | capture("^V0*(?<num>[0-9]+)").num), .] | @text "\(.[0]) \(.[1].data.pokemonSettings.pokemonId) \(.[1].data.pokemonSettings.encounter.baseCaptureRate)" else empty end\'';

my $bcr_list = `$bcr_cmd`;
foreach my $bcr_line (split(/[\r\n]+/, $bcr_list)) {
    if ($bcr_line =~ m/^(\d+)\s+(\S+)\s+([\d.]+)$/) {
        my ($id, $name, $bcr) = ($1, $2, $3);

        unless (exists $id_bcr{$id}) {
            $id_bcr{$id} = $bcr;
        } else {
            if ($id_bcr{$id} != $bcr) {
                warn 'Found ambiguous species: ', $name, "\n";
                $id_ambiguous{$id} = 1;
            }
        }
    }
}

foreach my $id (keys %id_ambiguous) {
    if (exists $id_bcr{$id}) {
        delete $id_bcr{$id};
    }
}


# $ ls -1 /tmp/archive_2023-08-18.tar.xz | while read LINE; do tar -OJxvf $LINE; done | ./parse_scan_db_dump.pl | head
#1000021822152479211	399	1667	BIDOOF	0	pogosj908194	25	0.25350344181061	3.229618787765502	1692337267	9263800794866515968	3	37.48119918136018	-122.28935729345841
#10000328550526847816	659	0	BUNNELBY	0	pogosj908649	21	0.33218926191330	4.12751007080078	3	1692340680	9263400716515409920	3	37.22155792335246	-121.96690717105919
#10000417366113232679	761	0	BOUNSWEET	0	SFp0g0SJ110920	25	0.36741191148758	4.79993009567261	3	1692339848	9263844790364012544	0	37.39456957494225	-121.97490458699795

my $n = 0;
my $catch_r = 0.0;
my $catch_b = 0.0;
my $catch_y = 0.0;
while (my $line = <STDIN>) {
    chomp($line);

    my @fields = split(/\t/, $line);

    my ($id, $name, $lvl) = ($fields[1], $fields[4], $fields[6]);

    next if (exists $id_ambiguous{$id});

    unless (exists $id_bcr{$id}) {
        unless (exists $id_warned{$id}) {
            warn sprintf('Need bcr for id #%d (%s)', $id, $name), "\n";
            $id_warned{$id} = 1;
        }
        next;
    }

    $n++;
    $catch_r += cr_by_level($id_bcr{$id}, $lvl, 1.4);
    $catch_b += cr_by_level($id_bcr{$id}, $lvl, 1.4 * 1.5);
    $catch_y += cr_by_level($id_bcr{$id}, $lvl, 1.4 * 2.0);
}

print sprintf("Catch rate for %d spawns: red: %.05f; blue: %.05f; yellow: %.05f\n", $n, $catch_r / ($n * 1.0), $catch_b / ($n * 1.0), $catch_y / ($n * 1.0));


sub get_cpm_by_level {
    my $lvl = shift;

    unless ($lvl =~ m/^\d+(\.5)?$/) {
        die 'Level malformed!', "\n";
    }

    if (($lvl < 1) || ($lvl > 40)) {
        die 'Level outside of 1-40 range', "\n";
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


sub cr_by_level {
    my $bcr = shift; # base capture rate
    my $lvl = shift;  # level
    my $mult = shift; # multipliers

    my $cr = fcr($bcr, get_cpm_by_level($lvl), $mult);

    #warn sprintf('brc: %f; mult: %f; lvl: %f; cr: %f', $bcr, $mult, $lvl, $cr), "\n";

    return $cr;
}


# Final capture rate
sub fcr {
    my $bcr = shift; # base capture rate
    my $cpm = shift; # cp modifier
    my $mult = shift; # multipliers

    my $sub_adj = (1.0 - ((1.0 * $bcr) / (2.0 * $cpm)));

    if ($sub_adj >= 1.0) {
        return 0.0;
    }

    if ($sub_adj <= 0.0) {
        return 1.0;
    }

    my $cr = (1.0 - (($sub_adj) ** (1.0 * $mult)));

    #print $cr, "\n";

    if ($cr >= 1.0) {
        $cr = 1.0;
    }

    return $cr;
}
