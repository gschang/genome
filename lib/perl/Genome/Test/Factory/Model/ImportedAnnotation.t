#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok("Genome::Test::Factory::Model::ImportedAnnotation");

my $m = Genome::Test::Factory::Model::ImportedAnnotation->setup_object();
ok($m->isa("Genome::Model::ImportedAnnotation"), "Generated an annotation model");

done_testing;

