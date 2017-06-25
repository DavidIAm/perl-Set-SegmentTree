use strict;
use Time::HiRes qw/gettimeofday/;
use Carp qw/confess/;
use IO::File;
use File::Map qw/map_file/;
use IntervalTree::ValueLookup;
use Data::Dumper;

my $range  = shift @ARGV;
my $repeat = shift @ARGV;
my $file   = shift @ARGV;

my $st = gettimeofday;
map_file my $bin, $file, '<';
my $tree = IntervalTree::ValueLookup->deserialize($bin);
my $et   = gettimeofday;
warn (( $et - $st ) . " elapsed to load tree");

sub rand_over_range {
    my ( $min, $max ) = @_;
    int( rand( $max - $min ) ) + $min,;
}
sub get_segments {
    my ($key) = @_;
    return () unless -f 'segments/' . $key;
    my $seg = IO::File->new();
    $seg->open( '< segments/' . $key );
    return map { chomp } <$seg>;
}

sub find_segments {
    my ( $ri, $inst ) = @_;
    my $root = $tree->nodes->[$ri];
    confess "Root is not a ref?" unless ref $root;
    return get_segments( $root->{segments} )
        if !defined $root->{split};
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
    warn "OUT OF RANGE $inst vs. $root->{min}, $root->{split}, $root->{max}";
    return ();
}

my $qst = gettimeofday;
for ( 0 .. $repeat ) {
    find_segments(
        $tree->root,
        rand_over_range(
            $tree->nodes->[ $tree->root ]->{min},
            $tree->nodes->[ $tree->root ]->{max}
        )
    );
}
my $qet = gettimeofday;
warn "took $repeat queries "
    . sprintf( '%0.3f', ( ( $qet - $qst ) * 1000 ) / $repeat )
    . " ms per ("
    . ( $qet - $qst )
    . " elap)\n";

