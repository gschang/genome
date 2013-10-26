#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok("Genome::Test::Factory::ProcessingProfile::DifferentialExpression");

my $p = Genome::Test::Factory::ProcessingProfile::DifferentialExpression->setup_object();
ok($p->isa("Genome::ProcessingProfile::DifferentialExpression"), "Generated a diff exp pp");

done_testing;
