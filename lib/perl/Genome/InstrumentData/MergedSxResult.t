#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Genome::Test::Factory::SoftwareResult::User;
use Test::More;

use_ok('Genome::InstrumentData::MergedSxResult');
use_ok('Genome::InstrumentData::InstrumentDataTestObjGenerator');

my $data_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData-SxResult';

my ($instrument_data) = Genome::InstrumentData::InstrumentDataTestObjGenerator::create_solexa_instrument_data($data_dir."/inst_data/-6666/archive.bam");
my ($instrument_data2) = Genome::InstrumentData::InstrumentDataTestObjGenerator::create_solexa_instrument_data($data_dir."/inst_data/-6666/archive.bam");
my $read_processor = '';
my $output_file_count = 2;
my $output_file_type = 'sanger';

my %sx_result_params = (
    instrument_data_id => $instrument_data->id,
    read_processor => $read_processor,
    output_file_count => $output_file_count,
    output_file_type => $output_file_type,
    test_name => ($ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef),
    users => Genome::Test::Factory::SoftwareResult::User->setup_user_hash,
);

my $sx_result = Genome::InstrumentData::SxResult->get_or_create(%sx_result_params);
isa_ok($sx_result, 'Genome::InstrumentData::SxResult', 'created 1st result');

$sx_result_params{instrument_data_id} = $instrument_data2->id;
my $sx_result2 = Genome::InstrumentData::SxResult->get_or_create(%sx_result_params);
isa_ok($sx_result2, 'Genome::InstrumentData::SxResult', 'created 2nd result');

ok(Genome::InstrumentData::MergedSxResult->create(
    instrument_data_id => [$instrument_data->id, $instrument_data2->id],
    read_processor => $read_processor,
    output_file_count => $output_file_count,
    output_file_type => $output_file_type,
    test_name => ($ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef),
    coverage => undef,
    _user_data_for_nested_results => Genome::Test::Factory::SoftwareResult::User->setup_user_hash,
    ),
   'Created sx result with multiple instrument data'
);

$instrument_data->taxon->estimated_genome_size(50);

ok(Genome::InstrumentData::MergedSxResult->create(
    instrument_data_id => [$instrument_data->id, $instrument_data2->id],
    read_processor => $read_processor,
    output_file_count => $output_file_count,
    output_file_type => $output_file_type,
    test_name => ($ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef),
    coverage => 10,
    _user_data_for_nested_results => Genome::Test::Factory::SoftwareResult::User->setup_user_hash,
    ),
   'Created merged sx result with coverage'
);

done_testing;
