#=============================================================================#
#  Payroll Module -- 2021 (modified from 2020)
#=============================================================================#
# Inputs referenced in this module: 
#
#	FROM FEDTAX
#		parent#_taxable_earnings 	#this is 0 if the parent is undocumented and does not have an ITIN.
#=============================================================================#

sub payroll
{
    my $self = shift;
    my $in = $self->{'in'};
    my $out = $self->{'out'};

  # outputs created
    our $payroll_tax = 0;
    our $parent1_payroll_tax = 0;
    our $parent2_payroll_tax = 0;
	our $parent3_payroll_tax = 0;
    our $parent4_payroll_tax = 0;
	our $payroll_tax1 = 0;	#The payroll tax for tax filing unit 1. This is important for determining the ACTC. there is the possibility of two diff filing units when there are unmarried adults or multiple adults in the household. ties into medicaid and taxes. 

  # variables used within this module
    my $social_sec_rate     = 0.062;    # social security tax rate 
    my $medicare_rate       = 0.0145;   #medicare rate 
    my $ssec_income_limit   = 142800;   #social security  wage base limit, the maximum wage subject to the tax for the year. 
    my $add_medicare_tax   = 0.009; 	#additional Medicare tax to those earning more than $200,000. 
    my $add_medicare_inc = 200000;	#wage ceiling before additional Medicare tax kicks in.  
		# Source: https://www.irs.gov/taxtopics/tc751 

    # calculated in Macro
    our $social_sec_tax_parent1 = 0;    # social security tax amount (parent 1)
    our $social_sec_tax_parent2 = 0;    # social security tax amount (parent 2)
	our $social_sec_tax_parent3 = 0;    # social security tax amount (parent 3)
    our $social_sec_tax_parent4 = 0;    # social security tax amount (parent 4)
    our $medicare_tax_parent1 = 0;      # medicare tax amount (parent 1)
    our $medicare_tax_parent2 = 0;      # medicare tax amount (parent 2)
	our $medicare_tax_parent3 = 0;      # medicare tax amount (parent 3)
    our $medicare_tax_parent4 = 0;      # medicare tax amount (parent 4)
    our $add_medicare_tax_parent1 = 0;      	#additional medicare tax amount (parent 1)
    our $add_medicare_tax_parent2 = 0;      	#additional medicare tax amount (parent 2)
	our $add_medicare_tax_parent3 = 0;      	#additional medicare tax amount (parent 3)
    our $add_medicare_tax_parent4 = 0;      	#additional medicare tax amount (parent 4)

	#Note: people do not pay payoll taxes for unemployment insurance benefits.

	for(my $i=1; $i<=$in->{'family_structure'}; $i++) { 
		${'social_sec_tax_parent'.$i} = $social_sec_rate * &least($out->{'parent'.$i.'_taxable_earnings'}, $ssec_income_limit);
		${'medicare_tax_parent'.$i} = $medicare_rate * $out->{'parent'.$i.'_taxable_earnings'};	
		${'add_medicare_tax_parent'.$i}  = $add_medicare_tax  * pos_sub($out->{'parent'.$i.'_taxable_earnings'}, $add_medicare_inc);
	}

    $parent1_payroll_tax = $social_sec_tax_parent1 + $medicare_tax_parent1 + $add_medicare_tax_parent1;
    $parent2_payroll_tax = $social_sec_tax_parent2 + $medicare_tax_parent2 + $add_medicare_tax_parent2;
	$parent3_payroll_tax = $social_sec_tax_parent3 + $medicare_tax_parent3 + $add_medicare_tax_parent3;
    $parent4_payroll_tax = $social_sec_tax_parent4 + $medicare_tax_parent4 + $add_medicare_tax_parent4;

    $payroll_tax = &round($parent1_payroll_tax + $parent2_payroll_tax + $parent3_payroll_tax + $parent4_payroll_tax);
	
	for(my $i=1; $i<=$in->{'family_structure'}; $i++) { 
		if ($in->{'parent'. $i.'_age'} > 17 && 1 == 0) { # turned off this part for now because as long as we are assuming a single tax filing unit, we don't need a separate head-of-household payroll tax calculation.
			if ($i == $out->{'filing_status1_adult1'} || $i == $out->{'filing_status1_adult2'}  || $i == $out->{'filing_status1_adult3'} || $i == $out->{'filing_status1_adult4'}) {
				$payroll_tax1 += $in->{'parent'.$i.'_earnings'};
			}
		}
	}

  # outputs
    foreach my $name (qw(payroll_tax parent1_payroll_tax parent2_payroll_tax parent3_payroll_tax parent4_payroll_tax)) {
        $out->{$name} = ${$name} || '';
        $self->saveDebugValues("payroll", $name, ${$name});
    }

    foreach my $variable (qw(social_sec_tax_parent1 social_sec_tax_parent2 social_sec_tax_parent3 social_sec_tax_parent4 medicare_tax_parent1 medicare_tax_parent2 medicare_tax_parent3 medicare_tax_parent4 add_medicare_tax_parent1 add_medicare_tax_parent2 add_medicare_tax_parent3 add_medicare_tax_parent4)) {
        $self->saveDebugValues("payroll", $variable, $$variable, 1);
    }

    return(0);

}

1;
