#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above "Genome";

require Genome::Utility::Test;
require File::Compare;
use Test::More;

use_ok('Genome::InstrumentData::Command::Import::Basic') or die;

my $sample = Genome::Sample->create(name => '__TEST_SAMPLE__');
ok($sample, 'Create sample');

my $test_dir = Genome::Utility::Test->data_dir_ok('Genome::InstrumentData::Command::Import');
my $source_bam = $test_dir.'/input.bam';
ok(-s $source_bam, 'source bam exists') or die;

my $cmd = Genome::InstrumentData::Command::Import::Basic->create(
    sample => $sample,
    source_files => [$source_bam],
    import_source_name => 'broad',
    instrument_data_properties => [qw/ lane=2 flow_cell_id=XXXXXX /],
);
ok($cmd, "create import command");
ok($cmd->execute, "excute import command");

my $instrument_data = Genome::InstrumentData::Imported->get(original_data_path => $source_bam);
ok($instrument_data, 'got instrument data');
is($instrument_data->original_data_path, $source_bam, 'original_data_path correctly set');
is($instrument_data->import_format, 'bam', 'import_format is bam');
is($instrument_data->sequencing_platform, 'solexa', 'sequencing_platform correctly set');
is($instrument_data->is_paired_end, 1, 'is_paired_end correctly set');
is($instrument_data->read_count, 256, 'read_count correctly set');
is(eval{$instrument_data->attributes(attribute_label => 'segment_id')->attribute_value;}, 2883581797, 'segment_id correctly set');
is(eval{$instrument_data->attributes(attribute_label => 'original_data_path_md5')->attribute_value;}, '940825168285c254b58c47399a3e1173', 'original_data_path_md5 correctly set');

my $bam_path = $instrument_data->bam_path;
ok(-s $bam_path, 'bam path exists');
is($bam_path, $instrument_data->data_directory.'/all_sequences.bam', 'bam path correctly named');
is(eval{$instrument_data->attributes(attribute_label => 'bam_path')->attribute_value}, $bam_path, 'set attributes bam path');
is(File::Compare::compare($bam_path.'.flagstat', $test_dir.'/input.bam.flagstat'), 0, 'flagstat matches');

my $allocation = $instrument_data->allocations;
ok($allocation, 'got allocation');
ok($allocation->kilobytes_requested > 0, 'allocation kb was set');

#print $instrument_data->data_directory."\n";<STDIN>;
done_testing();
