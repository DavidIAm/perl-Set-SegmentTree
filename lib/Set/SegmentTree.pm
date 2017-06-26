package Set::SegmentTree;

use 5.022001;
use strict;
use warnings;

require Exporter;

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our $VERSION = '0.01';

use Carp qw/confess croak carp/;
use Set::SegmentTree::ValueLookup;
use List::Util qw/uniq/;
use File::Map qw/map_file/;
use Set::SegmentTree::Builder;

use strict;
use warnings;

sub new {
    croak 'There is no new.  Do you mean Set::Interval::Builder->new(\$'
        . 'options)?';
}

sub from_file {
    my ( $class, $filename ) = @_;
    map_file my $bin, $filename, '<';
    return
        bless {
        flatbuffer => Set::SegmentTree::ValueLookup->deserialize($bin) },
        $class;
}

sub deserialize {
    my ( $class, $serialization ) = @_;
    return
        bless { flatbuffer =>
            Set::SegmentTree::ValueLookup->deserialize($serialization) },
        $class;
}

sub find {
    my ( $self, $instant ) = @_;
    return uniq $self->find_segments(
        $self->node( $self->{flatbuffer}->root ), $instant );
}

sub node {
    my ( $self, $offset ) = @_;
    return $self->{flatbuffer}->nodes->[$offset];
}

sub find_segments {
    my ( $self, $node, $instant ) = @_;
    warn "instant $instant node "
        . $node->min . '->'
        . $node->max . q^: ^
        . join( q^ ^, sort @{ $node->segments || [] } ) . "\n"
        if $self->{verbose};
    return uniq @{ $node->segments || [] },
        map { $self->find_segments( $_, $instant ) }
        grep { $instant >= $_->{min} && $instant <= $_->{max} }
        map { $node->$_ ? $self->node( $node->$_ ) : () } qw/low high/;
}

1;
__END__

=head1 NAME

Set::SegmentTree - Perl extension for Segment Trees

=head1 SYNOPSIS

  use Set::SegmentTree;
  my $builder = Set::SegmentTree::Builder->new(@segment_list);
  $builder->insert([ segment_name, start, end ], [ ... ]);
  my $newtree = $builder->build();
  my @segments = $newtree->find($value);
  $newtree->serialize( $filename );

  my $savedtree = Set::SegmentTree->from_file( $filename );
  my @segments = $savedtree->find($value);

=head1 DESCRIPTION

wat? L<Segment Tree|https://en.wikipedia.org/wiki/Segment_tree>

A Segment tree is an immutable tree structure used to efficiently
resolve a value to the set of segments which encompass it.

A segment:
 [ Segment Label, Start Value , End Value ]

Start Value and End Values Must be numeric.

Start Value Must be less than End Value

Segment Label Must occur exactly once

The speed of Set::SegmentTree depends on not being concerned
with additional segment relevant data, so it is expected one would
use the label as an index into whatever persistance retains
additional information about the segment.

Use walkthrough

 my @segments = (['A',1,5],['B',2,3],['C',3,8],['D',10,15]);

This defines four intervals which both do and don't overlap 
 - A - 1 to 5
 - B - 2 to 3
 - C - 3 to 8
 - D - 10 to 15

Doing a find within the resulting tree 

 my $tree = Set::SegmentTree::Builder->new(@segments)->build

Would make these tests pass

 is_deeply [$tree->find(0)], [];
 is_deeply [$tree->find(1)], [qw/A/];
 is_deeply [$tree->find(2)], [qw/A B/];
 is_deeply [$tree->find(3)], [qw/A B C/];
 is_deeply [$tree->find(4)], [qw/A C/];
 is_deeply [$tree->find(6)], [qw/C/];
 is_deeply [$tree->find(9)], [];
 is_deeply [$tree->find(12)], [qw/D/];

And although this structure is relatively expensive to build,
it can be saved efficiently,

 my $builder = Set::SegmentTree::Builder->new(@segments);
 $builder->to_file('filename');

and then loaded and queried extremely quickly, making this 
pass in only milliseconds.

 my $tree = Set::SegmentTree->from_file('filename');
 is_deeply [$tree->find(3)], [qw/A B C/];

This structure is useful in the use case where...

1) value segment intersection is important
1) performance of loading and lookup is critical, but building is not

The Segment Tree data structure allows you to resolve any single value to the
list of segments which encompass it in O(log(n)+nk) 

=head1 HOW IT WORKS

=head2 Building Trees
 l=label
 v=value
 L=low
 H=high

1) take the list of endpoints  aL, aH, bL, bH
1) sort the endpoints  aL, bL, aH, bH
1) expand to elementary aL->aL, aL->bL, bL->bL, bL->aH, aH->aH, aH->bH, bH->bH
1) create binary tree from this { Vmin, Vmax, ->low, ->high, @segments }
1) populate segments on leaf nodes with the labels they relate to (see below)
1) load into a google flatbuffer table

Each leaf node spans only one of the elementary segments, and has a list
of all of the segments which matching values within its range.

  Many are super familiar with how to build trees, but being new to
  me I document my notes here.

  When handling elementary indexes 10 through 14, this math
  to spliting into tree 

  10, 14 => int((14-10)/2)+10 = int(4/2)+10 = 2+10 = <10, 12, 14>
                           <10L, 14H>
              <10L, 12H  >                  <12L, 14H>
        <10L, 11H>    <12L, @S, 12H>    <12L, 13H>     <14L, @S, 14H>
  <10L, @S, 10H> <11L, @S, 11H>  <12L, @S, 12H> <13L, @S, 13H>

  10 to 13 has an even number and looks like this.

  10, 13 => int((13-10)/2)+10 = int(3/2)+10 = 1+10 = <10, 11, 13>
                     <10L, 13H>
            <10L, 11H>              <12L, 12H, 13H>
  <10L, @S, 10H> <11L, @S, 11H> <12L, @S , 12H> <13L, @S , 13H>

  10 to 12 goes  this way

  10, 12 => int((12-10)/2)+10 = int(2/2)+10 = 1+10 = <10, 11, 12>
                          <10L, 12H>
            <10L, 11H>                   <12L, 12H>
  <10L, @S, 10H> <11L, @S, 11H>                  <12L, @S, 12H>

  only two left

  10, 11 => int((11-10)/2)+10 = int(1/2)+10 = 0+10 = <10, 10, 11>
                     <10L, 11H>
                               <11L, 12H>
                         <11L, @S, 11H>  <12L, @S, 12H>

  Just one node

  10, 10 => int((10-10)/2)+10 = int(0/2)+10 = 0+10 = <10, 10 , 11>
                     <10, @S, 10>

=head2 Populating segments

The way this works is that after I had constructed the tree, I made a loop
that finds the leaf nodes.  (they have undefined low/high pointers).
For each of the leaf nodes I filtered the original segment list
(pre-expansion so fairly short, and includes the labels), comparing the
values of that leaf node to see if its numbers were inside the range
that segment addressed. After filtering, I just mapped them to their
label value.

  foreach my $node (grep { is_leaf? } $self->allnodes) {
    $node->{segments} = map { to_label }
      grep { leafnode_within_segment? } @segments
  }

where k = number of segments
where j = number of distinct elementary segments (>k*2)
This O(sqrt(j)+j*k) algorithm is probably responsible for most of the build
time, but without it the tree is useless.

=head2 Seeking segments

As you probably know seeking in a binary tree is O(log(n)) complexity.

Given an value and a root node, yield the segments by:

Given to match a value, node
1) start with the label set of the current node (noop unless leaf)
2) union the label sets of the matching subnodes
3) return the set

label sets of the matching subnodes
1) start with the list of possible directions (low, high)
1) map to a list of subnodes (->low, ->high)
1) ignore any that are undefined (leaf node condition, no infinite recursion)
1) filter nodes on min <= value and value <= max
1) recursively match with value, node

=head1 SUBROUTINES/METHODS

=over 4

=item new

  stub to throw an errow to alert this isn't your typical object

=item from_file

  parameter - filename

  Readies your Set::SegmentTree by memory mapping the file specified
  and returning a new Set::SegmentTree object.

=item deserialize

  parameter - flatbuffer serialization

  Readies your Set::SegmentTree by using the data passed
  and returning a new Set::SegmentTree object.

=item find

  parameter - value to find segments that intersect

  returns list of segment identifiers

=item node

  parameter - offset into the underlying array we want the table entry for

  internal function - data structure dereferencer

=item find_segments

  parameter - value to find segments that intersect
  parameter - node under which to search

  internal function - recursive tree iterator

=back

=head1 DIAGNOSTICS

extensive logging if you construct with option { verbose => 1 }

=head1 CONFIGURATION AND ENVIRONMENT

Written to require very little configuration or environment

Reacts to no environment variables.

=head2 EXPORT

None

=head1 SEE ALSO

Data::FlatTables

=head1 INCOMPATIBILITIES

A system with variant endian maybe?

=head1 PERFORMANCE

Analysis at this early date indicates my vm with 1 3ghz cpu on 
ubuntu linux is capable of consistently surpassing 1000
lookups per second from a memory mapped file. Initializing the file
into memory map takes no measurable time beyond file system overhead.

Lookup performance from a native perl memory array is almost twice as
fast.

My vm with a quota of 1 3ghz cpu takes over 30 seconds to construct
a segment tree consisting of 1000 root segments with a heavy
degree of overlapping.  I suspect that this performance is adequate
to my use cases.

I suspect that converting the code to be compiled rather than pure
perl could increase performance.  Also, my inefficient algorithm
for populating labels into leaf nodes possibly could be improved.

=head1 MOTIVATION

My Replay project L<https://github.com/DavidIAm/Replay> has a use case
for rapidly looking up intersection of an instant with a series of
business rules which are configured with an effective from and to date.
Any of the configuration states which are created over time result in a
segment tree for lookup. Any of those states may be active, so being able
to retrieve and query them efficiently is critical. This is part of
the Mapper component's ability to determine which configured rules
will be relevant to any particular incoming event.

Collaborators welcome.

=head1 DEPENDENCIES

Google Flatbuffers

=head1 BUGS AND LIMITATIONS

Doesn't tell you if you matched the endpoint
of a segment, but it could.

Doesn't error check the integrity of a segment for numericity or order

Only works with FlatBuffers for serialization

Subject the limitations of Data::FlatTables

Only stores keys for you to use to index into other structures
I like uuids for that.

The values for ranging are evaluated in numeric context, so using
non-numerics probably won't work

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 by David Ihnen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.1 or,
at your option, any later version of Perl 5 you may have available.

=head1 AUTHOR

David Ihnen, E<lt>davidihnen@gmail.comE<gt>

=cut
