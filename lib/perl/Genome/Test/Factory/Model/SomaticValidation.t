#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok("Genome::Test::Factory::Model::SomaticValidation");

my $m = Genome::Test::Factory::Model::SomaticValidation->setup_object();
ok($m->isa("Genome::Model::SomaticValidation"), "Generated a somatic validation model");

done_testing;

