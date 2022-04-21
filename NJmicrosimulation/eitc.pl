#=============================================================================#
#  EITC – 2021 (Updated with EITC 2021 numbers, modified from KY 2020 and MTRC 2021)
#=============================================================================#
# Calculates EITC benefits
#
# Inputs referenced in this module:
#
#   FROM BASE
#       eitc        # flag
#       earnings
#       child_number
#       family_structure
#		itin 						#whether undocumented household members have an itin or not.
#
#	FROM EARNINGS
#		parent#_earnings
#	
#   FROM INTEREST:
#       interest
#
#	FROM FEDTAX:
#		parent#_taxable_earnings
#		filing_status
#=============================================================================#

use Switch;

sub eitc
{
    my $self = shift;
    my $in = $self->{'in'};
    my $out = $self->{'out'};
    my $debug = $self->{'debug'};

  # outputs created
    our $eitc_recd = 0;           # [Federal EITC] annual value of federal EITC

  # variables used in this module
	our $childless_age_min	= 25;		#The minimum age needed for childless housheholds to claim EITC, under pre-ARPA tax rules
	our $childless_age_min_arpa = 19;	#The minimum age needed for childless housheholds to claim EITC, under ARPA tax rules (except for special populations whcih the FRS does not yet include, such as adult students, former foster youth, and homeless families.
	our $eitc_phasein_rate      = 0;			              # eitc phase-in rate 
    our $eitc_plateau_start     = 0;		#earned income amount
    our $eitc_plateau_end       = 0;		#threshold phaseout amount
    our $eitc_max_value         = 0;			
    our $eitc_phaseout_rate     = 0;		
    our $eitc_income_limit      = 0;		#completed phaseout amount
	our $meets_childless_age_min_unit1		= 0;		#Whether there are any adults in the family who meet the age limit for childless tax filers. "Unit1" refers to the first tax filing unit. We only consider one filing unit per household in the  FRS as of 2021, but are working to incorporate multiple tax filing units in our calculations, so this suffix sets up that coding for easier integration later on. 
    our $eitc_eligible_children = 0;		#number of children eligible for the eitc (only children with SSNs are counted as qualifying children) https://www.irs.gov/pub/irs-pdf/p596.pdf  https://www.irs.gov/credits-deductions/individuals/earned-income-tax-credit/qualifying-child-rules . Foster children are eligible 
	
	#Changes for 2017: We are adding interest into earnings since the 2016 instructions for 1040 instruct  using the number from line 38 to estimate EITC eligibility which is earnings + interest. Prior versions did not include interest. We do not include investment income anywhere in the FRS, and thus, exclude it here as well.
	our $eitc_family_structure = 0;		#family structure after excluding undocumented adults without SSNs (must have an SSN to qualify for EITC)
	our $taxable_earnings = 0;
    # Note (old): Interest is not considered part of earned income. While investment income, 
    # including interest, factors into EITC calculations, it only does so if interest 
    # and other investments add up to more than $3,400 in tax year 2015. This is not 
    # possible in the 2015 version of the FRS, since user-entered savings can only be 
    # entered up to $9,999, and the interest rate is low enough that the maximum possible 
    # interest is well below this threshold. If we choose to increase the savings maximum or 
    # make these variables more malleable in the future, we would need to adjust the below code 
    # to include that consideration, but for 2015 there is no reason for interest to be an input at all.

	our $no_childless_age_minimum = 0;
	our $itin_eitc_eligibility = 0;
	our $potential_eitc_no_age_minimum = 0;
	our $potential_eitc_itin_eligibility = 0;
	our $potential_eitc_itin_and_no_age_minimum = 0;


	#We move forward with current policy and/or ARPA expansions:
	if ($in->{'covid_eitc_expansion'}) { 		
		$childless_age_min = $childless_age_min_arpa; #ARPA lowered (for the 2021 tax year) the minimum age for childless adults to claim the EITC.
	}

	for (my $eitc_model=1; $eitc_model<=4; $eitc_model++) {
		#Modeling different EITC scenarios is  increasingly useful as states are exploring state EITC expansions.

		#We start by indicating the federal policies in effect:
		$no_childless_age_minimum = 0;
		$itin_eitc_eligibility = 0;
		
		#EITC model 1: model without childless age minumums, but with current restrictions around ITIN holders.
		if ($eitc_model == 1) {
			$no_childless_age_minimum = 1;

		#EITC model 2: model with current childless age minimums, but in which ITIN holders are eligible for the EITC.
		} elsif ($eitc_model == 2) {
			$itin_eitc_eligibility = 1;

		#EITC model 3: model without childless age minimum, and in which ITIN holders are eligible for the EITC.
		} elsif ($eitc_model == 3) {
			$no_childless_age_minimum = 1;
			$itin_eitc_eligibility = 1;
		}

		#EITC model 4: federal model, as currently construed, including with potential ARPA (COVID) expansions. 
		
		#No changes. Running this last will mean that the final EITC variables generated will be the ones in use for determining federal EITC and taxes.


		$meets_childless_age_min_unit1 = 0;			
		for (my $i=1; $i<=$in->{'family_structure'}; $i++) {
			if ($in->{'parent'.$i.'_age'} > 17) {
				if ($in->{'parent'.$i.'_age'} >= $childless_age_min || $no_childless_age_minimum == 1) {
					$meets_childless_age_min_unit1 = 1;
				}
			}
		}

		#Calculate the number of eligible adults and children for the EITC. Only taxpayers with SSNs can claim the EITC and only dependents with SSNs can be claimed as a qualifying dependent under EITC rules. We assume that if a parent/child is undocumented they do not have an SSN.
		
		$eitc_eligible_children = $in->{'child_number'} - $in->{'undocumented_child_count'} * (1 - $itin_eitc_eligibility); #The substraction at the end will reinclude itins in the scenario where EITC output includes ITIN holders
		$eitc_family_structure = $in->{'family_structure'} - $in->{'undocumented_adult_count'} * (1 - $itin_eitc_eligibility);
		$taxable_earnings =  $out->{'parent1_taxable_earnings'} + $out->{'parent2_taxable_earnings'};

		if($in->{'eitc'} == 0 || $taxable_earnings == 0) {
			$eitc_recd = 0; # If the user selects to deny the family EITC or has no earned income,  they do not get any EITC.
		} elsif (($eitc_eligible_children == 0 && $meets_childless_age_min_unit1 == 0) || $eitc_family_structure == 0) { #a household is not eligible for EITC if they are a childless tax filing unit (or have no qualifying children) and don't meet the age requirement, or if all adults are undocumented or if the filing status is married filing separately.
			$eitc_recd = 0; 
		} else {
			# Use EITC table to determine (based on family_structure and child_number):
			switch ($eitc_eligible_children) {
			  case 0 {
				if ($in->{'covid_eitc_expansion'} == 1) { #Here's the expansion:
					#These figures were derived from ARPA, the EITC law, a helpful CRS report on the matter, and interpretations from previous IRS updates to the EITC law to reflect inflation. Under "normal years," the IRS releases statements with all these figures and updates, but the additional calculations are detailed below because the IRS has not released a similar guidance as they have for previous annual updates to EITC and other tax figures. Hence, the lengthy explanations for the numbers derived below.
					#ARPA indicates the phase-in and phase-out for the EITC is 15.3%, a change from the 7.65% of the original EITC law. 
					$eitc_phasein_rate = 0.153;
					$eitc_phaseout_rate = 0.153;
					#ARPA indicates the plateau start -- where the full EITC is claimed -- is $9,820, a seemingly inflation-adjusted amount from the original $4,220 plus the ARPA expansion.
					$eitc_plateau_start =  9820;
					#The maximum credit amount is the phase-in rate (.153) multiplied by the lowest earnings which qualifiies filers for the maximum credit amont ($9,820), rounded down.
					$eitc_max_value = 1502;
					#ARPA indicates the plateau end -- the highest income at which the full EITC can be claimed -- is $11,610, a seemingly inflation-adjusted amount from the original $5,280 plus the ARPA expansion. "In the case of a joint return filed by an eligible individual and such individual's spouse, the phaseout amount determined under subparagraph (A) shall be increased by $5,000." The previous IRS adjustment for 2021 indicated that the $5,000 indicated in the original law, adjusted for inflation, is $5,940 (the difference between $14,820 and $8,880. So that's $17,550, a number confirmed by CRS and other reports. CRS indicates this plateau's end is $11,610 for single filers, $17,550 for married ones.
					$eitc_plateau_end  = ($eitc_family_structure == 1 ? 11610 : 17550);
					#The income limits or "income thresholds" for the EITC are mathematically derived from the numbers above, according to the EITC law, in federal statute "26 USC 32: Earned income," as follows: "The amount of the credit allowable to a taxpayer under paragraph (1) for any taxable year shall not exceed the excess (if any) of (A) the credit percentage of the earned income amount, over (B) the phaseout percentage of so much of the adjusted gross income (or, if greater, the earned income) of the taxpayer for the taxable year as exceeds the phaseout amount."  Using the variable designations (and $eitc_recd for the amount of EITC received, and $eitc_income_limit for these thresholds, this translates to 
					# $eitc_recd = ($eitc_phasein_rate) * ($eitc_plateau_start) - ($eitc_phaseout_rate)*($eitc_income_limit - $eitc_plateau_end).
					# When setting $eitc_recd to 0, the two numbers emerging from this equality for $eitc_income_limit are $21,427 and $27,367. These are not widely discussed figures but are reflected in charts in the CRS document and other documents related to the ARPA changes.
					$eitc_income_limit = ($eitc_family_structure == 1 ? 21427 : 27367);
					
				} else {
					#Below are the regular, non-COVID EITC policy data for childless tax filers:
					$eitc_phasein_rate = 0.0765;
					$eitc_plateau_start = 7100;
					$eitc_max_value = 543;
					$eitc_phaseout_rate = 0.0765;		
					$eitc_plateau_end  = ($eitc_family_structure == 1 ? 8880 : 14820);
					$eitc_income_limit = ($eitc_family_structure == 1 ? 15980 : 21920);
				}
			  }
			  case 1 {
				$eitc_phasein_rate = 0.34;
				$eitc_plateau_start = 10640;
				$eitc_max_value = 3618;
				$eitc_phaseout_rate = 0.1598;		
				$eitc_plateau_end  = ($eitc_family_structure == 1 ? 19520 : 25470);
				$eitc_income_limit = ($eitc_family_structure == 1 ? 42158 : 48108);
			  }
			  case 2 {
				$eitc_phasein_rate = 0.4;
				$eitc_plateau_start = 14950;	
				$eitc_max_value = 5980;		
				$eitc_phaseout_rate = 0.2106;		
				$eitc_plateau_end  = ($eitc_family_structure == 1 ? 19520 : 25470);
				$eitc_income_limit = ($eitc_family_structure == 1 ? 47915 : 53865);
			  }
			  case 3 {
				$eitc_phasein_rate = 0.45;
				$eitc_plateau_start = 14950;	
				$eitc_max_value = 6728;		
				$eitc_phaseout_rate = 0.2106;
				$eitc_plateau_end  = ($eitc_family_structure == 1 ? 19520 : 25470);
				$eitc_income_limit = ($eitc_family_structure == 1 ? 51464 : 57414);
			  }          
			  case 4 {
				 $eitc_phasein_rate = 0.45;
				$eitc_plateau_start = 14950;		
				$eitc_max_value = 6728;			
				$eitc_phaseout_rate = 0.2106;
				$eitc_plateau_end  = ($eitc_family_structure == 1 ? 19520 : 25470);
				$eitc_income_limit = ($eitc_family_structure == 1 ? 51464 : 57414);
			  }
			  case 5 {
				$eitc_phasein_rate = 0.45;
				$eitc_plateau_start = 14950;			
				$eitc_max_value = 6728;					
				$eitc_phaseout_rate = 0.2106;
				$eitc_plateau_end  = ($eitc_family_structure == 1 ? 19520 : 25470);	
				$eitc_income_limit = ($eitc_family_structure == 1 ? 51464 : 57414);	

			  }
			}
		 if ($out->{'federal_adjusted_gross_income'} >= $eitc_income_limit) { #The first test for EITC is actually whether either gross income or earned exceed the EITC income limit, as gross income can be less than earnings in some cases, but for the FRS as construed as of 2020, gross income will never be lower than earned income. So we just test initially for gross income here.
				$eitc_recd = 0; 
			} elsif($taxable_earnings < $eitc_plateau_start) { #Previous simulator years had this as earnings plus interest, but gross income is only considered when gross income exceeds the EITC plateau start.
				$eitc_recd = $eitc_phasein_rate * $taxable_earnings; 
			} elsif($taxable_earnings >= $eitc_plateau_start && $taxable_earnings < $eitc_plateau_end) { 
				$eitc_recd = $eitc_max_value; 
			} elsif($taxable_earnings>= $eitc_plateau_end && $taxable_earnings < $eitc_income_limit) { 
				$eitc_recd = $eitc_phaseout_rate * ($eitc_income_limit - ($taxable_earnings + $out->{'interest'})); 
			}

				
			#Then, we check if the conditions are met for the EITC to be determined by gross income, which occurs when gross income is higher than earned income and gross income exceeds the beginning of the EITC's phase-out period. The EITC is the smaller of these two calculations. This will occur as EITC phases out for any family that has interest income.
			
			if ($out->{'federal_adjusted_gross_income'} >= $eitc_plateau_end && $out->{'federal_adjusted_gross_income'} < $eitc_income_limit) {
				 $eitc_recd = &least($eitc_recd ,$eitc_phaseout_rate * ($eitc_income_limit - ($out->{'federal_adjusted_gross_income'})));
			}


			# round eitc_recd to the nearest integer
			$eitc_recd = sprintf "%.0f", $eitc_recd;
		}
		#Generating output depending on current or potential EITC policy scenarios:
		if ($eitc_model == 1) {
			$potential_eitc_no_age_minimum = $eitc_recd;
		}

		if ($eitc_model == 2) {
			$potential_eitc_itin_eligibility = $eitc_recd;
		}

		if ($eitc_model == 3) {
			$potential_eitc_itin_and_no_age_minimum = $eitc_recd;
		}
		
		#EITC model 4, the federal model, will run last and be outputed by the eitc_recd below, and the rest of the outputs will also accord to current federal poliicies (or federal adjustments)
	}


	# outputs
    foreach my $name (qw(eitc_recd meets_childless_age_min_unit1 eitc_family_structure eitc_eligible_children potential_eitc_no_age_minimum  potential_eitc_itin_eligibility potential_eitc_itin_and_no_age_minimum no_childless_age_minimum taxable_earnings)) { 
        $out->{$name} = ${$name};
        $self->saveDebugValues("eitc", $name, ${$name});
    }

    foreach my $variable (qw(eitc_phasein_rate eitc_plateau_start eitc_plateau_end eitc_max_value eitc_phaseout_rate eitc_income_limit eitc_family_structure eitc_eligible_children childless_age_min)) {
        $self->saveDebugValues("eitc", $variable, $$variable, 1);
    }

    return(0);

}

1;