# NAME

Set::SegmentTree - Perl extension for Segment Trees

# SYNOPSIS

    use Set::SegmentTree;
    my $builder = Set::SegmentTree::Builder->new(@segment_list);
    $builder->add_segments([ start, end, segment_name ], [ ... ]);
    my $newtree = $builder->build();
    my @segments = $newtree->find($value);
    $newtree->serialize( $filename );

    my $savedtree = Set::SegmentTree->from_file( $filename );
    my @segments = $savedtree->find($value);

# DESCRIPTION

wat? [Segment Tree](https://en.wikipedia.org/wiki/Segment_tree)

A Segment tree is an immutable tree structure used to efficiently
resolve a moment to the set of segments which it intersects.

A segment:
 \[ Start Value , End Value , Segment Label \]

Wherein the Start and End values are expected to be numeric.

Start Value is expected to be less than End Value

The speed of Set::SegmentTree depends on not being concerned
with additional segment relevant data, so it is expected one would
use the label as an index into whatever persistance retains
additional information about the segment.

Use walkthrough

    my @segments = ([1,5,'A'],[2,3,'B'],[3,8,'C'],[10,15,'D']);

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
it can be saved and then loaded and queried extremely quickly

    my $builder = Set::SegmentTree::Builder->new(@segments);
    $builder->build;
    $builder->to_file('filename');
    ...

Making this pass in only milliseconds.

    my $tree = Set::SegmentTree->from_file('filename');
    is_deeply [$tree->find(3)], [qw/A B C/];

This structure is useful in the use case where...

1) value segment intersection is important
1) performance of loading and lookup is critical, but building is not

The Segment Tree data structure allows you to resolve any single value to the
list of segments which encompass it in O(log(n)+nk) 

# SUBROUTINES/METHODS

- new

        stub to throw an errow to alert this isn't your typical object

- from\_file

        parameter - filename

        Readies your Set::SegmentTree by memory mapping the file specified
        and returning a new Set::SegmentTree object.

- deserialize

        parameter - flatbuffer serialization

        Readies your Set::SegmentTree by using the data passed
        and returning a new Set::SegmentTree object.

- find

        parameter - value to find segments that intersect

        returns list of segment identifiers

- node

        parameter - offset into the underlying array we want the table entry for

        internal function - data structure dereferencer

- find\_segments

        parameter - value to find segments that intersect
        parameter - node under which to search

        internal function - recursive tree iterator

# DIAGNOSTICS

extensive logging if you construct with option { verbose => 1 }

# CONFIGURATION AND ENVIRONMENT

Written to require very little configuration or environment

Reacts to no environment variables.

## EXPORT

None

# SEE ALSO

Data::FlatTables
File::Map

# INCOMPATIBILITIES

A system with variant endian maybe?

# DEPENDENCIES

Google Flatbuffers

# BUGS AND LIMITATIONS

Doesn't tell you if you matched the endpoint
of a segment, but it could.

Only works with FlatBuffers for serialization

Subject the limitations of Data::FlatTables

Only stores keys for you to use to index into other structures
I like uuids for that.

The values for ranging are evaluated in numeric context, so using
non-numerics probably won't work

# LICENSE AND COPYRIGHT

Copyright (C) 2017 by David Ihnen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.1 or,
at your option, any later version of Perl 5 you may have available.

# AUTHOR

David Ihnen, &lt;davidihnen@gmail.com>
