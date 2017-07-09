#!/usr/bin/perl
# This script is used by the author to...
# - generate the flattables classes
# - apply perltidy to them (and the main classes)
# - add version numbers to flattables classes
# - update version numbers in the main classes
# - Update the META.yml with the abstract from the doc

# Use the perl data flattables to build our flatbuffer classes
use lib '../perl-Data-FlatTables';
use Data::FlatTables;
use YAML qw/LoadFile Dump/;
chdir 'lib';
Data::FlatTables::main('../schema.fbs');
chdir '..';

our %abstracts;

my $vhandle = IO::File->new('.version');
our $VERSION = <$vhandle>;
chomp $VERSION;

foreach my $file (
    qw^lib/Set/SegmentTree/node.pm lib/Set/SegmentTree/ValueLookup.pm lib/Set/SegmentTree.pm lib/Set/SegmentTree/Builder.pm Makefile.PL^
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
        my $saw_abstract = 0;
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
            elsif (/^=head1 NAME/) {
                $out->print($_);
                my $skipBlank      = <$in>;
                $out->print( $skipBlank   );
                my $line = <$in>;
                $out->print($line);
                until ($line =~ /^=/) {
                  if ($line =~ / - (.+)$/) {
                    push @{$abstracts{$file}}, $1;
                  }
                  $line = <$in>;
                  $out->print($line);
                }
            }
            elsif (/^abstract/) {
                print_abstract($out, $abstracts{'lib/Set/SegmentTree.pm'}[0]) unless $saw_abstract;
                $saw_abstract = 1;
            }
            elsif (/^license/) {
                $out->print($_);
                print_abstract($out, $abstracts{'lib/Set/SegmentTree.pm'}[0]) unless $saw_abstract;
                $saw_abstract = 1;
            }
            else {
                $out->print($_);
            }
        }
    };
    unlink $back if -s $file;
}

sub print_abstract {
  my ($out, $abstract) = @_;
  $out->print("abstract '$abstract';\n");
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

# and make sure the Makefile regenerates everything, like the readmes.
system "perl Makefile.PL";
