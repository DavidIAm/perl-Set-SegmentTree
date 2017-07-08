#!/usr/bin/perl
# This script is used by the author to...
# - generate the flattables classes
# - apply perltidy to them (and the main classes)
# - add version numbers to flattables classes
# - update version numbers in the main classes

# Use the perl data flattables to build our flatbuffer classes
use lib '../perl-Data-FlatTables';
use Data::FlatTables;
chdir 'lib';
Data::FlatTables::main('../schema.fbs');
chdir '..';

my $vhandle = IO::File->new('.version');
our $VERSION = <$vhandle>;
chomp $VERSION;

foreach my $file (
    qw^lib/Set/SegmentTree/node.pm lib/Set/SegmentTree/ValueLookup.pm lib/Set/SegmentTree.pm lib/Set/SegmentTree/Builder.pm^
    )
{
    my $back = $file . '.bak';
    rename $file, $back;
    system "cat $back | perltidy -pbp -iob > $file";
    do {
        my $in  = IO::File->new( $back, 'r' );
        my $out = IO::File->new( $file, 'w' );
        my $vpat        = '\\d+\\.\\d+';
        my $saw_version = 0;
        while (<$in>) {
            if (/^(our \$VERSION = ')$vpat(';)$/) {
                $out->print( $1, $VERSION, $2, "\n" );
                $saw_version = 1;
            }
            elsif (/^=head1 VERSION$/) {
                my $skipBlank      = <$in>;
                my $consumeVersion = <$in>;
                $out->print($_);
                $out->print($skipBlank);
                $out->print( $VERSION . "\n" );
            }

            # When we have a generated file with no version
            elsif (/^sub new \{$/) {
                unless ($saw_version) {
                    $out->print( "our \$VERSION = '" . $VERSION . "';\n\n" );
                }
                $out->print($_);
            }
            else {
                $out->print($_);
            }
        }
    };
    unlink $back if -s $file;
}

use Test::XT 'WriteXT';

# Write some specific tests:
WriteXT(
    # Generally safe and recommended for most distributions
    'Test::Pod'            => 't/pod.t',
    'Test::CPAN::Meta'     => 't/meta.t',
    'Test::MinimumVersion' => 't/minimumversion.t',
    'Test::HasVersion'     => 't/hasversion.t',

    # May become unreliable over time as PPI and Perl::Critic change.
    # Safe when BOTH distribution and policy file are active and maintained.
    'Test::Perl::Critic' => 't/critic.t',
);

