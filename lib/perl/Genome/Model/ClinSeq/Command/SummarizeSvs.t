#!/usr/bin/env genome-perl

#Written by Malachi Griffith

use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

use above "Genome";
use Test::More tests=>7;
use Genome::Model::ClinSeq::Command::SummarizeSvs;
use Data::Dumper;

use_ok('Genome::Model::ClinSeq::Command::SummarizeSvs') or die;

#Define the test where expected results are stored
my $expected_output_dir = $ENV{"GENOME_TEST_INPUTS"} . "/Genome-Model-ClinSeq-Command-SummarizeSvs/2012-11-23/";
ok(-e $expected_output_dir, "Found test dir: $expected_output_dir") or die;

#Create a temp dir for results
my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir");

#Get a clin-seq build
my $somvar_build_id1 = 119390903;
my $somvar_build1 = Genome::Model::Build->get($somvar_build_id1);

#Create summarize-svs command and execute
#genome model clin-seq summarize-svs --outdir=/tmp/summarize_svs/ 126680687

my $cancer_annotation_db = Genome::Db->get("tgi/cancer-annotation/human/build37-20130401.1");
my $summarize_svs_cmd = Genome::Model::ClinSeq::Command::SummarizeSvs->create(
    outdir=>$temp_dir, 
    builds=>[$somvar_build1], 
    cancer_annotation_db => $cancer_annotation_db,
);
$summarize_svs_cmd->queue_status_messages(1);
my $r1 = $summarize_svs_cmd->execute();
is($r1, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$r1);
is($summarize_svs_cmd->fusion_output_file, $temp_dir."/CandidateSvCodingFusions.tsv", "Output file was set correctly");
#Dump the output of summarize-svs to a log file
my @output1 = $summarize_svs_cmd->status_messages();
my $log_file = $temp_dir . "/SummarizeSvs.log.txt";
my $log = IO::File->new(">$log_file");
$log->print(join("\n", @output1));
ok(-e $log_file, "Wrote message file from summarize-svs to a log file: $log_file");

#The first time we run this we will need to save our initial result to diff against
#Genome::Sys->shellcmd(cmd => "cp -r -L $temp_dir/* $expected_output_dir");

#Perform a diff between the stored results and those generated by this test
my @diff = `diff -r -x '*.png' $expected_output_dir $temp_dir`;
ok(@diff == 0, "Found only expected number of differences between expected results and test results")
or do { 
  diag("expected: $expected_output_dir\nactual: $temp_dir\n");
  diag("differences are:");
  diag(@diff);
  my $diff_line_count = scalar(@diff);
  print "\n\nFound $diff_line_count differing lines\n\n";
  Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-summarize-svs-result/");
  Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-summarize-svs-result");
};
