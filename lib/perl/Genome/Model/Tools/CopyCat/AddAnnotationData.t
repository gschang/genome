#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1; #FeatureLists generate their own IDs, but this is still a good idea
};

use Test::More tests => 6;

use above 'Genome';
use Genome::Utility::Test qw(compare_ok);
use Genome::Test::Factory::SoftwareResult::User;
use File::Spec;

my $class = 'Genome::Model::Tools::CopyCat::AddAnnotationData';
use_ok($class);

my $test_dir = File::Spec->join(Genome::Utility::Test->data_dir($class), 'v1');
my $data_directory = File::Spec->join($test_dir, 'data_directory');
ok(-d $data_directory, "test data directory $data_directory exists");
my $reference_build = Genome::Model::Build->get(106942997); 
ok($reference_build, 'Successfully found reference build');
my $version = '-99';

my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash(
    reference_sequence_build => $reference_build,
);


my $cmd = Genome::Model::Tools::CopyCat::AddAnnotationData->create(reference_sequence => $reference_build,
                                                                   version            => $version,
                                                                   data_directory     => $data_directory);

ok($cmd, 'Successfully created command');
ok($cmd->execute, 'Successfully executed command');

my $result = Genome::Model::Tools::CopyCat::AnnotationData->get_with_lock(
                                                                    reference_sequence => $reference_build,
                                                                    version            => $version,
                                                                    users              => $result_users,
);
ok($result, 'Successfully found the AnnotationData');
