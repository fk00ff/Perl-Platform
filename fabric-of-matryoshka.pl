#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use lib '.';

use Data::Dumper;
use ext;

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

my @LAN_VLAN = ext::input('-L-AN VLAD ID:', proceed_num);
my @LAN_GW_8 = ext::input('-LAN- gateway last octet [254]:', proceed_gw);
my @LAN_IP = ext::input('-L-AN IP:', proceed_ip, $LAN_GW_8[0]);
my @LAN_bond = ext::input('Enter Interfaces numbs for create -L-AN bond:', proceed_number_line, 0+@interfaces);
print "\n";
my @SAN_VLAN = ext::input('*S*AN VLAN ID:', proceed_num);
my @SAN_IP = ext::input('*S*AN IP:', proceed_ip, $LAN_GW_8[0]);
my @SAN_bond = ext::input('Enter Interfaces numbs for create *S*AN bond:', proceed_number_line, 0+@interfaces);
print "\n";
my @COPY_NTP = ext::input('Use external(existed) NTP server [yN]:', proceed_yn);
my @NTP_IP = ext::input('NTP IP:', proceed_ip);
print "\n";
my @COPY_SMB = ext::input('Use external(existed) SMB/CIFS server [yN]:', proceed_yn);
my @SMB_IP = ext::input('SMB IP:', proceed_ip);
print "\n";
my @DNS_IP = ext::input('DNS IP:', proceed_ip);
my @DNS_UP = ext::input('Upstream DNS IP:', proceed_ip);
my @DNS_DOMAIN = ext::input('Search Domain:', proceed_name);
my @HOST_NAME = ext::input("This Host name:", proceed_name);
print "\n";

print "\nsave answers ....\n";
my $ans_name = ext::home_path . '/used-addresses';
{
    open my $fh, ">", $ans_name or die "Can't write to file '$ans_name'";
    print $fh "VLAN=$LAN_VLAN[0]\n";
    print $fh "IP=$LAN_IP[0]\n";
    print $fh "GW=$LAN_IP[1]\n";
    print $fh "DNS=$DNS_IP[0]\n";
    print $fh "DNS_UP=$DNS_UP[0]\n";
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

my $m_name = ext::home_path.'/create-matryoshka';
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
    my ($num) = @_;
    my @columns = split " ", $interfaces[$num];
    return $columns[0];
}

