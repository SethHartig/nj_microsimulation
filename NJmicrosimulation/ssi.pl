#=============================================================================#
#  SSI (Supplemental Security Income) Module – 2021(based off 2020) 
#=============================================================================#
#
# Inputs referenced in this module:
#
# FROM BASE
# SSI                 # This flag, to be entered in the “public benefits” input checklist, was new for 2017. 
# savings
# vehicle1_value 
# vehicle1_owed
# vehicle2_value 
# vehicle2_owed 
# savings
# family_structure
# disability_parent1
# disability_parent2
# disability_work_expenses_m     # This is also a new user-entered input. 
# child_number
# covid_ui_disregard	#policy modeling option. SSA did not count any unemployment compensation for SSI eligibility/benefits determiniation between 3/2020 - 9/2021. If this policy option is selected, we assume that all UI in 2021 was received during this period of disregarded UI. 
#
# FROM INTEREST
# interest_m
#
# FROM PARENT EARNINGS
# earnings_mnth 
# parent1_earnings
# parent2_earnings
# gift_income_m
#
# FROM SSP (new module for 2019)
# ssp_couple 
# ssp_individual
#
# FROM FLI_TDI
# fli_plus_tdi_recd
#
# FROM UI
# ui_recd
#=============================================================================#

sub ssi
{
	my $self = shift;
	my $in = $self->{'in'};
	my $out = $self->{'out'};

	# outputs created in macro:
	our $fbr_couple = 1191; 		# monthly max SSI benefit for couple
	our $fbr_individual = 794;		# monthly max SSI benefit for individual
	our $ssi_couple_asset_limit = 3000;	# SSI asset limit for couples
	our $ssi_indiv_asset_limit = 2000;	# SSI asset limit for individuals
	our $applicable_asset_limit = 0;		# The asset limit applicable to the family
	our $ssi_assets = 0;			# SSI asset calculation
	our $ssi_income = 0;			# Countable income according to SSI rules
	our $ssi_recd_mnth = 0;		# monthly SSI payment
	our $ssi_recd = 0;			# yearly SSI payment
	our $parent1ssi_recd = 0;
	our $parent2ssi_recd = 0;
	our $deemed_child_allocation	 = 0;	# Income deemed to children (excluded from SSI income)
	our $eligible_parent_earnings = 0;	# Delineates disabled parent earnings from non-disabled  parent earnings.
	our $ineligible_parent_earnings = 0; 	# Delineates non-disabled parent earnings from disabled  parent earnings.
	our $ineligible_parent_unearned_income = 0;	# Separates non-disabled parent’s unearned income  	# based on SSI eligibility formula.
	our $ineligible_parent_earned_income = 0;	# Separates non-disabled parent’s earned income  # based on SSI eligibility formula.


	#Added intermediary variables for child SSI:
	our $number_disabled_children = 0;
	our $number_nondisabled_children = 0;
	our $asset_limit_child = 0;
	our $deemable_parents_ssi = 0;
	our $parent1_ssi  = 0;
	our $parent2_ssi  = 0;
	our $parent1_tanf  = 0;
	our $parent2_tanf  = 0;
	our $num_parents_ssi = 0;
	our $deemed_income = 0;
	our $ssi_deemed_remainder = 0;
	our $monthly_countable_unearned_income = 0;
	our $monthly_countable_earned_income = 0;
	our $demable_unearned_income = 0;
	our $nondisabled_child_allocation = 397;
	our $allocation_remainder = 0;
	our $number_nondisabled_children = 0;
	our $demable_earned_income = 0;
	our $deemed_unearned_income	= 0;
	our $deemed_disregard_remainder = 0;
	our $deemed_earned_income = 0;
	our $parental_allocation = qw(791 1191) [$in->{'family_structure'}];
	our $fbr_difference = 0;
	our $deemed_income_perchild = 0;
	our $child_ssi_recd = 0;
	our $child1_ssi_recd = 0;
	our $child2_ssi_recd = 0;
	our $child3_ssi_recd = 0;
	our $child4_ssi_recd = 0;
	our $child5_ssi_recd = 0;
	our $ssi_recd_count = 0; #The total number of SSI recipients in the household. Helpful for the fed_hlth_insurance and tanf codes.
	our $qualifying_disability_parent1 = 0; #These "qualifying" variable flags equal disabilty flags unless a household member is disqualified from receiving SSI due to their immigration status.
	our $qualifying_disability_parent2 = 0;
	our $qualifying_disability_child1 = 0;
	our $qualifying_disability_child2 = 0;
	our $qualifying_disability_child3 = 0;
	our $qualifying_disability_child4 = 0;
	our $qualifying_disability_child5 = 0;
	our $ssi_ineligible_parent_id = 0;
	our $ssi_eligible_parent_id = 0;
	our $gross_ineligible_parent_unearned_income_m = 0;
	our $eligible_parent_unearned_income_m = 0;
	our $ssi_unearned_income = 0;
	our $ssi_earned_income = 0;
	
	# variables used in this script 
	our $interest_m = $out->{'interest_m'};
	our $parent1_earnings = $out->{'parent1_earnings'};
	our $parent2_earnings = $out->{'parent2_earnings'}; 
	our $earnings_mnth = $out->{'earnings_mnth'};

	our $debugssi = 0;
	$debugssi = 1 - $in->{'covid_ui_disregard'};

	if ($in->{'ssi'} == 0 && $in->{'hlth'} == 0 ) {
		#We are invoking the hlth flag here because we can use the deeming formula below to determine eligibiltiy for Mediciad While Working programs in some states (at least in NJ), that apply the same deeming formulas in cases of a family with one SSI-ineligible spouse and one SSI-eligible spouse.
		$ssi_recd_mnth  = 0;
	} else {
		#Undocumented immigrants, DACA recipients, and other immigrant groups such as Legal Permanent Residents for under 5 years cannot receive SSI. 

		for(my $i=1; $i<=2; $i++) {
			if($in->{'parent'.$i.'_age'} >= 18) {
				if ($in->{'disability_parent'.$i}== 1 && $in->{'parent'.$i.'_unqualified'} == 0) {
					${'qualifying_disability_parent'.$i} = 1;
				}
			}
		}

		for(my $i=1; $i<=5; $i++) {
			if($in->{'child'.$i.'_age'} > -1) {
				if ($in->{'disability_child'.$i}== 1 && $in->{'child'.$i.'_unqualified'} == 0) {
					${'qualifying_disability_child'.$i} = 1;
				}
			}
		}

		if ($qualifying_disability_parent1 == 0 && $qualifying_disability_parent2 == 0) {
			$ssi_recd_mnth  = 0;
			$ssi_recd = 0;
		
		} else {
			# For parents, from https://www.ssa.gov/OP_Home/ssact/title16b/1600.htm, https://www.ssa.gov/ssi/text-understanding-ssi.htm.  

			# Resource and disability test
			# One vehicle is excluded regardless of value if used for transportation for you or member of your household. The below formula would therefore only count the lowest value vehicle in the asset calculation.

			# One vehicle is excluded. According to https://secure.ssa.gov/poms.nsf/lnx/0501130200, exclude vehicles such that the exclusion is most advantageous to the recipient. These instructions also indicate that vehicle equity (not current market value) is used for this determination. 
			$ssi_assets = ($in->{'savings'} + &least(($in->{'vehicle1_value'} - $in->{'vehicle1_owed'}), ($in->{'vehicle2_value'} - $in->{'vehicle2_owed'}))); 
			
			if ($in->{'family_structure'} == 1) {	
				# These limits have remained unchanged since 1989.
				# single-parent unit
				$applicable_asset_limit = $ssi_indiv_asset_limit;
			} else {
				# two-parent unit (All resources from a family unit are deemed resources, regardless of whether they can be attributed to an individual eligible or ineligible for SSI.)
				$applicable_asset_limit = $ssi_couple_asset_limit;
			} 

			
			# Determination based on income (from https://www.ssa.gov/ssi/text-income-ussi.htm) :
			#
			# First $20 received in each month “of most income received in a month” is a disregard. Another $65 is also deducted from earnings, and half that is also deducted. Additional expenses needed for a disabled adult to get to work (Impairment-Related Work Expenses) can also be deducted.  The below series of pos_sub commands allows $20 to be deducted first from unearned income and then, if $20 exceeds unearned income, the remainder to be applied to earned income. $65 of earned income is excluded before an exclusion of half of that remainder is applied.
			
			#"The first $20 of unearned income in a month other than income in the form of in-kind support and maintenance received in the household of another and income based on need;" is excluded from unearned income. "Any portion of the monthly $20 exclusion that we did not exclude from unearned income;" is excluded from earned income. See https://www.ssa.gov/oact/ssir/SSI21/V_B_Exclusions.html#39817. 
			
			# Scenario 1: single disabled parent, no spouse, and a qualified alien or citizen:

			if ($in->{'family_structure'} == 1) { 
				#We use Covid_ui_disregard as a dummy variable here; it will lead to counting fli, tdi, and ui if off, but not counting them if on.
				$ssi_income = &pos_sub(((&pos_sub($interest_m + (1 - $in->{'covid_ui_disregard'}) * ($out->{'fli_plus_tdi_recd'}/12 + $out->{'ui_recd'}/12) + $out->{'gift_income_m'}, 20)) + (.5 * (&pos_sub($earnings_mnth, (65 + &pos_sub(20, $interest_m + (1 - $in->{'covid_ui_disregard'}) * ($out->{'fli_plus_tdi_recd'}/12 + $out->{'ui_recd'}/12) + $out->{'gift_income_m'})))))), ($in->{'disability_work_expenses_m'}));

				#SSI income is helpful in determining eligibiltiy for Medicaid While Working, which in at least some states (like NJ), appear to be based on SSI-determined income.
				
				#We use average FLI, TDI, and UI receipt over the course of a year, even though in most cases, each of these three benefits will span much less than a year. Breaking down these payments by month and then aggregrating them over the course of 12 months is a later task in the FRS development, and we are simplifying for now. When we get there, the other invocations of these variables also need to be corrected.
				
				#Here we assume any gift income is countable however, "Any portion of a grant, scholarship, fellowship, or gift to an individual used for paying tuition, fees, or other necessary educational expenses" is excluded from unearned income. https://www.ssa.gov/oact/ssir/SSI21/V_B_Exclusions.html#39817
				
				if ($in->{'ssi'} && $ssi_assets <= $applicable_asset_limit) {
					$ssi_recd_mnth = &pos_sub($fbr_individual + $out->{'ssp_individual'}, $ssi_income);

					#Incorporating any state supplement payments that increase the amount of SSI received by the entire household. Outputs used here as inputs are generated in state SSP codes. New Jersey is an example of a state with this program; some SSI recipients can get a supplement added to their SSI check to help pay for the cost of utilities. It appears implicit in this policy that only adults would receive this benefit, as it is directed at individuals who pay utility bills.					
					if ($ssi_recd_mnth > 0) {
						$ssi_recd_mnth += $out->{'ssp_household'};
					}
					
					#Final parental SSI amounts:
					$parent1ssi_recd = $ssi_recd_mnth * 12;
				}
			} elsif ($qualifying_disability_parent1 == 1 && $qualifying_disability_parent2 == 1) {
				# Scenario 2: two disabled parents, both qualified aliens or citizens
			
				$ssi_income = &pos_sub(((&pos_sub($interest_m + $out->{'fli_plus_tdi_recd'}/12 + $out->{'ui_recd'}/12 + $out->{'gift_income_m'}, 20)) + (.5 * (&pos_sub($earnings_mnth, (65 + &pos_sub(20, $interest_m + (1 - $in->{'covid_ui_disregard'}) * ($out->{'fli_plus_tdi_recd'}/12 + $out->{'ui_recd'}/12) + $out->{'gift_income_m'})))))), ($in->{'disability_work_expenses_m'}));
				
				if ($in->{'ssi'} && $ssi_assets <= $applicable_asset_limit) {
					$ssi_recd_mnth = &pos_sub($fbr_couple + $out->{'ssp_couple'}, $ssi_income);

					#Incorporating any state supplement payments that increase the amount of SSI received by the entire household:
					if ($ssi_recd_mnth > 0) {
						$ssi_recd_mnth += $out->{'ssp_household'};
					}
					
					$parent1ssi_recd = $ssi_recd_mnth * 12 / 2;
					$parent2ssi_recd = $ssi_recd_mnth * 12 / 2;
				}
				
			} elsif ($in->{'family_structure'} == 2) {
				# Scenario 3: One parent is disabled, the other is not, and/or one is a qualified alien/citizen and the other is not.
				
				# We now follow the steps for deeming income from an ineligible spouse. From https://secure.ssa.gov/poms.nsf/lnx/0501320400, it appears that child support is not included as income to the ineligible child for the purposes of reducing the ineligible child allocation. There does not seem to be any deeming calculated for the income of single eligible parents – or income of children – toward ineligible children. https://www.ssa.gov/policy/docs/issuepapers/ip2003-01.html, https://www.ssa.gov/OP_Home/ssact/title16b/1600.htm, and http://www.worksupport.com/documents/parentChildDeemFeb08.pdf are also helpful.
				$deemed_child_allocation = $in->{'child_number'} * ($fbr_couple - $fbr_individual); 
					
				# I think we can assume that families who have people with disabilities transfer all interest-generating accounts to the non-disabled individual, in order to maximize their SSI receipt. Therefore, all interest will be considered unearned income for any non-disabled parents. We need to make a note of this in our list of assumptions.
				
				#Beginning in 2021, we can no longer make the above assumption since we are now including unearned income tied to certain adults in the family, specicically UI, FLI, and TDI, and gift income, and eventually SSDI. So, we needed to un-simplify this code. We can still trnsfer interest income to the non-qualifying adult, but will need to go into the policies to figure out how unearned income of the qualifying parent plays into the formulas below. 
				#LOOK AT ME RE GIFT INCOME: it seems that we would need to collect information gift_income_m by each individual - instead of having a catch-all hosuehold variable to figure out deeming below. For now, we have split the gift income in half.
				
				#"Spouse-to-spouse deeming generally results in approximately the same amount of income available to the couple that would be available if both members of the couple were aged, blind, or disabled and eligible for SSI." - https://www.ssa.gov/oact/ssir/SSI21/III_ProgramDescription.html#96840 

				# In order to make this work, and to generalize this so that we can use efficient code to describe two different situations (one where parent1 is disabled but not parent2, and the other where parent2 is disabled but not parent1), we can use the following shortcut:

				if ($qualifying_disability_parent1 == 1 ) {
					$eligible_parent_earnings = $parent1_earnings/12;
					$ineligible_parent_earnings = $parent2_earnings/12;
					$ssi_ineligible_parent_id = 2;
					$ssi_eligible_parent_id = 1;
				} else {
					$eligible_parent_earnings = $parent2_earnings/12;
					$ineligible_parent_earnings = $parent1_earnings/12;
					$ssi_ineligible_parent_id = 1;
					$ssi_eligible_parent_id = 2;
				} 

				# The child allocation is subtracted from the ineligible’s parent’s unearned income, and any remainder is applied to their earned income.

				$gross_ineligible_parent_unearned_income_m = $interest_m + (1- $in->{'covid_ui_disregard'}) * ($out->{'parent'.$ssi_ineligible_parent_id.'_fli_recd'}/12 + $out->{'parent'.$ssi_ineligible_parent_id.'_tdi_recd'}/12 + $out->{'parent'.$ssi_ineligible_parent_id.'_ui_recd'}/12) + $out->{'gift_income_m'}/$in->{'family_structure'};

				$ineligible_parent_unearned_income = &pos_sub($gross_ineligible_parent_unearned_income_m, $deemed_child_allocation);

				if ($deemed_child_allocation > $gross_ineligible_parent_unearned_income_m) {
					$ineligible_parent_earned_income = &pos_sub($ineligible_parent_earnings, ($deemed_child_allocation - $gross_ineligible_parent_unearned_income_m));
				
				} else {
					$ineligible_parent_earned_income = $ineligible_parent_earnings;
				}
				
				# When the remaining income is lower than the difference between the FBR for a couple and the FBR for an individual, there is no income to deem from the ineligible spouse to the eligible individual, and only the eligible individual’s income is considered for SSI eligibility and receipt (assuming each parent’s incomes are consistent across all months in a year). We are still considering all interest will be held by the ineligible parent, so we need to re-calculate the eligible parent's unearned income.

				$eligible_parent_unearned_income_m = (1- $in->{'covid_ui_disregard'}) * ($out->{'parent'.$ssi_eligible_parent_id.'_fli_recd'}/12 + $out->{'parent'.$ssi_eligible_parent_id.'_tdi_recd'}/12 + $out->{'parent'.$ssi_eligible_parent_id.'_ui_recd'}/12) + $out->{'gift_income_m'}/$in->{'family_structure'};

				if (($ineligible_parent_unearned_income + $ineligible_parent_earned_income) <=  ($fbr_couple - $fbr_individual)) { 
				
					$ssi_income = &pos_sub((&pos_sub($eligible_parent_unearned_income_m, 20) + (.5 * (&pos_sub($earnings_mnth, (65 + &pos_sub(20,$eligible_parent_unearned_income_m)))))), $in->{'disability_work_expenses_m'});
					#We can use the above deemed income calculationin the hlth code, for various Medicaid determinations.
					$ssi_unearned_income = &pos_sub($eligible_parent_unearned_income_m, 20);
					$ssi_earned_income = pos_sub(.5 * &pos_sub($earnings_mnth, 65 + &pos_sub(20,$eligible_parent_unearned_income_m)),$in->{'disability_work_expenses_m'});
					
					if ($in->{'ssi'} == 1 && $ssi_assets <= $applicable_asset_limit) {
						$ssi_recd_mnth = &pos_sub($fbr_individual + $out->{'ssp_individual_in_couple'}, $ssi_income); 
					}
					
				} else {
					# Deeming applies when remaining income is higher than the difference between the FBR for a couple and the FBR for an individual. They are treated as an eligible couple, but with the ineligible parent’s income lowered based on the deeming above.

					$ssi_income = &pos_sub(&pos_sub($ineligible_parent_unearned_income +$eligible_parent_unearned_income_m, 20) + .5 * &pos_sub($ineligible_parent_earned_income + $eligible_parent_earnings, 65) + &pos_sub(20, $ineligible_parent_unearned_income + $eligible_parent_unearned_income_m), $in->{'disability_work_expenses_m'});

					if ($in->{'ssi'} == 1 && $ssi_assets <= $applicable_asset_limit) {
						$ssi_recd_mnth = &pos_sub($fbr_couple + $out->{'ssp_couple'}, $ssi_income); #Adding SSP variable here is new for 2019. The SSP policy for PA works this way, but it may be more complicated for other states.
						$ssi_deemed_remainder = &pos_sub($ssi_income, $fbr_couple + $out->{'ssp_couple'}); #The leftover amount of deemable income is 	important for  child SSI calculations, below.
					}
					

					# Note: “The SSI benefit under these deeming rules cannot be higher than it would be if deeming did not apply,” but for the variables we are considering, this would never happen. It could happen if earnings are inconsistent between months. 	
				}	
				#Incorporating any state supplement payments that increase the amount of SSI received by the entire household:
				if ($ssi_recd_mnth > 0) {
					$ssi_recd_mnth += $out->{'ssp_household'};
				}
				
				if ($qualifying_disability_parent1 == 1 ) {
					$parent1ssi_recd = $ssi_recd_mnth * 12;
				} else {
					$parent2ssi_recd = $ssi_recd_mnth * 12;
				}
			}			
		}



		#Tallying SSI receipt, helpful for Medicaid and TANF calculations.
		for(my $i=1; $i<=2; $i++) {
			if ($in->{'parent'.$i.'_age'} > 17) {
				if (${'parent'.$i.'ssi_recd'} > 0) {
					${'parent'.$i.'_ssi'} = 1;
					$ssi_recd_count += 1;
				}
			}
		}

		#Child SSI (New for 2021):
		
		$asset_limit_child = $ssi_indiv_asset_limit; #This is $2,000; we treat child asset limits like they are unmarried individuals.
		

		for(my $i=1; $i<=5; $i++) {
			if ($in->{'child'.$i.'_age'} > -1) {
				if (${'qualifying_disability_child'.$i} == 1) { 
					$number_disabled_children += 1;
				} else {
					$number_nondisabled_children += 1;
				}
			}
		}
		
		$num_parents_ssi = $parent1_ssi + $parent2_ssi;
		
		if ($number_disabled_children > 0) {			
						
		
				#Deem assets for determining child eligibility
				
				#Based on SSI rules, “[i]f a child under age 18 lives with one parent, $2,000 of the parent's total countable resources does not count. If the child lives with 2 parents, $3,000 does not count. We count amounts over the parents’ limits as part of the child's $2,000 resource limit.” Only income and assets of parents residing with the child are counted, and only the resources of parents who are not receiving SSI themselves are counted. It is possible that the parents of the child in the household may not be married, so total countable assets need to be recalculated.

				#It is important to note here that it appears that in the case of two unmarried parents of a child potentially eligible for disability, the asset calculation for any of those parents in determining their own potential SSI eligibility will be different than the asset calculation for their children. That is because if a couple is unmarried, their assets are counted separately, but counted together in the case of a child they have together. So, we cannot use the total countable assets calculated for unmarried parents if we have also previously totaled assets in determining the eligibility of at least one of the parents; we need to calculate it again.

				#We are assuming here that children do not have assets like bank accounts that could impact their eligibility. This simplifies matters; otherwise each child would need to be assessed separately (iteratively, starting with the child with the highest amount of assets) to assess whether they are eligible for SSI. 

				#The below code assumes that the parent of a child is person 1 as imputed by the user, and that the second parent, if in the household, is person 2. E.g. parent1_ssi will correspond to adult1_ssi. A more advanced translation of these policies could search all household members for imputed parental and relationship information, and reassign these in a loop as parent_1 and parent_2. parents of the child need to be assigned parental identification numbers, translating the “..._[x]” input variables. E.g. 


				#Count number of SSI-eligible parents of eligible child and factor in allocations

				#If parents are eligible for and receiving SSI themselves, then none of their income is deemed to the children. For each parent of the child, we test whether they receive SSI or whether their income is counted. At first, for allocations, we include both earned and unearned income.

				#We have already calculated parental income in cases when one of the parents may also be eligible for SSI. For children potentially eligible for SSI, the remaining case we consider here is when no parent in the family -- or more specifically, no parent of any child who may also be on SSI -- also has a disability eligible for SSI. The income of parent(s) receiving Public Income Maintenance payment (PIM), such as TANF is not deemed income for the child., 

				for(my $i=1; $i<=2; $i++) {
					if ($in->{'parent'.$i.'_age'} > 17) {
						if ($out->{'tanf_recd'} + $out->{'tanf_recd_proxy'} > 0 && $in->{'tanf'} == 1) {
							#Here we use the proxy variable that assigns a value of $1 to TANF receipt to all parents at outset. This will exclude their earnings from the below calculation, temporarily maximizing SSI receipt in advance of calculating TANF later on. The TANF code will output an actual value of tanf_recd and set the tanf_recd_proxy to 0. When this code is run again, it will either remove children from SSI receipt, thereby resulting in a correct TANF calculation when TANF is run again, or maintain children's eligibiltiy for SSI. These correct calculations will inform the next runs of TANF, which will in turn output correct (potentialy adjsuted) results. We're trying this out, but may need to return to it -- need to diagream the various possibilities and write it all down.
							
							#Note: if we end up including TANF sanctions, we'll need to adjust this code to personalize TANF receipt by parent. (E.g. "$tanf_recd_parent1". LOOK AT ME FOR STATES OTHER THAN NJ 2021: This is fine for NJ, but may need to adjust this logic for states where sanctions can be assigned to different household members. 
							${'parent'.$i.'_tanf'} = 1;
						}
					}
				}
		
				$deemable_parents_ssi = $in->{'family_structure'} - greatest(0, $parent1_ssi, $parent1_tanf) - greatest(0, $parent2_ssi, $parent2_tanf);



				if ($deemable_parents_ssi == 0 || $num_parents_ssi > 0) {	
					#In this case, either all parental income is excluded because either (a) all parent(s) receive either SSI or TANF, or (b) at least one of two parents have a disability and at least one of them receives SSI, meaning that all parental income is not considered deemable. In the case of both parents receiving SSI, neither of their incomes are passed on to the child. In the case of one parent being receiving SSI and the other not, the ineligible parent has already deemed any income of theirs in the calculation of the SSI recipient’s SSI benefits, reducing any of their SSI already as a result. There is no remaining income deemable to the child.

					$deemed_income = 0;
				
				} elsif ($in->{'family_structure'} == 2 && $qualifying_disability_parent1 + $qualifying_disability_parent2 == 1 && $num_parents_ssi == 0) { # && married = true
				
				#In this case, one parent in a married couple has a disability that makes them potentially eligible for SSI, but another parent does not have a disability and therefore their income is deemed to the potentially eligible parent. When that deemed income is high enough to make the potentially eligible parent ineligible based on income, the remainder of that income is determined deemable to the disabled child(ren).

					$deemed_income = $ssi_deemed_remainder;

				} else { 
		
					#The below calculation occurs when no parent in the household of the child receives SSI. It’s the same calculation for a one-parent family if that parent has a disability that potentially makes them also eligible for SSI; if they have a disability but have too much income themselves to qualify for SSI, then they are not eligible for SSI and therefore their income is treated the same way in reference to their children as if they did not have a disability.

					$monthly_countable_unearned_income = $out->{'interest_m'} + (1- $in->{'covid_ui_disregard'}) * ($out->{'fli_plus_tdi_recd'}/12 + $out->{'ui_recd'}/12) + $in->{'gift_income_m'};

					for(my $i=1; $i<=5; $i++) { 
						if ($in->{'child'.$i.'support'}==1) {
							$monthly_countable_unearned_income += ($out->{'child_support_recd_m'}/$out->{'cs_child_number'})*(2/3); #Need to add SSDI and any additional unearned income once we have SSDI. "One third of support payments made by an absent parent if the recipient is a child" is excluded from unearned income https://www.ssa.gov/oact/ssir/SSI21/V_B_Exclusions.html#39817)
						}
					}
					if ($parent1_ssi == 0 && $parent1_tanf == 0) {
						$monthly_countable_earned_income += $out->{'parent1_earnings_m'};
					}

					if ($parent2_ssi == 0 && $parent2_tanf == 0) {
						$monthly_countable_earned_income += $out->{'parent2_earnings_m'};
					}
					
					#The below step-by-step process is described at  https://secure.ssa.gov/poms.nsf/lnx/0501320500. 

					$demable_unearned_income = pos_sub($monthly_countable_unearned_income, $nondisabled_child_allocation * $number_nondisabled_children);

					$allocation_remainder = pos_sub($nondisabled_child_allocation * $number_nondisabled_children, $monthly_countable_unearned_income);

					$demable_earned_income = pos_sub($monthly_countable_earned_income, $allocation_remainder);

					$deemed_unearned_income = pos_sub($demable_unearned_income, 20); #We may want to add a policy variable indicating 20 is the value of the income disregard, and create a variable based on that. But this is clearer for now.

					$deemed_disregard_remainder = pos_sub(20, $demable_unearned_income);

					$deemed_earned_income = (1 - .5) * pos_sub($demable_earned_income, $deemed_disregard_remainder + 65);

					$deemed_income = pos_sub($deemed_unearned_income + $deemed_earned_income, $parental_allocation);
				}

				#Deem income to disabled children.
				#Divide the parental income by the number of children with disabilities. 

				$deemed_income_perchild = $deemed_income / $number_disabled_children;

				#The amount deemed is considered unearned income to the disabled child.

				#Calculate SSI benefit for each disabled child in the home 
				
				#Parental allocations are considered unearned income to the child

				$fbr_difference = $fbr_couple - $fbr_individual;
				
				for(my $i=1; $i<=5; $i++) {
					
					if ($in->{'child'.$i.'_age'} > -1 && ${'qualifying_disability_child'.$i} == 1 && $in->{'ssi'} && pos_sub($ssi_assets, $applicable_asset_limit) / $number_disabled_children < $asset_limit_child) { 

						#Deemed income, considered a child’s unearned income, is reduced by the income disregard (applicable only to unearned income), and the resulting total is subtracted from the difference between the married FBR and the unmarried FBR. The amount left over is the amount of SSI a child receives.

						${'child'.$i.'_ssi_recd'} = pos_sub($fbr_difference, pos_sub($deemed_income_perchild,20)); #QUESTION FOR SETH - it seems like we're applying the $20 unearned disregard twice - should this be removed since $deemed_income_perchild has already incorporated the $20 disregard? ANSWER: No, I think this is rigth. The first invocation of the income disregard seems to be for parents to disregard money they receive, while this one is specific to income the child receives.
						$child_ssi_recd += ${'child'.$i.'_ssi_recd'};
						$ssi_recd_mnth += ${'child'.$i.'_ssi_recd'};
						$ssi_recd_count += 1;
					}
				}
			
				#We add this to the total ssi_recd_mnth, which may be 0 or positive depending on whether any adults in the household receive SSI.

		} 
	}
	
	#Finally, we multiply the monthly total to get the annual amount:
	$ssi_recd = 12 * $ssi_recd_mnth;
	
	# outputs
	foreach my $name (qw(ssi_recd ssi_recd_mnth parent1ssi_recd parent2ssi_recd ssi_recd_count num_parents_ssi parent1_ssi parent2_ssi child_ssi_recd child1_ssi_recd child2_ssi_recd child3_ssi_recd child4_ssi_recd child5_ssi_recd ssi_income ssi_unearned_income ssi_earned_income deemed_income_perchild)) { #added outputs useful to tanf and ccdf here.
		$out->{$name} = ${$name};
		$self->saveDebugValues("ssi", $name, ${$name});
	}
	
	#debugs
	foreach my $variable (qw(ssi_assets ssi_income applicable_asset_limit deemed_child_allocation eligible_parent_earnings ineligible_parent_earnings ineligible_parent_unearned_income ineligible_parent_earned_income ssi_assets number_disabled_children asset_limit_child qualifying_disability_parent1 qualifying_disability_parent2 qualifying_disability_child1 qualifying_disability_child2 qualifying_disability_child3 qualifying_disability_child4 qualifying_disability_child5 debugssi)) { 
		$self->saveDebugValues("ssi", $variable, $$variable, 1);
	}

	return(0);
}

1;
