#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Data::Dumper;
use Functions;

chomp(my $home_path = `echo \$HOME`);
my @body = ("#!/bin/bash\n");
my $filter ='';

push @body, "echo .remove old try ....";
$filter = q[awk '/(^|br-)[sm]b0(\.| )/ {print $1,$2}'];
my @old_intf=`nmcli con sh | $filter`;
for my $old (@old_intf) {
    my @o = split " ", $old;
    push @body, "echo - $o[0]";
    push @body, "nmcli con delete $o[1]";
}

push @body, "echo .remove installation artefacts ....";
my @art_intf=`nmcli con sh`;
shift @art_intf;
for my $old (@art_intf) {
    my @o = split " ",$old;

    my $name;
    my $id;

    for my $s (@o) {
        if (length($s) == 36) {
            $id = $s;
            last;
        }
        $name .= ' '.$s;

    }

    push @body, "echo - $o[-2]: $name";
    push @body, "nmcli con delete $id";
}
push @body, "";

print "Ethernet connection list:\n";
$filter = q[ grep " UP " | awk '{print $1"\t\t"$3}'];
my @interfaces = `ip -br l | $filter`;
unshift @interfaces, "NAME\t\t\tMAC\n";
#
my $n=0;
for my $line (@interfaces) {
    print $n == 0? '   ': $n.'. ', $line;
    $n=$n+1;
}
print "\n";

my $proceed_number_line = \&check_num_line;
my $proceed_num = \&check_num;
my $proceed_ip = \&check_ip;
my $proceed_name = \&check_name;
my $proceed_gw = \&check_gw;
my $proceed_yn = \&check_yN;

my @LAN_VLAN = input('-L-AN VLAD ID:', $proceed_num);
my @LAN_GW_8 = input('-LAN- gateway last octet [254]:', $proceed_gw);
my @LAN_IP = input('-L-AN IP:', $proceed_ip);
my @LAN_bond = input('Enter Interfaces numbs for create -L-AN bond:', $proceed_number_line);
print "\n";
my @SAN_VLAN = input('*S*AN VLAN ID:', $proceed_num);
my @SAN_IP = input('*S*AN IP:', $proceed_ip);
my @SAN_bond = input('Enter Interfaces numbs for create *S*AN bond:', $proceed_number_line);
print "\n";
my @COPY_NTP = input('Use external(existed) NTP server [yN]:', $proceed_yn);
my @NTP_IP = input('NTP IP:', $proceed_ip);
print "\n";
my @COPY_SMB = input('Use external(existed) SMB/CIFS server [yN]:', $proceed_yn);
my @SMB_IP = input('SMB IP:', $proceed_ip);
print "\n";
my @DNS_IP = input('DNS IP:', $proceed_ip);
my @DNS_DOMAIN = input('Search Domain:', $proceed_name);
print "\n";
my @HOST_NAME = input("Aaand this Host name:", $proceed_name);

print "\nsave answers ....\n";
my $ans_name = $home_path . '/used-addresses';
{
    open my $fh, ">", $ans_name or die "Can't write to file '$ans_name'";
    print $fh "VLAN=$LAN_VLAN[0]\n";
    print $fh "IP=$LAN_IP[0]\n";
    print $fh "GW=$LAN_IP[1]\n";
    print $fh "DNS=$DNS_IP[0]\n";
    print $fh "EXT-NTP=$COPY_NTP[0]\n";
    print $fh "NTP=$NTP_IP[0]\n";
    print $fh "EXT-SMB=$COPY_SMB[0]\n";
    print $fh "SMB=$SMB_IP[0]\n";

    close $fh;
}

#create BOND
push @body, "echo .create Bond -L-AN";
push @body, "nmcli con add type bond con-name mb0 ifname mb0 bond.options \"mode=802.3ad,miimon=1,downdelay=0,updelay=0\" ipv4.method disabled ipv6.method ignore";
#
#create ETHERNET connections for interfaces
push @body, "echo .create Bond-Slave";
for my $LAN_e_num (@LAN_bond) {
    my $LAN_e_name = get_con_name(0+$LAN_e_num);
    push @body, "nmcli con add type ethernet slave-type bond master mb0 con-name mb0.$LAN_e_name ifname $LAN_e_name";
}
#create BRIDGE
#create VLAN over BOND
{
    my $LAN_VLAN_ID = 0+$LAN_VLAN[0];

    push @body, "\necho .create Bridge";
    push @body, "nmcli con add type bridge con-name br-mb0.$LAN_VLAN_ID ifname br-mb0.$LAN_VLAN_ID ipv4.method manual ipv6.method ignore ipv4.addresses $LAN_IP[0]/24 ipv4.gateway $LAN_IP[1] ipv4.dns $DNS_IP[0] ipv4.dns-search $DNS_DOMAIN[0] ipv4.route-metric 100";
    push @body, "echo .create VLAN-br-Slave";
    push @body, "nmcli con add type vlan slave-type bridge master br-mb0.$LAN_VLAN_ID con-name mb0.$LAN_VLAN_ID ifname mb0.$LAN_VLAN_ID dev mb0 id $LAN_VLAN_ID";

    push @body, "\necho .activate -L-AN connections";
    push @body, "nmcli con up mb0";
    push @body, "nmcli con up mb0.$LAN_VLAN_ID";
    push @body, "nmcli con up br-mb0.$LAN_VLAN_ID";

    push @body, "";
}

push @body, "echo .create Bond *S*AN";
push @body, "nmcli con add type bond con-name sb0 ifname sb0 bond.options \"mode=802.3ad,miimon=1,downdelay=0,updelay=0\" ipv4.method disabled ipv6.method ignore";
#
#create ETHERNET connections for interfaces
push @body, "echo .create Bond-Slave";
for my $SAN_e_num (@SAN_bond) {
    my $SAN_e_name = get_con_name(0+$SAN_e_num);
    push @body, "nmcli con add type ethernet slave-type bond master sb0 con-name sb0.$SAN_e_name ifname $SAN_e_name";
}
{
    my $SAN_VLAN_ID = 0+$SAN_VLAN[0];

    push @body, "\necho .create VLAN";
    push @body, "nmcli con add type vlan con-name sb0.$SAN_VLAN_ID ifname sb0.$SAN_VLAN_ID dev sb0 id $SAN_VLAN_ID ipv4.method manual ipv6.method ignore ipv4.addresses $SAN_IP[0]/24  ipv4.route-metric 200";

    push @body, "\necho .activate *S*AN connections";
    push @body, "nmcli con up sb0";
    push @body, "nmcli con up sb0.$SAN_VLAN_ID";

    push @body, "";
}
push @body, "\necho .restart NM service";
push @body, "systemctl restart NetworkManager.service";
push @body, "";

push @body, "\necho .set HOSTNAME";
push @body, "hostnamectl set-hostname $HOST_NAME[0]";
push @body, "";
push @body, "ip -c -br a";
push @body, "";

my $m_name = $home_path.'/create-matryoshka';
{
    open my $fh, ">", $m_name or die "Can't write to file '$m_name'";
    for my $str (@body) {
        print $fh "$str\n";
    }
    close $fh;
}

`chmod +x $m_name`;

print "\n";
print "Use:\n$m_name\n";
print "\n";

exit(0);

sub get_con_name {
    my ($n) = @_;
    my @columns = split " ", $interfaces[$n];
    return $columns[0];
}

sub input {
    my ($prompt, $checker) = @_;
    my $for_bond_ref;

    while (1) {
        print $prompt;
        my $intfs;

        while(!defined($intfs = <STDIN>)) {};
        chomp $intfs;

        (my $is_good, $for_bond_ref) = $checker -> ($intfs);
        last if $is_good == 1;
    }

    return @{$for_bond_ref};
}

sub check_num_line {
    my ($line) = @_;

    my @lines = split " |,", $line;
    my $good = 1;

    CHECK:
    for my $intf (@lines) {
        if ( !($intf =~ m/^\d{1,2}$/) or $intf >= (0+@interfaces) ) {
            print 'Available only Numbers separated by " " or ","! And no more than interfaces count.'; print("\n");
            $good=0;
            last CHECK;
        }
    }

    return ($good, \@lines);
}

sub check_num {
    my ($line) = @_;

    my $good = $line =~ m/^\d{1,4}$/ ? 1 : 0;
    if (!$good) {
        print 'Available only single Number!'; print "\n";
    }

    my @lines = ($line);

    return $good, \@lines;
}

sub check_ip {
    my ($line) = @_;

    my $mask = '^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})$';

    my $good = $line =~ m/$mask/ ? 1 : 0;
    if (!$good) {
        print 'Available only correct IP address!'; print "\n";
    }

    my $gw = $line;
    $gw =~ s/$mask/$1.$LAN_GW_8[0]/;

    my @lines = ($line,  $gw);

    return $good, \@lines;
}

sub check_gw {
    my ($octet) = @_;

    my $good = 1;
    my @lines = ($octet =~ m/^\d{1,3}$/ ? $octet : 254);

    return $good, \@lines;
}

sub check_name {
    my ($line) = @_;

    my $good = $line =~ m/^[a-zA-Z0-9.-]+$/ ? 1 : 0;
    if (!$good) {
        print 'NOT available empty value!'; print "\n";
    }

    my @lines = ($line);

    return $good, \@lines;
}

sub check_yN {
    my ($yn) = @_;

    my $good = 1;
    my @lines = ($yn =~ m/^[yY]$/ ? 'Y' : 'N');

    return $good, \@lines;
}
