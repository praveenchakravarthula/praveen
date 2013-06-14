#!/usr/bin/perl

use strict;
use Data::Dumper;
use AI::DecisionTree;
use Text::CSV;
use GraphViz;

$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;

my $train_file = "train.csv";
open my $train_fh, $train_file
  or die "Unable to open training file $train_file: $!\n";

my $csv = Text::CSV->new( { binary => 1 } );

my $cols = $csv->getline($train_fh);
$csv->column_names($cols);

my $dtree = AI::DecisionTree->new( prune => 0, noise_mode => 'pick_best' );

my $result_col = $cols->[0];
my %req_attrs  = map { $_ => 1 } qw(sex pclass);
my @delete     = grep { !$req_attrs{$_} } @{$cols};
shift @delete;

my $train_count = 1000;
my $iter = 0;
while ( my $row = $csv->getline_hr($train_fh) ) {

    delete $row->{$_} for @delete;
    my $result = delete $row->{$result_col};

    print Dumper($row) . " = $result\n";
    $dtree->add_instance( attributes => $row, result => $result );
    last if ($train_count && $iter++ >= $train_count);
}
close TRAIN;

$dtree->train;
print STDERR "Trained using $iter rows\n";

my $graph = $dtree->as_graphviz();
$graph->as_png("tree.png");

my $test = { sex => 'female', pclass => 4 };
my $survived = $dtree->get_result( attributes => $test );
# print "Test: " . Dumper($test) . " Surivied? $survived\n";
