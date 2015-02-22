#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1; #FeatureLists generate their own IDs, but this is still a good idea
};

use above 'Genome';
use Test::More;
use Genome::Utility::Test qw(compare_ok);
use Test::Exception;

my $class = 'Genome::FeatureList';

use_ok($class);

my $test_dir = Genome::Utility::Test->data_dir($class);
$test_dir .= "/v1";
my $test_bed_file = $test_dir. '/1.bed';
my $test_merged_bed_file = $test_dir. '/1.merged.bed';
my $one_based_file_output = $test_dir.'/1-onebased.bed';
ok(-e $test_bed_file, 'test file ' . $test_bed_file . ' exists');
ok(-e $test_merged_bed_file, 'test file ' . $test_merged_bed_file . ' exists');
ok(-e $one_based_file_output, 'test file ' . $one_based_file_output . ' exists');

my $test_bed_file_md5 = Genome::Sys->md5sum($test_bed_file);

my $feature_list = Genome::FeatureList->create(
    name                => 'GFL test feature-list',
    format              => 'true-BED',
    content_type        => 'target region set',
    file_path           => $test_bed_file,
    file_content_hash   => $test_bed_file_md5,
);

ok($feature_list, 'created a feature list');
isa_ok($feature_list, 'Genome::FeatureList');
ok($feature_list->verify_file_md5, 'bed file md5 checks out');
is($feature_list->file_content_hash, $feature_list->verify_file_md5, 'verify_bed_file_md5 calculated the expected value');

my $file_path = $feature_list->file_path;
my $diff = Genome::Sys->diff_file_vs_file($test_bed_file, $file_path);
ok(!$diff, 'returned file matches expected file')
    or diag("diff:\n" . $diff);

# Test gzipping and tabix indexing
my $gzipped_file = $feature_list->get_tabix_and_gzipped_bed_file;
my $tabix_file = "$gzipped_file.tbi";
my $expected_gzipped_file = "$test_dir/expected.bed.gz";
my $expected_tabix_file = "$expected_gzipped_file.tbi";

ok(-s $gzipped_file, "Gzipped file exists");
compare_ok($gzipped_file, $expected_gzipped_file, "gzipped file ($gzipped_file) is as expected ($expected_gzipped_file)");
ok(-s $tabix_file, "Tabix index exists");
compare_ok($tabix_file, $expected_tabix_file, "tabix file ($tabix_file) is as expected ($expected_tabix_file)");

my $merged_file = $feature_list->merged_bed_file;
ok(-s $merged_file, 'merged file created');
my $merged_diff = Genome::Sys->diff_file_vs_file($merged_file, $test_merged_bed_file);
ok(!$merged_diff, 'returned file matches expected file')
    or diag("diff:\n" . $merged_diff);

my $feature_list_with_bad_md5 = Genome::FeatureList->create(
    name                => 'GFL bad MD5 list',
    format              => 'true-BED',
    content_type        => 'target region set',
    file_path           => $test_bed_file,
    file_content_hash   => 'abcdef0123456789abcdef0123456789',
);
ok(!$feature_list_with_bad_md5, 'failed to produce a new object when MD5 was incorrect');

my $test_multitracked_1based_bed = $test_dir.'/2.bed';
my $test_multitracked_1based_merged_bed = $test_dir. '/2.merged.bed';
ok(-e $test_multitracked_1based_bed, 'test file ' . $test_multitracked_1based_bed . ' exists');
ok(-e $test_multitracked_1based_merged_bed, 'test file ' . $test_multitracked_1based_merged_bed . ' exists');

my $test_multitracked_1based_bed_md5 = Genome::Sys->md5sum($test_multitracked_1based_bed);

my $feature_list_2 = Genome::FeatureList->create(
    name                => 'GFL test multi-tracked 1-based feature-list',
    format              => 'multi-tracked 1-based',
    content_type        => 'targeted',
    file_path           => $test_multitracked_1based_bed,
    file_content_hash   => $test_multitracked_1based_bed_md5,
);
ok($feature_list_2, 'created multi-tracked 1-based feature list');
ok($feature_list_2->verify_file_md5, 'bed file md5 checks out');
is($test_multitracked_1based_bed_md5, $feature_list_2->verify_file_md5, 'verify_bed_file_md5 calculated the expected value');

my $merged_file_2 = $feature_list_2->merged_bed_file;
ok(-s $merged_file_2, 'merged file created');
my $merged_diff_2 = Genome::Sys->diff_file_vs_file($merged_file_2, $test_multitracked_1based_merged_bed);
ok(!$merged_diff_2, 'returned file matches expected file')
    or diag("diff:\n" . $merged_diff_2);

my $one_based_file = $feature_list_2->get_one_based_file;
ok(-s $one_based_file, "one_based_file exists");
compare_ok($one_based_file, $feature_list_2->file_path, name => "1-based file is the same for a 1-based feature list");

my $one_based_file2 = $feature_list->get_one_based_file;
ok(-s $one_based_file2, "one_based_file exists");
compare_ok($one_based_file2, $one_based_file_output, name => "true-BED was correctly converted to 1-based file");

# Test converting multi-tracked to single-tracked
my $single_track_bed = $feature_list_2->get_target_track_only('target_region');
my $expected_single_track_bed = File::Spec->join($test_dir, "single_track_of_multi_track.bed");
compare_ok($single_track_bed, $expected_single_track_bed, name => "get_target_track_only returned the expected file");

dies_ok {$feature_list_2->get_target_track_only('does not exist')}, "get_target_track_only dies when provided with a bad track name";

my $feature_list_3 = Genome::FeatureList->create(
    name => 'GFL test unknown format feature-list',
    format              => 'unknown',
    content_type        => 'target region set',
    file_path           => $test_multitracked_1based_bed,
    file_content_hash   => $test_multitracked_1based_bed_md5,
);
ok($feature_list_3, 'created unknown format feature list');
ok($feature_list_3->verify_file_md5, 'bed file md5 checks out');
my $merged_bed_file; 
eval {$merged_bed_file = $feature_list_3->merged_bed_file};
ok(!$merged_bed_file, 'refused to merge bed file with unknown format');
my $processed_bed_file;
eval{$processed_bed_file = $feature_list_3->processed_bed_file};
ok(!$processed_bed_file, 'attempt to process bed file did not return a bed file');

lives_ok {$feature_list_3->_check_bed_list_is_on_correct_reference}, "_check_bed_list_is_on_correct_reference worked";

is_deeply([$feature_list_2->chromosome_list],[qw(1 2 X)], "list_chromosomes returns the expected list");

done_testing();
