#=============================================================================#
#  SSDI Module -- 2021 
#=============================================================================#
#
# Inputs referenced in this module:
#   FROM BASE
#	
#=============================================================================#

sub ssdi
{
    my $self = shift; 
    my $in = $self->{'in'};
    my $out = $self->{'out'};

	# LOOK AT ME: This is a placeholder code for now. Time permitting, we will be adding in SSDI, but it is a lesser priority than other more immediate tasks. So the placeholder version of this code will just produce the monthly and annual outputs needed for other codes to run.
	

	# VARIABLES NEEDED FOR MACRO: hard-coded outputs that would need to be updated to keep code up-to-date
	our $ssdi_recd = 0;
	our $ssdi_recd_m = 0;
	our $parent1_ssdi_recd = 0;
	our $parent2_ssdi_recd = 0;
	our $child1_ssdi_recd = 0;
	our $child2_ssdi_recd = 0;
	our $child3_ssdi_recd = 0;
	our $child4_ssdi_recd = 0;
	our $child5_ssdi_recd = 0;

	# outputs
    foreach my $name (qw(ssdi_recd  ssdi_recd_m parent1_ssdi_recd parent2_ssdi_recd child1_ssdi_recd child2_ssdi_recd child3_ssdi_recd child4_ssdi_recd child5_ssdi_recd)) {
       $out->{$name} = ${$name};
	   $self->saveDebugValues("ssdi", $name, ${$name});
    }	

	foreach my $variable (qw(ssdi_recd)) {
		$self->saveDebugValues("ssdi", $variable, $$variable, 1);
	}

	return(0);
	
}

1;
