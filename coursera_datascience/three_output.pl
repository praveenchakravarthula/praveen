#!/usr/bin/perl

use strict;
use Data::Dumper;
use AI::DecisionTree;
use Text::CSV;
use Statistics::R;
use Time::HiRes qw/gettimeofday tv_interval/;
use Algorithm::Combinatorics qw/combinations/;

$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;

my $train_file = "train.csv";
my $test_file  = "test.csv";

my $r = Statistics::R->new;
$r->startR;
my @attrs = qw(sex pclass parch sibsp age fare);
my $m_attr_count = 4;    #use this many attrs to build a tree in the forest
my @agebins = ( 5, 15, 40, 60 );
my @farebins = ( 10, 20, 50, 100 );

my $train_data = get_train_data($train_file);
my $forest     = make_forest(200);

# my $score = evaluate( $forest, $train_data );
predict( $test_file, $forest );

sub predict {
    my ( $test_file, $forest ) = @_;

    my %pos = (
        pclass   => 1,
        name     => 2,
        sex      => 3,
        age      => 4,
        sibsp    => 5,
        parch    => 6,
        cabin    => 7,
        fare     => 8,
        embarked => 9
    );
    open my $test_fh, $test_file
      or die "Unable to open training file $train_file: $!\n";
    my $csv = Text::CSV->new( { binary => 1 } );

    my $cols = $csv->getline($test_fh);
    $csv->column_names($cols);

    open my $predict_fh, "> predict_forest.csv"
      or die "Unable to open prediction file: $!\n";

    my $out_csv = Text::CSV->new( { binary => 1 } );
    print $predict_fh "survived," . join( ",", @{$cols} ) . "\n";

    my $majority = scalar(@$forest) / 2;
    while ( my $row = $csv->getline($test_fh) ) {
        my $t_res = 0;
        foreach my $dt (@$forest) {
            my %attrs =
              map { $_ => $row->[ $pos{$_} - 1 ] } @{ $dt->{attrs} };
            if ( $attrs{age} ) {
                $attrs{age} = bin_values( $attrs{age}, @agebins );
            }
            if ( $attrs{fare} ) {
                $attrs{fare} = bin_values( $attrs{fare}, @farebins );
            }
            # print Dumper ( \%attrs ) . "\n";
            $t_res += $dt->{tree}->get_result( attributes => {%attrs} );
        }

        print Dumper($row) . "\n";
        print "score: $t_res (out of " . @$forest . ")\n";
        my $result = $t_res > $majority ? 1 : 0;
        unshift @$row, $result;
        $out_csv->combine(@$row);
        print $predict_fh $out_csv->string . "\n";
    }
}

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
        $row->{age}  = bin_values( $row->{age},  @agebins );
        $row->{fare} = bin_values( $row->{fare}, @farebins );
        push @data, $row;
    }
    return ( \@data );
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

sub make_forest {
    my ($iter) = @_;
    my @forest;
    my $start = [gettimeofday];
    for ( my $i = 0 ; $i < $iter ; $i++ ) {
        my ( $sample_indexes, $out_of_bag ) = sample_train_data($train_data);
        my $dtree =
          AI::DecisionTree->new( prune => 1, noise_mode => 'pick_best' );
        $r->send( q`attrs <- c('` . join( "', '", @attrs ) . q`')` );
        $r->send( q`m_attrs <- sample(attrs, ` . $m_attr_count . q`)` );
        $r->send(q`cat(m_attrs)`);
        my @m_attrs = split( /\s+/, $r->read );
        foreach my $s_index (@$sample_indexes) {
            my $td = $train_data->[ $s_index - 1 ];
            my %attrs = map { $_ => $td->{$_} } @m_attrs;
            $dtree->add_instance(
                attributes => {%attrs},
                result     => $td->{survived},
            );
        }

        $dtree->train;
        push @forest, { tree => $dtree, attrs => [@m_attrs] };
        print "Trained $i tree with params: " . Dumper( \@m_attrs ) . "\n";
    }

    return \@forest;
}

sub evaluate {
    my ( $forest, $test_data ) = @_;
    my ( $tp, $tn, $fp, $fn );

    my $majority = scalar(@$forest) / 2;

    foreach my $t_data (@$test_data) {
        my $t_res = 0;
        foreach my $dt (@$forest) {
            my %attrs = map { $_ => $t_data->{$_} } @{ $dt->{attrs} };
            $t_res += $dt->{tree}->get_result( attributes => {%attrs} );
        }

        my $result = $t_res > $majority ? 1 : 0;
        my $exp_result = $t_data->{survived};

        $tp++ if ( $result  && $exp_result );
        $tn++ if ( !$result && !$exp_result );
        $fp++ if ( !$result && $exp_result );
        $fn++ if ( $result  && !$exp_result );
    }

    my $score = ( $tp + $tn ) / scalar(@$test_data);
    return $score;
}

sub bin_values {
    my ( $value, @bins ) = @_;

    return 0 unless ( $value && $value =~ /^[0-9]+(\.[0-9]+)?$/ );

    my $i = 1;
    for ( ; $i <= $#bins ; $i++ ) {
        last if $value <= $i;
    }

    return $i;
}
