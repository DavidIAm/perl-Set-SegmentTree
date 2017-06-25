# Before 'make install' is performed this script should be runnable with
use Carp qw/confess/;
use IO::File;

# 'make test'. After 'make install' it should work as 'perl Set-SegmentTree.t'

use Data::Dumper;
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 11;
BEGIN { use_ok('Set::SegmentTree') }

our @nodelist;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# provide a set of intervals
# get a tree builder
# my $treebuilder = Set::SegmentTreeBuilder->new()
# Get yourself an actual queryable segment tree
# my $tree = $treebuilder->build([[MIN,MAX,ID],[ ... ]]);
# save the tree to a file
# $tree->write(file => $fh);
# read from a previously written file
# $tree->read(file => $fh);
# Query your tree for a particular data
# (ID, ID, ID, ID) = $tree->find(QUERYVALUE);
use Data::UUID;

use Set::SegmentTree;
my $tree = Set::SegmentTree->build([1,5,'A'],[2,3,'B'],[3,8,'C']);
is scalar $tree->find(0), 0, 'find 0';
is scalar $tree->find(1), 1, 'find 1';
is scalar $tree->find(2), 2, 'find 2';
is scalar $tree->find(3), 3, 'find 3';
is scalar $tree->find(4), 2, 'find 4';
is scalar $tree->find(5), 2, 'find 5';
is scalar $tree->find(6), 1, 'find 6';
is scalar $tree->find(7), 1, 'find 7';
is scalar $tree->find(8), 1, 'find 8';
is scalar $tree->find(9), 0, 'find 9';
#print Dumper $tree->find(0);
#print "---\n";
#print Dumper $tree->find(1);
#print "---\n";
#print Dumper $tree->find(2);
#print "---\n";
#print Dumper $tree->find(3);
#print "---\n";
#print Dumper $tree->find(4);
#print "---\n";
#print Dumper $tree->find(5);
#print "---\n";
#print Dumper $tree->find(6);
#print "---\n";


__DATA__

sub rand_over_range {
    my ( $min, $max ) = @_;
    int( rand( $max - $min ) ) + $min,;
}

sub intervaldata {
    my ( $count, $min, $max ) = @_;
    my $ug = Data::UUID->new;
    die "max is less than min" if $min > $max;
    map {
        [   (   sort { $a <=> $b } rand_over_range( $min, $max ),
                rand_over_range( $min, $max )
            ),
            $ug->to_string( $ug->create() ),
        ]
    } ( 0 .. $count );
}

use Time::HiRes qw/gettimeofday/;
my $cc  = 0;
my $icc = 0;
our $segmentlookups = {};
our $filehandles    = {};
our $INTERVAL_MIN   = 0;
our $INTERVAL_MAX   = 1;
our $INTERVAL_UUID  = 2;


sub buildRandomTree {
    my ( $count, $range ) = @_;
    my $ap = {};
    warn "generating intervals...\n" if $self->{verbose};
    my @rawintervals = intervaldata( $count, time - $range, time + $range );
    buildTree(@rawintervals);
}
my $ug       = new Data::UUID;

sub get_segments {
    my ($key) = @_;
    return undef unless -f 'segments/' . $key;
    my $seg = IO::File->new();
    $seg->open( '< segments/' . $key );
    return <$seg>;
}

sub place_intervals {
    my ( $treeroot, $intervals ) = @_;
    foreach my $interval ( @{$intervals} ) {
        $icc++;
        foreach ( find_union_nodes( $treeroot, $interval ) ) {
            add_segment( $_->{segments}, $interval->[$INTERVAL_UUID] );
        }
    }
    return $treeroot;
}

sub find_segments {
    my ( $ri, $inst ) = @_;
    my $root = $nodelist[$ri];
    confess "Root is not a ref?" unless 'HASH' eq ref $root;
    return get_segments( $root->{segments} ) if !defined $root->{split};
    return get_segments( $root->{segments} ),
        find_segments( $root->{high}, $inst )
        if $inst == $root->{max};
    return get_segments( $root->{segments} ),
        find_segments( $root->{low}, $inst )
        if $inst == $root->{min};
    return get_segments( $root->{segments} ),
        find_segments( $root->{low}, $inst )
        if $inst > $root->{min} && $inst <= $root->{split};
    return get_segments( $root->{segments} ),
        find_segments( $root->{high}, $inst )
        if $inst > $root->{split} && $inst < $root->{max};
}

sub find_union_nodes {
    my ( $node_index, $int ) = @_;

    my $min   = $int->[$INTERVAL_MIN];
    my $max   = $int->[$INTERVAL_MAX];
    my $uuid  = $int->[$INTERVAL_UUID];
    my $node  = $nodelist[$node_index];
    my $split = $node->{split};

    my @thisnode = ();

    # union node point! return!
    push @thisnode, $node if $node->{min} == $min && $node->{max} == $max;

    return @thisnode unless defined $split;
    confess Dumper [ $node, $int ] unless defined $split;

    # create direction list
    # nodemin, intmin, split, intmax, nodemax
    # nodemin, intmin, intmax, split, nodemax
    # nodemin, split, intmin, intmax, nodemax
    my @node_indexes;

    if ( $min <= $split ) {
        if ( $max > $split ) {
            push @node_indexes, [ $node->{low}, [ $min, $split ] ];
        }
        else {
            push @node_indexes, [ $node->{low}, $int ];
        }
    }

    if ( $max >= $split ) {
        if ( $min < $split ) {
            push @node_indexes, [ $node->{high}, [ $split, $max ] ];
        }
        else {
            push @node_indexes, [ $node->{high}, $int ];
        }
    }

    confess "problem" . Dumper [ $node, $int ] unless scalar @node_indexes;
    @thisnode, map { find_union_nodes( @{$_} ) } @node_indexes;
}

my $intervals = shift @ARGV;
my $range     = shift @ARGV;
my $repeat    = shift @ARGV;
my $outfile   = shift @ARGV;
warn "BUILDING $intervals intervals over range $range...";
my $tree = buildTree( $intervals, $range );
warn "QUERYING...";

#print Dumper $tree;

my $qst = gettimeofday;
for ( 0 .. $repeat ) {
    find_segments( $tree, rand_over_range( time - $range, time + $range ) );
}
my $qet = gettimeofday;
warn "took $repeat queries "
    . sprintf( '%0.3f', ( ( $qet - $qst ) * 1000 ) / $repeat )
    . " ms per ("
    . ( $qet - $qst )
    . " elap)\n";

use IntervalTree::ValueLookup;

my $t = IntervalTree::ValueLookup->new(
    root    => $tree,
    nodes   => [@nodelist],
    created => time
);
open FILE, '>:raw', $outfile;
print FILE $t->serialize;
close FILE;

