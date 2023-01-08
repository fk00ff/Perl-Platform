#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Functions;

Functions::checkOnCDROM;
my $pwd = Functions::pwd;

my @body = ("#!/bin/bash\n");
my $filter ='';
my $core_net = 'core-network';
my $is_control_host = 0;

chomp(my $home_path = `echo \$HOME`);
my %ips = Functions::loadAddresses($home_path . '/used-addresses');



