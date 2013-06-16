#!/usr/bin/perl

use strict;
use Algorithm::Combinatorics qw/combinations/;
use Data::Dumper;

my @attrs = qw(pclass sex sibsp parch);

for ( my $i = 1 ; $i <= scalar(@attrs) ; $i++ ) {
    my @values = combinations(\@attrs, $i);    
    # print Dumper ($_) for @values;
    foreach my $v (@values) {
        my $cmd = "./two.pl " . join(" ", @$v) ;
        #print "cmd: $cmd\n";
        system $cmd;
        print '-' x 50 . "\n";
    }
}
