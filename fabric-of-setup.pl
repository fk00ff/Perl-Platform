#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Data::Dumper;
use Functions;

Functions::checkOnCDROM;
my $pwd = Functions::pwd;

my @body = ("#!/bin/bash\n");
my $filter ='';
my $core_net = 'core-network';
my $is_control_host = 0;

chomp(my $home_path = `echo \$HOME`);
my %ips = Functions::loadAddresses($home_path . '/used-addresses');

push @body, "echo .install host trial licence";
push @body, "vzlicload -f $pwd/license/RVZ.000000981.0002.txt";
push @body, "";

$filter = q[awk '{if ($4 == "CT") {print $1, $5}}'];
my @sysc=`prlctl list -a | $filter`;

if (@sysc > 0) {
    push @body, "echo .restart system containers ....";
    $is_control_host = 1;

    for my $sysc (@sysc) {

        my @a = split " ", $sysc;
        push @body, "echo - $a[1]";
        push @body, "prlctl restart $a[0]";
    }
    push @body, "";

    push @body, "echo .install storage trial license";
    push @body, "vstorage -c <claster-name> load-license -f $pwd/license/PCSS.000000100.0001.txt";
    push @body, "";
}

push @body, "echo .remove core virtual network ....";
push @body, "prlsrvctl net del $core_net";
push @body, "echo .create core virtual network ....";
push @body, "prlsrvctl net add $core_net --type bridged -d \"Core components network\" --ifname mb0.".$ips{'VLAN'};
push @body, "";

push @body, "echo .set NTP server for host";
push @body, "cp /etc/chrony.conf /etc/chrony.conf.bak";
push @body, qq[sed -e "s/^\\(server \\)/#\\1/" -i /etc/chrony.conf];
push @body, qq[sed -e "0,/#server/ s/^\\(#server \\)/server $ips{'NTP'}\\n\\1/" -i /etc/chrony.conf];
push @body, "systemctl restart chronyd";
push @body, "echo Use:";
push @body, "echo .  chronyc sources -v";
push @body, "";

if ($is_control_host == 1) {

    #    123456789012345
    #IP="999.888.777.001"
    #GATEWAY="999.888.777.002"
    #DNS_SERVER="999.888.777.003"

    my $seed1 = get_XXDs('IP="999.888.777.001"');
    my $seed2 = get_XXDs('GATEWAY="999.888.777.002"');
    my $seed3 = get_XXDs('DNS_SERVER="999.888.777.003"');

    my ($repl1ntp, $repl1smb, $repl2, $repl3);
    {
        my $r = pad_ip($ips{'NTP'}, 'IP'); # for test purpose
        $repl1ntp = get_XXDs($r);

        $repl1smb = get_XXDs(pad_ip($ips{'SMB'}, 'IP'));
        $repl2 = get_XXDs(pad_ip($ips{'GW'}, 'GATEWAY'));
        $repl3 = get_XXDs(pad_ip($ips{'DNS'}, 'DNS_SERVER'));
    }

    if ($ips{'EXT-NTP'} eq 'N') {
        register_VM('/sitronics/srv-ntp', 'srv-ntp.tar.gz', 'NTP');
        push @body, qq[xxd -p harddisk.hdd | tr -d "\\n" | sed -e "s/$seed1/$repl1ntp/" -e "s/$seed2/$repl2/" -e "s/$seed3/$repl3/" | xxd -p -r > harddisk.hdd.new ];
        push @body, "rm harddisk.hdd";
        push @body, "mv harddisk.hdd.new harddisk.hdd";
	    push @body, "prlctl start srv-ntp";
        push @body, "";
    }

    if ($ips{'EXT-SMB'} eq 'N') {
        register_VM('/sitronics/srv-smb', 'srv-smb.tar.gz', 'SMB');
        push @body, qq[xxd -p harddisk.hdd | tr -d "\\n" | sed -e "s/$seed1/$repl1smb/" -e "s/$seed2/$repl2/" -e "s/$seed3/$repl3/" | xxd -p -r > harddisk.hdd.new ];
        push @body, "rm harddisk.hdd";
        push @body, "mv harddisk.hdd.new harddisk.hdd";
        push @body, "prlctl start srv-smb";
        push @body, "";
    }
}

my $m_name = $home_path.'/setup-host';
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

sub pad_ip {
    my ($ip, $prefix) = @_;

    $prefix . sprintf('%-18s', '="' . $ip . '"');
}

sub get_XXDs {
    my ($str) = @_;
    chomp($x_str = `echo '$str' | xxd -p`);

    $x_str =~ s/^(.+)(0a)$/$1/;

    return $x_str;
}

sub register_VM {
    my ($path, $name, $desc) = @_;

    push @body, "";
    push @body, "echo .copy $desc server ....";
    push @body, "mkdir -p $path ; chmod -R 700 $path ; chown -R root:root $path";
    push @body, "rsync --progress $pwd/$name $path/";
    push @body, "";

    push @body, "echo .extract ....";
    push @body, "cd $path";
    push @body, "tar -xf $name";
    push @body, "rm -f $name";
    push @body, "";

    push @body, "echo .register ....";
    push @body, "prlctl register $path";

    my @o = split "/", $path;
    $name = $o[-1];

    push @body, "echo .configure ....";
    push @body, "prlctl set $name --device-set net0 --network $core_net";
    push @body, "prlctl set $name --autostart on";
    push @body, "";
}