package Genome::Model::Tools::Pindel::RunPindel2Vcf;

use warnings;
use strict;

use Genome;
use Workflow;

my $DEFAULT_VERSION = '0.5';
my $PINDEL_COMMAND = 'pindel';

class Genome::Model::Tools::Pindel::RunPindel2Vcf {
    is => ['Command'],
    has => [
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
    # Make workflow choose 64 bit blades
    has_param => [
        lsf_queue => {
            default_value => 'apipe',
        },
        lsf_resource => {
            default_value => "-M 16000000 -R 'select[type==LINUX64 && mem>16000] rusage[mem=16000]'",
        },
    ],
};

my $pindel2vcf_path = $ENV{GENOME_SW} . "/pindel2vcf/0.1.9/pindel2vcf-0.1.9"; # 0.1.9
#my $pindel2vcf_path = '/usr/lib/pindel0.2.4o/bin/pindel2vcf'; # 0.2.8

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

    $self->status_message("Completed verify_inputs step.");

    return 1;
}

sub _run_pindel2vcf {
    my $self = shift;

    my $refseq = $self->_refseq;
    my $rs     = Genome::Model::Build::ImportedReferenceSequence->get($self->reference_build_id);
    my $refseq_name = $rs->name;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $date       = $year . "/" . ($mon+1) . "/" . $mday . "-" . $hour . ":" . $min . ":" . $sec;
    my $pindel_raw = $self->pindel_raw_output;
    my $output     = $self->output_file;

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
