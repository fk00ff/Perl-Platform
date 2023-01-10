#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use lib '.';

use ext;

ext::checkOnCDROM;

my @body = ("#!/bin/bash\n");
my $filter ='';

$filter = q[awk '{if ($5 == "va-mn") {print $3}}'];
my @VA_MN_IP=`prlctl list -a | $filter`;

$filter = q[awk '{if ($5 == "vstorage-ui") {print $3}}'];
my @VSTOR_IP=`prlctl list -a | $filter`;

if (@VA_MN_IP+@VSTOR_IP < 2) {
    print "Can't find containers.\n";
    exit(-2);
}

my %ips = ext::loadAddresses(ext::home_path . '/used-addresses');

my @PROXY_IP = ext::input('Internal web console IP:', proceed_ip);
my @PORTAL_IP = ext::input('web console IP:', proceed_ip);

my $name = "sit_vm_console";
{
    ext::register_VM($name, 'internal web console', \@body, "add");

    push @body, "prlctl set sit_vm_console --device-set cdrom0 --image '/sitronics/$name/docker.iso'";
    push @body, "prlctl start $name";

    push @body, "Mounting media ...";
    push @body, "prlctl exec $name mount /dev/cdrom /mnt/cdrom";

    push @body, "Loading image ...";
    push @body, "prlctl exec $name docker load --input /mnt/cdrom/virt.tar";
    push @body, qq[prlctl exec $name "docker run -d --restart always --name virt-proxy-nginx -p 443:443 -p 8889:8889 --env NGINX_SERVERNAME=$ips{'IP'} --env NGINX_UPSTREAM_VIRT=$VA_MN_IP[0] --env NGINX_UPSTREAM_CEPH=$VSTOR_IP[0] 10.120.3.99:8082/gl/sit_virt/virt-proxy-prod"];

    push @body, "prlctl exec $name umount /dev/cdrom";
    push @body, "prlctl set $name --device-set cdrom0 --disconnect";

    push @body, "rm -f /sitronics/sit_vm_console/docker.iso";
}

fw_rule("va-mn", $PROXY_IP[0], 4648);
fw_rule("vstorage-ui", $PROXY_IP[0], 8888);

$name = "sit_vm_portal";
{
    ext::register_VM($name, 'web console', \@body, "add");

    push @body, "prlctl set $name --device-set net0 --ipaddr $PORTAL_IP[0] --gw $ips{'GW'} --nameserver $ips{'DNS'}";

    push @body, "prlctl set sit_vm_console --device-set cdrom0 --image '/sitronics/$name/docker.iso'";
    push @body, "prlctl start $name";

    push @body, "Mounting media ...";
    push @body, "prlctl exec $name mount /dev/cdrom /mnt/cdrom";

    push @body, "Loading image ...";
    push @body, "prlctl exec $name docker load --input /mnt/cdrom/images.tar.gz";

    push @body, "prlctl exec $name mkdir /root/vmportal";
    push @body, "prlctl exec $name cp -R /mnt/cdrom/config /root/vmportal";
    push @body, "prlctl exec $name cp /mnt/cdrom/docker-compose.yml /root/vmportal";
    push @body, "prlctl exec $name cd /root/vmportal";
    push @body, "prlctl exec $name 'docker compose up -d'";

    push @body, "prlctl exec $name umount /dev/cdrom";
    push @body, "prlctl set $name --device-set cdrom0 --disconnect";

    push @body, "rm -f /sitronics/sit_vm_console/docker.iso";
}

my $m_name = ext::home_path.'/install-platform';
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

sub fw_rule {
    my ($name, $ip, $port) = @_;

    push @body, "prlctl exec $name firewall-cmd --permanent --zone=trusted --remove-interface=venet0";
    push @body, "prlctl exec $name firewall-cmd --permanent --zone=public --add-interface=venet0";
    push @body, "prlctl exec $name firewall-cmd --set-default-zone=public";
    push @body, "prlctl exec $name firewall-cmd --permanent --add-port=161/udp";
    push @body, qq[prlctl exec $name firewall-cmd --permanent --add-rich-rule 'rule family="ipv4" source address=$ip port port="$port" protocol="tcp" accept'];
    push @body, "prlctl exec $name firewall-cmd --reload";
}

