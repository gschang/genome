#!/usr/bin/env genome-perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 7;
use File::Compare;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

    use_ok('Genome::Model::Tools::Somatic::FilterLoh');    
};

my $test_input_dir      = Genome::Config::get('test_inputs') . '/Genome-Model-Tools-Somatic-FilterLoh/54367/';
my $tumor_snp_file      = $test_input_dir . 'tumor.snp'; #In SVN rev.54367, changed input format
my $normal_snp_file     = $test_input_dir . 'normal.snp';

my $test_output_dir     = File::Temp::tempdir('Genome-Model-Tools-Somatic-FilterLoh-XXXXX', CLEANUP => 1, TMPDIR => 1);
$test_output_dir .= '/';
my $output_file         = $test_output_dir . 'filtered.snp.out';
my $loh_output_file     = $test_output_dir . 'loh.snp.out';

my $expected_dir        = $test_input_dir;
my $expected_out_file   = $expected_dir . 'output.expected';
my $expected_loh_file   = $expected_dir . 'loh_output.expected';

my $filter_loh = Genome::Model::Tools::Somatic::FilterLoh->create(
    tumor_snp_file  => $tumor_snp_file,
    normal_snp_file => $normal_snp_file,
    output_file     => $output_file,
    loh_output_file => $loh_output_file,
);

ok($filter_loh, 'created FilterLOH object');
ok($filter_loh->execute(), 'executed FilterLOH object');

ok(-s $output_file, 'generated output file');
ok(-s $loh_output_file, 'generated LOH output file');

is(compare($expected_out_file, $output_file), 0, 'Output matched expected results');

is(compare($expected_loh_file, $loh_output_file), 0, 'LOH output matched expected results');
