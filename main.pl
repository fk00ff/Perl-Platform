#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Scalar::Util qw(looks_like_number);
use Data::Dumper;

print "Remove old try....\n";
my @old_intf=`nmcli con sh | awk '/?m0./ {print \$2}'`;
foreach my $old (@old_intf) {
    print $old;
    `nmcli con delete $old`;
}

my @interfaces=`nmcli con sh | awk '/^.+/ {print \$0}'`;
my $n = 0;
#
foreach my $line (@interfaces) {
    print $n == 0? '   ': $n.'. ', $line;
    $n=$n+1;
}

my @LAN_bond = input('Enter Interfaces numbs for create -L-AN bond:');
my @SAN_bond = input('Enter Interfaces numbs for create *S*AN bond:');
my @LAN_VLAN = input('-L-AN VLAD ID:');
my @SAN_VLAN = input('*S*AN VLAN ID:');
my $LAN_IP = input('-L-AN IP:');
if (

my @SAN_IP = input('*S*AN IP:');


my @body;
@body=();

$body[0] = "#!/bin/bash\n"."nmcli con add type bond ifname mb0\n";

foreach my $LAN_e_num (@LAN_bond) {
    my $LAN_e_name = get_con_name(0+$LAN_e_num);
    push @body, "nmcli con add type ethernet ifname $LAN_e_name master mb0\n";
}
{
    my $LAN_VLAN_ID = 0+shift(@LAN_VLAN);
    push @body, "nmcli con add type vlan id=$LAN_VLAN_ID\n";
}
{
    push @body, "nmcli con add type brudge ...\n";
}

foreach my $SAN_e_num (@SAN_bond) {
    my $SAN_e_name = get_con_name(0+$SAN_e_num);
    push @body, "nmcli con add type ethernet ifname $SAN_e_name master mb0\n";
}
{
    my $SAN_VLAN_ID = 0+shift(@SAN_VLAN);
    push @body, "nmcli con add type vlan id=$SAN_VLAN_ID\n";
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
    my ($prompt) = @_;
    my $for_bond_ref;

    while (1) {
        print $prompt;
        my $intfs;

        while(!defined($intfs = <STDIN>)) {};

        (my $is_good, $for_bond_ref) = check_line($intfs);
        last if $is_good == 1;
    }

    return @{$for_bond_ref};
}

sub check_line {
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
