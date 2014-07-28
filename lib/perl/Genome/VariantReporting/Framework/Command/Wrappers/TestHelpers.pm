package Genome::VariantReporting::Framework::Command::Wrappers::TestHelpers;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;
use Genome;
use Genome::Test::Factory::Model::SomaticValidation;
use Genome::Test::Factory::ProcessingProfile::SomaticValidation;
use Genome::Test::Factory::Build;
use Genome::Test::Factory::Model::ReferenceSequence;
use Genome::Test::Factory::Model::ImportedVariationList;
use Genome::Test::Factory::Sample;
use Genome::Utility::Test;
use Sub::Install qw(reinstall_sub);
use Exporter 'import';

our @EXPORT_OK = qw(get_build succeed_build);
my $TEST_DIR = __FILE__.".d";
my $PROVIDER_TEST_DIR = Genome::Utility::Test->data_dir_ok("Genome::VariantReporting::Framework::Component::ResourceProvider", "v3");

sub _get_pp {
    return Genome::Test::Factory::ProcessingProfile::SomaticValidation->setup_object();
}
Memoize::memoize("_get_pp");

my $fl_counter = -1;
sub _get_or_create_feature_list {
    my $name = shift;
    my $feature_list = Genome::FeatureList->get(name => $name);
    unless ($feature_list) {
        $feature_list = Genome::FeatureList->__define__(name => $name, id => $fl_counter, format => "true-BED",
            file_content_hash => "5081d1f22d4514f3ac09b003385a6e7e");
        $fl_counter--;
        reinstall_sub({
            into => "Genome::FeatureList",
            as => "file_path",
            code => sub {return File::Spec->join($TEST_DIR, "test.bed")},
        });
    }
    return $feature_list;
}

sub get_build {
    my ($roi_name, $tumor_sample, $normal_sample) = @_;
    my $roi = _get_or_create_feature_list($roi_name);
    my $pp = _get_pp;
    my $discovery_model = Genome::Test::Factory::Model::SomaticValidation->setup_object(processing_profile_id => $pp->id);
    $discovery_model->tumor_sample($tumor_sample);
    $discovery_model->normal_sample($normal_sample);
    $discovery_model->add_region_of_interest_set(id => $roi->id);

    my $discovery_build = Genome::Test::Factory::Build->setup_object(model_id => $discovery_model->id);
    my $dbsnp_model = Genome::Test::Factory::Model::ImportedVariationList->setup_object();
    my $dbsnp_build = Genome::Test::Factory::Build->setup_object(model_id => $dbsnp_model->id);
    $discovery_build->previously_discovered_variations_build($dbsnp_build);
    reinstall_sub( {
            into => "Genome::Model::Build::ImportedVariationList",
            as => "snvs_vcf",
            code => sub {
                return File::Spec->join($TEST_DIR, "dbsnp.vcf");
            },
        }
    );

    my $vcf_result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Combine->__define__;
    my $vcf = File::Spec->join($PROVIDER_TEST_DIR, "snvs.vcf.gz");
    reinstall_sub({
            into => "Genome::Model::Build::SomaticValidation",
            as => "get_detailed_vcf_result",
            code => sub {
                return $vcf_result;
            },
        });

    reinstall_sub({
            into => "Genome::Model::Tools::DetectVariants2::Result::Vcf",
            as => "get_vcf",
            code => sub {
                return $vcf;
            },
        });

    my $alignment_result =  _get_alignment_result();
    reinstall_sub( {
            into => "Genome::Model::Build::SomaticValidation",
            as => "merged_alignment_result",
            code => sub {
                return $alignment_result;
            },
        });

    my $control_alignment_result = _get_control_alignment_result();

    reinstall_sub( {
            into => "Genome::Model::Build::SomaticValidation",
            as => "control_merged_alignment_result",
            code => sub {
                return $control_alignment_result;
            },
        });

    my $reference_sequence_model = Genome::Test::Factory::Model::ReferenceSequence->setup_object();
    my $reference_sequence_build = Genome::Test::Factory::Build->setup_object(model_id => $reference_sequence_model->id);
    reinstall_sub( {
            into => "Genome::Model::Build::SomaticValidation",
            as => "reference_sequence_build",
            code => sub {
                return $reference_sequence_build;
            },
        });
    reinstall_sub( {
            into => "Genome::Model::Build::ReferenceSequence",
            as => "get_feature_list",
            code => sub {
                return $roi;
            },
        });
    reinstall_sub({
        into => "Genome::Model::Build::ReferenceSequence",
        as => "full_consensus_path",
        code => sub {
            return File::Spec->join($PROVIDER_TEST_DIR, "reference.fasta");
        },
    });
    reinstall_sub({
        into => "Genome::InstrumentData::AlignmentResult::Merged",
        as => "reference_build",
        code => sub {
            return $reference_sequence_build;
        },
    });
    return $discovery_build;
}

sub succeed_build {
    my $build = shift;
    $build->status("Succeeded");
    $build->date_completed("2013-07-11 20:47:51");
}

sub _get_alignment_result {
    my $result = Genome::InstrumentData::AlignmentResult::Merged->__define__(id => "-b52e1b52f81e4541af7f71ce14ca96f6", output_dir => $TEST_DIR);
        my %bam_paths = (
            "-b52e1b52f81e4541af7f71ce14ca96f6" => "bam1.bam",
            "-533e0bb1a99f4fbe9e31cf6e19907133" => "bam2.bam",
        );
        my %sample_names = (
            "-b52e1b52f81e4541af7f71ce14ca96f6" => "TEST-patient1-somval_tumor1",
            "-533e0bb1a99f4fbe9e31cf6e19907133" => "TEST-patient1-somval_normal1",
        );
        reinstall_sub({
            into => "Genome::InstrumentData::AlignmentResult::Merged",
            as => "bam_file",
            code => sub {my $self = shift; return File::Spec->join($PROVIDER_TEST_DIR, $bam_paths{$self->id})},
        });
        reinstall_sub({
            into => "Genome::InstrumentData::AlignedBamResult",
            as => "sample_name",
            code => sub {my $self = shift; return $sample_names{$self->id}},
        });
    return $result;
}
Memoize::memoize("_get_alignment_result");

sub _get_control_alignment_result {
    Genome::InstrumentData::AlignmentResult::Merged->__define__(id => "-533e0bb1a99f4fbe9e31cf6e19907133", output_dir => $TEST_DIR);
}
Memoize::memoize("_get_control_alignment_result");
1;

