#!/usr/bin/perl

use strict;
use Statistics::R;
use Data::Dumper;

my $r = Statistics::R->new;
$r->startR;

my @a = (1 .. 10);
my $a_values = join(',', @a);
$r->send(q`a <- c(` . $a_values . q`)`);
$r->send(q`a`);

foreach my $i (1 .. 5) {
    $r->send(q`sample(a, length(a), TRUE)`);
    my @out = split(/\s+/, $r->read);
    shift @out;
    shift @out;

    print Dumper (\@out);
}

