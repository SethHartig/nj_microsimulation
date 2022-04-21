#=============================================================================#
#  State Taxes -- NJ 2021
#=============================================================================#
#
# Inputs referenced in this module:
#
#   FROM BASE
#	   	child_number
#	   	family_structure
#	   	rent_cost_m
#	   	state_eitc
#		undocumented_adult_count
#		undocumented_child_count
#		daca_child_count
#		eitc_itin_alt	#policy modeling option for NJ 2021: "Policy change: Expand state EITC eligibility to workers with ITINs" (checkbox feature or drop down yes/no).
#		empire_state_ctc_alt       #policy modeling option for NJ 2021: "Policy change: Structure the NJ state CTC like the Empire State CTC?" checkbox yes/no.
#		tax_credit_alt 			#POLICY MODELING OPTION FOR NJ 2021: "Policy option: Include an additional tax credit of $_______for all taxpayers."
#		tax_credit_user_input	#POLICY MODELING OPTION FOR NJ 2021: up to a 4 figure amount? 
#		spousal_sup_ncp
#
#	 Outputs:
#	   earnings
#
#   FROM HLTH_COSTS
#	   health_expenses
#
#   FROM CTC
#	   federal_tax_credits
#
#   FROM EITC
#	   eitc_recd
#	   parent#_earnings_taxes 		this is recalculated in the federal eitc code. 
#	   childless_age_min_nj_alt 	
#	   eitc_income_threshold_fulfilled_nj_alt
#   FROM FEDTAX
#	   filing_status
#	   federal_tax_income
#	   federal_tax_gross
#	   cadc_eligible_child_count
#	   ctc_max_income_alt
#		ctc_eligible_children_count
#		ctc_ineligible_children_under17_count
#		
#   FROM INTEREST
#	   interest
#
#=============================================================================#

sub statetax {	
	my $self = shift;
	my $in = $self->{'in'};
	my $out = $self->{'out'};
	my $dbh = $self->{'dbh'};

	  # additional policy variables used within this macro
	our $couple_min = 20000;			  # Income below which state taxes are not due for married or head of household
	our $single_min = 10000;			  # Income below which state taxes are not due for single or married filing separately
	our $child_exempt_amt = 1500;		 # Dependent child exemption per child
	our $disability_exempt_amt = 1000;		 # Dependent child exemption per child
	our $single_exempt_amt = 1000;		# Personal exemption value
	our $couple_exempt_amt = 2000;		# Personal and spouse exemption value
	our $med_expense_deduction_std = .02; #the perentage of gross income above which medical expenses -- including insurance - can be deducted from NJ gross earnings.
	our $rent_pt_pct = 0.18;			  # Renters property tax calcluates as 18% annual rent
	our $state_eitc_pct = .4;			# NJ EITC = 40% federal eitc
	our $ui_rate = 0.003825;			#New for NJ 2021 - UI payroll tax for workers depends on job classification. We can make an assumption here that all users are the same classification of worker, or, for future iterations, ask users to select what classification of worker they are. The rate listed here is the one that applies to non-government workers. 
	our $di_rate = 0.004700;			#New for NJ 2021 - Disability insurance payroll tax - same for all types of workers.
	our $wfswf_rate = 0.000425;			#New for NJ 2021 -Workforce Development(WF/SWF) payroll tax - same for all types of workers.
	our $fli_rate = 0.0028;				#New for NJ 2021 -Family Leave Insurance (FLI) payroll tax - same for all types of workers
	our $ui_base_salary = 36200;		#New for NJ 2021 Taxable Wage Base for UI and Workforce Development(WF/SWF)
	our $fli_base_salary = 138200;		#New for NJ 2021 Taxable Wage Base for Family Leave Insurance and Temporary Disability Insurance.
	#sources for NJ payroll taxes: https://www.nj.gov/labor/ea/employer-services/rate-info/. This site (https://taxnews.ey.com/news/2019-2031-new-jersey-announces-2020-wage-bases-and-tax-rates-for-unemployment-disability-and-family-leave-insurance) is helpful for understanding that "tax base" as used here represent the amount up to which taxpayers pay taxes based on the above rates, but above which the specific payroll tax being calculated does not increase.
	our $state_cadc_incomelimit = 150000; #income limit for NJ CDCTC. #
	our $mctrebate_single_incomelimit = 75000;	#income limit for NJ middle class tax rebate for individuals filing single https://www.state.nj.us/treasury/taxation/individuals/mctr.shtml
	our $mctrebate_married_hoh_incomelimit = 150000; #income limit for NJ middle class tax rebate for individuals filing status = married, head of household, or surviving spouse. 
	our $max_middle_class_rebate = 500;
	our $prop_tax_ded_max = 15000; #the max property tax deduction, for all filers except for married filing seprarately (for whom it is 7500).
	
	#Outputs created
	our $state_tax = 0;				 # state taxes paid
	our $state_eic_recd = 0;
	our $state_tax_gross = 0;
	our $state_tax_credits = 0;
	our $tax_before_credits = 0;
	our $tax_after_credits = 0;
	our $state_payroll_tax = 0;		#New for NJ 2021
	our $middle_class_tax_rebate = 0;
	our $additional_state_tax_credits  = 0;	#policy modeling option for NJ 2021
	
	#Intermediary variables calculated in macro to help determine outputs
	our $state_gross_inc = 0;			 # Gross income, determines taxability
	our $tax_income_min = 0;			  # Income below which state taxes are not due 
	our $exemption = 0;				   # Combined value of exemptions for adult and child hh members
	our $health_ded = 0;				  # Amount of health expenses eligible for deduction
	our $state_gross_inc = 0;			 # State gross income
	our $state_tax_inc = 0;			   # Base taxable income
	our $adj_state_tax_inc = 0;		   # Base taxable income less property tax
	our $rent_prop_tax = 0;			   # Renters property tax value
	our $tax_diff = 0;					# Difference between tax rate and property tax adjusted tax rate, determines whether to use property tax deduction or property tax credit
	our $prop_tax_ded = 0;				# Property tax deduction
	our $prop_tax_credit_recd = 0;			 # Property tax credit
	our $net_income = 0;				  # Income after deductions
	our $state_tax_rate = 0;			  # Tax rate based on income range
	our $adj_state_tax_rate = 0;		  # Tax rate based on adjust income range
	our $less_amt = 0;					# Amount subtracted from income * tax rate
	our $adj_less_amt = 0;				# Amount subtracted from Adj_income * tax rate
	our $state_cadc_percentage = 0;
	our $state_cadc_gross = 0;
	our $state_cadc_max_claims = 0;
	our $state_cadc_recd = 0;
	our $childless_age_min_nj_alt = 18; #POLICY MODELING OPTION FOR NJ 2021: used only if the user selects "yes" to the "State policy option: Lower the age eligibility for NJ state EITC for a childless worker from 25 to 18?" Should only be able to select this if eitc == 1. In FY 2022, the EITC will be further expanded for these workers by reducing the minimum age to 18 and lifting the maximum age requirement. https://www.njpp.org/publications/report/shining-a-light-on-new-jerseys-fy-2022-budget/#_edn4
	our $ctc_max_income_alt = 0;						#policy modeling option
	our $state_ctc_recd = 0;
	our $potential_state_eic_recd = 0;
	
	# DELETE below ONCE PROGRAMMED INTO PHP/discussed with Brittany/Renee

	#$in->{'eitc_income_threshold_alt'} = 0; #policy modeling option: we decided against including this because it was a holdover from pre ARPA changes. Commening out this next policy option, pending clarification from Brittany and discussion of how this particular EITC expansion is an approximation of the ARPA EITC expansion for filers without dependents. 
	#Changes for 2017: We are adding interest into earnings since the 2016 instructions for 1040 instruct  using the number from line 38 to estimate EITC eligibility which is earnings + interest. Prior versions did not include interest. We do not include investment income anywhere in the FRS, and thus, exclude it here as well.

	# 1. DETERMINE LIABILITY FOR STATE TAX
	#
	if($in->{'family_structure'} == $in->{'undocumented_adult_count'} && $in->{'itin'} == 0) {  
		$state_gross_inc = 0;
		$state_tax_inc = 0;
		$state_tax_gross = 0;
	} else {
		$state_gross_inc = $out->{'taxable_earnings'} + $out->{'interest'} + $in->{'spousal_sup_ncp'}; #only countable parent's earnings are counted here for taxes. Earnings of undocumented parents without an ITIN are not counted. this is defined in fedtax and recalculated in eitc for those who chose the policy modeling options for the state eitc. 
		#NJ does not tax UI, FLI, or TDI benefits and should not be included in determination of whether to file a form. See state income tax instructions and https://www.myunemployment.nj.gov/help/faqs/taxes.shtml and https://www.nj.gov/labor/roles/empupdte/TaxReporting.html#:~:text=An%20Internal%20Revenue%20Service%20ruling,as%20third%2Dparty%20sick%20pay.&text=Temporary%20Disability%20benefits%20and%20Unemployment,New%20Jersey%20state%20income%20tax. 
		
		if ($in->{'parent1_immigration_status'} eq 'undocumented_or_other' && $in->{'itin'} == 0) {  
			$state_gross_inc -= $in->{'spousal_sup_ncp'};	#spousal support is assigned to parent 1, but remove spousal support if the parent 1 is undocumented without an itin.
		}
		
		if(($out->{'filing_status'} eq 'Married' || $out->{'filing_status'} eq 'Head of Household') && $state_gross_inc < $couple_min) {
			$state_tax_gross = 0;
		} elsif($state_gross_inc < $single_min) { 
			$state_tax_gross = 0;
		} else {
		
			#
			# 2. CALCULATE ADULT AND CHILD EXEMPTIONS, MEDICAL EXPENSE DEDUCTION AND STATE TAXABLE INCOME
			#
			
			$health_ded = pos_sub($out->{'health_expenses'}, $med_expense_deduction_std * $state_gross_inc);

			#FUTURE NOTE: adult student dependents less than 22 years old also have a separate exemption claim (note this does not match the federal definition fo under 24), as do veterans.
			#Calculate exemptions.
			#Start with child exemptions. Only children/dependents with an SSN or an ITIN are eligible for exemption amount
			$exemption = ($in->{'child_number'} - $in->{'undocumented_child_count'} * (1 - $in->{'itin'})) * $child_exempt_amt; #The 1-itin term will zero out any reductions due to undocumented status when the members of the tax filing unit in question have an ITIN. 
			
			#Then add disability, one by one.
			for (my $i = 1; $i <= $in->{'family_structure'}; $i++)	{
				if ($in->{'disability_parent'.$i} == 1 && ($in->{'parent'.$i.'_immigration_status'} ne 'undocumented_or_other' || $in->{'itin'} == 1)) {
					$exemption += $disability_exempt_amt;
				}
			}
			
			#Then assign exemption for married or single.
			if ($in->{'family_structure'} == 1 || ($in->{'undocumented_adult_count'} > 0 && $in->{'itin'} == 0)) { #Either (a) One-adult family or (b) family with two adults, but in which only one adult is filing because the other is undocumtned and has no ITIN. There is no case to consider where both adults are undocumented without ITINs, because that family cannot file.
				$exemption += $single_exempt_amt;
			} else {
				$exemption += $couple_exempt_amt;
			}		
			
			$state_tax_inc = pos_sub($state_gross_inc, $exemption + $health_ded);
			#
			# 3. CALCULATE PROPERTY TAX, PROPERTY TAX  TAX DEDUCTION
			#Note: This credit and deduction is also available to homeowners. Rather than using their property tax to estimate this credit, we are estimating this based on 18% of rent paid, as is stipulated in the tax code. 
			#FUTURE NOTE: Renters living in privately-owned housing who are receiving Section 8 or HCVP subsidies are eligible for this credit. However, residents in properties that are tax-exempt are not eligible, meaning that people in Public Housing would not be eligible.

			if ($out->{'filing_status'} eq 'Married' || $out->{'filing_status'} eq 'Head of Household' ) { #meaning married or head of household filing status:
				$tax_income_min = $couple_min;
			} else { #tax filing status is single
				$tax_income_min = $single_min;
			}	

			
			if ($state_gross_inc > $tax_income_min) {
				$rent_prop_tax = $rent_pt_pct * $out->{'rent_paid'};
			}
			#We have to calculate an alternate tax calculation as if the property tax deduction is not claimed, so that we can figure out if the property tax credit is better for the filer. This follows NJ's income tax instructions.
			$adj_state_tax_inc = $state_tax_inc - &least($rent_prop_tax, $prop_tax_ded_max);
			
			#Calculate NJ income tax, gross.
			if($out->{'filing_status'} eq 'Single') {
				for ($state_tax_inc) {
					$state_tax_rate = ($_ <= 20000)   ?   0.014	:
									  ($_ <= 35000)   ?   0.0175   :
									  ($_ <= 40000)   ?   0.035	:
									  ($_ <= 75000)   ?   0.05525  :
									  ($_ <= 500000)  ?   0.0637   :
									  ($_ <= 5000000)  ?   0.0897   :
														  .1075;
									  
					$less_amt =	   	  ($_ <= 20000)   ?   0	   :
									  ($_ <= 35000)   ?   70	  :
									  ($_ <= 40000)   ?   682.5   :
									  ($_ <= 75000)   ?   1492.5  :
									  ($_ <= 500000)  ?   2126.25 :
									  ($_ <= 5000000)  ?   15126.25 :
														  104126.25;
				}
				
				for ($adj_state_tax_inc) {
					$adj_state_tax_rate = ($_ <= 20000)   ?   0.014	:
										  ($_ <= 35000)   ?   0.0175   :
										  ($_ <= 40000)   ?   0.035	:
										  ($_ <= 75000)   ?   0.05525  :
										  ($_ <= 500000)  ?   0.0637   :
										  ($_ <= 5000000)  ?   0.0897   :
															  .1075;
									  
					$adj_less_amt =	   ($_ <= 20000)   ?   0	   :
										  ($_ <= 35000)   ?   70	  :
										  ($_ <= 40000)   ?   682.5   :
										  ($_ <= 75000)   ?   1492.5  :
										  ($_ <= 500000)  ?   2126.25 :
										  ($_ <= 5000000)  ?   15126.25 :
															  104126.25;
				}
			} else { # Married filing jointly or Head of Household

				for ($state_tax_inc) {
				
					$state_tax_rate = ($_ <= 20000)   ?   0.014	:
									  ($_ <= 50000)   ?   0.0175   :
									  ($_ <= 70000)   ?   0.0245   :
									  ($_ <= 80000)   ?   0.035	:
									  ($_ <= 150000)  ?   0.05525  :
									  ($_ <= 500000)  ?   0.0637   :
									  ($_ <= 5000000)  ?   0.0897   :
														  .1075;
									  
					$less_amt =	   ($_ <= 20000)   ?   0		:
									  ($_ <= 50000)   ?   70	   :
									  ($_ <= 70000)   ?   420	  :
									  ($_ <= 80000)   ?   1154.5   :
									  ($_ <= 150000)  ?   2775	 :
									  ($_ <= 500000)  ?   4042.5	 :
									  ($_ <= 5000000)  ?   17042.5	 :
														  106042.5;
				}
				for ($adj_state_tax_inc) {
					
					$adj_state_tax_rate = ($_ <= 20000)   ?   0.014	:
										  ($_ <= 50000)   ?   0.0175   :
										  ($_ <= 70000)   ?   0.0245   :
										  ($_ <= 80000)   ?   0.035	:
										  ($_ <= 150000)  ?   0.05525  :
										  ($_ <= 500000)  ?   0.0637   :
										  ($_ <= 5000000)  ?   0.0897   :
															  .1075;
									  
					$adj_less_amt =	   ($_ <= 20000)   ?   0		:
									  ($_ <= 50000)   ?   70	   :
									  ($_ <= 70000)   ?   420	  :
									  ($_ <= 80000)   ?   1154.5   :
									  ($_ <= 150000)  ?   2775	 :
									  ($_ <= 500000)  ?   4042.5	 :
									  ($_ <= 5000000)  ?   17042.5	 :
														  106042.5;
				}  
			}
		}

		#Property tax credit, redux
		$tax_diff = ($state_tax_rate * $state_tax_inc - $less_amt) - ($adj_state_tax_rate * $adj_state_tax_inc - $adj_less_amt); #For people with gross income of 0, this will be 0 and they will be eligible for the refundable credit calculated below.

		if($tax_diff > 50 || $in->{'prop_tax_credit'} == 0) {
			$prop_tax_ded = &least($rent_prop_tax, $prop_tax_ded_max);
			$prop_tax_credit_recd = 0;
			$state_tax_rate = $adj_state_tax_rate;
			$less_amt = $adj_less_amt;
		} else {
			$prop_tax_ded = 0;
			$prop_tax_credit_recd = 50;
		}
		$state_tax_inc = pos_sub($state_tax_inc, $prop_tax_ded); #We deduct the refundable credit, which can be positive or 0, as a refundable credit below.

		$state_tax_gross = pos_sub($state_tax_rate * $state_tax_inc - $less_amt);
		

		#NJ Child Care Tax Credit:
		if ($in->{'state_cadc_incomelimit_alt'} == 1) { 	 
			$state_cadc_incomelimit = $in->{'state_cadc_incomelimit_user_input'};
		}
		if ($state_tax_inc <= $state_cadc_incomelimit && $out->{'cadc_gross'} > 0 && $in->{'state_cadc'} == 1) { #You are only allowed a NJ CADC if you have income above this threshold and are "allowed" a federal credit (so cannot claim this if you file separately or if dependents do not have an SSN or ITIN). #based on newly passed bill A6071 in Dec 2021 https://www.njleg.state.nj.us/2020/Bills/A9999/6071_R1.PDF. "shall apply retroactively to taxable years beginning on and after January 1, 2021."
			for ($state_tax_inc) {	 
				$state_cadc_percentage = ($_ <= 30000)  ?   0.5   :
										 ($_ <= 60000)  ?   0.4   :
										 ($_ <= 90000)  ?   0.3   :
										 ($_ <= 120000)  ?  0.2   :
										 ($_ <= $state_cadc_incomelimit)  ?   0.1   :
															0;		
			}
#			if ($out->{'cadc_eligible_child_count'} + $out->{'cadc_dis'} <= 1) { #These variables check for dependent eligible children and dependent disabled adults. (The adult in question here will always be adult 2.)
#				$state_cadc_max_claims = 500;
#			} else { #$out->{'cadc_eligible_child_count'} + $out->{'cadc_dis'} > 1
#				$state_cadc_max_claims = 1000;
#			}
		
			$state_cadc_gross = $state_cadc_percentage * $out->{'cadc_real_recd'}; #newly passed bill A6071 makes this a refundable credit and gets rid of the maximum claim amount.
		}

		$state_cadc_recd = $state_cadc_gross; #This is no longer an above-the-line, nonrefundable credit.Newly passed bill A6071 makes this a refundable credit and gets rid of the maximum claim amount.

		# if ($in->{'cadc_refundable_alt'} == 1) { #these policy options are no longer relevant. 
		# $state_cadc_recd = $state_cadc_gross; #Redefning state CADC here in case of the policy change. In general, where possible, I think we should generate the policy changes in separate blocks than the current policies, so as not to get too bogged down in if-blocks, and to allow these policy changes to be removed more easily. The credit is fully refundable now in NJ: https://www.njpp.org/publications/report/shining-a-light-on-new-jerseys-fy-2022-budget/#_edn4
		# }

		#Policy modeling option for NJ 2021: calculate state ctc 
		if ($in->{'empire_state_ctc_alt'} == 1) { #POLICY MODELING OPTION FOR NJ 2021: the user can choose to model a child tax credit structured like NYS's Empire State CTC, where the CTC is the greater of 33% of the ctc or $100 * qualifying children. and tax filers with qualifying children and incomes under 110,000 for married couples and $75,000 for singles who did not claim the fed child ctc but meet the other eligibility requirements can receive a credit of $100 * # of qualifying children. This interpretation is from the general instructions, not the line-by-line worksheet.
			if ($out->{'filing_status'} eq 'Single' || $out->{'filing_status'} eq 'Head of Household'){
				$ctc_max_income_alt = 75000;	#these are for policy modeling options for NJ 2021. modeled after Empire State Credit https://www.tax.ny.gov/pdf/current_forms/it/it213i.pdf 
			} elsif($out->{'filing_status'} eq 'Married') {
				$ctc_max_income_alt = 110000;
			} 
			
			if ($out->{'ctc_total_recd'} > 0) { #If they filed for and received a federal CTC:
				$state_ctc_recd = greatest(.33 * $out->{'ctc_total_recd'}, 100 * $out->{'ctc_eligible_children_count'});
			} elsif ($out->{'taxable_earnings'} + $out->{'interest'} <= $ctc_max_income_alt && $out->{'child_number'} > 0) { #Special case if you did not claim the CTC but meet requirements allowing older children or other children not eligible for the CTC.
				for (my $i = 1; $i <= 5; $i++)	{
					if ($in->{'child'.$i.'_age'} >= 0) {
						if ($in->{'child'.$i.'_immigration_status'} ne  'undocumented_or_other' || $in->{'itin'} == 1) {
							$state_ctc_recd += 100;
						}
					}
				}
			}
		}
	
		#
		# 5. CALCULATE NJ STATE EITC
		#
		  
		if($in->{'state_eitc'}) {
			if ($in->{'eitc_alt'} == 1) {	#NJ 2021 POLICY MODELING OPTION: Similar to what was displayed for OH 2015, "Change value of State EITC to ____% of federal EITC". Must be greater than current amount, which is 40%
				$state_eitc_pct = $in->{'state_eitc_user_input'}/100;
			}

			if ($out->{'eitc_recd'} == 0 && $out->{'meets_childless_age_min_unit1'} == 0 && $out->{'potential_eitc_no_age_minimum'} > 0 && $out->{'child_number'} == 0 && ($in->{'parent1_age'} >= 18 || $in->{'parent2_age'} >= 18)) { 
				$state_eic_recd = $out->{'potential_eitc_no_age_minimum'} * $state_eitc_pct;
			} else {
				$state_eic_recd = $out->{'eitc_recd'} * $state_eitc_pct;
			}

			#NJ 2021 POLICY MODELING OPTION: expands state EITC eligibility to workers with ITINs (need to calculate federal EITC in order to model the state option).

			if ($in->{'eitc_itin_alt'} == 1) { 
				$state_eic_recd = &greatest($state_eic_recd, $out->{'potential_eitc_itin_and_no_age_minimum'} * $state_eitc_pct);
			}
			
			#Potential additional state EITC expansion: Increasing the income limit for EITC for childless adults. Commening out this next policy option, pending clarification from Brittany and discussion of how this particular EITC expansion is an approximation of the ARPA EITC expansion for filers without dependents. 

			#if ($in->{'eitc_income_threshold_alt'} == 1) { #STATE POLICY MODELING OPTION: Increase the income threshold for workers without qualifying children from $15,570 (this was TY 2019 levels) to $25,000. Need to first calculate what they would have gotten in the federal EITC in order to calculate the state policy modeling option. Need to make sure they get $0 in federal EITC, but obtain the state eitc. 
			#	$eitc_income_limit = ($eitc_family_structure == 1 ? 25000 : 25000); #This would have to be a new EITC potential policy change scenario in the federal code, if we decide on it.
			#}

			#if ($out->{'meets_childless_age_min_nj_alt'} == 1 || ($in->{'eitc_itin_alt'} == 1 && $in->{'itin'} == 1) || $out->{'eitc_income_threshold_fulfilled_nj_alt'} == 1) {	#NJ POLICY MODELING OPTIONS: Reduce the minimum age requirement for workers without qualifying children from 25 to 18 & itin holders as eligible for state eitc && reduce income threshold for filers without qualifying children to $25,000.
			#	$state_eic_recd = $out->{'eitc_recd'} * $state_eitc_pct;
			#	$out->{'eitc_recd'} = 0;		#resets federal eitc_recd to 0 because they would not be eligible for federal eitc, but the output was needed to calculate the state eitc. 
			#}
		}
	}

	#Policy modeling option for NJ 2021: a user-entered tax credit amount
	if ($in->{'tax_credit_alt'} == 1) {
		$additional_state_tax_credits = $in->{'tax_credit_user_input'};
	}
	
	#Incorporate NJ Middle Class Tax Rebate. This is a new nonrefundable income tax credit introduced in 2021 for the 2020 tax year. Consult income tax forms for 2021 when it comes out to confirm calculations.

	if ($in->{'state_mctr'} == 1) {
		if ($in->{'child_number'}-$in->{'undocumented_child_count'}-$in->{'daca_child_count'}> 0) {
			if ((($out->{'filing_status'} eq 'Married' || $out->{'filing_status'} eq 'Head of Household') && $state_gross_inc<= $mctrebate_married_hoh_incomelimit) ||($out->{'filing_status'} eq 'Single' && $state_gross_inc<= $mctrebate_single_incomelimit))  {
				
				$middle_class_tax_rebate = &least(&pos_sub($state_tax_gross, $state_eic_recd + $prop_tax_credit_recd + $state_cadc_recd + $state_ctc_recd + $additional_state_tax_credits), $max_middle_class_rebate);
			}
		} #See N.J. Stat. 54A:9-30 (https://casetext.com/statute/new-jersey-statutes/title-54a-new-jersey-gross-income-tax-act/chapter-54a9-applicability-of-state-tax-uniform-procedure-law/section-54a9-30-eligibility-for-tax-rebate) for guidance on Middle class tax rebate and definition of qualifying child in 26 U.S. Code 152 - Dependent defined https://www.law.cornell.edu/uscode/text/26/152
	}
	
	# Calculate NJ state payroll taxes.
	
	for (my $i = 1; $i <= $in->{'family_structure'}; $i++)	{
		$state_payroll_tax += least($out->{'parent'.$i.'taxable_earnings'}, $ui_base_salary) * ($ui_rate +  $wfswf_rate) + least($out->{'parent'.$i.'taxable_earnings'},$fli_base_salary) * ($fli_rate + $di_rate); 
		#LOOK AT ME: parent#_taxable_earnings includes fli+tdi when defined in fedtax. However, fli and tdi are not taxed at the state level. once we program in UI, we need to make sure to parse it out by parent# subtract it from parent#_taxable_earnings.
		#We decided that undocumented folks without an itin don't pay payroll taxes. We're essentially adopting a "do no felony" stance on this, since in order to pay payroll taxes, a person will need to fake having a social security number, which is identity fraud. #parents#_earnings_taxes = taxable earnings. this is 0 if the parent is undocumented and doesn't have an ITIN.
	}
	
	#Note about local taxes: there are currently no local income or payroll taxes payable by employees in New Jersey. Newark has a 1% payroll tax payable by employers, https://ecode360.com/36680253, but "No employer shall deduct or withhold any amount from the remuneration payable to an employee because of the tax imposed by this chapter." - §10:21-5(c). According to taxfoundation.com, this is the only payroll tax in the state: https://taxfoundation.org/local-income-taxes-2019/. Also see https://taxnews.ey.com/news/2021-0406-new-jersey-court-says-changes-are-needed-to-local-payroll-taxes-to-prevent-double-taxation, which reports of a lawsuit against the attempt by another NJ locality (Jersey City) from imposing a similar tax (also not payable by employees).
	
	#There does not appear to be any local income taxes in NJ, nor local sales taxes beyond a few exceptions (Cape May and Atlantic City), the additional sales taxes for which are specific to certain items beyond the scope of the FRS tool to separately calcuate.
		
	#Incorporate state payroll taxes and calculate tax before credits and tax after credits
	
	$state_tax_credits = $state_eic_recd + $prop_tax_credit_recd + $state_cadc_recd + $state_ctc_recd + $additional_state_tax_credits + $middle_class_tax_rebate;
	
	$state_tax = &pos_sub($state_tax_gross, $state_tax_credits) + $state_payroll_tax;
	
	$tax_before_credits = $out->{'federal_tax_gross'} + $state_tax_gross  + $state_payroll_tax;
	
	$tax_after_credits = $tax_before_credits - $out->{'federal_tax_credits'} - $state_tax_credits;
	
	
	# outputs
	foreach my $name (qw(state_tax state_eic_recd prop_tax_credit_recd state_cadc_recd state_tax_gross state_tax_credits tax_before_credits tax_after_credits eitc_recd)) { #added recalculated federal eitc here. 
		$out->{$name} = ${$name} || '';
		$self->saveDebugValues("statetax", $name, ${$name});
	}

	foreach my $variable (qw(state_gross_inc couple_min single_min exemption child_exempt_amt single_exempt_amt  couple_exempt_amt  health_ded state_gross_inc state_tax_inc adj_state_tax_inc  rent_prop_tax rent_pt_pct tax_diff prop_tax_ded prop_tax_credit_recd state_eitc_pct net_income state_tax_rate adj_state_tax_rate less_amt adj_less_amt state_payroll_tax middle_class_tax_rebate additional_state_tax_credits)) {
		$self->saveDebugValues("statetax", $variable, $$variable, 1);
	}

	return(0);

}

1;