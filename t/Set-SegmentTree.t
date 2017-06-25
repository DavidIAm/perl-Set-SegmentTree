# Before 'make install' is performed this script should be runnable with
use Carp qw/confess/;
use IO::File;

# 'make test'. After 'make install' it should work as 'perl Set-SegmentTree.t'

use Data::Dumper;
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 27;
BEGIN { use_ok('Set::SegmentTree') }

our @nodelist;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# provide a set of intervals
# get a tree builder
# my $treebuilder = Set::SegmentTreeBuilder->new()
# Get yourself an actual queryable segment tree
# my $tree = $treebuilder->new([[MIN,MAX,ID],[ ... ]])->build;
# save the tree to a file
# $tree->write(file => $fh);
# read from a previously written file
# $tree->read(file => $fh);
# Query your tree for a particular data
# (ID, ID, ID, ID) = $tree->find(QUERYVALUE);
use Data::UUID;

use Set::SegmentTree;
my $rawtree = Set::SegmentTree::Builder->new(['A',1,5],['B',2,3],['C',3,8],['D',10,12]);
my $tree = $rawtree->build;
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
is scalar $tree->find(10), 1, 'find 10';
is scalar $tree->find(11), 1, 'find 11';
is scalar $tree->find(12), 1, 'find 12';
is scalar $tree->find(13), 0, 'find 13';

my$size = $rawtree->to_file('smalltemp.fastbuf');
ok $size, 'file write succeed';
my $readtree = Set::SegmentTree->from_file('smalltemp.fastbuf');
isa_ok $readtree, 'Set::SegmentTree';
is scalar $readtree->find(0), 0, 'read 0';
is scalar $readtree->find(1), 1, 'read 1';
is scalar $readtree->find(2), 2, 'read 2';
is scalar $readtree->find(3), 3, 'read 3';
is scalar $readtree->find(4), 2, 'read 4';
is scalar $readtree->find(5), 2, 'read 5';
is scalar $readtree->find(6), 1, 'read 6';
is scalar $readtree->find(7), 1, 'read 7';
is scalar $readtree->find(8), 1, 'read 8';
is scalar $readtree->find(9), 0, 'read 9';
is scalar $readtree->find(10), 1, 'find 10';
is scalar $readtree->find(11), 1, 'find 11';
is scalar $readtree->find(12), 1, 'find 12';
is scalar $readtree->find(13), 0, 'find 13';

exit;

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

sub buildRandomTree {
    my ( $base, $count, $range ) = @_;
    my $ap = {};
    my @rawintervals = intervaldata( $count, $base - $range, $base + $range );
    my $b = Set::SegmentTree::Builder->new(@rawintervals);
    return $b, $b->build;
}

do {
    use Benchmark qw(:hireswallclock :all);

    my ($builder, $tree);
    do {
        my $mt = timeit( 50,
            sub { ($builder, $tree) = buildRandomTree( time, 200, 100 ) } );
        warn "build 5 500 interval trees - " . timestr($mt) . "\n";
    };
    do {
        my $mt = timeit(
            1000,
            sub {
                $tree->find( rand_over_range( time - 100, time + 100 ) );
            }
        );
        warn $mt->iters . " memory read took - " . timestr($mt) . "\n";
    };
    do {
        my $mt = timeit( 5, sub { $builder->to_file('tree.bin') } );
        warn "serialize 10 intervals - "
            . timestr($mt) . "\n";
    };
    my $readtree;
    do {
        my $mt = timeit( 5,
            sub { $readtree = Set::SegmentTree->from_file('tree.bin') } );
        warn "deserialize 50 intervals - "
            . timestr($mt) . "\n";
    };
    do {
        my $mt = timeit(
            100,
            sub {
                $readtree->find(
                    rand_over_range( time - 100, time + 100 ) );
            }
        );
        warn "map read took - " . timestr($mt) . "\n";
    };
};
