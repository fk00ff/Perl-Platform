#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Data::Dumper;

chomp(my $pwd = `pwd`);
{
    my $t_name = $pwd."/kjenvjkeneknffefjveee";
    my $rez = ( open my $fh, ">", $t_name );
    if (defined($rez) && ($rez == 1)) {
        `rm -f $t_name`;
        print "Run script from mounted-cdrom-folder, please!\n";
        exit(-1);
    }
    close $fh;
}

chomp(my $home_path = `echo \$HOME`);
my @body = ("#!/bin/bash\n");
my $filter ='';
my $core_net = 'core-network';
my $is_control_host = 0;

print "Load addresses ....\n";
my $ans_name = $home_path . '/used-addresses';
my %ips = ();
{
    open my $fh, "<", $ans_name or die "Can't open file '$ans_name'";
    my @ips = <$fh>;
    close $fh;

    for my $ip (@ips) {
        chomp $ip;

        my @o = split "=", $ip;
        $ips{$o[0]}=$o[1];
    }
}

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
    #all seeds in external files

    chomp(my $seed1 = `echo IP="999.888.777.001" | xxd -p`);
    $seed1 = kill_0a($seed1);
    chomp(my $seed2 = `echo GATEWAY="999.888.777.002" | xxd -p`);
    $seed2 = kill_0a($seed2);
    chomp(my $seed3 = `echo DNS_SERVER="999.888.777.003" | xxd -p`);
    $seed3 = kill_0a($seed3);
    my ($repl1, $repl2, $repl3);
    {
        my $r;

        $r = &pad_ip($ips{'IP'}, 'IP');
        chomp($repl1 = `echo $r | xxd -p`);
        $repl1 = kill_0a($repl1);

        $r = &pad_ip($ips{'GW'}, 'GATEWAY');
        chomp($repl2 = `echo $r | xxd -p`);
        $repl2 = kill_0a($repl2);

        $r = &pad_ip($ips{'DNS'}, 'DNS_SERVER');
        chomp($repl3 = `echo $r | xxd -p`);
        $repl3 = kill_0a($repl3);
    }

    if ($ips{'EXT-NTP'} eq 'N') {
        register_VM('/sitronics/srv-ntp', 'srv-ntp.tar.gz', 'NTP');
        push @body, qq[xxd -p harddisk.hdd | sed -e "s/$seed1/$repl1/" -e "s/$seed2/$repl2/" -e "s/$seed3/$repl3/" | xxd -p -r > harddisk.hdd.new ];
        push @body, "rm harddisk.hdd";
        push @body, "mv harddisk.hdd.new harddisk.hdd";
	    push @body, "prlctl start srv-ntp";
        push @body, "";
    }

    if ($ips{'EXT-SMB'} eq 'N') {
        register_VM('/sitronics/srv-smb', 'srv-smb.tar.gz', 'SMB');
        push @body, qq[xxd -p harddisk.hdd | sed -e "s/$seed1/$repl1/" -e "s/$seed2/$repl2/" -e "s/$seed3/$repl3/" | xxd -p -r > harddisk.hdd.new ];
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

    my $ret = $prefix . sprintf('%-18s', '="' . $ip . '"');
    $ret =~ s/[ ]/#/g;

    return $ret;
}

sub kill_0a {
    my ($str) = @_;

    $str =~ s/^(.+)(0a)$/$1/;
    $str =~ s/23/20/g;

    return $str;
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
    #push @body, "prlctl set $name --device-add net";
    push @body, "prlctl set $name --device-set net0 --network $core_net";
    push @body, "prlctl set $name --autostart on";
    push @body, "";
}