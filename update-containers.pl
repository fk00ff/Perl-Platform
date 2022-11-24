#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Data::Dumper;

chomp(my $home_path = `echo \$HOME`);
my @body = ("#!/bin/bash\n");
my $filter ='';

print "Load addresses ....\n";
my $ans_name = $home_path . '/used-addresses';
my @ips = ();
{

    open my $fh, "<", $ans_name or die "Can't open file '$ans_name'";

    @ips = <fh>;

    close $fh;
}

push @body, "echo .restart system containers ....";
$filter = q[awk 'if ($4 == "CT") {print $1, $5}}'];
my @sysc=`prlctl list -a | $filter`;
for my $sysc (@sysc) {
    my @a = split " ", $sysc;
    push @body, "echo - $a[1]";
    push @body, "prlctl restart $a[0]";
}

push @body, "echo .create system virtual network ....";
push @body, "prlsrvctl "



