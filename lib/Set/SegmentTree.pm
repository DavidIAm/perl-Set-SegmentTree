package Set::SegmentTree;

use 5.022001;
use strict;
use warnings;

require Exporter;

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our $VERSION = '0.01';

use Carp qw/confess/;
use Data::Dumper;
use Data::UUID;
use File::Map qw/map_file/;
use IO::File;
use List::Util qw/reduce uniq/;
use Set::SegmentTree::ValueLookup;
use Time::HiRes qw/gettimeofday/;
use Readonly;

use strict;
use warnings;
#########################
Readonly our $INTERVAL_IDX       = 0;
Readonly our $INTERVAL_MIN       = 0;
Readonly our $INTERVAL_MAX       = 1;
Readonly our $INTERVAL_UUID      = 2;
Readonly our $TRUE               = 1;
Readonly our $MS_IN_NS           = 1000;
Readonly our $INTERVALS_PER_NODE = 2;

my $cc  = 0;
my $icc = 0;
#########################
#
sub new {
    croak 'There is no new.  Do you mean Set::Interval->build(\$'
        . 'options)?';
}

sub new_instance {
    my ( $class, $options ) = @_;
    return bless { uuid_generator => Data::UUID->new, %{ $options || {} } },
        $class;
}

sub build {
    my ( $class, @list ) = @_;
    return $class->new_instance->build_tree(@list);
}

sub deserialize {
    my ( $class, $file ) = @_;
    map_file my $bin, $file, '<';
    return $class->new_instance(
        { tree => IntervalTree::ValueLookup->deserialize($bin) } );
}

sub serialize {
    my ( $self, $outfile ) = @_;

    my $t = Set::SegmentTree::ValueLookup->new(
        root    => $self->{tree},
        nodes   => $self->{nodelist},
        created => time
    );
    my $out = IO::File->new( '>:raw', $outfile );
    $out->print( $t->serialize );
    undef $out;
    return -s $outfile;
}

sub endpoint {
    my ( $self, $offset, $which ) = @_;
    return $self->{elist}->[$offset]->[$which];
}

sub endpoints {
    my ( $self, @endpoints ) = @_;
    my @list = sort { $a <=> $b }
        map { ( $_->[$INTERVAL_MIN], $_->[$INTERVAL_MAX] ) } @endpoints;
    return @list;
}

sub add_endpoint_uuid {
    my ( $self, $stime, $etime, $uuid ) = @_;
    warn "add for $stime to $etime $uuid\n" if $self->{verbose};
    return $self->{idx}{ $stime . q^-^ . $etime }{$uuid} = $TRUE;
}

# uuids for endpoint
sub endpoint_uuids {
    my ( $self, $min, $max ) = @_;
    my $offset = 0;
    warn "lookup endpoint $min-$max time " . q^ - ^
        . join( q^+^, sort keys %{ $self->{idx}{ $min . q^-^ . $max } } )
        . "\n"
        if $self->{verbose};
    return keys %{ $self->{idx}{ $min . q^-^ . $max } };
}

sub place_intervals {
    my ( $self, @intervals ) = @_;
    foreach my $node ( @{ $self->{nodelist} } ) {
        next if exists $node->{low};
        foreach my $interval (@intervals) {
            my ( $min, $max, $uuid ) = @{$interval};
            if ( $node->{min} >= $min && $node->{max} <= $max ) {
                $self->add_endpoint_uuid( $node->{min}, $node->{max}, $uuid );
            }
        }
        @{ $node->{segments} }
            = $self->endpoint_uuids( $node->{min}, $node->{max} );
    }
    return;
}

sub build_elementary_list {
    my ( $self, @interval_list ) = @_;
    my ($elementary) = reduce {
        my ( $d, $c ) = ( $a, $a );
        if ( 'ARRAY' ne ref $a ) {
            $d = [ [ $c, $c ], $c ];
        }
        $c = pop @{$d};
        [ @{$d}, [ $c, $b ], [ $b, $b ], $b ];
    }
    $self->endpoints(@interval_list);
    pop @{$elementary};    # extra bit
    $self->{elist} = $elementary;
    return $elementary;
}

sub build_tree {
    my ( $self, @interval_list ) = @_;
    if ( ref $self->{tree} ) {
        croak 'This tree is immutable. Build a new one.';
    }
    my $elementary = build_elementary_list(@interval_list);

    if ( $self->{verbose} ) {
        warn "Building binary tree\n";
    }
    my $st = gettimeofday;
    $self->{tree} = $self->build_binary( 0, $#{$elementary} );
    if ( $self->{verbose} ) {
        my $et
            = gettimeofday warn "took $cc calls "
            . sprintf( '%0.3f', ( ( $et - $st ) * $MS_IN_NS ) / $cc )
            . ' ms per ('
            . ( $et - $st )
            . " elap)\n";
        warn "placing intervals...\n";
    }
    my $ist = gettimeofday;
    $self->place_intervals(@interval_list);
    my $iet = gettimeofday;
    warn "took $icc segment placements "
        . sprintf( '%0.3f', ( ( $iet - $ist ) * $MS_IN_NS ) / $icc )
        . ' ms per ('
        . ( $iet - $ist )
        . " elapsed)\n"
        if $self->{verbose};
    return $self;
}

# from being offset into elementary list
# to being offset into elementary list
sub build_binary {
    my ( $self, $from, $to ) = @_;
    $cc++;
    my $segmentuuid = $self->{uuid_generator}
        ->to_string( $self->{uuid_generator}->create );
    my $mid = int( ( $to - $from ) / $INTERVALS_PER_NODE ) + $from;
    my $node = {
        split => $self->endpoint( $mid,  $INTERVAL_MAX ),
        min   => $self->endpoint( $from, $INTERVAL_MIN ),
        max   => $self->endpoint( $to,   $INTERVAL_MAX ),
    };

# 10, 14 => int((14-10)/2)+10 = int(4/2)+10 = 2+10 = <10, 12, 14>
#                                      <10L, 12H, 14H>
#                     <10L, 11H, 12H>                  <12L, 13H, 14H>
#       <10L, 10H, 11H>          <12L, - , 12H>    <12L, 12H , 13H> <14L, - , 14H>
# <10L, - , 10H> <11L, - , 11H>               <12L, - , 12H> <13L, - , 13H>
#
# 10, 13 => int((13-10)/2)+10 = int(3/2)+10 = 1+10 = <10, 11, 13>
#                    <10L, 11H, 13H>
#       <10L, 10H, 11H>              <12L, 12H, 13H>
# <10L, - , 10H> <11L, - , 11H> <12L, - , 12H> <13L, - , 13H>
#
# 10, 12 => int((12-10)/2)+10 = int(2/2)+10 = 1+10 = <10, 11, 12>
#                       <10L, 11L, 12H>
#       <10L, 10H , 11H>              <11L, 11H , 12H>
# <10L, - , 10H> <11L, - , 11H> <11L, - , 11H> <12L, -, 12H>
#
# 10, 11 => int((11-10)/2)+10 = int(1/2)+10 = 0+10 = <10, 10, 11>
#                    <10L, 10H, 11H>
#                              <11L, 11H , 12H>
#                        <11L, - , 11H>  <12L, - , 12H>
#
# 10, 10 => int((10-10)/2)+10 = int(0/2)+10 = 0+10 = <10, 10 , 11>
#                    <10, -, 10>
#                                 <11, - , 11>
    if ( $from != $to ) {
        $node->{low}  = $self->build_binary( $from,    $mid );
        $node->{high} = $self->build_binary( $mid + 1, $to );
    }
    push @{ $self->{nodelist} }, $node;
    return $#{ $self->{nodelist} };
}

sub find {
    my ( $self, $instant ) = @_;
    return uniq $self->find_segments( $self->node( $self->{tree} ),
        $instant );
}

sub node {
    my ( $self, $offset ) = @_;
    return $self->{nodelist}->[$offset];
}

$Data::Dumper::Sortkeys = 1;

sub find_segments {
    my ( $self, $node, $instant ) = @_;
    warn "instant $instant node "
        . $node->{min} . '->'
        . $node->{split} . '->'
        . $node->{max} . q^: ^
        . join( q^ ^, sort @{ $node->{segments} || [] } ) . "\n"
        if $self->{verbose};
    return uniq @{ $node->{segments} || [] },
        map { $self->find_segments( $_, $instant ) }
        grep { $instant >= $_->{min} && $instant <= $_->{max} }
        map { defined $node->{$_} ? $self->node( $node->{$_} ) : () }
        qw/low high/;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

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

wat? L<Segment Tree|https://en.wikipedia.org/wiki/Segment_tree>

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

=back

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
