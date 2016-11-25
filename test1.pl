#!/usr/bin/perl

use strict;
use warnings;
use opsconfig;
use opsian;
use POSIX;

my $config = new opsconfig("opsian.cfg");
my $opsian = new opsian($config->{server}, $config->{username}, $config->{password});
# uncomment to parse map and find oases
#$opsian->parseMapSQL();
#$opsian->findOases(18, -16, 20, -56);
#exit;
$opsian->login();
$opsian->{palamode}=0;
$opsian->s5raidinit();
$opsian->{curfarm1} = -1; # village 1
$opsian->{curfarm2} = -1; # village 2

while(1) {
    $opsian->s5raid(61573, 1); # village id 1
    sleep 5+rand(4);
    $opsian->s5raid(11582, 2); # village id 2
    sleep 5+rand(4);
    sleep 70+rand(40);
}
