#!/usr/bin/perl

use strict;
use warnings;

my %hbuckets = ();
my %wbuckets = ();
my %wvbuckets = ();

my %wtot_by_h = ();
my %wcnt_by_h = ();

my $foff = 2641;
my @hstart = (0.3, 0.4, 0.5, 0.6);
my @hend = (0.4, 0.5, 0.6, 0.8);
my @meanh = (0.3, 0.4, 0.5, 0.8);
my @meanw = (3.5, 5.0, 7.5, 15.0);
my @woff = (1.0, 1.0, 1.0, 1.0);

my $total = 0;

while (my $line = <STDIN>) {
    chomp($line);

    # 1000196106995496179	710	2642	PUMPKABOO	0	xxxxx	19	0.48785266280174	7.43106222152710	NULL	1666505421	9263846506203447296	1	37.32182427926086	-121.90904184987200
    my @fields = ();

    if ($line =~ m/^\d+\s+710\s+/) {
        @fields = split(/\s+/, $line);
    } else {
        next;
    }

    my $form = $fields[2];
    my $height = $fields[7];
    my $weight = $fields[8];

    next if ($form < $foff);
    next if ($form > $foff + 3);

    my $fidx = $form - $foff;

    #my $weightv = ($weight / $meanw[$fidx]) - (((($height - $hstart[$fidx]) / ($hend[$fidx] - $hstart[$fidx])) ** 2.0 - $woff[$fidx]));
    my $weightv = ($weight / $meanw[$fidx]) - (($height / $meanh[$fidx]) ** 2.0 - $woff[$fidx]);

    my $hbin = sprintf("%.02f", $height - 0.000);
    my $wbin = sprintf("%.02f", $weight - 0.000);
    my $wvbin = sprintf("%.02f", $weightv - 0.000);

    unless (exists $hbuckets{$hbin}) {
        $hbuckets{$hbin} = 0;

        $wtot_by_h{$hbin} = 0.0;
        $wcnt_by_h{$hbin} = 0;
    }
    $hbuckets{$hbin} += 1;

    $wtot_by_h{$hbin} += $weight;
    $wcnt_by_h{$hbin} += 1;

    unless (exists $wbuckets{$wbin}) {
        $wbuckets{$wbin} = 0;
    }
    $wbuckets{$wbin} += 1;

    unless (exists $wvbuckets{$wvbin}) {
        $wvbuckets{$wvbin} = 0;
    }
    $wvbuckets{$wvbin} += 1;

    $total++;
}

#foreach my $bin (sort {$a <=> $b} keys %hbuckets) {
#    print $bin, "\t", $hbuckets{$bin}, "\t", ($hbuckets{$bin} * 1.0) / ($total * 1.0), "\n";
#}

#foreach my $bin (sort {$a <=> $b} keys %wbuckets) {
#    print $bin, "\t", $wbuckets{$bin}, "\t", ($wbuckets{$bin} * 1.0) / ($total * 1.0), "\n";
#}

foreach my $bin (sort {$a <=> $b} keys %wvbuckets) {
    print $bin, "\t", $wvbuckets{$bin}, "\t", ($wvbuckets{$bin} * 1.0) / ($total * 1.0), "\n";
}

#foreach my $bin (sort {$a <=> $b} keys %wtot_by_h) {
#    print $bin, "\t", ($wtot_by_h{$bin} * 1.0) / ($wcnt_by_h{$bin} * 1.0), "\n";
#}
