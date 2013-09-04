package Genome::Model::Tools::Annotate::TranscriptVariants::Version1;

use strict;
use warnings;

use Data::Dumper;
use Genome;
use File::Temp;
use List::Util qw/ max min /;
use List::MoreUtils qw/ uniq /;
use Bio::Seq;
use Bio::Tools::CodonTable;
use DateTime;
use Carp;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Tools::Annotate::TranscriptVariants::Base',

    doc => 'TranscriptStructure-centric annotator designed to produce the same answers as version 0 but run faster.',
);


sub transcript_status_priorities {
    return (
        reviewed    => 1,
        validated   => 2,
        provisional => 3,
        predicted   => 4,
        model       => 5,
        inferred    => 6,
        known       => 7,
        novel       => 8,
        unknown     => 9,
    );
}


sub is_mitochondrial {
    my ($self, $chrom_name) = @_;

    # Are NT entries actually mitochondrial? What about the new GLXXXXXX.X entries?
    return $chrom_name =~ /^[MN]T/;
}


sub cache_gene_names {
    # Nothing to cache for Version 1
}

sub filter_and_partition_structures {
    my $self = shift;
    my $crossing_substructures = shift;
    my $transcript_substructures = shift;
    my $variant_start = shift;

    # Hack to support the old behavior of only annotating against the first structure
    # of a transcript.  We need to keep a list of all the other structures for later
    # listing them in the deletions column of the output
    my @less;
    foreach my $substructure ( @$crossing_substructures ) {
        my $transcript_id = $substructure->transcript_transcript_id;
        if ($substructure->{'structure_start'} <= $variant_start and $substructure->{'structure_stop'} >= $variant_start) {
            push @less, $substructure;
        }
        $transcript_substructures->{$transcript_id} ||= [];
        push @{$transcript_substructures->{$transcript_id}}, $substructure;
    }
    $crossing_substructures = \@less;

    return;
}

sub specialized_deletion_annotation {
    my ($self, $substruct, $transcript_substructures, $annotation) = @_;

    my @del_strings = map { $_->structure_type . '[' . $_->structure_start . ',' . $_->structure_stop . ']' }
                          @{$transcript_substructures->{$substruct->transcript_transcript_id}};
    $annotation->{'deletion_substructures'} = '(deletion:' . join(', ', @del_strings) . ')';

    return;
}

sub reference_sequence_id {
    my $self = shift;

     return $self->build->reference_sequence_id;
}

sub should_update_variant_attributes {
    my ($self, $variant, $structure) = @_;

    if ($variant->{stop} > $structure->structure_stop and $variant->{type} eq 'DEL') {
        return 1;
    }

    return;
}

sub get_dnp_snp_trv_type {
    my ($self, $original_aa, $mutated_aa) = @_;

    if ($mutated_aa eq $original_aa) {
        return 'silent';
    }
    else {
        my ($reduced_original_aa, $reduced_mutated_aa, $offset) = $self->_reduce(
            $original_aa, $mutated_aa);

        if (index($reduced_mutated_aa, '*') != -1) {
            return 'nonsense';
        }
        elsif (index($reduced_original_aa, '*') != -1) {
            return 'nonstop';
        }
        else {
            return 'missense';
        }
    }
}


sub get_dnp_snp_protein_data {
    my ($self, $original_aa, $mutated_aa, $protein_position) = @_;

    if ($mutated_aa eq $original_aa) {
        return ("p." . $original_aa . $protein_position, $protein_position);
    }
    else {
        my ($reduced_original_aa, $reduced_mutated_aa, $offset) = $self->_reduce(
            $original_aa, $mutated_aa);
        $protein_position += $offset;

        return ("p." . $reduced_original_aa . $protein_position . $reduced_mutated_aa,
            $protein_position);
    }
}


# Taken from Genome::Transcript
# Given a version and species, find the imported reference sequence build
sub get_reference_build_for_transcript {
    my($self, $structure) = @_;

    my ($version) = $structure->transcript_version =~ /^\d+_(\d+)[a-z]/;
    my $species = $structure->transcript_species;

    unless ($self->{'_reference_builds'}->{$version}->{$species}) {

        my $model = Genome::Model::ImportedReferenceSequence->get(name => "NCBI-$species");
        confess "Could not get imported reference sequence model for $species!" unless $model;
        my $build = $model->build_by_version($version . "-lite");
        unless ($build) {
            $build = $model->build_by_version($version);
        }
        confess "Could not get build version $version from $species imported reference sequence model!" unless $build;

        $self->{'_reference_build'}->{$version}->{$species} = $build;
    }
    return $self->{_reference_build}->{$version}->{$species};
}


sub bound_relative_stop {
    my ($self, $relative_stop, $limit) = @_;

    # NOTE In Version1, we do not use this bound (leave this bug in place).

    return $relative_stop;
}

1;

=pod
=head1 Name

Genome::Transcript::VariantAnnotator

=head1 Synopsis

Given a variant, all transcripts affected by that variant are annotated and returned

=head1 Usage

# Variant file tab delimited, columns are chromosome, start, stop, reference, variant
# Need to infer variant type (SNP, DNP, INS, DEL) as well
my $variant_file = variants.tsv;
my @headers = qw/ chromosome_name start stop reference variant /;
my $reader = Genome::Utility::IO::SeparatedValueReader->create(
        input => $variant_file,
        headers => \@headers,
        separator => "\t",
        is_regex => 1,
        );

my $model = Genome::Model->get(name => 'NCBI-human.combined-annotation');
my $build = $model->build_by_version('54_36p');
my $iterator = $build->transcript_iterator;
my $window = Genome::Utility::Window::Transcript->create(
        iterator => $iterator,
        range => 50000,
        );
my $annotator = Genome::Transcript::VariantAnnotator->create(
        transcript_window => $window
        );

while (my $variant = $reader->next) {
    my @annotations = annotator->transcripts($variant);
}

=head1 Methods

=head2 transcripts

=over

=item I<Synopsis>   gets all annotations for a variant

=item I<Arguments>  variant (hash; see 'Variant Properites' below)

=item I<Returns>    annotations (array of hash refs; see 'Annotation' below)

=back

=head2 prioritized_transcripts

=over

=item I<Synopsis>   Gets one prioritized annotation per gene for a variant(snp or indel)

    =item I<Arguments>  variant (hash; see 'Variant properties' below)

    =item I<Returns>    annotations (array of hash refs; see 'Annotation' below)

    =back

    =head2 prioritized_transcript

    =over

    =item I<Snynopsis>  Gets the highest priority transcript affected by variant

    =item I<Arguments>  variant (hash, see 'Variant properties' below)

    =item I<Returns>    annotations (array of hash refs; see 'Annotation' below)

    =back

    =head1 Variant Properties

    =over

    =item I<chromosome_name>  The chromosome of the variant

    =item I<start>            The start position of the variant

    =item I<stop>             The stop position of the variant

    =item I<variant>          The snp base

    =item I<reference>        The reference base at the position

    =item I<type>             snp, dnp, ins, or del

    =back

    =head1 Annotation Properties

    =over

    =item I<transcript_name>    Name of the transcript

    =item I<transcript_source>  Source of the transcript

    =item I<strand>             Strand of the transcript

    =item I<c_position>         Relative position of the variant

    =item I<trv_type>           Called Classification of variant

=item I<priority>           Priority of the trv_type (only from get_prioritized_annotations)

    =item I<gene_name>          Gene name of the transcript

    =item I<intensity>          Gene intenstiy

    =item I<detection>          Gene detection

    =item I<amino_acid_length>  Amino acid length of the protein

    =item I<amino_acid_change>  Resultant change in amino acid in snp is in cds_exon

    =item I<variations>         Hashref w/ keys of known variations at the variant position

    =item I<type>               snp, ins, or del

    =back

    =head1 See Also

    B<Genome::Model::Command::Report>

    =head1 Disclaimer

    Copyright (C) 2008 Washington University Genome Sequencing Center

    This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

    Core Logic:

    B<Xiaoqi Shi> I<xshi@genome.wustl.edu>

    Optimization:

    B<Eddie Belter> I<ebelter@watson.wustl.edu>

    B<Gabe Sanderson> l<gsanders@genome.wustl.edu>

    B<Adam Dukes l<adukes@genome.wustl.edu>

    B<Brian Derickson l<bdericks@genome.wustl.edu>

    =cut

#$HeadURL$
#$Id$
