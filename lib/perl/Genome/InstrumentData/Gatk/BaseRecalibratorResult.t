#! /gsc/bin/perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above 'Genome';

require Genome::Utility::Test;
use Test::More;

my $class = 'Genome::InstrumentData::Gatk::BaseRecalibratorResult';
use_ok($class) or die;
my $result_data_dir = Genome::Utility::Test->data_dir_ok($class, 'v1');

# Inputs
use_ok('Genome::InstrumentData::Gatk::Test') or die;
my $gatk_test = Genome::InstrumentData::Gatk::Test->get;
my $bam_source = $gatk_test->bam_source;
my $reference_build = $gatk_test->reference_build;
my %params = (
    version => 2.4,
    bam_source => $bam_source,
    reference_build => $reference_build,
    known_sites => [ $gatk_test->known_site ],
);

# Get [fails as expected]
my $base_recalibrator = Genome::InstrumentData::Gatk::BaseRecalibratorResult->get_with_lock(%params);
ok(!$base_recalibrator, 'Failed to get existing gatk indel realigner result');

# Create
$base_recalibrator = Genome::InstrumentData::Gatk::BaseRecalibratorResult->get_or_create(%params);
ok($base_recalibrator, 'created gatk indel realigner');

# Outputs
is($base_recalibrator->recalibration_table_file, $base_recalibrator->output_dir.'/'.$bam_source->id.'.bam.grp', 'recalibration table file named correctly');
ok(-s $base_recalibrator->recalibration_table_file, 'recalibration table file exists');
Genome::Utility::Test::compare_ok($base_recalibrator->recalibration_table_file, $result_data_dir.'/expected.bam.grp', 'recalibration table file matches');

# Users
my @bam_source_users = $bam_source->users;
ok(@bam_source_users, 'add users to bam source');
is_deeply([map { $_->label } @bam_source_users], ['bam source'], 'bam source users haver correct label');
my @users = sort { $a->id <=> $b->id } map { $_->user } @bam_source_users;
is_deeply(\@users, [$base_recalibrator], 'bam source is used by base recal result');

# Allocation params
is(
    $base_recalibrator->resolve_allocation_disk_group_name,
    'info_genome_models',
    'resolve_allocation_disk_group_name',
);
is(
    $base_recalibrator->resolve_allocation_kilobytes_requested,
    4,
    'resolve_allocation_kilobytes_requested',
);
like(
    $base_recalibrator->resolve_allocation_subdirectory,
    qr(^model_data/gatk/base_recalibrator-),
    'resolve_allocation_subdirectory',
);

#print $base_recalibrator->_tmpdir."\n";
#print $base_recalibrator->output_dir."\n"; <STDIN>;
done_testing();
