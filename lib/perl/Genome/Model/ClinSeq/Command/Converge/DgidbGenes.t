#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::More;

my $expected_out = Genome::Config::get('test_inputs') . '/Genome-Model-ClinSeq-Command-Converge-DgidbGenes/2015-02-05/';
ok(-d $expected_out, "directory of expected output exists: $expected_out") or die;

my $clinseq_build_id = '478c89dd197e44d392865ca0fbc6f122';
my $clinseq_build = Genome::Model::Build->get($clinseq_build_id);
ok($clinseq_build, "Got clinseq build from id: $clinseq_build_id") or die;
my $cancer_annotation_db = $clinseq_build->cancer_annotation_db;
my @builds = ($clinseq_build);

#Create a temp dir for results
my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir");

my $cmd = Genome::Model::ClinSeq::Command::Converge::DgidbGenes->create(
    builds => \@builds, 
    outdir => $temp_dir,
    bam_readcount_version => 0.6,
    cancer_annotation_db => $cancer_annotation_db,
);

$cmd->queue_status_messages(1);
my $return = $cmd->execute();
is($return, 1, 'Testing for successful execution.  Expecting 1.  Got: '. $return);

#Perform a diff between the stored results and those generated by this test
my @diff = `diff -r $expected_out $temp_dir`;
ok(@diff == 0, "Found only expected number of differences between expected results and test results")
or do {
  diag("expected: $expected_out\nactual: $temp_dir\n");
  diag("differences are:");
  diag(@diff);
  my $diff_line_count = scalar(@diff);
  print "\n\nFound $diff_line_count differing lines\n\n";
  Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-clinseq-converge-dgidbgenes/");
  Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-clinseq-converge-dgidbgenes");
};

done_testing()
