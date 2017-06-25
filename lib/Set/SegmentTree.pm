package Set::SegmentTree;

use 5.022001;
use strict;
use warnings;

require Exporter;

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our $VERSION = '0.01';

use Carp qw/confess croak/;
use Data::Dumper;
use Data::UUID;
use File::Map qw/map_file/;
use Set::SegmentTree::ValueLookup;
use List::Util qw/reduce uniq/;
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
        bless { flatbuffer =>
            Set::SegmentTree::ValueLookup->deserialize($bin) },
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
    return uniq $self->find_segments( $self->node( $self->{flatbuffer}->root ),
        $instant );
}

sub node {
    my ( $self, $offset ) = @_;
    return $self->{flatbuffer}->nodes->[$offset];
}

sub find_segments {
    my ( $self, $node, $instant ) = @_;
    warn "instant $instant node "
        . $node->min . '->'
        . $node->split . '->'
        . $node->max . q^: ^
        . join( q^ ^, sort @{ $node->segments || [] } ) . "\n"
        if $self->{verbose};
    return uniq @{ $node->segments || [] },
        map { $self->find_segments( $_, $instant ) }
        grep { $instant >= $_->{min} && $instant <= $_->{max} }
        map { $node->$_ ? $self->node( $node->$_ ) : () }
        qw/low high/;
}

1;
__END__

=head1 NAME

Set::SegmentTree - Perl extension for Segment Trees

=head1 SYNOPSIS

  use Set::SegmentTree;
  my $builder = Set::SegmentTree::Builder->new(@segment_list);
  $builder->add_segments([ start, end, segment_name ], [ ... ]);
  my $newtree = $builder->build();
  my @segments = $newtree->find($value);
  $newtree->serialize( $filename );

  my $savedtree = Set::SegmentTree->from_file( $filename );
  my @segments = $savedtree->find($value);

=head1 DESCRIPTION

wat? L<Segment Tree|https://en.wikipedia.org/wiki/Segment_tree>

In the use case where 

1) you have a series of potentially overlapping segments
1) you need to know which segments encompass any particular value
1) the access pattern is almost exclustively read biased
1) need to shift between prebuilt segment trees

The Segment Tree data structure allows you to resolve any single value to the
list of segments which encompass it in O(log(n)+nk) 

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
File::Map

=head1 INCOMPATIBILITIES

A system with variant endian maybe?

=head1 DEPENDENCIES

Google Flatbuffers

=head1 BUGS AND LIMITATIONS

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
