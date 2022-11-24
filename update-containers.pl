#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Data::Dumper;

chomp(my $pwd = `pwd`);
{
    my $t_name = $pwd."/kjenvjkeneknffefjveee";
    my $rez = ( open my $fh, ">", $t_name );
    if ($rez == 1) {
        `rm -f $t_name`;
        die "Run script from mounted-cdrom-folder, please!";
    }
    close $fh;
}

chomp(my $home_path = `echo \$HOME`);
my @body = ("#!/bin/bash\n");
my $filter ='';
$core_net = 'core-network';

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

push @body, "echo .restart system containers ....";
$filter = q[awk 'if ($4 == "CT") {print $1, $5}}'];
my @sysc=`prlctl list -a | $filter`;
for my $sysc (@sysc) {
    my @a = split " ", $sysc;
    push @body, "echo - $a[1]";
    push @body, "prlctl restart $a[0]";
}
push @body, "";

push @body, "echo .remove core virtual network ....";
push @body, "prlsrvctl net del $core_net";
push @body, "echo .create core virtual network ....";
push @body, "prlsrvctl net add $core_net --type bridged -d \"Core components network\" --ifname mb0.".$ips{'VLAN'};
push @body, "";

if ($ips{'EXT-NTP'} eq 'N') {
    register_VM('/sitronics/srv-ntp', 'srv-ntp.tar.gz', 'NTP');



    #IP="999.888.777.001"
    #GATEWAY="999.888.777.002"
    #DNS_SERVER="999.888.777.003"
}



sub register_VM {
    my ($path, $name, $desc) = @_;

    push @body, "echo .copy $desc server ....";
    push @body, "mkdir $path ; chmod -R 700 $path ; chown -R root:root $path";
    push @body, "rsync --progress $pwd/$name $path/";

    push @body, "echo .extract ....";
    push @body, "cd $path";
    push @body, "tar -xf $name";
    push @body, "rm -f $name";

    push @body, "echo .register ....";
    push @body, "prlctl register $path";

    @o = split "/", $path;
    $name = $o[-1];

    push @body, "echo .configure ....";
    push @body, "prlctl set $name --device-add net";
    push @body, "prlctl set $name --device-set net0 --network $core_net";
    push @body, "prlctl set $name --autostart on";
}