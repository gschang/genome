package Genome::Model::SmallRna::Command::FilterBamFlagstat;

use strict;
use warnings;

use Genome;

class Genome::Model::SmallRna::Command::FilterBamFlagstat {
	is        => 'Genome::Model::Tools::BioSamtools',
	has_input => [
		bam_file => {
			is  => 'String',
			doc => 'Input BAM file of alignments.',
		},
		filtered_bam_file => {
			is  => 'String',
			doc => 'Output BAM file of filtered read alignments .',
			is_output =>1
		},
		
		read_size_bin => {
			is => 'Text',
			doc =>'Min_max read length bin separated by \'_\' : eg 17_75',
		},

	],
};

sub execute {
	my $self = shift;

	my $bam_file 	= $self->bam_file;
	my $new_bam	 	= $self->filtered_bam_file;
	
	
	my $filter_cmd = Genome::Model::SmallRna::Command::FilterNewBam->create
	(
				bam_file 		  => $bam_file,
				filtered_bam_file => $new_bam,
				read_size_bin 	  => $self->read_size_bin,
				xa_tag			  => 1
	);
	
	unless ($filter_cmd->execute)
	{die;}
	
	
	unless (-s $new_bam) {
		die( 'Failed to open filtered BAM file: ' . $new_bam );
	}
	
	
	my $flagstat_file= $new_bam.'.flagstat';
	
	
	my $flagstat_cmd = Genome::Model::Tools::Sam::Flagstat->create
  			 	(
   					bam_file    => $new_bam,
        			output_file => $flagstat_file, 
			);
	unless ($flagstat_cmd->execute)
   			{die;}
   			
   
	
    
	
	return 1;
}
	
1;

__END__
