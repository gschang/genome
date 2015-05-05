#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require File::Compare;
require File::Temp;
use Test::More;

use_ok('Genome::Model::Tools::Sx') or die;

my $dir = Genome::Config::get('test_inputs') . '/Genome-Model-Tools-Sx';
my $example_in_file = $dir.'/fast_qual.example.fastq';
ok(-s $example_in_file, 'example in fastq file exists');
my $example_out_file = $dir.'/fast_qual.example.fasta';
ok(-s $example_out_file, 'example out fasta file exists');

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
my $out_file = $tmpdir.'/out.fasta';
my $input_metrics_file = $tmpdir.'/metrics.in.txt';
my $output_metrics_file = $tmpdir.'/metrics.out.txt';

class Sx::Test { is => 'Genome::Model::Tools::Sx::Base', };
my $fq = Sx::Test->create(
    input => [ $example_in_file ],
    input_metrics => $input_metrics_file,
    output => [ $out_file ],
    output_metrics => $output_metrics_file,
);
ok($fq, 'create w/ fastq files');
ok($fq->execute, 'execute');
is(File::Compare::compare($out_file, $example_out_file), 0, 'output file ok');
ok(-s $input_metrics_file, 'input metrics file created');
my $input_metrics = Genome::Model::Tools::Sx::Metrics->from_file($input_metrics_file);
ok($input_metrics, 'got input metrics from file');
is_deeply({ bases => $input_metrics->bases, count => $input_metrics->count }, { bases => 75, count => 1, }, 'input metrcis match');
ok(-s $output_metrics_file, 'output metrics file created');
my $output_metrics = Genome::Model::Tools::Sx::Metrics->from_file($output_metrics_file);
ok($output_metrics, 'got output metrics from file');
is_deeply({ bases => $output_metrics->bases, count => $output_metrics->count }, { bases => 75, count => 1, }, 'output metrcis match');

#print "$tmpdir\n"; <STDIN>;
done_testing();
