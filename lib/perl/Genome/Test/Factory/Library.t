#! /usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More tests => 2;
use Genome::Test::Factory::Test qw(test_setup_object);

my $class = 'Genome::Test::Factory::Library';
use_ok($class);

test_setup_object($class);
