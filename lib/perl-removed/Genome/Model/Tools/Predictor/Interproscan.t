#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Utility::Test qw(compare_ok);

use_ok('Genome::Model::Tools::Predictor::Interproscan') or die;

my $temp_output_dir = Genome::Sys->create_temp_directory();
ok(-d $temp_output_dir, "created temp output dir at $temp_output_dir");

my $test_data_path = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-Predictor';
my $test_fasta = join('/', $test_data_path, 'medium.fasta');
ok(-e $test_fasta, "test fasta file exists")
    or diag "test_fasta: $test_fasta";


my $version = '4.8';
my $interpro = Genome::Model::Tools::Predictor::Interproscan->create(
    output_directory => $temp_output_dir,
    input_fasta_file => $test_fasta,
    version => $version,
    parameters => '-cli -appl hmmpfam -appl hmmtigr -goterms -verbose -iprlookup -seqtype p -format raw',
    dump_predictions_to_file => 1,
);
ok($interpro, 'successfully created interpro command object');

my $ipr_tmp_path = $interpro->tool_path_for_version($version);
$ipr_tmp_path =~ s!/bin/iprscan!/tmp/!;

my ($used_kb) = qx(df -Pk $ipr_tmp_path | tail -n 1 | awk '{print \$4}') =~ /(\d+)/;
cmp_ok($used_kb, ">", (1024*1024), ">1GB free space in iprscan tmp directory")
    or die("disk containing iprscan tmp at $ipr_tmp_path is almost full! Try removing old runs to free space. Delete stuff that is 30 days old: `find $ipr_tmp_path -mtime +30 -delete`.");

# Had to use touch instead of -w since -w must only check permissions.
my $exit = system("touch $ipr_tmp_path");
ok($exit == 0, 'iprscan tmp directory is writable')
    or die 'iprscan tmp directory is not writable';

ok($interpro->execute, 'successfully executed interpro');
ok(-e $interpro->raw_output_path, "raw output file exists at expected location")
    or diag "expected location: " . $interpro->raw_output_path;
ok(-e $interpro->dump_output_path, "dump file exists at expected location")
    or diag "expected location: " . $interpro->dump_output_path;

# Compare output to expected output
my $expected_raw_output = join('/', $test_data_path, 'interpro.medium_fasta.raw.expected');
ok(-e $expected_raw_output, "expected raw output file for interpro exists")
    or diag "expected_raw_output: $expected_raw_output";

my $expected_dump_output = join('/', $test_data_path, 'interpro.medium_fasta.dump.expected');
ok (-e $expected_dump_output, "expected dump output file for interpro exists")
    or diag "expected_dump_output: $expected_dump_output";

compare_ok($interpro->dump_output_path, $expected_dump_output, "test dump output matches expected")
    or diag sprintf("test dump output: %s\nexpected dump output: %s\n", $interpro->dump_output_path, $expected_dump_output);

my $ace_file = $interpro->ace_file_path;
ok(-e $ace_file, "interpro produced an ace file")
    or diag "ace_file: $ace_file";

done_testing();
