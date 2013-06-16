#!/usr/bin/perl

use strict;
use Data::Dumper;
use AI::DecisionTree;
use Text::CSV;
use GraphViz;
use Statistics::R;
use Time::HiRes qw/gettimeofday tv_interval/;

$Data::Dumper::Indent = 1;
$Data::Dumper::Terse  = 1;

my $train_file = "train.csv";
my $r          = Statistics::R->new;
$r->startR;

my ( $train_data, $train_results ) = get_train_data($train_file);

foreach my $iter ( 1 .. 20 ) {
    my $start = [gettimeofday];
    my ( $sample_indexes, $out_of_bag ) = sample_train_data($train_data);
    my $dtree = AI::DecisionTree->new( prune => 1, noise_mode => 'pick_best' );
    foreach my $s_index (@$sample_indexes) {
        $dtree->add_instance(
            attributes => $train_data->[ $s_index - 1 ],
            result     => $train_results->[ $s_index - 1 ]
        );
    }

    $dtree->train;

    my $score = evaluate( $dtree, $out_of_bag );
    print "Score: $score\n";

    my $end = tv_interval($start);
    print "#$iter finished in $end seconds\n";
}

sub get_train_data {
    my $train_file = shift;
    open my $train_fh, $train_file
      or die "Unable to open training file $train_file: $!\n";

    my $csv = Text::CSV->new( { binary => 1 } );

    my $cols = $csv->getline($train_fh);
    $csv->column_names($cols);

    my $result_col = $cols->[0];
    my %req_attrs  = ( pclass => 1, sex => 3, sibsp => 5, parch => 6 );
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
    my ( $dtree, $test_indexes, $expected ) = @_;
    my ( $tp, $tn, $fp, $fn );
    foreach my $t_index (@$test_indexes) {
        my $result =
          $dtree->get_result( attributes => $train_data->[ $t_index - 1 ] );
        my $exp_result = $train_results->[$t_index - 1];

        $tp++ if ( $result  && $exp_result );
        $tn++ if ( !$result && !$exp_result );
        $fp++ if ( !$result && $exp_result );
        $fn++ if ( $result  && !$exp_result );
    }

    my $score = ( $tp + $tn ) / scalar(@$test_indexes);
    return $score;
}

