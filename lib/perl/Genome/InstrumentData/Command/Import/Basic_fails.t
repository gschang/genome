#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above "Genome";

use Test::More;

use_ok('Genome::InstrumentData::Command::Import::Basic') or die;

my $analysis_project = Genome::Config::AnalysisProject->create(name => '__TEST_AP__');
ok($analysis_project, 'create analysis project');
my $library = Genome::Library->create(
    name => '__TEST_SAMPLE__-extlibs', sample => Genome::Sample->create(name => '__TEST_SAMPLE__')
);
ok($library, 'Create library');

my @source_files = (
    $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData-Command-Import-Basic/fastq-1.txt.gz', 
    $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData-Command-Import-Basic/fastq-2.fastq',
);

my $fail = Genome::InstrumentData::Command::Import::Basic->create(
    analysis_project => $analysis_project,
    library => $library,
    source_files => [ 'blah.fastq' ],
    import_source_name => 'broad',
    instrument_data_properties => [qw/ sequencing_platform=solexa lane=2 flow_cell_id=XXXXXX /],
);
ok(!$fail->execute, 'Fails w/ invalid files');
#FIXME can this error be retrieved?
#my $error = $fail->error_message;
#is($error, 'Source file does not exist! blah.fastq', 'Correct error meassage');

$fail = Genome::InstrumentData::Command::Import::Basic->create(
    analysis_project => $analysis_project,
    library => $library,
    source_files => [ 'blah' ],
    import_source_name => 'broad',
    instrument_data_properties => [qw/ sequencing_platform=solexa lane=2 flow_cell_id=XXXXXX /],
);
ok(!$fail->execute, 'Fails w/ no suffix');
#FIXME can this error be retrieved?
#$error = $fail->error_message;
#is($error, 'Failed to get suffix from source file! blah', 'Correct error meassage');

$fail = Genome::InstrumentData::Command::Import::Basic->create(
    analysis_project => $analysis_project,
    library => $library,
    source_files => \@source_files,
    import_source_name => 'broad',
    instrument_data_properties => [qw/ sequencing_platform=solexa lane= flow_cell_id=XXXXXX /],
);
ok(!$fail->execute, 'Fails w/ invalid instrument_data_properties');
is($fail->error_message, 'Failed to process instrument data properties!', 'Correct error meassage');

$fail = Genome::InstrumentData::Command::Import::Basic->create(
    analysis_project => $analysis_project,
    library => $library,
    source_files => \@source_files,
    import_source_name => 'broad',
    instrument_data_properties => [qw/ sequencing_platform=solexa lane=2 lane=3 flow_cell_id=XXXXXX /],
);
ok(!$fail->execute, 'Fails w/ invalid instrument_data_properties');
is($fail->error_message, 'Failed to process instrument data properties!', 'Correct error meassage');

$fail = Genome::InstrumentData::Command::Import::Basic->create(
    analysis_project => $analysis_project,
    library => $library,
    source_files => \@source_files,
    import_source_name => 'broad',
    downsample_ratio => 0.25,
    instrument_data_properties => [qw/ downsample_ratio=0.24 /],
);
ok(!$fail->execute, 'Fails w/ conflicting cmd and instdata properties instrument_data_properties');
is($fail->error_message, "Failed to process instrument data properties!", 'Correct error message');

my $inst_data = Genome::InstrumentData::Imported->create(
    library => $library,
    original_data_path => join(',', @source_files),
);
$inst_data->add_attribute(attribute_label => 'segment_id', attribute_value => '__TEST_SAMPLE__-extlibs');
$fail = Genome::InstrumentData::Command::Import::Basic->create(
    analysis_project => $analysis_project,
    library => $library,
    source_files => \@source_files,
    import_source_name => 'broad',
    instrument_data_properties => [qw/ sequencing_platform=solexa lane=2 flow_cell_id=XXXXXX /],
);
ok(!eval{$fail->execute}, "Failed to reimport");
#FIXME can this error be retrieved?
#$error = $fail->error_message;
#like($error, qr/^Found existing instrument data for library and source files. Were these previously imported\? Exiting instrument data id:/, 'Correct error meassage');

done_testing();

