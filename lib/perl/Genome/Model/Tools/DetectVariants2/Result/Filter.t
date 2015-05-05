#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN{
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above "Genome";
use Test::More;
use Genome::Test::Factory::SoftwareResult::User;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}
else {
    plan tests => 26;
}

use_ok('Genome::Model::Tools::DetectVariants2::Result::Filter');

#TODO this could really use its own very tiny dataset--we don't care about the results in this test so much as the process
my $test_dir = Genome::Config::get('test_inputs') . '/Genome-Model-Tools-DetectVariants2-Samtools/';
my $test_working_dir = File::Temp::tempdir('DetectVariants2-ResultXXXXX', CLEANUP => 1, TMPDIR => 1);
my $bam_input = $test_dir . '/alignments/102922275_merged_rmdup.bam';


my $refbuild_id = 101947881;

my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash(
    reference_sequence_build_id => $refbuild_id,
);

my $version = 'r613';

my $detector_parameters = '';

my %command_params = (
    reference_build_id => $refbuild_id,
    aligned_reads_input => $bam_input,
    version => $version,
    params => $detector_parameters,
    output_directory => $test_working_dir . '/test',
    aligned_reads_sample => 'TEST',
    result_users => $result_users,
);

my $command = Genome::Model::Tools::DetectVariants2::Samtools->create(%command_params);

isa_ok($command, 'Genome::Model::Tools::DetectVariants2::Samtools', 'created samtools detector');
$command->dump_status_messages(1);
ok($command->execute, 'executed samtools command');
my $result = $command->_result;
isa_ok($result, 'Genome::Model::Tools::DetectVariants2::Result', 'generated result');

my %filter_params = (
    previous_result_id => $result->id,
    version => 'v1',
    output_directory => $test_working_dir . '/test/filter1',
    aligned_reads_sample => 'TEST',
    result_users => $result_users,
);

my $filter_command = Genome::Model::Tools::DetectVariants2::Filter::SnpFilter->create(%filter_params);
isa_ok($filter_command, 'Genome::Model::Tools::DetectVariants2::Filter::SnpFilter', 'created snp-filter filter');
$filter_command->dump_status_messages(1);
ok($filter_command->execute, 'executed snp-filter filter');
my $filter_result = $filter_command->_result;
isa_ok($filter_result, 'Genome::Model::Tools::DetectVariants2::Result::Filter', 'generated filter result');
is($filter_result->_instance->previous_result, $result, 'filter result is based on samtools result');

$filter_params{output_directory} = $test_working_dir . '/test/filter2';

my $filter_command2 = Genome::Model::Tools::DetectVariants2::Filter::SnpFilter->create(%filter_params);
isa_ok($filter_command2, 'Genome::Model::Tools::DetectVariants2::Filter::SnpFilter', 'created second snp-filter filter');
$filter_command2->dump_status_messages(1);
ok($filter_command2->execute, 'executed second snp-filter filter');
my $filter_result2 = $filter_command2->_result;
is($filter_result2, $filter_result, 'got back same result');

my $filter_command2a = Genome::Model::Tools::DetectVariants2::Filter::SnpFilter->create(%filter_params);
isa_ok($filter_command2a, 'Genome::Model::Tools::DetectVariants2::Filter::SnpFilter', 'created snp-filter filter to test shortcutting to same directory');
$filter_command2a->dump_status_messages(1);
ok($filter_command2a->execute, 'executed snp-filter filter to test shortcutting to same directory');
my $filter_result2a = $filter_command2->_result;
is($filter_result2a, $filter_result, 'got back same result');


$filter_params{output_directory} = $test_working_dir . '/test/filter1/filter1a';
$filter_params{previous_result_id} = $filter_result->id;

my $filter_command3 = Genome::Model::Tools::DetectVariants2::Filter::SnpFilter->create(%filter_params);
isa_ok($filter_command3, 'Genome::Model::Tools::DetectVariants2::Filter::SnpFilter', 'created subsidiary snp-filter filter');
$filter_command3->dump_status_messages(1);
ok($filter_command3->execute, 'executed subsidiary snp-filter filter');
my $filter_result3 = $filter_command3->_result;
isnt($filter_result3, $filter_result, 'got back new result that differs only in previous filters');
is($filter_result3->previous_filter_strategy, 'Genome::Model::Tools::DetectVariants2::Filter::SnpFilter v1', 'previous_filter_strategy has expected value');

$filter_params{output_directory} = $test_working_dir . '/test/filter1/filter1a/filter1b';
$filter_params{previous_result_id} = $filter_result3->id;

my $filter_command4 = Genome::Model::Tools::DetectVariants2::Filter::SnpFilter->create(%filter_params);
isa_ok($filter_command4, 'Genome::Model::Tools::DetectVariants2::Filter::SnpFilter', 'created subsidiary snp-filter filter');
$filter_command4->dump_status_messages(1);
ok($filter_command4->execute, 'executed subsidiary snp-filter filter');
my $filter_result4 = $filter_command4->_result;
isnt($filter_result4, $filter_result3, 'got back another new result that differs only in previous filters');
isnt($filter_result4, $filter_result, 'got back another new result that differs only in previous filters');
is($filter_result4->previous_filter_strategy, 'Genome::Model::Tools::DetectVariants2::Filter::SnpFilter v1 then Genome::Model::Tools::DetectVariants2::Filter::SnpFilter v1', 'previous_filter_strategy has expected value');


my $delete_ok3 = eval { $filter_result3->delete };
ok(!$delete_ok3, 'prevented from deleting a filter result that is used by another result');

#Remove the results from this filter_result so it can be removed
my @users = $filter_result4->users;
map { $_->delete } @users;
my $delete_ok4 = eval { $filter_result4->delete };
my $error = $@;
ok($delete_ok4, 'can delete a filter result not otherwise used') or diag('error: ' . $error);

my %result_params = (
        detector_name => $filter_result->detector_name,
        detector_params => $filter_result->detector_params,
        detector_version => $filter_result->detector_version,
        filter_name => $filter_result->filter_name,
        filter_params => $filter_result->filter_params,
        filter_version => $filter_result->filter_version,
        previous_filter_strategy => undef,
        aligned_reads => $filter_result->aligned_reads,
        control_aligned_reads => $filter_result->control_aligned_reads,
        reference_build_id => $filter_result->reference_build_id,
        region_of_interest_id => $filter_result->region_of_interest_id,
        test_name => $filter_result->test_name,
        chromosome_list => $filter_result->chromosome_list,
        users => $result_users,
);

my $filter_result_get = Genome::Model::Tools::DetectVariants2::Result::Filter->get_with_lock(%result_params);
is($filter_result_get, $filter_result, 'got back filter result through regular get');
