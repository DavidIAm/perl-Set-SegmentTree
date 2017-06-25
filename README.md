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

In the use case where 

1) you have a series of potentially overlapping segments
1) you need to know which segments encompass any particular value
1) the access pattern is almost exclustively read biased
1) need to shift between prebuilt segment trees

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
