#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Utility::Test qw (compare_ok);

my $class = "Genome::Db::Tgi::Command::ImportFromDgidbByCategory";

use_ok($class);

my $data_dir = Genome::Utility::Test->data_dir_ok($class, "v1");
my $temp_file = Genome::Sys->create_temp_file_path;

my $cmd = $class->create(output_file => $temp_file, categories => ["kinase"]);
ok($cmd->execute, "Command executed correctly");
ok(-s $temp_file);

done_testing;

