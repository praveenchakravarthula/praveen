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

my $dtree = AI::DecisionTree->new( prune => 1, noise_mode => 'pick_best' );

my $result_col = $cols->[0];
my %req_attrs  = ( pclass => 1, sex => 3, sibsp => 5, parch => 6 );
my @delete     = grep { !$req_attrs{$_} } @{$cols};
shift @delete;

my $train_count = 1000;
my $iter        = 0;
while ( my $row = $csv->getline_hr($train_fh) ) {

    delete $row->{$_} for @delete;
    my $result = delete $row->{$result_col};

    # print Dumper($row) . " = $result\n";
    $dtree->add_instance( attributes => $row, result => $result );
    last if ( $train_count && $iter++ >= $train_count );
}
close TRAIN;

$dtree->train;
print STDERR "Trained using $iter rows\n";

my $graph = $dtree->as_graphviz();
$graph->as_png("tree.png");

my $test_file = "test.csv";
open my $test_fh, $test_file
  or die "Unable to open test file $test_file: $!\n";

my $out_file = "test_out.csv";
open my $out_fh, "> $out_file"
  or die "Unable to open out file $out_file: $!\n";

my $test_csv = Text::CSV->new( { binary => 1 } );
my $out_csv  = Text::CSV->new( { binary => 1 } );

my $test_cols = $test_csv->getline($test_fh);
$test_csv->column_names($test_cols);

print $out_fh join(",", @{$cols}) . "\n";

while ( my $row = $test_csv->getline($test_fh) ) {
    print Dumper($row) . "\n";
    my $attributes = {};
    foreach my $key ( keys %req_attrs ) {
        $attributes->{$key} = $row->[ $req_attrs{$key} - 1 ];
    }
    my $result = $dtree->get_result( attributes => $attributes );
    unless (defined $result) {
        $result = int(0);
    }
    unshift @{$row}, $result;
    print "RESULT: $result\n";
    $out_csv->combine(@$row);
    print $out_fh $out_csv->string . "\n";

}
