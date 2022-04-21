#=============================================================================#
#  SSP (State Supplemental Program) Module – 2021 NJ 
#=============================================================================#
#
#
#=============================================================================#

sub ssp
{
	my $self = shift;
	my $in = $self->{'in'};
	my $out = $self->{'out'};

	# outputs created in macro:
	# Some states supplement the federal SSI benefit with their own state benefit, which increases cash assistance for individuals eligible for SSI or ineligible due to incomes that slightly exceed SSI standards. To keep the SSI module applicable across different states, we are adding a separate module beginning in 2020 that tracks state SSI supplements (called the "state supplementary program", or SSP) in states that have them. Although small in amount, receiving this supplement can also allow individuals with disabilities at slightly higher incomes to receive Medicaid. Kentucky indeed provides an SSP, but it is limited to individuals with disabilities requiring in-home care or living in a licensed facility serving people with disabilities. The potential benefit from Kentucky's SSP program will be $0 unless we reassess our living arrangement options. See https://chfs.ky.gov/agencies/dcbs/dfs/Documents/OMVOLV.pdf. 
	# These SSP amounts and variables are incorporated into the federal SSI Perl code. If Kentucky had an SSP program that covered populations we currently include in the FRS, we would mark that here and adjust the use of these variables in the SSI module accordingly.
	
#LOOK AT ME: There is some evidence that NJ has a program, but only from federal sources and not NJ state sources. The below figures represent the difference between SSI allotments and the total monthly allotments available at https://www.ssa.gov/pubs/EN-05-11148.pdf. Other documents -- for example, county-level public assistance outreach information, reference similar numbers, and earlier federal documents reference state statutes that indicate the legal justification for providing additional amounts, but do not specify those amounts. So, these numbers are worth confirming with state officials.

	our $ssp_couple = 31.25; 
	our $ssp_individual = 25.36;
	our $ssp_individual_in_couple = 153; # It seems that NJ's SSP program also provided (or provides) a sizeable boost to people on SSI living with and married to spouses ineligble for SSI. This is interesting because it seems to help offset the marriage penalty in SSI. 
	our $ssp_household = 18.75; #This is the monthly amount for NJ's Special utility Supplement -  The Special Utility Supplement is to assist SSI beneficiaries who are not eligible for the state's Lifeline utility programs (not to be confused with the federal Lifeline telephone subsidies). This is added to each SSI check in an amount equal to 1/12 of the yearly supplement of $225. This benefit is up to $18.75/month https://www.nj.gov/humanservices/providers/rulefees/regs/NJAC%2010_167D%20Liefeline%20Credit%20Program_Tenants%20Lifeline%20Assistance%20Program%20Manual.pdf. 
	
	#Like other programs, NJ also provides additional benefits via SSP to residents in institutional faclities.

	 # outputs
	foreach my $name (qw(ssp_couple ssp_individual ssp_individual_in_couple ssp_household)) {
		$out->{$name} = ${$name};
		$self->saveDebugValues("ssp", $name, ${$name});
	}
  
	  foreach my $variable (qw(ssp_couple ssp_individual ssp_individual_in_couple)) { 
		$self->saveDebugValues("ssp", $variable, $$variable, 1);
	}

	return(0);
}

1;
