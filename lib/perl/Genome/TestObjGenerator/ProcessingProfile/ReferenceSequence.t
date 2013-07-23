#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok("Genome::TestObjGenerator::ProcessingProfile::ReferenceSequence");

my %provided = (name => "test1");
my $p = Genome::TestObjGenerator::ProcessingProfile::ReferenceSequence->generate_obj(\%provided);
ok($p->isa("Genome::ProcessingProfile::ReferenceSequence"), "Generated a processing profile");
is($p->name, "test1", "Processing profile has the correct name");

my $p2 = Genome::TestObjGenerator::ProcessingProfile::ReferenceSequence->setup_object();
ok($p2->isa("Genome::ProcessingProfile::ReferenceSequence"), "Generated a processing profile");
is($p2->name, "test_processing_profile_1", "Processing profile got default name");

done_testing;
