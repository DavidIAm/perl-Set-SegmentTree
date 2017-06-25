######

package Set::SegmentTree::Builder;
use strict;
use warnings;
use Carp qw/croak confess/;
use IO::File;
use Time::HiRes qw/gettimeofday/;
use List::Util qw/reduce uniq/;
use Readonly;

Readonly our $INTERVAL_IDX       => 0;
Readonly our $INTERVAL_MIN       => 0;
Readonly our $INTERVAL_MAX       => 1;
Readonly our $INTERVAL_UUID      => 2;
Readonly our $TRUE               => 1;
Readonly our $MS_IN_NS           => 1000;
Readonly our $INTERVALS_PER_NODE => 2;

#########################
my $cc  = 0;
my $icc = 0;
#########################

sub new_instance {
    my ( $class, $options ) = @_;
    return bless { locked => 0, uuid_generator => Data::UUID->new, segment_list => [], %{ $options || {} } },
        $class;
}

sub build {
    my ( $self ) = @_;
    $self->build_tree(@{$self->{segment_list}});
    return Set::SegmentTree->deserialize(
        $self->serialize );
}

sub new {
    my ( $class, @list ) = @_;
    my $options = {};
    $options = pop @list if 'HASH' eq ref @list;
    $class->new_instance($options)->add_segments(@list);
}

sub add_segments {
  my ($self, @list) = @_;
  confess "This tree already built. Make a new one" if $self->{locked};
  push @{$self->{segment_list}}, @list;
  return $self;
}

sub serialize {
    my ( $self) = @_;
    confess "Cannot serialized unlocked tree" unless $self->{locked};

    my $t = Set::SegmentTree::ValueLookup->new(
        root    => $self->{tree},
        nodes   => $self->{nodelist},
        created => time
    );
    return $t->serialize;
}

sub to_file {
  my ($self, $outfile ) = @_;
    my $out = IO::File->new( $outfile, '>:raw' );
    $out->print($self->serialize);
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
    my ( $self, @segment_list ) = @_;
    my ($elementary) = reduce {
        my ( $d, $c ) = ( $a, $a );
        if ( 'ARRAY' ne ref $a ) {
            $d = [ [ $c, $c ], $c ];
        }
        $c = pop @{$d};
        [ @{$d}, [ $c, $b ], [ $b, $b ], $b ];
    }
    $self->endpoints(@segment_list);
    pop @{$elementary};    # extra bit
    $self->{elist} = $elementary;
    return $elementary;
}

sub build_tree {
    my ( $self, @segment_list ) = @_;
    if ( $self->{locked} ) {
        croak 'This tree is immutable. Build a new one.';
    }
    $self->{locked} = 1;
    my $elementary = $self->build_elementary_list(@segment_list);

    if ( $self->{verbose} ) {
        warn "Building binary tree\n";
    }
    my $st = gettimeofday;
    $self->{tree} = $self->build_binary( 0, $#{$elementary} );
    if ( $self->{verbose} ) {
        my $et = gettimeofday;
        warn "took $cc calls "
            . sprintf( '%0.3f', ( ( $et - $st ) * $MS_IN_NS ) / $cc )
            . ' ms per ('
            . ( $et - $st )
            . " elap)\n";
        warn "placing intervals...\n";
    }
    my $ist = gettimeofday;
    $self->place_intervals(@segment_list);
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

1;
__END__

=head1 NAME

Set::SegmentTree::Builder - Builder for Segment Trees in Perl

=head1 SYNOPSIS

  use Test::More;
  my $builder = Set::SegmentTree::Builder->new(
    @segment_list, 
    {option => ovalue}
    );
  $builder->add_segments([ start, end, segment_name ], [ ... ]);
  isa_ok $builder->build(), 'Set::SegmentTree';
  $builder->to_file('filename');

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

  constructor for a new builder

  accepts a list of segments

  segments are three element array refs like this

  [ low value, high value, string identifier ]

=item add_segments

  allows incremental building if you don't have them all at once 

=item build

  creates a new segment tree object
  pass a list of intervals
  returns the tree object

  This may take quite some time!

=item to_file

  save the tree to a file
  Writes a google flatbuffer style file

=back

=head1 DIAGNOSTICS

extensive logging if you construct with option { verbose => 1 }

=head1 CONFIGURATION AND ENVIRONMENT

Written to require very little configuration or environment

Reacts to no environment variables.

=head2 EXPORT

None

=head1 SEE ALSO

Set::FlatBuffer
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
