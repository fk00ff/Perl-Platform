#!/usr/bin/perl
package Functions;

use strict;
use warnings FATAL => 'all';

use Exporter 'import';
our $VERSION = '1.00';
our @EXPORT = qw[];

my $pwd;

sub pwd {
    if( !defined($pwd) ) {
        chomp($pwd = `pwd`);
    }

    return $pwd;
};

sub checkOnCDROM {
    &pwd;

    my $t_name = $pwd."/kjenvjkeneknffefjveee";
    my $rez = ( open my $fh, ">", $t_name );
    if (defined($rez) && ($rez == 1)) {
        `rm -f $t_name`;
        print "Run script from mounted-cdrom-folder, please!\n";
        # exit(-1);
    }
    close $fh;
}

sub loadAddresses {
    my ($ans_filename) = @_;

    print "Load addresses ....\n";
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

    return %ips;
}