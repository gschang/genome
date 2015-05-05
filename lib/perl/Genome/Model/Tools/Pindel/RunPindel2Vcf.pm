package Genome::Model::Tools::Pindel::RunPindel2Vcf;

use warnings;
use strict;

use Genome;
use Workflow;
use Date::Format;


class Genome::Model::Tools::Pindel::RunPindel2Vcf {
    is => ['Command'],
    has => [
        tool_path => {
            is => 'String',
            is_input => 1,
            doc => 'pindel2vcf tool path',
        },
        aligned_reads_sample => {
            is => 'String',
            is_input => 1,
            is_optional => 1,
            doc => 'tumor sample name',
        },
        control_aligned_reads_sample => {
            is => 'String',
            is_input => 1,
            is_optional => 1,
            doc => 'normal sample name',
        },
        output_file => {
            is => 'String',
            is_optional => 0,
            is_input => 1,
            is_output => 1,
            doc => 'Where the output should go.',
        },
        pindel_raw_output => {
            is => 'String',
            doc => 'This is the indels.hq file generated by the pindel module',
            default => '10',
            is_input => 1,
        },
        reference_build_id => {
            is => 'Text',
            doc => 'The build-id of a reference sequence build',
            is_input => 1,
        },
        reference_sequence_input => {
            calculate_from => ['reference_build_id'],
            calculate => q{ Genome::Model::Build->get($reference_build_id)->cached_full_consensus_path('fa') },
            doc => 'Location of the reference sequence file',
        },
        _refseq => {
            is => 'Text',
            calculate_from => ['reference_sequence_input'],
            calculate => q| $reference_sequence_input |,
        },
    ],
    has_param => [
        lsf_queue => {
            default_value => Genome::Config::get('lsf_queue_build_worker_alt'),
        },
        lsf_resource => {
            default_value => "-M 16000000 -R 'select[mem>16000] rusage[mem=16000]'",
        },
    ],
};


sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt pindel run-pindel-2-vcf
EOS
}

sub help_detail {
    return <<EOS
    convert raw pindel output into vcf
EOS
}

sub execute {
    my $self = shift;

    unless($self->_verify_inputs) {
        die $self->error_message('Failed to verify inputs.');
    }

    unless ($self->_run_pindel2vcf) {
        die $self->error_message("Failed to get a return value from _detect_variants.");
    }

    return 1;
}

sub _verify_inputs {
    my $self = shift;

    my $ref_seq_file = $self->reference_sequence_input;
    unless(Genome::Sys->check_for_path_existence($ref_seq_file)) {
        $self->error_message("reference sequence input $ref_seq_file does not exist");
        return;
    }

    $self->debug_message("Completed verify_inputs step.");

    return 1;
}

sub _run_pindel2vcf {
    my $self = shift;

    my $refseq = $self->_refseq;
    my $rs     = Genome::Model::Build::ImportedReferenceSequence->get($self->reference_build_id);
    my $refseq_name = $rs->name;

    my $time = time;
    my $template = "%y/%m/%d-%H:%M:%S";
    my $date = time2str($template, $time);

    my $pindel_raw = $self->pindel_raw_output;
    my $output     = $self->output_file;

    my $pindel2vcf_path = $self->tool_path;
    my $cmd    = $pindel2vcf_path . " -p ".$pindel_raw." -r ". $refseq . " -R " . $refseq_name . " -d " . $date . " -v " . $output.'.tmp';
    my $result = Genome::Sys->shellcmd(cmd => $cmd);

    unless($result){
        die $self->error_message("Could not complete pindel2vcf run: ".$result);
    }

    my %params = (
        input_file  => $output.'.tmp',
        output_file => $output,
        aligned_reads_sample        => $self->aligned_reads_sample,
        reference_sequence_build_id => $self->reference_build_id,
    );

    $params{control_aligned_reads_sample} = $self->control_aligned_reads_sample
        if $self->control_aligned_reads_sample;
    $cmd = Genome::Model::Tools::Vcf::Convert::Indel::PindelVcf->create(%params);

    my $rv = $cmd->execute;
    unlink $output.'.tmp';

    unless ($rv) {
        $self->error_message("Failed to run PindelVcf !");
        return;
    }

    return 1;
}


1;
