#!/usr/bin/perl
package ext;

use strict;
use warnings FATAL => 'all';

use Exporter 'import';
our $VERSION = '1.00';
our @EXPORT = qw[proceed_number_line proceed_num proceed_ip proceed_name proceed_gw proceed_yn];

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
        open my $fh, "<", $ans_filename or die "Can't open file '$ans_filename'";
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

sub proceed_number_line {
    return \&check_num_line;
}

sub proceed_num {
    return \&check_num;
}

sub proceed_ip {
    return \&check_ip;
}

sub proceed_name {
    return \&check_name;
}

sub proceed_gw {
    return \&check_gw;
}

sub proceed_yn {
    return \&check_yN;
}


sub input {
    my ($prompt, $checker, $checker_param1, $checker_param2) = @_;
    my $array_ref;

    while (1) {
        print $prompt;
        my $intfs;

        while(!defined($intfs = <STDIN>)) {};
        chomp $intfs;

        (my $is_good, $array_ref) = $checker -> ($intfs, $checker_param1, $checker_param2);
        last if $is_good == 1;
    }

    return @{$array_ref};
}

sub check_num_line {
    my ($line, $count) = @_;

    my @lines = split " |,", $line;
    my $good = 1;

    CHECK:
    for my $intf (@lines) {
        if ( !($intf =~ m/^\d{1,2}$/) or $intf >= $count ) {
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
    if ($good == 0) {
        print 'Available only single Number!'; print "\n";
    }

    my @lines = ($line);

    return $good, \@lines;
}

sub check_ip {
    my ($line, $ip_gw) = @_;

    my $mask = '^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})$';

    my $good = $line =~ m/$mask/ ? 1 : 0;
    if ($good == 0) {
        print 'Available only correct IP address!'; print "\n";
    }

    my $gw;
    #
    if(defined $ip_gw) {
        $gw = $line;
        $gw =~ s/$mask/$1.$ip_gw/;
    }

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
