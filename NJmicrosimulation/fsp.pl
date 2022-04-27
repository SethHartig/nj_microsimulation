# 2/13/20 note: This SNAP module now fully accounts for ABAWDs.
#===========================================================================#
#  Food Stamps Module – 2020 (modified from 2017)
#=============================================================================#
#
# Inputs referenced in this module:
#
#   FROM BASE
#     Inputs:
#       fsp
#       family_size
#       family_structure
#       number_children
#       child#_age
#       savings
#       vehicle#_owed
#       state_eitc
#       state
#       year
#       residence
#		exclude_abawd_provision
#		snap_training
#		heat_in_rent
#		parent#_unqualified
#		unqualified_immigrant_adult_count
#		spousal_support_ncp
#
#     Outputs:
#       earnings_mnth
#       earnings
#
#   FROM INTEREST
#       interest_m
#
#   FROM TANF
#       tanf_recd_m
#       child_support_recd_m
#
#   FROM CHILD CARE
#       child_care_expenses_m
#
#   FROM FOOD STAMP ASSETS
#       fs_vehicle#
#       bbce_gross_income_pct
#       bbce_no_asset_limit
#       bbce_asset_limit
#		bbce_no_netincome_limit
#       heatandeat_nominal_payment
#		ineligible_immigrant_prorata_grossincome
#		ineligible_immigrant_prorata_netincome		
#		sua_heat
#		sua_phoneandinternet_only
#		sua_utilities_only
#		optional_sua_policy
#		snap_state_immigrant_option
#		snap_foster_child_option
#
#   FROM EITC
#       eitc_recd
#
#	FROM HEALTH
# 		parent#_health_expenses
#		
#
#	FROM FLI/TDI
#		parent#_fli_recd
#		parent#_tdi_recd
#	
#	FROM SSI
#		child_ssi_recd
#		ssi_recd_mnth
#		parent#_ssi_recd
#
#	FROM FOSTERCARE
#		foster_children_count
#		foster_child_payment_m
#=============================================================================#

#use Switch; #Commenting this out but also think it can probably be commented out in the online FRS. We've simplified this to the extent that Switch functions are likely no longer needed.

sub fsp {
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};


    # outputs created
    our $fsp_recd = 0;          # annual value of food stamps received
    our $fsp_recd_m = 0;        # monthly value of food stamps received
    our $fs_assets = 0;         # assets counted in calculating total income for food stamps/SNAP eligibility
   	our $liheap_recd = $out->{'liheap_recd'};		#We need to use this variable in this code, and will recalculate its initial value based on whether the state has a heat and eat program that provides nominal payments from LIHEAP or a local utility subsidy program, conferring eligibility to claim the full SUA in SNAP calculations.
	#
    # Additional variables used within the macro:
    # There was a pre-2015 note in here that may or may not be active anymore -- I believe it is inactive based on 2017 being correct and hard-coded, but it will be worth checking if moving these codes to an FRS on the live site: "Values for the following eight variables have been abstracted out of the script and stored in the FoodStamps table according to the fiscal year.  Values will automatically be retrieved based on the month that the Simulator is modeling." Since at least 2015, we have hard-coded these variables based on the latest version of SNAP eligibiltiy criteria and deductions schedules available on the FNS websites and associated COLA memos.

	our @fs_gross_income_limit_array = 	(0,	1396,	1888,	2379,	2871,	3363,	3855,	4347,	4839); #the gross income limits, per household size, up to 8 people.
	our @fs_net_income_limit_array = 	(0,	1074,	1452,	1830, 	2209,	2587,	2965,	3344,	3722); #the net income limits, per household size, up to 8 people.
	our @fs_max_ben_array = 			(0,	250,	459,	658,	835,	992,	1190,	1316,	1504); #the maximum benefit amounts, per household size, up to 8 people.
	our @fs_standard_ded_array = 		(0,	177,	177,	177,	184,	215,	246,	246,	246);  #The SNAP standard deductions, per household size, up to 8 people
	our $gross_income_limit_additional = 492; #amount added to the gross income limit for each additional person in the household above 8 people. Will be important if we expand FRS further to cover larger families.
	our $net_income_limit_additional = 379; #amount added to the net income limit for each additional person in the household above 8 people.
	our $maxben_additional = 188; #amount added to the maximum benefit for each additional person in the household above 8 people.
    
    our $fs_earned_ded_per        = 0.20;    # percent of earned income disregarded
    our $fs_max_shelter_ded       = 586;    # max excess shelter deduction
	our $fs_med_expenses_floor	  = 35;
    our $fs_min_ben               = 16;     # Monthly minimum benefit amount (for 1-2-person housholds)
    our $fs_asset_limit           = 2500;   # Maximum assets a household can have to receive SNAP. Was 2250, changed to 2500 as of October 2021.
    our $fs_asset_limit_disability = 3750;   # Maximum assets a household can have to receive SNAP Was 3500, changed to 3750 as of October 2021.
	our $bbce_gross_income_pct_max = 2;	# The highest ratio of gross income to the federal poverty allowable that BBCE policies allow to be eligible for SNAP. This absolute number is important for determining whether families containing people with disabilities pass the asset test.
    our $heatandeat_min           = 20;     # Minimum LIHEAP benefit needed to be categorically eligible to claim SUA for purposes of SNAP benefits, in households that would not otherwise be eligible for the SUA (which predmominantly includes households that pay their heat in rent).
	our $abawd_workreq			= 80;	#Number or hours in a month that able bodied adults without dependents need to work in order to receive more than 3 months of SNAP benefits. We divide this by 4.33 below to compare adults' weekly work schedule to these requirements.
	our $adult1_excluded = 0;
	our $adult2_excluded = 0;
	our $adults_excluded = 0;
	our $fs_countable_earnings_m = 0;
	our $fs_deemed_earnings_m = 0;
	our $fs_countable_unearned_income_m = 0;
	our $fs_deemed_unearned_income_m = 0;
	our $fs_earned_income_excluded = 0;
	# our $fs_unearned_income_excluded = 0;
	our $excluded_proration_shelter = 0;
    our $fs_gross_income_limit  = 0;    # monthly gross income limit
    our $fs_net_income_limit	= 0;    # monthly net income limit
    our $fs_max_ben				= 0;    # monthly max benefit amount
    our $fs_standard_ded		= 0;    # standard deduction (note: varies by family size beginning FY2003)
    our $fs_gross_income        = 0;    # gross income for food stamps (set to 0 when categorically eligible)
    our $fs_income              = 0;    # gross income for determining deductions and net income
    # (equal to fs_gross_income unless categorically eligible)
    our $minben_flag            = 0;   # flag indicating whether family is categorically eligible for food stamps
    # and has family size of either 1 or 2 and is therefore eligible for a minimum benefit of $16
    our $fs_net_income          = 0;    # adjusted net income for food stamp calculations
    our $fs_shelter_ded_recd    = 0;    # excess shelter deduction
    our $fs_cc_ded_recd         = 0;    # child care deduction
    our $fs_adjusted_income     = 0;    # adjusted income, meaning income inclusive of all deductions except excess shelter deduction 
    our $sua_m                  = 0;    # monthly standard utility allowance used in shelter deduction calculations
    our $fs_perchild_cc_ded     	= 0;    # TODO NIP max per child care deduction
    our $fs_under2_add_cc       	= 0;    # TODO NIP additional per child care deduction for child <2
 	our $energy_cost = 0; 
	# our $excluded_proration_dis = 0; #See note below; no longer needed.
	our $excluded_proration_cc_expenses = 0;
	our $potential_fs_earned_income_excluded = 0;
	our $potential_fs_unearned_income_excluded = 0;
	our $fs_excluded_income_gross = 0;
	our $fs_excluded_income_net = 0;
	
	our $snap_eligible_family_size = 0; # The number of family members who are eligible to receive SNAP. Guidance from NJ SNAP Handbook, NJAC Chapter 10-87. The following individuals residing with a household shall be excluded from the household when determining the household's size for the purposes of assigning a benefit level to the household or of comparing the household's monthly income with the income eligibility standards. However, the income and resources of an excluded household member shall be considered available to the remaining household members in accordance with N.J.A.C. 10:87-7.7. Excluded household members may not participate in the program as separate households.
	
	our $disabled_members_med_expenses = 0;
	our $med_expenses_ded = 0;	#the amount of medical deduction allowed for elderly/disabled family members. 

	#New variables that apply gross income and asset tests, instead of zeroing out gross income and asset tests.
	our $passes_grossincome_test = 0;
	our $passes_asset_test = 0;
	our $categorically_eligible = 0; #Whether the hh qualifies based on categorical eligibilty, but not necessarily BBCE expansions.
	our $bbce_eligible = 0;			 #Whether the hh passes the gross income eligibilty based on BBCE expansions, but not necessarily categorical eligibity.
				
	#debug variables:
	our $exclude_abawd_provision = $in->{'exclude_abawd_provision'};
	our $snap_training = $in->{'snap_training'};
	our $sanctioned = $in->{'sanctioned'};
	our $tanfwork = $in->{'tanfwork'};


	#Determine the eligible family size for SNAP benefis. 

    if($in->{'fsp'} != 1) {
        # if food stamp module not used
        $fsp_recd = 0;
        $fsp_recd_m = 0;
     #   END
    } else {
		$snap_eligible_family_size = $in->{'family_size'}; #Start by counting everybody, then subtract based on exclusionary criteria. Qualified immigrant children are eligible for SNAP without a 5 year waiting period: https://www.fns.usda.gov/snap/eligibility/citizen/non-citizen-policy. 
		if ($out->{'snap_state_immigrant_option'} == 0) {
			$snap_eligible_family_size -= $in->{'daca_child_count'} + $in->{'undocumented_child_count'}; 	
		}
		
		if ($out->{'snap_foster_child_option'} == 0) {	#states may have different regulations on whether foster children count in the family size. In NJ, families can choose whether to include or exclude foster children from snap applications. It is more advantageous to the family to exclude the foster child, so the FRS assumes the family will do that when snap_foster_child_option == 0. 
			$snap_eligible_family_size -= $out->{'foster_children_count'};
		}
		
		for (my $i = 1; $i <= $in->{'family_structure'}; $i++)	{		
			#Check for satisfaction of ABAWD work requirements, along with whether user is modeling the exclusion of ABAWDS who don't satsify work requirements (exclude_abawd_provision) AND is not modeling the availability of training to ABAWDS when they work too few hours to qualify for SNAP work requirements (snap_training). Also check of immigration status leads to adults becoming excluded.
			if (($in->{'child_number'} == 0 && $in->{'exclude_abawd_provision'} == 1 && $in->{'snap_training'} == 0 && $in->{'parent'.$i.'_age'} >= 18 && $in->{'parent'.$i.'_age'} <=49 && $out->{'parent'.$i.'_transhours_w'} < $abawd_workreq/4.33 && $out->{'parent'.$i.'ssi_recd'} == 0) || ($in->{'parent'.$i.'_unqualified'} == 1 && $out->{'snap_state_immigrant_option'} == 0)) {

				# If exclude_abawd_provision = 0, the user is opting to ignore ABAWD requirements, so the following code will not be activated. If exclude_abawd_provision = 1 but snap_training = 1, then the recipient ABAWD will not lose SNAP but will instead opt to attend training to make up the difference in hours. The increased transportation hours that will result from training will be addressed in a repeat of the work code, which will happen sequentially (or repearted) after this SNAP code.

				# If this condition is met, we first need to exclude ABAWDS who are not satisyfing work requirements from the household; the possibility for reducting household size is why we need to check this here, near the top of the code, rather than later. We also also need to check the case of a 2-ABAWD HH in which one ABAWD needs to satisfy work reqs, and another doesn't. In this case, one adult can receive some SNAP benefits while the other can't, and part of the excluded individual's income is "deemed" to the included individual's income for calculating eligibility and receipt. 

				#Note the last condition here (ssi_recd_mnth or disability_parent1), which is similar to the below or-condition for parent2. People who receive SSI for their disability are not bound by SNAP work requirements. If parent1 has a disabiltiy but the family does not receive SSI for it, they are still bound by SNAP work requirements. If the family receives SSI but parent1 has no disability (meaning that parent2 has a disability), parent1 is also bound by work requirements (but parent2 isnt'). This is true even if parent2 may technically be a "dependent" for tax purposes, which is different than the term "dependent" in SNAP.

				${'adult'.$i.'_excluded'} = 1;
				$adults_excluded += 1;

			}			
		}
		$snap_eligible_family_size -= $adults_excluded; 	
		
		#We need to determine the gross income of the excluded individual, in order to prorate the SNAP benefits approprirately. 
		
		for (my $i = 1; $i <= $in->{'family_structure'}; $i++)	{		
			if ($in->{'adult'.$i.'_excluded'} == 1) {
				$potential_fs_earned_income_excluded += $out->{'parent'.$i.'_earnings_m'} - (1- $fs_earned_ded_per) * $out->{'parent'.$i.'_earnings_m'} * $snap_eligible_family_size / $in->{'family_size'}; #This is income deemed to the second adult in the household. Another way to think about deeming is by defining SNAP's gross income with deeming as  $parent2_earnings_m + (1- $fs_earned_ded_per)*$parent1_earnings/2, where 2 is the family size in that instance of a two-abawd household.
				#For unearned income like interest and TANF, we can assume that bank accounts are shared by the household and that these amounts can be split in two. This includes TANF, even though in many states (like NH), families without children cannot get TANF. For simplicity's sake, if translating some of these codes to where states childless households are not eligible for TANF, the TANF variables can be removed from this block referring to ABAWDs. 
				$potential_fs_unearned_income_excluded += (($out->{'interest_m'} + $out->{'child_support_recd_m'}) / $in->{'family_structure'} + $out->{'tanf_recd_m'}  + $out->{'tanf_sanctioned_amt'} +  $out->{'parent'.$i.'_ui_recd'}/12 + $out->{'parent'.$i.'_fli_recd'}/12 + $out->{'parent'.$i.'_tdi_recd'}/12 + $out->{'spousal_support_ncp'}/12) / $in->{'family_size'};

				if ($in->{'parent'.$i.'_unqualified'} == 1) {
					if ($out->{'ineligible_immigrant_prorata_grossincome'} == 1) {
						$fs_excluded_income_gross = $potential_fs_earned_income_excluded + $potential_fs_unearned_income_excluded;
					}
					if ($out->{'ineligible_immigrant_prorata_netincome'} == 1) {
						$fs_earned_income_excluded = $potential_fs_earned_income_excluded;
						$fs_excluded_income_net = $potential_fs_earned_income_excluded + $potential_fs_unearned_income_excluded;
					}
				} else {
					$fs_earned_income_excluded = $potential_fs_earned_income_excluded;
					$fs_excluded_income_gross, $fs_excluded_income_net =  $fs_earned_income_excluded + $potential_fs_unearned_income_excluded;
				}
				$excluded_proration_shelter += 1/$in->{'family_size'}; #This is the portion of the deduction that will need to be subtracted from the shelter deducation for non-excluded household members. We are assuming all adults share in the cost of shelter and child care. See fsp assets for reference to NJ code. 
				$excluded_proration_cc_expenses += 1/$in->{'family_size'};#This is the portion of the deduction that will need to be subtracted from the child care expenses deduction for non-excluded household members.
				
			}
		}
		
		#There's no more need for the below proration percentage calculation of disabled family members, as we are now making the calculation of the medical expense deduction specific to eligible individuals instead of using an aggregate number (which we used to divide among household members with disabilities).
		
		#if ($in->{'disability_parent1'} + $in->{'disability_parent2'} > 0) {
		#	$excluded_proration_dis = ($in->{'disability_parent1'} * $adult1_excluded + $in->{'disability_parent2'} * $adult2_excluded) / ($in->{'disability_parent1'} + $in->{'disability_parent2'});
		#} 
		
		#CALCULATE MEDICAL EXPENSES DEDUCTION FOR ELDERLY AND DISABLED HOUSEHOLD MEMBERS

		#SNAP policy defines disability as the receipt of disability benefits (e.g. SSI and SSDI), not, as previously written in this code, any sort of medical condition. This sets up the potential for a benefit cliff when a family member stops receiving SSI while still eligible for SNAP.
		if ($out->{'ssi_recd'} > 0) { #Can add other disability benefits like SSDI (per https://www.fns.usda.gov/snap/eligibility/elderly-disabled-special-rules#Who%20is%20disabled?), as we add more.
			for (my $i = 1; $i <= $in->{'family_structure'}; $i++) {
				if ($out->{'parent'.$i.'ssi_recd'} == 1 && $in->{'adult'.$i.'_excluded'} == 0) {
					$disabled_members_med_expenses += $out->{'parent'.$i.'_health_expenses'};
				}
			}	
			for(my $i=1; $i<=5; $i++) {
				if ($in->{'child'.$i.'_age'} >= 0) {
					if ($out->{'child'.$i.'_ssi_recd'} > 0 && ($in->{'child'.$i.'_immigration_status'} ne 'undocumented_or_other' || $in->{'child'.$i.'_immigration_status'} ne 'daca')) {
						$disabled_members_med_expenses += $out->{'child'.$i.'_health_expenses'};
					}	
				}
			}			
		}
		$med_expenses_ded = pos_sub($disabled_members_med_expenses, $fs_med_expenses_floor);
		
		if ($snap_eligible_family_size == 0) {
			$fsp_recd = 0;	
			$fsp_recd_m = 0;
		} else {

			# get variables based on family size & fiscal year
			$fs_gross_income_limit =  $fs_gross_income_limit_array[$snap_eligible_family_size]; 
			$fs_net_income_limit =  $fs_net_income_limit_array[$snap_eligible_family_size]; 
			$fs_max_ben =  $fs_max_ben_array[$snap_eligible_family_size]; 
			$fs_standard_ded =  $fs_standard_ded_array[$snap_eligible_family_size];
			
			
			#This covid_fsp_15percent_expansion variable would have been valid if we were trying to model the impact of covid expansions prior to the 2021 permanent expansion of SNAP benefits, but is no longer relevant.
			#if ($in->{'covid_fsp_15percent_expansion'} == 1) {
			#	$fs_max_ben = $fs_max_ben * 1.15;
			#}
			
			# 1. Categorical Eligibility Test


			# Families of 1 or 2 who are categorically eligible but in fact do not qualify for a can receive a minimum benefit ($16 in 2021) if they are either categorically eligible or meet the asset, gross, and net income tests. There is no min benefit for families of more than 2. 

			# set the minben_flag here instead of using the same block of code inside each if-block below
			if($snap_eligible_family_size <= 2) {
				$minben_flag = 1;
			}
			if ($in->{'minben_increase_alt'} == 1) {
				$fs_min_ben = $in->{'minben_user_input'};
			}	
			#Note: In some states (like DC), no asset test is applied for families that include people with disabilities. In other states, asset tests are applied when gross income exceeds the maximum BBCE gross income limit (which can be abvoe the BBCE gross income limit per state, since for example PA had a BBC  gross income limit of 160% in 2019, whereas the maximum limit is 200%.) In all states, no gross income test is applied to these households.
			
			$fs_gross_income = &pos_sub($out->{'earnings'}/12 + $out->{'interest_m'} + $out->{'child_support_recd_m'} + $out->{'tanf_recd_m'} + $out->{'ssi_recd_mnth'} + $out->{'tanf_sanctioned_amt'} + $out->{'ui_recd'}/12 + $out->{'fli_recd'}/12 + $out->{'tdi_recd'}/12 +$out->{'spousal_support_ncp'}/12, $fs_excluded_income_gross); #LOOK AT ME: for inclusion later - foster care payments are counted as income, as well as income from self-employment and social security benefits. 
			
			if ($out->{'foster_children_count'} > 0 && $out->{'snap_foster_child_option'} == 1) { #adding foster child payments to gross income if the foster children are required to be included in the household's application for SNAP. (This might vary by state).
				$fs_gross_income += $out->{'foster_child_payment_m'};
			}	
			#Determining if every hh member potentially eligible for SNAP is on SSI.
			
			#Previously, this SNAP code used to zero out fs_assets and fs_gross_income using the same general categories, with remaining populations having the fs_assets counted, but this becomes problematic when working in different rules that remove the asset test or gross income test without removing the other. So we are now first defining fs_assets, like we do above with gross income, and zeroing them out separately, without "else" conditions, based on categorical elgibiltiy rules.
			
			$fs_assets = $in->{'savings'} + $out->{'fs_vehicle1'} + $out->{'fs_vehicle2'};
			#Note: resources of all ineligible immigrants are counted, regardless of state

			#GROSS INCOME TEST
			
			if(($out->{'tanf_recd'} > 0 || $out->{'ssi_recd_count'} == $snap_eligible_family_size) && $fs_gross_income < $bbce_gross_income_pct_max * $fs_net_income_limit) {
				#This accords to rules around categorical eligibility for SNAP. If all members of the home receive TANF or SSI, they are considered categorically eligible for SNAP, but rules on SNAP categorical eligibility specify that it cannot be confered if gross income exceeds 200% FPL. The possibility that all family members may be on SSI or TANF with gross income above 200% FPL is remote but possible, especially among some policy modeling options we have built into this tool around possible TANF expansions.
				#From: https://www.fns.usda.gov/snap/eligibility/elderly-disabled-special-rules#Who%20is%20disabled?:
				#"Households may have $2,500 in countable resources (such as cash or money in a bank account) or $3,750 in countable resources if at least one member of the household is age 60 or older, or is disabled.
				#"However, certain resources are NOT counted when determining eligibility for SNAP:
				#"A home and lot;
				#"Resources of people who receive Supplemental Security Income (SSI);
				#"Resources of people who receive Temporary Assistance for Needy Families (TANF; also known as welfare); and
				#"Most retirement and pension plans (withdrawals from these accounts may count as either income or resources depending on how often they occur)."
				$passes_asset_test = 1; #Because a household of the above structure does not have any assets counted, based on the clarifications above, they mechanically pass the asset test.
				#Then, this is just regular categorical eligibility. TANF recipients and households where everyone receives SSI are assumed categorically eligible, by federal rules, as long as their income is lower than 200% FPL: https://www.law.cornell.edu/cfr/text/7/273.9. That is, they pass the gross income test.
				$passes_grossincome_test = 1;
				$categorically_eligible = 1;
			}
			
			#We calculate eligibility under non-categorical eligibilty and BBCE separately, as for some states, it matter whether someone is eligibel for BBCE vs other categorical eligibility.
			if ($out->{'ssi_recd_count'} > 0) { #Used to be with this added condition: "&& $fs_gross_income <= $fs_gross_income_limit". But that seems wrong. See federal BBCE chart for explanation of this policy: "Under regular program rules, SNAP households with elderly or disabled members do not need to meet the gross income limit, but must meet the net income limit." and clarification that under normal rules, hh's with disability presence are exempt from the asset test and gross income test up to 130% FPL. https://www.fns.usda.gov/snap/eligibility/elderly-disabled-special-rules#What%20resources%20can%20I%20have%20(and%20still%20get%20SNAP%20benefits).
				$passes_grossincome_test = 1;
			} elsif ($fs_gross_income <= $fs_gross_income_limit) {
				$passes_grossincome_test = 1;
			} elsif ($fs_gross_income < $out->{'bbce_gross_income_pct'} * $fs_net_income_limit) {
				$passes_grossincome_test = 1;
				$bbce_eligible = 1;
			} 


			
			# 2. ASSET TEST
			
			#First check if the disability-specific asset test applies and is not passed:
			if ($in->{'parent1_ssi'} - $adult1_excluded == 1 || $in->{'parent2_ssi'} - $adult2_excluded == 1 || $in->{'child_ssi_recd'} > 0) { #If someone receiving SSI is in the SNAP assistance unit...
				if ($fs_assets <= $fs_asset_limit_disability) { #This is always higher than the asset limit for non-DOE (disabled or elderly) famili
					$passes_asset_test = 1;
				} elsif ($out->{'bbce_disability_no_asset_limit'} == 1 || $fs_gross_income <= $bbce_gross_income_pct_max * $fs_net_income_limit) { #These subtractions might look odd but they check whether there's any disabled adult in the family who is not excluded due to ABAWD work requirements or other reans.
				#This covers the policy of some states allowing hh's that include people with disabiltiies to be exempt from asset tests regardless of income (resulting in their income no longer being a factor for the gross income test), See federal BBCE chart for explanation of this policy, and clarification that under normal rules, hh's with disability presence are exempt from the asset test and gross income test up to 130% FPL. That rule is included below, but this covers states that apply similar rules regardless of income. See also https://www.fns.usda.gov/snap/eligibility/elderly-disabled-special-rules#What%20resources%20can%20I%20have%20(and%20still%20get%20SNAP%20benefits).
					$passes_asset_test = 1;
					$bbce_eligible = 1;
				} 
			} elsif ($fs_assets <= $fs_asset_limit) {
				#Then check, for the non-disability-specific asset test, which is always a lower threshold than the disability-specific one:		
				$passes_asset_test = 1;
			} elsif ($out->{'bbce_no_asset_limit'}==1) {  
				$passes_asset_test = 1;
				$bbce_eligible = 1;
			} elsif ($fs_assets <= $out->{'bbce_asset_limit'}) {
				$passes_asset_test = 1;
				$bbce_eligible = 1;
			}
			
			#
			# 3. GROSS INCOME TEST
			#

			if ($passes_grossincome_test == 1 && $passes_asset_test  == 1) {

				#
				# 4. CALCULATE ADJUSTED INCOME
				#
				
				# Need to redefine income here instead of subtracting from gross income above, since we've zeroed out gross income in states with BBCE rules.
				
				#Can now use gross income instead of "fs_income", better matching how this is actually done. "Adjusted income is the "remaining gross income" before the shelter deduction. It's helpful to calculate this before calculating the shelter deduction, because that remaining deducation is used in in determining the shelter deduction.
				
				$fs_adjusted_income =&pos_sub($fs_gross_income, (($out->{'earnings_mnth'} - $fs_earned_income_excluded) * $fs_earned_ded_per) + $fs_standard_ded + ($out->{'child_care_expenses_m'} * (1-$excluded_proration_cc_expenses)) + $med_expenses_ded/12); 

				# 4a. calculate shelter cost for purpose of calculating shelter deduction
				# Incorporate any state or local heat-and-eat nominal payments to confer eligibility for the SUA.
				#
				# The liheap module will recalculate liheap_recd if LIHEAP is selected as a benefit, but we use it here to allow for the HCSUA to be claimed in families participating in heat-and-eat programs by families othewise ineligible for it, since all LIHEAP recipients are eligible to receive HCSUA.
				#				
				# NOTE: The KY SNAP application asks about LIHEAP receipt in the last year, so even though some states only offer LIHEAP during seasons when families experience high energy bills (such as summer or winter), we are assuming here that all states have a similar policy and that confer categorical eligibility for the SUA based on LIHEAP receipt in the past year.
				#
				$liheap_recd = &greatest($liheap_recd, $out->{'heatandeat_nominal_payment'});

				if ((($out->{'housing_subsidized'} == 1 && $out->{'rent_difference'} <= 0) || $in->{'heat_in_rent'} == 1) && $liheap_recd  < $heatandeat_min) {
					#This restricts the Heating SUA against people who pay utilities out of their rent (heat-in-rent) and people who are in project-based housing choice or public housing (which we assume when people receive Section 8 and pay at or below the FMR level) from receiving SUAs, unless their state provides heat-and-eat nominal LIHEAP payments. This seems reaonable but needs to be assessed in terms of potential additional SUAs (non heating or cooling) that families might be entitled to.  This is a new condition for 2019-2020 simulators. 
					
					#We now incorporate differnet SUAs. These are the polices for NH, they may be generalized elsewhere as we apply the MTRC to other states. See fsp_assets code for explanations as to why this is applicable.
					if ($in->{'energy_cost_override'} == 0) {
						$sua_m = $out->{'sua_utilities_only'}; 
					} elsif ($in->{'energy_cost_override_amt'} > 0) {
						$sua_m = $out->{'sua_utilities_only'};
					} elsif ($in->{'phone_override'} == 0) {
						$sua_m = $out->{'sua_phoneandinternet_only'};
					} elsif ($in->{'phone_override_amt'} > 0) {
						$sua_m = $out->{'sua_phoneandinternet_only'};
					} else {
						$sua_m = 0;
					}	
				} else {
					$sua_m = $out->{'sua_heat'}; 
				}


				# Note: There is no cap on the shelter deduction for people with disabilities. The below code also accounts for states that use optional SUAs; for those staes, the dummy variable  is 1; otherwise it is 0 and will not be active in the below calculations.
				# Since FMRs include utilities such as heating and cooling, we cannot include both the FMR and the SUA_m as separate parts of the shelter deduction; that would be double-counting. Instead, unless users enter their own utility costs, we use county PHA’s utility allowances (used in housing programs) for a closer approximation of utility costs than the (inflated) SUAs offer, to separate the rent component of the FMR separate from utilities. For states with a mandatory SUA (when optional_sua_policy = 0), the SUA replaces the cost of utilities as long as individuals pay some of their utility costs. In states that do not have mandatory SUA policies, recipients can claim a higher utility allowance with higher energy bills. In states with "heat-and-eat" program, SNAP recipients who do not pay separate utilities (whose rent includes utilitie) can also claim the SUA because they receive a nominal LIHEAP payment, as federal statutes allow anyone who receives LIHEAP to claim a state's SUA. This is why the beneficiaries of heat-and-eat progrms disproportionaely live in project-based Section 8 or public housing, because many of those buildings include utilities in rent bills. 
				# Please note even though  “housing assistance  payments made through a State or local housing authority” are excluded as SNAP income, since those payments for programs like Section 8 are made by the government to landlords, and not as a pass through to landlords via residents, Section 8 recipients will be able to claim only the amount of (reduced) rent they pay to landlords for this decuction, and not the full value of market rate rent. use the market rate rent (or the user-entered rent) as the rent to be excluded, rather than the actual rent_paid_m. (See Federal regulation 7 CFR 273.9 (c)(1)(i)(E).)  This cost would thus also include utilities, and therefore SUA_m cannot be counted. Changing rent_paid_m below to rent_cost_m will therefore not reduce a family’s SNAP benefit because they  receive Section 8, consistent with federal 
				if($in->{'energy_cost_override'}) {
					$energy_cost = $in->{'energy_cost_override_amt'};
				} else {
					$energy_cost = $out->{'pha_ua'};
				}
 
				if ($out->{'ssi_recd'} > 0 || $in->{'parent1_age'} >= 60 || $in->{'parent2_age'} >= 60 ) { 
					$fs_shelter_ded_recd = (1 - $excluded_proration_shelter) * &pos_sub($out->{'rent_paid_m'} - $energy_cost + &greatest($sua_m, $out->{'$optional_sua_policy'} * $energy_cost), 0.5 * $fs_adjusted_income); #	The definition of disabiltity below is specifically a disability that results in the receipt of SSI or SSP, and defines elderly as someone 60 years or older (within the FRS's range). It also covers some populations  that the FRS doesn't yet cover (e.g. surviving spouses of veterans). It is more specific than just disability so we can't use the disability# variables, but we can use the SSI variable here since a hh with a child who receives SSI is covered by this definition. 
					#definition of elderly or disabled here: https://www.law.cornell.edu/cfr/text/7/271.2
					#excess shelter deduction rule here: https://www.law.cornell.edu/cfr/text/7/273.9 
				} else {					
					$fs_shelter_ded_recd = (1 - $excluded_proration_shelter) * &least($fs_max_shelter_ded, &pos_sub(($out->{'rent_paid_m'} - $energy_cost + &greatest($sua_m,$out->{'$optional_sua_policy'} * $energy_cost)), 0.5 * $fs_adjusted_income));
				}

				$fs_net_income = &pos_sub($fs_adjusted_income, $fs_shelter_ded_recd);

				# 5. Calculate benefits and, if applicable, net income test

				if($fs_net_income > $fs_net_income_limit && ($out->{'bbce_no_netincome_limit'} == 0 || ($out->{'bbce_categorical_no_netincome_limit'} == 0 && $categorically_eligible == 1 && $bbce_eligible == 0))) { #Some states have BBCE but implent a net income test; that's the test of the first part of the or-condition here. Other states (at least Virginia) implement a net income test only for categorically eligible households that are not eligible under broad-based categorical eligibility rules; that's the second test here.
					if ($minben_flag == 0) {
						$fsp_recd = 0;
						$fsp_recd_m = 0;
					} elsif($minben_flag == 1) {
						$fsp_recd = 12 * $fs_min_ben;
						$fsp_recd_m = $fs_min_ben;
					}
				} elsif($snap_eligible_family_size > 2) { #State has a BBCE policy OR state does not have a BBCE policy but family passes income test.
					$fsp_recd_m = &pos_sub($fs_max_ben, (0.3 * $fs_net_income));
				} else { #Family sizes of 1 or 2 qualify for the SNAP minimum benefit.
					$fsp_recd_m = &pos_sub($fs_max_ben, (0.3 * $fs_net_income));
					$fsp_recd_m = &greatest($fs_min_ben, $fsp_recd_m);
				}
			}
			$fsp_recd = $fsp_recd_m * 12;
		}
	}

    # outputs
    foreach my $name (qw(fsp_recd fsp_recd_m fs_assets liheap_recd adult1_excluded adult2_excluded)) {
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;