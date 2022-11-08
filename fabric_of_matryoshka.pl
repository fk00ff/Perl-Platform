#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Scalar::Util qw(looks_like_number);
use Data::Dumper;

print "Remove old try....\n";
my @old_intf=`nmcli con sh | awk '/?b0\./ {print \$2}'`;
foreach my $old (@old_intf) {
    print $old;
    `nmcli con delete $old`;
}

my @interfaces=`nmcli con sh | awk '/ ethernet / {print \$0}'`;
#
my $n = 0;
foreach my $line (@interfaces) {
    print $line;
    $n=$n+1;
}

my $proceed_number_line = \&check_num_line;
my $proceed_num = \&check_num;
my $proceed_ip = \&check_ip;

my @LAN_bond = input('Enter Interfaces numbs for create -L-AN bond:', $proceed_number_line);
my @SAN_bond = input('Enter Interfaces numbs for create *S*AN bond:', $proceed_number_line);
print "\n";
my @LAN_VLAN = input('-L-AN VLAD ID:', $proceed_num);
my @SAN_VLAN = input('*S*AN VLAN ID:', $proceed_num);
print "\n";
my @LAN_IP = input('-L-AN IP:', $proceed_ip);
my @SAN_IP = input('*S*AN IP:', $proceed_ip);

my @body = ();

$body[0] = "#!/bin/bash\n"."nmcli con add type bond ifname mb0\n";

foreach my $LAN_e_num (@LAN_bond) {
    my $LAN_e_name = get_con_name(0+$LAN_e_num);
    push @body, "nmcli con add type ethernet ifname $LAN_e_name master mb0\n";
}
{
    my $LAN_VLAN_ID = 0+$LAN_VLAN[0];
    push @body, "nmcli con add type vlan con-name mb0.$LAN_VLAN_ID ifname mb0.$LAN_VLAN_ID dev mb0 id $LAN_VLAN_ID\n";
}
{
    push @body, "nmcli con add type brudge ...\n";

    push @body, "\n";
}

foreach my $SAN_e_num (@SAN_bond) {
    my $SAN_e_name = get_con_name(0+$SAN_e_num);
    push @body, "nmcli con add type ethernet ifname $SAN_e_name master mb0\n";
}
{
    my $SAN_VLAN_ID = 0+$SAN_VLAN[0];
    my $SAN_VLAN_GW = $SAN_IP[0]; # replace last octet
    push @body, "nmcli con add type vlan con-name sb0.$SAN_VLAN_ID ifname sb0.$SAN_VLAN_ID dev sb0 id $SAN_VLAN_ID ip4 $SAN_IP[0]/24 gw4 $SAN_VLAN_GW\n";

    push @body, "\n";
}
push @body, "systemctl restart NetworkManager.service\n";

open my $fh, ">", 'create-matryoshka.sh' or die "Can't write to file 'create-matryoshka.sh'";
print $fh "@body\n";
close $fh;

print "Use:\nchmod +x create-matryoshka.sh\n./create-matryoshka.sh\n";
print "\n";

exit(0);

sub get_con_name {
    my ($n) = @_;
    my @columns = split " ", $interfaces[$n];
    return $columns[-1];
}

sub input {
    my ($prompt, $checker) = @_;
    my $for_bond_ref;

    while (1) {
        print $prompt;
        my $intfs;

        while(!defined($intfs = <STDIN>)) {};

        (my $is_good, $for_bond_ref) = $checker -> ($intfs);
        last if $is_good == 1;
    }

    return @{$for_bond_ref};
}

sub check_num_line {
    my ($line) = @_;
    chomp $line;

    my @lines = split " |,", $line;
    my $good = 1;

    CHECK:
    for my $intf (@lines) {
        if ( !looks_like_number($intf) ) {
            print 'Available only Numbers separated by " " or ","!'; print("\n");
            $good=0;
            last CHECK;
        }
    }

    return ($good, \@lines);
}

sub check_num {
    my ($line) = @_;
    chomp $line;

    my $good = looks_like_number($line) ? 1 : 0;
    if (!$good) {
        print 'Available only single Number!'; print "\n";
    }

    my @lines = ($line);

    return $good, \@lines;
}

sub check_ip {
    my ($line) = @_;
    chomp $line;

    my $good = $line =~ /(^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$)/ ? 1 : 0;
    if (!$good) {
        print 'Available only correct IP address!'; print "\n";
    }

    my @lines = ($line);

    return $good, \@lines;
}
