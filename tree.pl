#!/usr/bin/perl

use strict;
use Data::Dumper;
use Tree::Simple;
use Tree::Simple::View::DHTML;

my $tree = Tree::Simple->new( {name=>'Titanic'}, Tree::Simple->ROOT );
my $m = Tree::Simple->new( { gender => 'M' }, $tree);
my $f = Tree::Simple->new( { gender => 'F' }, $tree);

my $l1 = Tree::Simple->new({Survived=>'N'}, $m);
my $l2 = Tree::Simple->new({Survived=>'Y'}, $f);

$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;
my $view =
  Tree::Simple::View::DHTML->new( $tree,
    node_formatter => sub { my $node = shift; return Dumper($node->getNodeValue()); } );

open (TREE, "> tree.html") 
    or die "Unable to open tree.html: $!\n";

print TREE "<html><head>\n";
print TREE $view->javascript;
print TREE "</head><body>";
print TREE "<h1>" . Dumper($tree->getNodeValue()) . "</h1>\n";
print TREE $view->expandAll;
print TREE "</body></html>";

close TREE;
