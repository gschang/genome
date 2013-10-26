#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Sys::Hostname;

my $file_count = 0;

use_ok('Genome::Model::Tools::MergeFiles') or die;

my $test_data_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-GenePrediction-Eukaryotic/';
ok(-d $test_data_dir, "test data dir exists at $test_data_dir") or die;

my $fasta_1 = $test_data_dir . 'short_ctg.dna';
ok(-e $fasta_1, "test fasta 1 exists at $fasta_1") or die;

my $fasta_2 = $test_data_dir . 'shorter_ctg.dna';
ok(-e $fasta_2, "test fasta 2 exists at $fasta_2") or die;

my $fasta_1_size = get_line_count_for_file($fasta_1);
my $fasta_2_size = get_line_count_for_file($fasta_2);
my $total_size = $fasta_1_size + $fasta_2_size;

my $test_output_dir = File::Temp::tempdir(
    TEMPLATE => 'Model-Tools-MergeFiles-XXXXX',
    TMPDIR => 1,
    CLEANUP => 1,
);
ok(-d $test_output_dir, "test output dir exists at $test_output_dir") or die;

######

my $output_1 = make_temp_file_in_dir($test_output_dir);
ok($output_1, "generated temp output file name $output_1");

my $merge_1 = Genome::Model::Tools::MergeFiles->create(
    input_files => [$fasta_1, $fasta_2],
    output_file => $output_1,
    remove_input_files => 0,
);
ok($merge_1, 'successfully created merge command object');

my $merge_1_rv = $merge_1->execute;
ok($merge_1_rv, 'merge successfully executed');

my $output_1_size = get_line_count_for_file($output_1);
ok($output_1_size == $total_size, "merged file has $output_1_size lines, which matches sum of input files ($total_size)");

######

my $output_2 = make_temp_file_in_dir($test_output_dir);
ok($output_2, "generated temp output file name $output_2");

my $merge_2 = Genome::Model::Tools::MergeFiles->create(
    input_files => [$fasta_1, $fasta_1],
    output_file => $output_2,
    remove_input_files => 0,
);
ok($merge_2, 'successfully created merge command object (again!)');

my $merge_2_rv = $merge_2->execute;
ok($merge_2_rv, 'merge successfully executed with duplicate input files');

my $output_2_size = get_line_count_for_file($output_2);
ok($output_2_size == $fasta_1_size, "merged file has $output_2_size lines, which matches size of just one input file ($fasta_1_size)");

done_testing();

sub get_line_count_for_file {
    my $file = shift;
    return 0 unless -e $file;
    my $count = `wc -l $file | awk '{print \$1}'`;
    chomp $count;
    return 0 unless defined $count;
    return $count;
}

# I'd use File::Temp, but that makes a 0-sized file, which makes Genome::Sys->cat (what merging uses to
# stick files together) to skip running (since the output file is present).
sub make_temp_file_in_dir {
    my $dir = shift;
    my $name = join('-', 'repeat_masker_merge_output', time, hostname, $$, $file_count++);
    return join('/', $dir, $name);
}
