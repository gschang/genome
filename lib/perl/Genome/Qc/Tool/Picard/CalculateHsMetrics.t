#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

my $pkg = 'Genome::Qc::Tool::Picard::CalculateHsMetrics';
use_ok($pkg);

my $data_dir = __FILE__.".d";

my $output_file = File::Spec->join($data_dir, 'output_file.txt');

my $tool = $pkg->create(
    gmt_params => {
        bait_intervals => __FILE__,
        input_file => __FILE__,
        output_file => $output_file,
        target_intervals => __FILE__,
        temp_directory => __FILE__,
        use_version => 1.123,
    }
);
ok($tool->isa($pkg), 'Tool created successfully');

my @expected_cmd_line =(
    'java',
    '-Xmx4096m',
    '-XX:MaxPermSize=64m',
    '-cp',
    '/usr/share/java/ant.jar:/gscmnt/sata132/techd/solexa/jwalker/lib/picard-tools-1.123/CalculateHsMetrics.jar',
    'net.sf.picard.analysis.directed.CalculateHsMetrics',
    sprintf('BAIT_INTERVALS=%s', __FILE__),
    sprintf('INPUT=%s', __FILE__),
    'MAX_RECORDS_IN_RAM=500000',
    sprintf('OUTPUT=%s', $output_file),
    sprintf('TARGET_INTERVALS=%s', __FILE__),
    sprintf('TMP_DIR=%s', __FILE__),
    'VALIDATION_STRINGENCY=SILENT',
);
is_deeply([$tool->cmd_line], [@expected_cmd_line], 'Command line list as expected');

my %expected_metrics = (
    'pct_bases_greater_than_2x_coverage' => 0,
    'pct_bases_greater_than_10x_coverage' => 0,
    'pct_bases_greater_than_20x_coverage' => 0,
    'pct_bases_greater_than_30x_coverage' => 0,
    'pct_bases_greater_than_40x_coverage' => 0,
    'pct_bases_greater_than_50x_coverage' => 0,
    'pct_bases_greater_than_100x_coverage' => 0,
);
is_deeply({$tool->get_metrics}, {%expected_metrics}, 'Parsed metrics as expected');

done_testing;
