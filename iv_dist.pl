#!/usr/bin/perl

use strict;
use warnings;


# $ ls -1 /tmp/archive_2023-08-18.tar.xz | while read LINE; do tar -OJxvf $LINE; done | ./parse_scan_db_dump.pl | head dump_2023-08-18_rdmdb-0002.sql
# 1000021822152479211	399	1667	BIDOOF	3	25	5	8	9
# 10000328550526847816	659	0	BUNNELBY	3	21	5	12	13
# 10000417366113232679	761	0	BOUNSWEET	0	25	1	4	10

# unboosted
my @iv_ub_atk = ((0) x 16);
my @iv_ub_def = ((0) x 16);
my @iv_ub_hp = ((0) x 16);
my @iv_ub_amb = ((0) x 16);
my @iv_ub_amc = ((0) x 16);
my @iv_ub_bmc = ((0) x 16);
my $n_ub = 0;

# boosted
my @iv_wb_atk = ((0) x 16);
my @iv_wb_def = ((0) x 16);
my @iv_wb_hp = ((0) x 16);
my @iv_wb_amb = ((0) x 16);
my @iv_wb_amc = ((0) x 16);
my @iv_wb_bmc = ((0) x 16);
my $n_wb = 0;
while (my $line = <STDIN>) {
    chomp($line);

    my @fields = split(/\t/, $line);

    my ($l, $atk_iv, $def_iv, $hp_iv) = ($fields[5], $fields[6], $fields[7], $fields[8]);

    my ($amb, $amc, $bmc) = ((($atk_iv - $def_iv) + 16) % 16, (($atk_iv - $hp_iv) + 16) % 16, (($def_iv - $hp_iv) + 16) % 16);

    if ($l < 6) {
        $iv_ub_atk[$atk_iv] += 1;
        $iv_ub_def[$def_iv] += 1;
        $iv_ub_hp[$hp_iv] += 1;

        $iv_ub_amb[$amb] += 1;
        $iv_ub_amc[$amc] += 1;
        $iv_ub_bmc[$bmc] += 1;

        $n_ub += 1;
    } elsif ($l > 30) {
        $iv_wb_atk[$atk_iv] += 1;
        $iv_wb_def[$def_iv] += 1;
        $iv_wb_hp[$hp_iv] += 1;

        $iv_wb_amb[$amb] += 1;
        $iv_wb_amc[$amc] += 1;
        $iv_wb_bmc[$bmc] += 1;

        $n_wb += 1;
    }
}

print sprintf('# unboosted n: %d; boosted n: %d', $n_ub, $n_wb), "\n";
for (my $i = 0; $i < 16; $i++) {
    print sprintf("%d\t%.07f\t%.07f\t%.07f\t%.07f\t%.07f\t%.07f\n", $i,
                  ($iv_ub_atk[$i] * 1.0) / ($n_ub * 1.0), ($iv_ub_def[$i] * 1.0) / ($n_ub * 1.0),($iv_ub_hp[$i] * 1.0) / ($n_ub * 1.0),
                  ($iv_wb_atk[$i] * 1.0) / ($n_wb * 1.0), ($iv_wb_def[$i] * 1.0) / ($n_wb * 1.0),($iv_wb_hp[$i] * 1.0) / ($n_wb * 1.0));
}

print sprintf('# lagged amb, amc, bmc'), "\n";
for (my $i = 0; $i < 16; $i++) {
    print sprintf("%d\t%d\t%d\t%d\t%d\t%d\t%d\n", $i,
                  $iv_ub_amb[$i], $iv_ub_amc[$i], $iv_ub_bmc[$i],
                  $iv_wb_amb[$i], $iv_wb_amc[$i], $iv_wb_bmc[$i]);

}
