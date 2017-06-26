#!/usr/bin/perl

# Use the perl data flattables to build our flatbuffer classes
use lib '../perl-Data-FlatTables';
use Data::FlatTables;
chdir 'lib';
Data::FlatTables::main('../schema.fbs');
chdir '..';

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

