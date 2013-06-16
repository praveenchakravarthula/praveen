#!/usr/bin/perl

use strict;
use Data::Dumper;
use AI::DecisionTree;
use Text::CSV;
use GraphViz;
use Statistics::R;
use Time::HiRes qw/gettimeofday tv_interval/;
use Clone qw/clone/;

$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;

my $train_file = "train.csv";
my $r          = Statistics::R->new;
$r->startR;
my @attrs = scalar(@ARGV) ? @ARGV : qw(sex);

print "Training Decision Tree using these attributes: " . Dumper(\@attrs) . "\n";
my $start = [gettimeofday];
my ( $train_data, $train_results ) = get_train_data($train_file);
my @scores;
foreach my $iter ( 1 .. 50 ) {
    my ( $sample_indexes, $out_of_bag ) = sample_train_data($train_data);
    my $dtree = AI::DecisionTree->new( prune => 1, noise_mode => 'pick_best' );
    foreach my $s_index (@$sample_indexes) {
        $dtree->add_instance(
            attributes => $train_data->[ $s_index - 1 ],
            result     => $train_results->[ $s_index - 1 ]
        );
    }

    $dtree->train;
    push @scores, evaluate( $dtree, $out_of_bag );
}
my $end = tv_interval($start);
$r->send( q`scores <- c(` . join( ",", @scores ) . q`)` );
$r->send(q`score_summary <- summary(scores)`);
$r->send(q`cat(score_summary)`);

my @summary_values = split( /\s+/, $r->read );
my $i;
my %summary =
  map { $_ => $summary_values[ $i++ ] } qw(min q1 median mean q3 max);
print Dumper ( {%summary} ) . "\n";
print "Finished in $end seconds\n";

sub get_train_data {
    my $train_file = shift;
    open my $train_fh, $train_file
      or die "Unable to open training file $train_file: $!\n";

    my $csv = Text::CSV->new( { binary => 1 } );

    my $cols = $csv->getline($train_fh);
    $csv->column_names($cols);

    my $result_col = $cols->[0];
    my %req_attrs  = map { $_ => 1 } @attrs;
    my @delete     = grep { !$req_attrs{$_} } @{$cols};
    shift @delete;

    my ( @data, @results );
    while ( my $row = $csv->getline_hr($train_fh) ) {
        delete $row->{$_} for @delete;
        my $result = delete $row->{$result_col};
        push @data,    $row;
        push @results, $result;
    }
    return ( \@data, \@results );
}

sub sample_train_data {
    my $train_data = shift;
    my $size       = scalar( @{$train_data} );
    $r->send( q`t_ind <- (1:` . $size . q`)` );
    $r->send(q`samp <- sample(t_ind, length(t_ind), TRUE)`);
    $r->send(q`cat(samp)`);
    my @s_indexes = split( /\s+/, $r->read );
    my %uniq = map { $_ => 1 } @s_indexes;
    my @out_of_bag = grep { !$uniq{$_} } ( 1 .. $size );
    return ( \@s_indexes, \@out_of_bag );
}

sub evaluate {
    my ( $dtree, $test_indexes ) = @_;
    my ( $tp, $tn, $fp, $fn );
    foreach my $t_index (@$test_indexes) {
        my $result =
          $dtree->get_result( attributes => $train_data->[ $t_index - 1 ] );
        my $exp_result = $train_results->[ $t_index - 1 ];

        $tp++ if ( $result  && $exp_result );
        $tn++ if ( !$result && !$exp_result );
        $fp++ if ( !$result && $exp_result );
        $fn++ if ( $result  && !$exp_result );
    }

    my $score = ( $tp + $tn ) / scalar(@$test_indexes);
    return $score;
}

