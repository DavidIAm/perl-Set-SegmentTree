=head1 NAME

Set::SegmentTree - Perl extension for Segment Trees

=head1 SYNOPSIS

  use Set::SegmentTree;
  my $newtree = Set::SegmentTree->build(file => 'tree.bin');
  $newtree->build([ start, end, segment_name ], [ start, end, segment_name ]);
  my @segments = $treehandler->find($value);
  $newtree->serialize( $filename );

  my $savedtree = Set::SegmentTree->deserialize( $filename );
  my @segments = $savedtree->find($value);

=head1 DESCRIPTION

wat? [[https://en.wikipedia.org/wiki/Segment_tree]]

In the use case where 

1) you have a series of potentially overlapping segments
1) you need to know which segments encompass any particular value
1) the access pattern is almost exclustively read biased

The Segment Tree data structure allows you to resolve any single value to the
list of segments which encompass it in O(log(n)+nk) 

=head2 EXPORT

This is not that kind of perl module

=head1 SUBROUTINES/METHODS

=over 4

=item build

  creates a new segment tree
  pass a list of intervals
  returns the tree object

  Intervals are defined as arrays with
   [ low_value, high_value, identifier_name ]

=item find

  find the list of segments for a value
  expected to be performant

  pass the value
  returns the list of segment names

=item serialize

  save the tree to a file
  Writes a google flatbuffer style file

=item deserialize

  make the tree available to query
  Uses FlatBuffers and memory mapping
  expected to be highly performant

=back 4

=head1 SEE ALSO

Data::FlatTables
File::Map

=head1 AUTHOR

David Ihnen, E<lt>davidihnen@gmail.comE<gt>

=head1 DIAGNOSTICS

extensive logging if you construct with option { verbose => 1 }

=head1 CONFIGURATION AND ENVIRONMENT

Written to require very little configuration or environment

Reacts to no environment variables.

=head1 INCOMPATIBILITIES

A system with variant endian maybe?

=head1 DEPENDENCIES

Google Flatbuffers

=head1 BUGS AND LIMITATIONS

Only works with FlatBuffers for serialization

Subject the limitations of Data::FlatTables

Only stores keys for you to use to index into other structures
I like uuids for that.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 by David Ihnen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
