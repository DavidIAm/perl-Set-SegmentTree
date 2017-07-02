use 5.022001;
use ExtUtils::MakeMaker;
use inc::Module::Install;

readme_from 'lib/Set/SegmentTree.pm', 1, 'md';
readme_from 'lib/Set/SegmentTree.pm';
license 'perl_5';
abstract 'Set::SegmentTree - Immutable segment trees with flatbuffers in perl';

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME => 'Set::SegmentTree',
    VERSION_FROM => 'lib/Set/SegmentTree.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM => { 'Test::XT' => '0.04', 'File::Map' => '0.64', 'Set::IntervalTree' => '0.01', },
    ABSTRACT_FROM => 'lib/Set/SegmentTree.pm', # retrieve abstract from module
    LICENSE       => 'perl_5',
    AUTHOR        => 'David Ihnen <davidihnen@gmail.com>',

    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Set-SegmentTree*' },
);
