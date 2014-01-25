package Genome::Model::Tools::Vcf::CreateCrossSampleVcf::CreateCrossSampleVcfBase;

use strict;
use warnings;

use Genome;
use Workflow;
use Workflow::Simple;
use Switch;
use List::MoreUtils "each_array";
use File::Basename qw/fileparse/;
use File::Spec;

class Genome::Model::Tools::Vcf::CreateCrossSampleVcf::CreateCrossSampleVcfBase {
    is => 'Command::V2',
    is_abstract => 1,
    has_input => [
        builds => {
            is => 'Genome::Model::Build',
            require_user_verify => 0,
            is_many => 1,
            is_optional => 1,
            doc => 'The builds that you wish to create a cross-sample vcf for',
        },
        model_group => {
            is => 'Genome::ModelGroup',
            require_user_verify => 0,
            is_optional => 1,
            doc => 'Model group from which last succeeded builds will be pulled',
        },
        variant_type => {
            is => 'Text',
            default => 'snvs',
            valid_values => ['snvs','indels'],
            doc => 'The type of variations present in the vcf files.',
        },
        max_files_per_merge => {
            is => 'Text',
            default => 200,
            doc => 'Set this to cause no more than N vcfs to be merged into a single operation at a time',
        },
        roi_list => {
            is => 'Genome::FeatureList',
            is_optional => 1,
            doc => 'Set this to limit the incoming vcfs to roi target regions',
        },
        wingspan => {
            is => 'Text',
            default => 0,
            doc => 'Set this to add a wingspan to region limiting',
        },
        allow_multiple_processing_profiles => {
            is => 'Boolean',
            is_optional => 1,
            doc => 'Setting this prevents the check for identical processing profiles on all inputs',
        },
        joinx_version => {
            is => 'Text',
            doc => 'Joinx version to use in all joinx operations',
            default => '1.7',
        },
        output_directory => {
            is => 'Text',
            is_optional => 0,
            doc => 'the directory where you want results stored',
        },
    ],
    has_optional => [
        software_result => {
            is => 'Genome::SoftwareResult',
            doc => 'The output generated by running this command can be accessed via this property.',
        },
        final_result => {
            is => 'Path',
            doc => 'The path to the final merged vcf file generated by this command.',
        },
        _submerged_position_beds => {
            doc => 'The names of the sub-merge outputs for bed positions',
        },
        _submerged_vcfs => {
            doc => 'The names of the sub-merge outputs for vcf merging',
        },
        _max_ops => {
            doc => 'Number of operations',
        },
    ],
    has_calculated_output => [
        output_vcf => {
            is_optional => 1,
            is => 'File',
            calculate => q| File::Spec->join($output_directory, "$variant_type.merged.vcf.gz") |,
            calculate_from => [qw(output_directory variant_type)],
        },
    ],
    doc => 'Base class used to create a combined vcf file for a model-group',
};

sub help_detail {
    return <<EOS
We first get the appropriate vcf file from the last_succeeded_build in
each model in the model-group.  From those we create a vcf that includes
every variation found (in any vcf).  For every location in this vcf we look
to the bam file for evidence (this is done for every build separately).
These 'back-filled' vcfs are then combined into a single multi-sample vcf.
EOS
}

sub generate_result {
    my ($self) = @_;

    $self->status_message("Resolving Builds...");
    my $builds = $self->_resolve_builds;

    $self->status_message("Validating Inputs...");
    $self->_validate_inputs($builds);

    $self->status_message("Constructing Workflow...");
    my ($workflow, $variant_type_specific_inputs, $region_limiting_specific_inputs) = $self->_construct_workflow;

    $self->status_message("Getting Workflow Inputs...");
    my $inputs = $self->_get_workflow_inputs($builds, $variant_type_specific_inputs, $region_limiting_specific_inputs);

    $self->status_message("Running Workflow...");
    my $result = Workflow::Simple::run_workflow_lsf($workflow, %$inputs);

    unless($result){
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        die $self->error_message("Workflow did not return correctly.");
    }

    return 1;
}

sub _resolve_builds {
    my $self = shift;

    my @builds;
    if ($self->builds and not $self->model_group) {
        @builds = $self->builds;
    } elsif ($self->model_group and not $self->builds) {
        my $command = Genome::ModelGroup::Command::GetLastCompletedBuilds->execute(model_group => $self->model_group);
        @builds = $command->builds;
        $self->builds(\@builds);
    }
    else {
        die $self->error_message("Given both builds and model-groups or neither.");
    }

    return \@builds;
}

sub _construct_workflow {
    my ($self) = @_;

    my $xml_file = $self->_get_workflow_xml;
    my $variant_type_specific_inputs = $self->_get_variant_type_specific_inputs;
    my $region_limiting_specific_inputs = $self->_get_region_limiting_inputs;

    my (undef, $base_dir) = fileparse(__FILE__);
    my $xml = File::Spec->join($base_dir, $xml_file);

    my $workflow = Workflow::Operation->create_from_xml($xml);
    $workflow->log_dir($self->output_directory);

    return $workflow, $variant_type_specific_inputs, $region_limiting_specific_inputs;
}

sub _get_workflow_xml {
#overwritten in subclass
}

sub _get_variant_type_specific_inputs {
#overwritten in subclass
}

sub _get_region_limiting_inputs {
    my $self = shift;
    my $inputs;
    if ($self->roi_list){
        $inputs = $self->_get_region_limiting_specific_inputs;
    }else{
        $inputs = $self->_get_non_region_limiting_specific_inputs;
    }
    return $inputs;
}

sub _get_region_limiting_specific_inputs {
    my $self = shift;
    my @builds = $self->builds;
    my $region_limiting_output_directory = $self->prepare_region_limiting_output_directory();
    my $reference_sequence_build = $builds[0]->reference_sequence_build;
    my %inputs = (
        variant_type => $self->variant_type,
        region_limiting_output_directory => $region_limiting_output_directory,
        roi_name => $self->roi_list->name,
        wingspan => $self->wingspan,
        region_bed_file => $self->get_roi_file($reference_sequence_build),
    );

    return \%inputs;
}

sub _get_non_region_limiting_specific_inputs {
    my $self = shift;
    my @vcf_files = $self->_get_vcf_files;
    my %inputs;
    return \%inputs
}

sub _get_vcf_files {
    my $self = shift;
    my @builds = $self->builds;
    my $accessor = $self->get_vcf_accessor;
    return map{$_->$accessor} @builds;
}

# Early detection for the common problem that the ROI reference_name is not set correctly
sub _check_roi_list {
    my $self = shift;

    my $bed_file = $self->roi_list->file_path;
    my @chr_lines = `grep chr $bed_file`;
    my $reference_name = $self->roi_list->reference_name;
    my $roi_name = $self->roi_list->name;

    #if (@chr_lines and not ($reference_name =~ m/nimblegen/) ) {
    if (@chr_lines and not ($reference_name =~ m/nimblegen/) ) {
        die $self->error_message("It looks like your ROI has 'chr' chromosomes but does not have a 'nimblegen' reference name (It is currently $reference_name).\n".
            "This will result in your variant sets being filtered down to nothing. An example of a fix to this situation: \n".
            "genome feature-list update '$roi_name' --reference nimblegen-human-buildhg19 (if your reference is hg19)");
    }

    return 1;
}

sub _validate_inputs {
    my ($self, $builds) = @_;

    Genome::Sys->create_directory($self->output_directory);
    unless(-d $self->output_directory) {
        die $self->error_message("Unable to find output directory: " . $self->output_directory);
    }

    if ($self->roi_list) {
        $self->_check_roi_list;
    }

    $self->_validate_builds($builds);

    return 1;
}

sub _validate_builds {
    my $self = shift;
    my $builds = shift;

    my $first_build = $builds->[0];
    my $reference_sequence = $first_build->reference_sequence_build;
    my $pp = $first_build->processing_profile;
    my %validation_params = (
        builds => $builds,
        builds_can => [qw(reference_sequence_build whole_rmdup_bam_file get_snvs_vcf get_indels_vcf)],
        status => ['Succeeded'],
        reference_sequence => [$reference_sequence],
    );
    if (!$self->allow_multiple_processing_profiles) {
        $validation_params{'processing_profile'} = [$pp];
    }
    Genome::Model::Build::Command::Validate->execute(%validation_params);

    $self->_check_build_files($builds);
}

sub _check_build_files {
    my ($self, $builds) = @_;

    my (@builds_with_file, @builds_without_file, @vcf_files);
    my $accessor = $self->get_vcf_accessor;
    for my $build (@$builds) {
        my $vcf_file = $build->$accessor;
        if (-s $vcf_file) {
            push @builds_with_file, $build->id;
            push @vcf_files, $vcf_file;
        } else {
            push @builds_without_file, $build->id;
        }
    }

    my $num_builds = scalar(@$builds);
    unless( scalar(@builds_with_file) == $num_builds){
        die $self->error_message("The number of input builds ($num_builds) did not match the" .
            " number of vcf files found (" . scalar (@builds_with_file) . ").\n" .
            "Check the input builds for completeness.\n" .
            "Builds with a file present: " . join(",", @builds_with_file) . "\n" .
            "Builds with missing or zero size file: " . join(",", @builds_without_file) . "\n"
        );
    }
}

sub get_vcf_accessor {
    my $self = shift;
    return sprintf("get_%s_vcf", $self->variant_type);
}

sub _get_workflow_inputs {
    my ($self, $builds, $variant_type_specific_inputs, $region_limiting_specific_inputs) = @_;

    my $reference_sequence_build = $builds->[0]->reference_sequence_build;
    my $ref_fasta = $reference_sequence_build->full_consensus_path('fa');
    $self->prepare_vcf_merge_working_directories();

    my %inputs = (
        build_clumps => $self->build_clumps,

        # InitialVcfMerge
        use_bgzip => 1,
        joinx_version => $self->joinx_version,
        initial_vcf_merge_working_directory => $self->initial_vcf_merge_working_directory,
        max_files_per_merge => $self->max_files_per_merge,
        segregating_sites_vcf_file => File::Spec->join($self->output_directory, 'segregating_sites.vcf.gz'),

        # Backfill(Indel)Vcf
        ref_fasta => $ref_fasta,

        %$variant_type_specific_inputs,

        %$region_limiting_specific_inputs,

        # FinalVcfMerge
        final_vcf_merge_working_directory => $self->final_vcf_merge_working_directory,
        output_vcf => $self->output_vcf,
    );

    return \%inputs;
}

sub build_clumps {
    my $self = shift;

    my @clumps;
    for my $build ($self->builds){
        my $sample = $build->model->subject->id;
        my $dir = $self->output_directory . "/".$sample;
        Genome::Sys->create_directory($dir);

        my $clump = $self->_get_build_clump($build);
        push @clumps, $clump;
    }
    return \@clumps;
}

sub _get_build_clump {
    my ($self, $build) = @_;

    my $sample = $build->model->subject->id;
    my $dir = $self->output_directory . "/".$sample;

    my $clump = Genome::Model::Tools::Vcf::CreateCrossSampleVcf::BuildClump->create(
        backfilled_vcf      => $dir."/".$self->variant_type.".backfilled.vcf.gz",
        bam_file            => $build->whole_rmdup_bam_file,
        pileup_output_file  => $dir."/".$sample.".for_".$self->variant_type.".pileup.gz",
        sample              => $sample,
        vcf_file            => $self->_get_vcf_from_build($build),
        filtered_vcf        => $dir."/".$self->variant_type.".non_calls_removed.vcf.gz",
        build_id            => $build->id,
    );

    return $clump;
}

sub _get_vcf_from_build {
    my ($self, $build) = @_;

    if ($self->roi_list) {
        my $dir = $self->region_limiting_output_directory;
        my $filename = sprintf("%s.%s.region_limited.vcf.gz",
            $self->variant_type, $build->model->subject->id);
        return File::Spec->join($dir, $filename);
    } else {
        my $accessor = $self->get_vcf_accessor;
        return $build->$accessor;
    }
}

sub get_roi_file {
    my ($self, $reference_sequence_build) = @_;

    my $roi_file;
    if(defined($self->roi_list)) {
        my $roi_list = $self->roi_list;

        if($roi_list->reference->id eq $reference_sequence_build->id) {
            $roi_file = $roi_list->file_path;
        } else {
            my $file_path = join("/", $self->output_directory,
                    "converted_roi.bed");
            $roi_file = $roi_list->converted_bed_file(
                    reference => $reference_sequence_build,
                    file_path => $file_path,
            );
            unless(-s $roi_file) {
                $self->error_message(
                            sprintf("%s is missing or has no size... Failed ".
                                    "to convert %s to reference %s.",
                            $file_path,
                            $roi_list->name,
                            $reference_sequence_build->name)
                );
                die $self->error_message();
            }
        }
    }
    return $roi_file;
}

sub prepare_vcf_merge_working_directories {
    my $self = shift;
    Genome::Sys->create_directory($self->initial_vcf_merge_working_directory);
    Genome::Sys->create_directory($self->final_vcf_merge_working_directory);
}

sub initial_vcf_merge_working_directory {
    my $self = shift;
    return File::Spec->join($self->output_directory, "initial_vcf_merge_workspace");
}

sub final_vcf_merge_working_directory {
    my $self = shift;
    return File::Spec->join($self->output_directory, "final_vcf_merge_workspace");
}

sub prepare_region_limiting_output_directory {
    my $self = shift;
    my $dir = $self->region_limiting_output_directory;
    return Genome::Sys->create_directory($dir);
}

sub region_limiting_output_directory {
    my $self = shift;
    return File::Spec->join($self->output_directory, "region_limited_inputs");
}

sub _get_samtools_version_and_params {
    my ($self, $strategy_str) = @_;

    my $strategy = Genome::Model::Tools::DetectVariants2::Strategy->get($strategy_str);

    my @detectors = $strategy->get_detectors();
    my ($version, $params);
    for my $detector (@detectors) {
        if ($detector->{name} eq 'samtools') {
            if ($version) {
                die "Multiple samtools steps found in strategy!";
            } else {
                $version = $detector->{version};
                $params = $detector->{params};
            }
        }
    }

    return ($version, $params);
}

1;
