#=============================================================================#
#  Public Health Insurance -- NJ 2021
#=============================================================================#
#
# Inputs referenced in this module:
#
#   FROM BASE
#   Inputs:
#   hlth
#   family_size
#	family_structure
# 	child1_age
# 	Child2_age
#	privateplan_type
#	hlth_amt_family_m  			# (if privateplan_type = user-entered)
#	hlth_amt_parent_m  			# (if privateplan_type = user-entered)
#	premium_tax_credit              # Y/N flag
#   userplantype                    # (either “employer” or “nongroup”) (if privateplan_type = user-entered) 
#   hlth_costs_oop_m                (=0 unless user specifies otherwise), aggregated in frs.pm or, for the BNBC, generated in nccp_simulator.
#   hlth_plan (see note below; even though hlth_plan has been removed from the below health 
#                   calculations, it remains an input assigned by the BNBC “budget” program.)
#	parent#_hlth_costs_oop_m
#	child#_hlth_costs_oop_m
#	
#   FROM FEDHEALTH: 
#	max_income_pct_employer
#	hlth_gross_income_m
#	private_max
#	percent_of_poverty
#	magi_disregard
#	sub_minimum
#	sub_maximum
#
#   FROM TANF
#   tanf_recd


#=============================================================================#

sub hlth
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};

	#Policy variables:
    our $parent_medicaid_limit = 1.38;  # adult income limit as % of FPG
    our $child_medicaid_limit = 3.55;    # child income limit as % of FPG
    #our $child_chip_limit = 2.18;    # child income limit as % of FPG
    our $self_only_coverage = 1614; #This is from the MEPS tables.
    our $a27yo_premium = qw(0 319.01 325.98 319.01 319.01 319.01 325.98 319.01 319.01 319.01 344.66 319.01 319.01 319.01 325.98 319.01 325.98 325.98 319.01 325.98 319.01 325.98)[$in->{'residence'}];  # These are the monthly premium for the second-lowest cost silver plan (SLCSP) for 27-year-olds in the state (NJ), by county, and can be used to calculate the associated premiums for all other ages. These are also in the SQL tables; this could be a sequel call.
	our $a27yo_premium_seh = qw(442.06 424.56 428.49 428.49 442.06 442.06 413.53 442.06 413.53 403.88 428.49 403.88 401.88 401.88 442.06 424.56 442.06 403.88 401.88 413.53 401.88)[$in->{'residence'}];  # These are the monthly premium for the second-lowest cost silver plan (SLCSP) for 27-year-olds in the state (NJ), by county, and can be used to calculate the associated premiums for all other ages. These are also in the SQL tables; this could be a sequel call.
	our $seh_employee_contribution = .267; #The average employee contribution to healthcare premiums, NJ, employers with 1-24 employees. From the SEH regulations, employers must cover at least 10% of total health costs, but MEPS data indicates the average employer coverage is more like 75%. This doesn't chane much depending on size of employer. Because this will result in small employer plans being much less than regular employer plans, planning on trying this out for now but likely suppressing it as we move to final.
	our @premium_ratioarray = (0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.833, 0.859, 0.885, 0.851, 0.941, 0.97, 1, 1, 1, 1, 1.004, 1.024, 1.048, 1.087, 1.119, 1.135, 1.159, 1.183, 1.198, 1.214, 1.222, 1.23, 1.238, 1.246, 1.262, 1.278, 1.302, 1.325, 1.357, 1.397, 1.444, 1.5, 1.563, 1.635, 1.706, 1.786, 1.865, 1.952, 2.04, 2.135, 2.23, 2.333, 2.437, 2.548, 2.603, 2.714, 2.81, 2.873, 2.952, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3); #These are the age curve ratios from 0 to 100.
	our @premium_ratioarray_seh = (0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.765, 0.833, 0.859, 0.885, 0.913, 0.941, 0.97, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.25, 1.275, 1.287, 1.305, 1.323, 1.334, 1.346, 1.352, 1.358, 1.363, 1.369, 1.381, 1.393, 1.41, 1.427, 1.45, 1.478, 1.511, 1.55, 1.593, 1.641, 1.688, 1.741, 1.792, 1.847, 1.902, 1.961, 2.019, 2.08, 2.142, 2.206, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28, 2.28); #These are the age curve ratios from 0 to 100 for NJ's Small Employer Health plans, which are group plans bound by additional rules distinct from the individual marketplace plans.
	our $nonmarketplace_individual_insurance_senior = 18522; #This and other similar variables below are from KFF's "Medicaid Spending Per Full Benefit Enrollee" chart, which we are using for how much an individual who doesn't receive employer insurance and ineligible for both Medicaid and marketplace coverage would have to pay to receive a baseline level of health insurance coverage. See https://www.kff.org/medicaid/state-indicator/medicaid-spending-per-full-benefit-enrollee/?currentTimeframe=0&sortModel=%7B%22colId%22:%22Location%22,%22sort%22:%22asc%22%7D
 	our $nonmarketplace_individual_insurance_disability = 21998;
	our $nonmarketplace_individual_insurance_adult = 5909;
	our $nonmarketplace_individual_insurance_child = 2574;
	our @medically_needy_incomelimit_array = qw(0 367 434 567 659 742 825 909 975 1042 1109); #This is the income limit for the Medically Needy Program, based on 133.3% of AFDC income limits as of 1996. The Medicaid income limits have not changed since 1996; they are not adjusted for inflation. The Medically Needy Income limits are updated (i.e. reprinted) each year on state websites and in a flyer, but (bizarrely) only up to family sizes of 6. The Medically Needy statutes clearly point to the limits as established in 1996, though, which cover families of larger sizes up to 10 at specific rates, and include a note to add in $67 to the limits for each additional person beyond 10. The FRS does not yet accomodate family sizes of more than 10 people, however, so we are not including that adjustment. The AFDC plan is avaiable at https://www.state.nj.us/humanservices/dmahs/info/state_plan/Attachment2_Eligibility.pdf; these Medically Needy limits are printed on pages 133-134 of the pdf of that plan.
	our $medically_needy_incomelimit = 0; #The Medically Needy income limit for the Medicaid assistance unit potentially eligibel for Medically Needy coverage, calculated in the code below.
	our @medically_needy_assetlimit_array = qw(0 4000 6000 6100 6200 6300 6400 6500 6600 6700 6800); 
	our $medically_needy_assetlimit = 0;
	our @medicaid_only_asset_limit_array = qw(0 2000 3000);
	our @mww_asset_limit_array = qw(0 20000 30000);
	
	
	# outputs created
	our $hlth_cov_parent1 = 'NA';   #@ health insurance status of parent1 (Medicaid, employer, nongroup, user-entered). 
    our $hlth_cov_parent2 = 'NA';   #@ health insurance status of parent2. See above for explanation.
    our $hlth_cov_parent = 'NA';   # health insurance status of parents (Medicaid, employer, nongroup, user-entered)
	our $hlth_cov_child_all = 'NA';  # health insurance status of all children (Medicaid, employer, individual), which we can have across chidldren because all children face identical policy environments in KY regardless of age. In thinking of making this code more universal, we'll have to be cognizant of this.
    our $hlth_cov_child1 = 'NA';  # health insurance status of Child 1 (Medicaid, employer, individual)
    our $hlth_cov_child2 = 'NA';  # health insurance status of child 2 (Medicaid, employer, individual)
    our $hlth_cov_child3 = 'NA';  # health insurance status of child 3 (Medicaid, employer, individual)
    our $hlth_cov_child4 = 'NA';  # health insurance status of child 4 (Medicaid, employer, individual). 
    our $hlth_cov_child5 = 'NA';  # health insurance status of child 5 (Medicaid, employer, individual). 
    our $health_expenses = 0;       # final annual cost of health insurance for family
	our $premium_credit_recd = 0;
    our $health_expenses_before_oop = 0;    # Health expenses before out-of-pocket medical costs are considered.  # This variable is only used by the BNBC program.                                  
    our $parent1_premium = 0;
    our $parent2_premium = 0;

	our $a27yo_premium_ratio = 0;
	our $a27yo_premium_ratio_seh =  0;  # This is the premium ratio on KY’s standard age curve.
	our $parent1_premium_ratio = 0;  
	our $parent2_premium_ratio = 0; 
	our $child1_premium_ratio = 0; 
	our $child2_premium_ratio = 0; 
	our $child3_premium_ratio = 0; 
	our $child4_premium_ratio = 0; 
	our $child5_premium_ratio = 0; 
	our $child1_premium = 0;
	our $child2_premium = 0;
	our $child3_premium = 0;
	our $child4_premium = 0;
	our $child5_premium = 0;
	our $child1_premium_individual = 0;
	our $child2_premium_individual = 0;
	our $child3_premium_individual = 0;
	our $child4_premium_individual = 0;
	our $child5_premium_individual = 0;
	our $parent1_premium_ratio_seh = 0;  
	our $parent2_premium_ratio_seh = 0; 
	our $child1_premium_ratio_seh = 0; 
	our $child2_premium_ratio_seh = 0; 
	our $child3_premium_ratio_seh = 0; 
	our $child4_premium_ratio_seh = 0; 
	our $child5_premium_ratio_seh = 0; 
	our $include_seh_child1 = 1;	#whether the rate for coverage for a child is included in a small group plan. We start by assuming that all are counted.
	our $include_seh_child2 = 1;	#whether the rate for coverage for a child is included in a small group plan
	our $include_seh_child3 = 1;	#whether the rate for coverage for a child is included in a small group plan
	our $include_seh_child4 = 1;	#whether the rate for coverage for a child is included in a small group plan
	our $include_seh_child5 = 1;	#whether the rate for coverage for a child is included in a small group plan
	
	our $ssi_recipient_exclusion = 1; #Apparently, NJ has this policy, and it may indeed be a policy that varies by state. First noticed this policy in DC, which based on 2017 documnetation interpreted at that time seemed to treat SSI recipients as their own assistance group, and exclude their income from eligibility determinations of other assistance groups in the household. There does not appear to be such a policy in DC anymore, and this policy does not seem included in the Medicaid expansion policies of KY, NH, PA, or ME, but based on N.J.A.C. 10:72-3.5, SSI recipients are excluded from Medicaid assistance units. Was about to remove this policy complication, but it is reaffirmed as something to model because it's included for NJ. May be worth exploring  more in detail to see how this may vary in other states. 
	our $medically_needy = 0; 


    # CALCULATED IN MACRO 
    our $sub_family_cost = 0;            # The cost of marketplace insurance for family members covered, after considering federal subsidies   
    our $sub_parent_cost = 0;            # The cost of marketplace insurance for parents, after considering federal subsidies  
    our $parent_cost_individual = 0;        # The unsubsidized cost of health insurance premium(s) for the parent(s) in the family available on the federal marketplace   
    our $family_cost_individual = 0;        # The unsubsidized cost of health insurance premiums for the entire family available on the federal marketplace
    our $parent_cost_employer = 0;       # The cost of health insurance premiums for parent(s) available to employees based on a hypothetical health insurance plan using MEPS data.
    our $family_cost_employer = 0;       # The cost of health insurance premiums for the entire family available to employees based on a hypothetical health insurance plan using MEPS data.
    our $familyswitch_dummy = 0;         # A dummy variable that switches from N to Y if employer-provided family health insurance is unaffordable enough to necessitate a switch to nongroup (subsidized) insurance.																																					 
    our $parentswitch_dummy = 0;         # A dummy variable that switches from N to Y if employer-provided parent health insurance is unaffordable enough to necessitate a switch to nongroup (subsidized) insurance.
    our $family_cost = 0;
    our $parent_cost = 0;
    our $parent1_premium_individual = 0;
	our $parent2_premium_individual = 0;		
	our $medicaidorchip_premiums = 0;
	our $sub_parent_cost1 = 0;
	our $sub_parent_cost2 = 0;
	our $parent_cost1 = 0;
	our $parent_cost2 = 0;
	our $parent_cost_individual_total = 0;
	our $family_cost_individual_total = 0;
	our $adult_medicaid_count = 0;
	our $child_medicaid_count = 0;
	our $adult_child_medicaid_count = 0;

	our $nongroup_nonmarketplace_cost_parent1 = 0;
	our $nongroup_nonmarketplace_cost_parent2 = 0;
	our $nongroup_nonmarketplace_cost_child1 = 0;
	our $nongroup_nonmarketplace_cost_child2 = 0;
	our $nongroup_nonmarketplace_cost_child3 = 0;
	our $nongroup_nonmarketplace_cost_child4 = 0;
	our $nongroup_nonmarketplace_cost_child5 = 0;
	our $nongroup_nonmarketplace_cost_children = 0;
	our $health_expenses_qualified_members = 0;
	
	our $parent1_health_expenses = 0;	#oop and premium costs
	our $parent2_health_expenses = 0;	#oop and premium costs
	our $child1_health_expenses = 0;	#oop and premium costs
	our $child2_health_expenses = 0;	#oop and premium costs
	our $child3_health_expenses = 0;	#oop and premium costs
	our $child4_health_expenses = 0;	#oop and premium costs
	our $child5_health_expenses = 0;	#oop and premium costs

	our $parent_greencard_premiums = 0;	#Helpful for determining premium tax credits for mixed-status immmigrant families
	our $family_greencard_premiums	= 0;

	our $mww_gross_unearned_income  = 0;
	our $mww_net_unearned_income = 0;
	our $mww_net_earned_income = 0;
	our $mww_poverty_level = 0;	

	our $medically_needy_eligible_expenses = 0;
	our $medically_needy_gross_income = 0;
	our $medically_needy_assets = 0; 
	our $medically_needy_net_income = 0;
	our $medically_needy_childcare_deduction = 0;
	our $medically_needy_earnedincome_deduction = 0;
	our $medically_needy_unearnedincome_deduction = 0;
	our $medically_needy_childsupport_deduction = 0;
	our $medically_needy_childsupport_deduction = 0;
	our $medically_needy_unit_size = 0;
	our $health_expenses_afdc_pathway = 0;
	our $medically_needy_eligible_expenses_afdc_pathway = 0;
	our $medically_needy_eligible_expenses_ssi_pathway = 0;
	
	our $parent1_potential_afdc_coverage = 0;
	our $parent2_potential_afdc_coverage = 0;
	our $parent1_afdc_coverage  = 0;
	our $parent2_afdc_coverage  = 0;

	our $debughlth1 = 0;
	our $debughlth2 = 0;
	our $debughlth3 = 0;

	
    # Start debug variables
    our $hlth = $in->{'hlth'};
    our $state = $in->{'state'};
    our $year = $in->{'year'};
    our $family_structure = $in->{'family_structure'};
    our $child_number = $in->{'child_number'};
    our $residence = $in->{'residence'};
    our $percent_of_poverty = $out->{'percent_of_poverty'};
	our $percent_of_poverty_ssi = $out->{'percent_of_poverty_ssi'}; 

    # our $magi_disregard = $out->{'magi_disregard'}; #For 2019 and 2020 simulators, we're going to try to use income limits for various age groups that include the MAGI disregard. I think this will make things easier.
    our $privateplan_type = $in->{'privateplan_type'};
    our $userplantype = $in->{'userplantype'};
    our $sub_minimum = $out->{'sub_minimum'};
    our $sub_maximum = $out->{'sub_maximum'};
    our $premium_tax_credit = $in->{'premium_tax_credit'};
    our $private_max = $out->{'private_max'};
    our $max_income_pct_employer = $out->{'max_income_pct_employer'};
    our $hlth_gross_income_m = $out->{'hlth_gross_income_m'};

	#specifc for DC need to create firstrunchildcare 
	
	our $firstrunchildcare = 1;
    # End debug variables
 
	# TABLE ARRAYS
	$a27yo_premium_ratio = $premium_ratioarray[27];
	$parent1_premium_ratio = $premium_ratioarray[$in->{'parent1_age'}];  
	$parent2_premium_ratio = $premium_ratioarray[$in->{'parent2_age'}]; 
	for(my $i=1; $i<=5; $i++) {
		if ($in->{'child'.$i.'_age'} > -1) {
			${'child'.$i.'_premium_ratio'} = $premium_ratioarray[$in->{'child'.$i.'_age'}];  
		}
	}
	$a27yo_premium_ratio_seh =  $premium_ratioarray_seh[27];  
	$parent1_premium_ratio_seh = $premium_ratioarray_seh[$in->{'parent1_age'}];  
	$parent2_premium_ratio_seh = $premium_ratioarray_seh[$in->{'parent2_age'}]; 
	for(my $i=1; $i<=5; $i++) {
		if ($in->{'child'.$i.'_age'} > -1) {
			${'child'.$i.'_premium_ratio_seh'} = $premium_ratioarray_seh[$in->{'child'.$i.'_age'}];  
		}
	}


	# In order for the BNBC to work correctly, we need to translate inputted values for hlth_plan into privateplan_type. Note that while hlth_plan = private translates exactly to privateplan_type = individual and hlth_plan = employer translates exactly to privateplan_type = employer, and both should yield calculable outputs by such translation,  hlth_plan = amount requires the additional determination of userplantype in order for health_expenses to be properly determined. However, since the BNBC does not look at the receipt of public benefits, there will be no difference in health_expenses between userplantype = employer and userplantype = individual, so either will suffice for the  purposes of BNBC calculations. The below assignment of userplantype = employer is therefore arbitrary, but also would yield the same results as if userplantype = individual.

    if ($in->{'hlth_plan'} eq 'private') {
        $in->{'privateplan_type'} = 'individual';
    }

    if ($in->{'hlth_plan'} eq 'employer') {
        $in->{'privateplan_type'} = 'employer';
    }

    if ($in->{'hlth_plan'} eq 'amount') {
        $in->{'privateplan_type'} = 'user-entered';
        $in->{'userplantype'} = 'employer';
    }

    # 1.  Check Public Health flag and premium tax credit flag
    #

	# First, determine the oldest and potentially second-oldest children in the hh, which will be helpful for small group plan rate determinations.
	
	if ($in->{'privateplan_type'} eq 'smallgroup' && $in->{'child_number'} > 3) { #NJ has a small group health insurance program that works similarly to the plans on the individual marketplace, with a few key adjustments, including a different age curve and setting a maximum number of children counted in determining the rates of a small group plan at 3 children.
		our $oldest = 1;
		our $second_oldest = 1;
		for(my $i=1; $i<=5; $i++) {
			if ($in->{'child'.$i.'_age'} > $in->{'child'.$oldest.'_age'}) {
				$oldest = $i;
			}
		}
		for(my $i=1; $i<=5; $i++) {
			if ($in->{'child'.$i.'_age'} > $in->{'child'.$oldest.'_age'} && $i != $oldest) {
				$second_oldest = $i;
			}
		}				
		${'include_seh_child'.$oldest} = 0; #we exclude the oldest child, since they are the most expensive to cover.
		if ($in->{'child_number'} == 5) {
			${'include_seh_child'.$second_oldest} = 0; #5 children. Need to also exclude the second-oldest
		}
	}

	#Back to the regular show, which is common across most states:
	
    if ($in->{'privateplan_type'} eq 'user-entered') { #we may want to change the user interface so that the user has to input each individual's costs, rather than just the parent's or the family's costs. 
        $parent_cost = $in->{'hlth_amt_parent_m'} * 12;
        $family_cost = $in->{'hlth_amt_family_m'} * 12;
    }

	if ($in->{'hlth'} == 0 && $in->{'premium_tax_credit'} == 0) { 
		if ($in->{'privateplan_type'} eq 'employer'){
			#Setting residence to 1 for now because have made employer codes all state-specific, as they are in MEPS. If residence can be removed from this lookup, do that.
			foreach my $datum (qw(parent_cost family_cost)) {	
				$in->{$datum} = &csvlookup($in->{'dir'}.'\FRS_health.csv', $datum, 'family_structure', $in->{'family_structure'}, 'child_number', $in->{'child_number'}, 'plan_type', $in->{'privateplan_type'}, 'residence', 1);
			}

			if (1 == 0) {	#EquivalentSQL:
				my $sql = "SELECT parent_cost, family_cost FROM FRS_Health WHERE state = ? && year = ? && family_structure = ? && child_number = ? && plan_type = ? && residence = ?";
				my $stmt = $dbh->prepare($sql) ||
					&fatalError("Unable to prepare $sql: $DBI::errstr");
				$stmt->execute($in->{'state'}, $in->{'year'}, $in->{'family_structure'}, $in->{'child_number'}, $in->{'privateplan_type'}, 1) ||
					&fatalError("Unable to execute $sql: $DBI::errstr");
				($parent_cost, $family_cost) = $stmt->fetchrow();
			}
			for (my $i=1; $i<=$in->{'family_structure'}; $i++) {
				if ($in->{'parent'.$i.'_age'} >= 18) { #If parent2 exists in the home...
					${'hlth_cov_parent'.$i} = 'employer';
				}
			}
			for (my $i=1; $i<=5; $i++) {
				if ($in->{'child'.$i.'_age'} >= 0) { 
					${'hlth_cov_child'.$i} = 'employer';
				}
			}
			
		} elsif ($in->{'privateplan_type'} eq 'smallgroup') { #NJ has a small group health insurance program that works similarly to the plans on the individual marketplace, with a few key adjustments, including a different age curve and setting a maximum number of children counted in determining the rates of a small group plan at 3 children.
			$hlth_cov_parent1 = 'smallgroup';
			$parent1_premium = ($parent1_premium_ratio_seh/$a27yo_premium_ratio_seh) * $a27yo_premium_seh * $seh_employee_contribution;
			# Parent2:
			if ($in->{'family_structure'} == 2) {
				$hlth_cov_parent2 = 'smallgroup';
				$parent2_premium = ($parent2_premium_ratio_seh/$a27yo_premium_ratio_seh) * $a27yo_premium_seh * $seh_employee_contribution;
			}
			$parent_cost = 12*($parent1_premium + $parent2_premium);
			$family_cost = $parent_cost;
			for(my $i=1; $i<=5; $i++) {
				if ($in->{'child'.$i.'_age'} > -1) {
					${'hlth_cov_child'.$i} = 'smallgroup';					
					if (${'include_seh_child'.$i} == 1) {
						${'child'.$i.'_premium'} = (${'child'.$i.'_premium_ratio_seh'}/$a27yo_premium_ratio_seh) *$a27yo_premium_seh *12 * $seh_employee_contribution;
						$family_cost += ${'child'.$i.'_premium'};
					}
				}
			}

		} elsif ($in->{'privateplan_type'} ne 'user-entered') { #individual plans
			# We use the premiums for 27-year-olds to determine the cost for parents and children.
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {

				#Add variables for individuals ineligible adults:

				if ($in->{'parent'.$i.'_immigration_status'} eq 'undocumented_or_other' ||$in->{'parent'.$i.'_immigration_status'} eq 'daca') {
					#Undocumented and DACA recipients cannot get insurance off the marketplace, both for adult and children.
					#Undocumented and DACA and New LPRs who are adults cannot get Medicaid. Undocumented and DACA recipients who are children cannot get Medicaid, but all LPR children can, even during the 5 year bar.
					if ($in->{'disability_parent'.$i} == 1) {
						${'nongroup_nonmarketplace_cost_parent'.$i} = $nonmarketplace_individual_insurance_disability / 12;
					} else {
						${'nongroup_nonmarketplace_cost_parent'.$i} = $nonmarketplace_individual_insurance_adult / 12;
					}
				} else {
					${'parent'.$i.'_premium'} = (${'parent'.$i.'_premium_ratio'}/$a27yo_premium_ratio) * $a27yo_premium;
				}
			}
			$parent_cost = 12*($parent1_premium + $parent2_premium);
			$family_cost = $parent_cost;
			for(my $i=1; $i<=5; $i++) {
				if ($in->{'child'.$i.'_age'} > -1) {
					if ($in->{'child'.$i.'_immigration_status'} eq 'undocumented_or_other' ||$in->{'child'.$i.'_immigration_status'} eq 'daca') {
						#Undocumented and DACA recipients cannot get insurance off the marketplace, both for adult and children.
						if ($in->{'disability_child'.$i} == 1) {
							${'nongroup_nonmarketplace_cost_child'.$i} = $nonmarketplace_individual_insurance_disability / 12;
						} else {
							${'nongroup_nonmarketplace_cost_child'.$i} = $nonmarketplace_individual_insurance_child / 12;
						}
						$nongroup_nonmarketplace_cost_children += ${'nongroup_nonmarketplace_cost_child'.$i};
					} else {
						${'child'.$i.'_premium'} = (${'child'.$i.'_premium_ratio'}/$a27yo_premium_ratio) *$a27yo_premium; 
						$family_cost += ${'child'.$i.'_premium'} *12;
					}
				}
			}
		}
	} else {

		# 1. Determine family’s eligibility for coverage
		#
		# We now apply MAGI income limits and disregards based on adult and child limits. These are based on KY rules and regulations implemented as of the 2019 MAGI Medicaid manual. There may be separate eligibility criteria for non-MAGI Medicaid options (which seem to be rare across states) but we are not including them here. 

		if ($in->{'hlth'} == 1) { 
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				#Undocumented and DACA and New LPRs who are adults cannot get Medicaid. Undocumented and DACA recipients who are children cannot get Medicaid, but all LPR children can, even during the 5 year bar.
				if ($in->{'parent'.$i.'_unqualified'} == 0) {
					if ($out->{'percent_of_poverty'} <= $parent_medicaid_limit) {
						${'hlth_cov_parent'.$i} = 'Medicaid';
						# 7/13 note: For DC, the type of health care for all children will be identical, since there are no separate eligibility criteria for its Medicaid program by age. If it makes the code simpler or less time consuming, we could change this variable simply to “hlth_cov_child” or “hlth_cov_children” and have that reflected as an output at the end. Or, we could simply use that as an intermediary variable and then set hlth_cov_child# to hlth_cov_children at the end of this code. In case the current code works fine, though, I’m just leaving it as is for now.
						#
						# We now account for instances when a parent on SSI makes a significant amount of household income. People on SSI are categorically eligible for Medicaid. Because of that, they are seemingly excluded from other eligibility groups according to the ESA policy manual, while presumably those other groups can still qualify for ACA income limits. See pages 284-285 of the ESA policy manual, along with pages 15, 89-92, 124, and 341. The below additions follow the addition of the _ssi variables in the federal health code, which will return the percent of poverty of the household excluding individuals on SSI as well as their income. It does not appear, however, that these affect the amount of premium tax credits received, so that initial determination of percent_of_poverty will be used here. 
					} elsif ($out->{'parent'.$i.'ssi_recd'}) { #Used to be just based on ssi_recd, but beginning in 2021, adding children to this, so need to clarify that this condition is just based on parent/adult receipt of SSI.
						${'hlth_cov_parent'.$i} = 'Medicaid';
					} elsif ($out->{'ssi_recd'} > 0 && $out->{'percent_of_poverty_ssi'}  <= $parent_medicaid_limit && $ssi_recipient_exclusion == 1) { #Someone in the home receives SSI and the parent/adult lives in a state where that person and their income are excluded from Medicaid calculations, resulting in a potentially lower income limit and revised accounting of family income. 
						${'hlth_cov_parent'.$i} = 'Medicaid';
					} elsif ($in->{'parent'.$i.'_age'} == 18 && $out->{'percent_of_poverty'} <= $child_medicaid_limit) {
						${'hlth_cov_parent'.$i} = 'Medicaid';
						$adult_child_medicaid_count += 1;
					} elsif ($out->{'ssi_recd'} > 0 && $in->{'parent1_age'} == 18 && $out->{'percent_of_poverty_ssi'} <= $child_medicaid_limit && $ssi_recipient_exclusion == 1) { # This would designate that the parent on SSI is older than 18 but the other parent is younger than 18, and qualifying for child Medicaid. 
						${'hlth_cov_parent'.$i} = 'Medicaid';
						$adult_child_medicaid_count += 1;
					} elsif ($in->{'covid_medicaid_expansion'}) {
							${'hlth_cov_parent'.$i} = 'Medicaid'; #This is essentially Medicaid/Medicare for all. But for COVID legislation, we assume that if the family checks Medicaid, they are always receiving Medicaid for those who are eligible. LOOK AT ME: Come back to this if getting all Medicaid all the time.
					} else { 
						${'hlth_cov_parent'.$i} = $in->{'privateplan_type'};
					}
					
					#Test for Medicaid While Working. Since this is a relatively long code, not isolated to one line, it follows initial assignment of a private plan.
					
					if ($in->{'disability_parent'.$i} == 1 && $out->{'parent'.$i.'ssi_recd'} == 0){
						#This is "NJ Workability," or NJ's Medicaid While Working program. It uses SSI income determinations.
						#This starts out the same as SSI income determinations:
						
						$mww_gross_unearned_income = (1- $in->{'covid_ui_disregard'}) * ($out->{'parent'.$ssi_eligible_parent_id.'_fli_recd'}/12 + $out->{'parent'.$ssi_eligible_parent_id.'_tdi_recd'}/12 + $out->{'parent'.$ssi_eligible_parent_id.'_ui_recd'}/12) + $out->{'gift_income_m'}/$in->{'family_structure'};
						$mww_net_unearned_income = &pos_sub($mww_gross_unearned_income, 20);
						$mww_net_earned_income = $ssi_income = pos_sub(.5 * &pos_sub($out->{'earnings_mnth'}, (65 + &pos_sub(20,$mww_gross_unearned_income))), $in->{'disability_work_expenses_m'});
						if ($mww_net_unearned_income + $mww_net_earned_income <= $in->{'fpl_1person'} / 12) {
							#We are not deeming any income from parents in the home, as their income could be used for a Medically Needy AFDC case.
							if ($in->{'family_structure'} == 1 || $in->{'child_number'} > 0) {
								$mww_poverty_level = $in->{'fpl_1person'} / 12;
							} else {
								#deem ineligible adult's income. We can use the deeming outputs from SSI for married couples.
								#Redefine the unearned and earned income amounts based on deeming calculations.
								$mww_net_unearned_income = $out->{'ssi_unearned_income'};
								$mww_net_earned_income = $out->{'ssi_earned_income'};
								$mww_poverty_level = $in->{'fpl_2people'} / 12;
							}
							#Apply the income test and asset test:
							if ($mww_net_earned_income < 2.5 * $mww_poverty_level && $mww_net_unearned_income < $mww_poverty_level && $in->{'savings'} + &pos_sub($in->{'vehicle2_value'}, $in->{'vehicle2_owed'}) < $mww_asset_limit_array[$in->{'family_structure'}]) {
								${'hlth_cov_parent'.$i} = 'Medicaid';
							}
						}
					}
					
				} else {
					#Parent's immigration status makes them ineligble for Medicaid.
					${'hlth_cov_parent'.$i} = $in->{'privateplan_type'};
				}
				
				if (${'hlth_cov_parent'.$i} eq 'Medicaid') {
					$adult_medicaid_count +=1;
				}

			}

			if ($adult_medicaid_count == $in->{'family_structure'}) {
				$hlth_cov_parent = 'Medicaid';
			} elsif ($adult_medicaid_count > 0 && $adult_medicaid_count < $in->{'family_structure'}) {
				$hlth_cov_parent = 'Medicaid and private';
			} else {
				$hlth_cov_parent = $in->{'privateplan_type'}; 
			}

			
			# 2. Children's coverage 
				#									   
			for(my $i=1; $i<=5; $i++) {
				if ($in->{'child'.$i.'_age'} > -1) {
					#Undocumented and DACA and New LPRs who are adults cannot get Medicaid. Undocumented and DACA recipients who are children cannot get Medicaid, but all LPR children can, even during the 5 year bar.
					if (($in->{'child'.$i.'_immigration_status'} ne 'undocumented_or_other' && $in->{'child'.$i.'_immigration_status'} ne 'daca') || $in->{'medicaidchip_all_immigrant_children'} == 1) {

						if ($out->{'percent_of_poverty'} <= $child_medicaid_limit) { 
							${'hlth_cov_child'.$i} = 'Medicaid';
							# See note above – this applies a similar methodology as above for determining eligibility when one or both parents are on SSI. If both parents are on SSI, they will both be on Medicaid due to categorical eligibility. This accounts completely for categorical eligibility for Medicaid among families in which all parents receive SSI.
						} elsif ($out->{'child'.$i.'_ssi_recd'} > 0) {
								${'hlth_cov_child'.$i} = 'Medicaid';						
						} elsif ($out->{'ssi_recd'} > 0 && $out->{'percent_of_poverty_ssi'} <= $child_medicaid_limit && $ssi_recipient_exclusion == 1) {  #Used to be just based on ssi_recd, but beginning in 2021, adding children to this, so need to clarify that this condition is just based on parent/adult receipt of SSI. This just excludes parent incomes with the SSI recipient exclusion policy that NJ has. 
							${'hlth_cov_child'.$i} = 'Medicaid';
						} elsif ($in->{'disability_child'.$i} == 1 && $out->{'child'.$i.'ssi_recd'} == 0 && pos_sub($out->{'deemed_income_perchild'}, 20) <= $in->{'fpl_1person'} / 12 && $in->{'savings'} + &pos_sub($in->{'vehicle2_value'}, $in->{'vehicle2_owed'}) < $mww_asset_limit_array[$in->{'family_structure'}] - $medicaid_only_asset_limit_array[$in->{'family_structure'}]) {
							#This is "NJ Workability," or NJ's Medicaid While Working program. That applies to children of parents who are working as well as to those adults who are working themselves. It uses SSI income determinations.
							#No need to check earned income; we are assuming child has no earned income.
							#The parent eligibility check for this is much more complicated, but because we can assume that the only income the child gets is from parental deeming, for which we are using the output from SSI in this (as NJ uses similar or identical formulas), mathematically, this check reduces to whether that deemed income is below the federal poverty level for one person. What this does is protect the child's health insurance when parental income is high enough that it kicks the child off both SSI and MAGI Medicaid. It's unclear how or whether this could happen mathematically in NJ, but there's probably some way it can.
							#The asset test above is also in line with Workdabiltiy rules; all income from parents above the Medicaid Only Limits are deemed to the child.
							${'hlth_cov_child'.$i} = 'Medicaid';
						} elsif ($in->{'covid_medicaid_expansion'}) {
								${'hlth_cov_child'.$i} = 'Medicaid'; #This is essentially Medicaid/Medicare for all. But for COVID legislation, we assume that if the family checks Medicaid, they are always receiving Medicaid for those who are eligible. LOOK AT ME: Come back to this if getting all Medicaid all the time.
						} else { 
							${'hlth_cov_child'.$i} = $in->{'privateplan_type'};
						}
					} else {
						${'hlth_cov_child'.$i} = $in->{'privateplan_type'};
					}
					
					if (${'hlth_cov_child'.$i} eq 'Medicaid') {
						$child_medicaid_count +=1;
					}
						
				}
			}			
			if ($child_medicaid_count == $in->{'child_number'}) {
				$hlth_cov_child_all = 'Medicaid';
			} elsif ($adult_medicaid_count > 0 && $adult_medicaid_count < $in->{'family_structure'}) {
				$hlth_cov_child_all = 'Medicaid and private';
			} else {
				$hlth_cov_child_all = $in->{'privateplan_type'}; 
			}

			if ($child_medicaid_count + $adult_medicaid_count > 0 && $out->{'percent_of_poverty'} > 2 && $in->{'eliminate_medicaidchip_premiums'} == 0) {
				#NJ institutes Medicaid premiums for families with children above 200% FPL, but those have been suspended due to COVID "until further notice."
				if ($out->{'percent_of_poverty'} <= 2.5) {
					$medicaidorchip_premiums = 44.5 * 12;
				} elsif ($out->{'percent_of_poverty'} <= 3) {
					$medicaidorchip_premiums = 90 * 12;
				} else {
					$medicaidorchip_premiums = 151.5 * 12;
				}
			}
		}
		# 3. Determine parent health care program
		# We now incorporate health care subsidies into the calculation of health care costs for employer or individual plans. Note that these factor into the FRS only by reducing costs, and not by being calculated as a separate benefit. None of the code in this step applies to user-entered fields, so conceivably this step could be skipped for users entering health data themselves, but none of the operations below relate to any variables necessary for calculating costs for user-entered data, so going through these steps is also a harmless exercise if health data is user-entered.

		# Use 'Health' table in base tables to determine parent_cost and family_cost based on residence, family_structure, and child_number, 
		# both for privateplan_type=individual (labeling the associated values parent_cost_individual and family_cost_individual) 
		# and for privateplan_type = employer (labeling the associated values parent_cost_employer and family_cost_employer).  Unlike previous years, we calculate premiums on the individual market based on age, using a formula instead of a lookup.

		# We use the premiums for 27-year-olds to determine the cost for parents and children.
		# Parent1:
		# The below calculation uses the “Age curve” table in the DC public health tables to determine premium_ratio by using parent1_age for age, and identify this as parent1_premium_ratio. Note to programmer  

		for(my $i=1; $i<=$in->{'family_structure'}; $i++) {	#This i is for each adult in the family.
			#Undocumented and DACA recipients cannot get insurance off the marketplace, both for adult and children.
			if ($in->{'parent'.$i.'_immigration_status'} eq 'undocumented_or_other' ||$in->{'parent'.$i.'_immigration_status'} eq 'daca') {
				if ($in->{'disability_parent'.$i} == 1) {
					${'nongroup_nonmarketplace_cost_parent'.$i} = $nonmarketplace_individual_insurance_disability / 12;
				} else {
					${'nongroup_nonmarketplace_cost_parent'.$i} = $nonmarketplace_individual_insurance_adult / 12;
				}
			} elsif (${'hlth_cov_parent'.$i} ne 'Medicaid') {
				# This accounts for families where at least one parent is on SSI and at least one is not eligible for Mediciad.
				${'parent'.$i.'_premium_individual'} = (${'parent'.$i.'_premium_ratio'}/$a27yo_premium_ratio) * $a27yo_premium;
				${'parent'.$i.'_cost_individual'} = 12 * ${'parent'.$i.'_premium_individual'};
				if ($in->{'parent'.$i.'_immigration_status'} eq 'newer_greencard' || $in->{'parent'.$i.'_immigration_status'} eq 'older_greencard') {
					$parent_greencard_premiums += ${'parent'.$i.'_cost_individual'};
				}
			}			
		}

		$parent_cost_individual = 12*($parent1_premium_individual + $parent2_premium_individual);

		$family_cost_individual = $parent_cost_individual;

		$family_greencard_premiums = $parent_greencard_premiums;
		
		# This calculation uses data from the “Age curve” table in the DC public health tables to determine premium_ratio by using child#_age for age, and identify this as child_premium_ratio. 
		for(my $i=1; $i<=5; $i++) {
			if ($in->{'child'.$i.'_age'} > -1) {
				if (($in->{'child'.$i.'_immigration_status'} eq 'undocumented_or_other' || $in->{'child'.$i.'_immigration_status'} eq 'daca') && ${'hlth_cov_child'.$i} ne 'Medicaid') {
					#Undocumented and DACA recipients cannot get insurance off the marketplace, both for adult and children.
					if ($in->{'disability_child'.$i} == 1) {
						${'nongroup_nonmarketplace_cost_child'.$i} = $nonmarketplace_individual_insurance_disability / 12;
					} else {
						${'nongroup_nonmarketplace_cost_child'.$i} = $nonmarketplace_individual_insurance_child / 12;
					}
					$nongroup_nonmarketplace_cost_children += ${'nongroup_nonmarketplace_cost_child'.$i};
				} elsif (${'hlth_cov_child'.$i} ne 'Medicaid') {
					${'child'.$i.'_premium_individual'} = (${'child'.$i.'_premium_ratio'}/$a27yo_premium_ratio) *$a27yo_premium; 
					$family_cost_individual += ${'child'.$i.'_premium_individual'} *12;
					if ($in->{'child'.$i.'_immigration_status'} eq 'newer_greencard' || $in->{'child'.$i.'_immigration_status'} eq 'older_greencard') {
						$family_greencard_premiums += ${'child'.$i.'_premium_individual'} *12;
					}
				}
			}
		}
		
		if ($adult_medicaid_count == $in->{'family_structure'}) {
			($parent_cost_employer, $family_cost_employer) = 0;
		} else {
			$parent_cost_employer = &csvlookup($in->{'dir'}.'\FRS_health.csv', 'parent_cost', 'family_structure', $in->{'family_structure'} - $adult_medicaid_count, 'child_number', $in->{'child_number'} - $child_medicaid_count, 'plan_type', $in->{'privateplan_type'}, 'residence', 1);			
			$family_cost_employer = &csvlookup($in->{'dir'}.'\FRS_health.csv', 'family_cost', 'family_structure', $in->{'family_structure'} - $adult_medicaid_count, 'child_number', $in->{'child_number'} - $child_medicaid_count, 'plan_type', $in->{'privateplan_type'}, 'residence', 1);

			if (1 == 0) { #EquivalentSQL
				my $sql = "SELECT parent_cost, family_cost FROM FRS_Health WHERE state = ? && year = ? && family_structure = ? && child_number = ? && plan_type = ? && residence = ?"; 
				my $stmt = $dbh->prepare($sql) ||
					&fatalError("Unable to prepare $sql: $DBI::errstr");
				$stmt->execute($in->{'state'}, $in->{'year'}, $in->{'family_structure'} - $adult_medicaid_count, $in->{'child_number'} - $child_medicaid_count, $in->{'privateplan_type'}, 1) || 
					&fatalError("Unable to execute $sql: $DBI::errstr");
				($parent_cost_employer, $family_cost_employer) = $stmt->fetchrow();
			}
		
			if ($in->{'privateplan_type'} eq 'smallgroup') { #NJ has a small group health insurance program that works similarly to the plans on the individual marketplace, with a few key adjustments, including a different age curve and setting a maximum number of children counted in determining the rates of a small group plan at 3 children. It is available to employers seeking to use small group / small employer health plans.
			#LOOK AT ME: When rearranging this to separate out health care coverage better, adjust this small group calculation (if we are still planning on including this option) so that th parent_cost_employer and family_cost_employer does not include people on Medicaid 
				$parent1_premium = ($parent1_premium_ratio_seh/$a27yo_premium_ratio_seh) * $a27yo_premium_seh * $seh_employee_contribution;
				# Parent2:
				if ($in->{'family_structure'} == 2) {
					$parent2_premium = ($parent2_premium_ratio_seh/$a27yo_premium_ratio_seh) * $a27yo_premium_seh * $seh_employee_contribution;
	  
				}
				$parent_cost_employer = 12*($parent1_premium + $parent2_premium);
				$family_cost_employer = $parent_cost_employer;
				for(my $i=1; $i<=5; $i++) {
					if ($in->{'child'.$i.'_age'} > -1 && ${'include_seh_child'.$i} == 1) {
						${'child'.$i.'_premium'} = (${'child'.$i.'_premium_ratio_seh'}/$a27yo_premium_ratio_seh) *$a27yo_premium_seh *12 * $seh_employee_contribution;
						$family_cost_employer += ${'child'.$i.'_premium'};
					}
				}
			}
		}
		if ($in->{'premium_tax_credit'} == 1 && ($out->{'percent_of_poverty'} <= $sub_maximum || $in->{'covid_ptc_expansion'} == 1) && ($out->{'percent_of_poverty'} >= $sub_minimum || $parent_greencard_premiums + $family_greencard_premiums > 0)) {
			if ($out->{'percent_of_poverty'} >= $sub_minimum) {
			# This follows IRS form 8962 in ensuring that maximum health coverage cost is the subsidized health care cost or the SLCSP, whichever is lower.
			# Note: This code, and the fed_hlth_insurance code, assumes that no one with access to employer plans and without eligibility for premium tax credits will elect a marketplace plan. This may be worth reassessing, as families in the "family glitch" may have cheaper health costs if one spouse remains on their employer plan while another takes on an unsubsidized marketplace plan. We may also be more easily able to address this by splitting up hlth_cov_parent to hlth_cov_parent1 and hlth_cov_parent2.
				$sub_parent_cost = &least($parent_cost_individual, $private_max);
				$sub_family_cost = &least($family_cost_individual, $private_max);
			} else {  # $parent_greencard_premiums + $family_greencard_premiums > 0) { 
			#Special case for green card holders, who are eligible for the PTC from 0% FPL - 100% FPL as well as the other income ranges. The presence of a greencard holder in the household who is not on Medicaid will result in the sum of these two variables being positive, otherwise it will be 0.
				#Separate costs of who has green cards and who does not. Individuls in the household who do not have green cards are still not eligible for premium tax credits if their income is below 100% FPL, so the family pays the full cost of  marketplace coverage for citizens. But greencard holders are able to file for the premium tax credit based on the premiums they pay and the poverty level of the home, potentially seeing reductions. In households completely composed of green card holders satisfying the above conditions, the first expression below (the subtraction) will be zero and the family will receive premium tax credits in a similar manner as eigible families above. 
				$sub_parent_cost = ($parent_cost_individual - $parent_greencard_premiums) + &least($parent_greencard_premiums, $private_max);
				$sub_family_cost = ($family_cost_individual - $family_greencard_premiums) + &least($family_greencard_premiums, $private_max);
			}
		} else {
			$sub_parent_cost = $parent_cost_individual;
			$sub_family_cost = $family_cost_individual;
		}
		
		if ($in->{'privateplan_type'} eq 'individual') {
			$family_cost = $sub_family_cost;
			$parent_cost = $sub_parent_cost;
		}

		# We then incorporate the ACA rule that employees whose employers don’t offer “affordable” health insurance can opt for the marketplace
		# rates, which could also include subsidies. Per healthcare.gov, “A job-based health plan is considered ‘affordable’ if the employee’s 
		# share of monthly premiums for the lowest-cost self-only coverage that meets the minimum value standard is less than 9.56% of their 
		# family’s income.” (This number was changed to 9.66% as of 2017.) While this approach could also be used for moving user-entered plans to marketplace plans (the code for that would 
		# be very similar to that below), we assume that a user-entered agent is not necessarily a rationally optimizing one and is sticking 
		# with those numbers for a reason. 

		if ($in->{'privateplan_type'} eq 'employer' || $in->{'privateplan_type'} eq 'smallgroup') {
			# Use 'Health' table in base tables to determine self_only_coverage for privateplan_type = employer. This number changes by state, and is included in the DC base tables.
			#We are excludign families with unqualified immmigrants from this option since we are modeling employer coverage of undocumented families. (Come back to this)
			if ($self_only_coverage > $out->{'max_income_pct_employer'} * $out->{'hlth_gross_income_m'} * 12 && $family_cost_employer > $sub_family_cost && $in->{'unqualified_immigrant_total_count'} == 0) {
				$familyswitch_dummy = 1;
				$family_cost = $sub_family_cost;
			} else {
				$family_cost = $family_cost_employer;
			}

			# We also recalculate parent_cost following similar rules. Parent_cost is only used to calculate health_expenses when children are covered by Medicaid, and nowhere else. So the below calculation will only have an effect on families when their children are covered by Medicaid, and their employer plans for adults in the family are unaffordable.
			if ($self_only_coverage > $out->{'max_income_pct_employer'} * $out->{'hlth_gross_income_m'} * 12 && $parent_cost_employer > $sub_parent_cost && $in->{'unqualified_immigrant_total_count'} == 0) {
				$parentswitch_dummy = 1;
				$parent_cost = $sub_parent_cost;
			} else {
				$parent_cost = $parent_cost_employer;
			}
		}
			
	} 
	
	#    4. Determine health insurance premiums and final coverage type
	#    Medicaid programs have no premiums.  CHP programs have premiums based on income ranges. 

	if ($hlth_cov_parent eq 'Medicaid') {
		$health_expenses = 0;
		#If all the parents are on Medicaid, all the children will be too, because either income will be lower than child Medicaid cut-offs (because parent income limits are higher than child ones) or because parents will be on SSI and therefore their income will be excluded from being counted toward Medicaid. 

	} elsif ($hlth_cov_child_all eq 'Medicaid' || $in->{'child_number'} == 0) { #All the kids are on Medicaid. 
		$health_expenses = $parent_cost;
		if ($in->{'privateplan_type'} eq 'user-entered') {
			if ($hlth_cov_parent ne 'Medicaid and private') {
				$hlth_cov_parent = $in->{'userplantype'};
			}
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				if (${'hlth_cov_parent'.$i} ne 'Medicaid') {
					${'hlth_cov_parent'.$i} = $in->{'userplantype'};
				}
			}
		} elsif ($parentswitch_dummy == 1) {
			if ($hlth_cov_parent ne 'Medicaid and private') {
				$hlth_cov_parent = 'individual';
			}
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				if (${'hlth_cov_parent'.$i} ne 'Medicaid') {
					${'hlth_cov_parent'.$i} = 'individual';
				}
			}
		} else {
			if ($hlth_cov_parent ne 'Medicaid and private') {
				$hlth_cov_parent = $in->{'privateplan_type'};
			}
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				if (${'hlth_cov_parent'.$i} ne 'Medicaid') {
					${'hlth_cov_parent'.$i} = $in->{'privateplan_type'};
				}
			}
		}
	} else { #At least some employer or marketplace costs are needed across adults and children. 
		$health_expenses = $family_cost;
		if ($in->{'privateplan_type'} eq 'user-entered') {
			if ($hlth_cov_parent ne 'Medicaid and private') {
				$hlth_cov_parent = $in->{'userplantype'};
			}
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				if (${'hlth_cov_parent'.$i} ne 'Medicaid') {
					${'hlth_cov_parent'.$i} = $in->{'userplantype'};
				}
			}
			
			if ($hlth_cov_child_all ne 'Medicaid and private') {
				$hlth_cov_child_all = $in->{'userplantype'};
			}
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				if (${'hlth_cov_child'.$i} ne 'Medicaid') {
					${'hlth_cov_child'.$i} = $in->{'userplantype'};
				}
			}
			
		} elsif ($familyswitch_dummy == 1) {
			if ($hlth_cov_parent ne 'Medicaid and private') {
				$hlth_cov_parent = 'individual';
			}
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				if (${'hlth_cov_parent'.$i} ne 'Medicaid') {
					${'hlth_cov_parent'.$i} = 'individual';
				}
			}

			if ($hlth_cov_child_all ne 'Medicaid and private') {
				$hlth_cov_child_all = 'individual';
			}
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				if (${'hlth_cov_child'.$i} ne 'Medicaid') {
					${'hlth_cov_child'.$i} = 'individual';
				}
			}

		} else {
			if ($hlth_cov_parent ne 'Medicaid and private') {
				$hlth_cov_parent = $in->{'privateplan_type'};
			}
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				if (${'hlth_cov_parent'.$i} ne 'Medicaid') {
					${'hlth_cov_parent'.$i} = $in->{'privateplan_type'};
				}
			}

			if ($hlth_cov_child_all ne 'Medicaid and private') {
				$hlth_cov_child_all = $in->{'privateplan_type'};
			}
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				if (${'hlth_cov_child'.$i} ne 'Medicaid') {
					${'hlth_cov_child'.$i} = $in->{'privateplan_type'};
				}
			}
		}
		
	}
	if($in->{'child_number'} == 0) {
		$hlth_cov_child_all = 'no children';
	}
	# We calculate premium_credit_recd, to use in the FRS charts.:
	if ($hlth_cov_child_all eq 'individual' && $in->{'privateplan_type'} ne 'user-entered') {
		$premium_credit_recd = $family_cost_individual - $sub_family_cost;
	} elsif ($hlth_cov_parent eq 'individual' && $in->{'privateplan_type'} ne 'user-entered') {
		$premium_credit_recd = $parent_cost_individual - $sub_parent_cost;
	} else {
		$premium_credit_recd = 0;
	}
	$health_expenses_before_oop = $health_expenses + $medicaidorchip_premiums;

	#The input variable hlth_costs_oop_m is generated in the BNBC through a separate PHP program (based on MEPS average cost data), but currently in the FRS, it reflects the out-of-pocket medical costs per household member. They are separate variable, aggregated in frs.pm.

	if ($in->{'bnbc_oop_flag'} == 1) {
		$health_expenses = $health_expenses_before_oop + (12 * $in->{'hlth_costs_oop_m'});
	} else {
	
		
		#Calculating premiums and health expenses per household member, important for SNAP and child support calculations:
		for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
			if (${'hlth_cov_parent'.$i} eq 'Medicaid' && $in->{'parent'.$i.'_age'} > 18) {
				${'parent'.$i.'_premium'} = 0;
			} elsif (${'hlth_cov_parent'.$i} eq 'Medicaid' && $in->{'parent'.$i.'_age'} == 18) {
				${'parent'.$i.'_premium'} = ($medicaidorchip_premiums / ($adult_child_medicaid_count + $child_medicaid_count)) / 12;
			} else {
				${'parent'.$i.'_premium'} = ($parent_cost / ($in->{'family_structure'} - $adult_medicaid_count) + ${'nongroup_nonmarketplace_cost_parent'.$i})/12;
				#LOOK AT ME: This oversimplifies marketplace coverage but really only when it is not covered by premium tax credits. When covered, the premium tax credits reduce total household medical expenses in a way that does not appear easily differentiated by household member.
			}
			#In NJ, companies operating Medicaid through Medicaid Managed Care arrangements cannot charge Medicaid enrollees any out-of-pocket costs such as deductibles or co-pays. Children receiving Medicaid as part of Plan C or Plan D (higher income families) can be billed a nominal $5-$10 co-pay for prescriptions. Since this reduces the out-of-pocket costs that families may pay while on Medicaid drastically, to a nominal level in most cases, we zero out out of pocket medical expenses for families on Medicaid.
			if (${'hlth_cov_parent'.$i} eq 'Medicaid') {
				${'parent'.$i.'_health_expenses'} = ${'parent'.$i.'_premium'}*12;
			} else { 
				${'parent'.$i.'_health_expenses'} = ($in->{'parent'.$i.'_hlth_costs_oop_m'} + ${'parent'.$i.'_premium'})*12;
			}
		}

		for(my $i=1; $i<=5; $i++) {
			if ($in->{'child'.$i.'_age'} > -1) {
				if (${'hlth_cov_child'.$i} eq 'Medicaid') {
					${'child'.$i.'_premium'} = ($medicaidorchip_premiums / ($adult_child_medicaid_count + $child_medicaid_count))/12;
				} else {
					${'child'.$i.'_premium'} = (($family_cost - $parent_cost) / ($in->{'child_number'} - $child_medicaid_count) + ${'nongroup_nonmarketplace_cost_child'.$i})/12;
					#LOOK AT ME: This oversimplifies marketplace coverage but really only when it is not covered by premium tax credits. When covered, the premium tax credits reduce total household medical expenses in a way that does not appear easily differentiated by  household member.
				}
				if (${'hlth_cov_child'.$i} eq 'Medicaid') {
					${'child'.$i.'_health_expenses'} = ${'child'.$i.'_premium'}*12;
				} else {
					${'child'.$i.'_health_expenses'} = ($in->{'child'.$i.'_hlth_costs_oop_m'} + ${'child'.$i.'_premium'})*12;
				}
			}
		}	

		#Redefine hlth_expenses based on the individualized health expenses defined above. This will adjust the health_expenses output to include out-of-pocket medical expenses.
		$health_expenses = $parent1_health_expenses + $parent2_health_expenses + $child1_health_expenses + $child2_health_expenses + $child3_health_expenses + $child4_health_expenses + $child5_health_expenses;
		
		# Medicaid Spend Down for Medically Needy Medicaid eligibility:
		# Now, we get even more complicated:
		
		if ($in->{'hlth'} == 1 && ($in->{'child_number'} > 0 || $in->{'disability_parent1'} + $in->{'disability_parent2'} > 0)) { 
		   # Medically Needy programs, or "spend down" programs, as this option is called in Kentucky, enrolls individuals into Medicaid when their income  is higher than Medicaid income limits, but is pushed down below Medicaid income  limits when subtracting health care costs. As a way to understand this program,  one can think about it as “buying into” the state’s Medicaid program, with the cost of that purchase the difference between current income and  the Medicaid income eligibility limit. That difference is the “share of cost” that families pay toward their medical bills before Medicaid covers the rest.
			
			#For the FRS's purposes, in NJ, the only groups that are eligible for MEdically Needy we are considering are children under 21 and people with disabilities. Pregnant women and people age 65 or older are also eligible but are not yet in the FRS.

			$health_expenses_afdc_pathway = $health_expenses; #We have to set this up here so that if the adults are only eligible through the MN SSI pathway, the codes use the accurate costs.

			$medically_needy_assets = $in->{'savings'};
			if ($in->{'family_structure'} == 2 && $out->{'parent2_transhours_w'} == 0) {
				#Cars are counted in assets if not needed to go to work or attend medical appointments. Users are only asked about a second car in 2-parent families.
				$medically_needy_assets  += &least(pos_sub($in->{'vehicle1_value'}, $in->{'vehicle1_owed'}), pos_sub($in->{'vehicle2_value'}, $in->{'vehicle2_owed'}));
			}

			$medically_needy_gross_income = $out->{'earnings_mnth'} + $out->{'interest_m'} + $out->{'ui_recd_m'} + $out->{'fli_plus_tdi_recd'}/12 + $out->{'gift_income_m'} + $out->{'ssi_recd_mnth'} + $out->{'child_support_paid_m'};
			
			if ($in->{'child_number'} > 0 || $in->{'parent1_age'} < 21 || $in->{'parent2_age'} < 21) {
				$medically_needy_unit_size = $in->{'family_size'} - $out->{'ssi_recd_count'};
				#"Any person who is in receipt of AFDC or SSI or who has applied for and been found eligible for regular Medicaid benefits related to those programs shall not be included in the budget unit of an AFDC-related case. Any person whose income and resources have been deemed to an eligible SSI beneficiary shall likewise not be included in the budget unit." -N.J. Admin. Code § 10:70-3.5.
				#This effectively ensure that children's medical expenses are covered in families where at least one adult in the home is receiving SSI.
				
				if ($out->{'parent1_ssi'} + $out->{'parent2_ssi'} == 1 && $in->{'family_structure'} == 2) {
					$medically_needy_unit_size  -=1;
				}
				
				$medically_needy_incomelimit = $medically_needy_incomelimit_array[$medically_needy_unit_size]; # Unlike how NJ excludes SSI recipients from its MAGI Medicaid program count, the budget unit under the "AFDC" group of Medically Needy eligibility is based on blood relations. it also excludes them from being counted in the Medically Needy budget unit.
				$medically_needy_assetlimit = $medically_needy_assetlimit_array[$medically_needy_unit_size]; 
				# We could incorporate the ABD program for Medicaid for adults who are blind or have a disability (ABD), and then use the income determinations from that to determine eligibiltiy for Medically Needy, but really what the ABD program does is provide Medicaid to people who receive SSI. Seems like the Medically Needy Spend-Down pathway is a way that people who have assets higher than the SSI limit but below the Medically Needy limit can get at least part of their health costs covered by the Medically Needy program.

				# There's also a separate eligibilty group for people who are blind (not yet included in the FRS), who we are not including here. 
							

				#We then deduct eligible deductions to arrive at the medically needy "net" income. We start with Child care deductions, the most complicated of these deductions. Parents employed part full time can deduct 200 from child care costs for children under 2, and 175 from other children or incapacitated adults. Parents employed part-time can deduct 150 of child care costs from children under 2, and 135 from other children.  These are per-child rates. Seems appropriate to use parent_workhours_w here, since that's the amount of child care needed related to the least-working adult in the home. I'd expect TANF-required training counts as work here or could be argued as such. Full-time work is defined as at least 30 hours per week, according to a reference elsewhere in the AFDC-Medicaid statutes.

				#Note that the child care expenses are not fully known by the time the hlth subroutine is first run. They are zeroed out in the parent_earnings code in order to get basic values and approximate potential Medically Needy Medicaid eligibility, but hlth is repeated after child_care is run, so that these values become actual. 

				for(my $i=1; $i<=5; $i++) {
					if ($in->{'child'.$i.'_age'} > -1) {
						
						if ($in->{'child'.$i.'_unqualified'} == 0 || $in->{'medicaidchip_all_immigrant_children'} == 1) { #Unlike NJ's MAGI Medicaid proogram, the statutes for its Medically Needy program align with TANF rules on barring legally present green card holders from participation for 5 years. The Cover All Kids policy agenda includes lifting this restriction, per NJCA's clarification.
							$medically_needy_eligible_expenses_afdc_pathway += ${'child'.$i.'_health_expenses'}; 
						}
						
						if ($out->{'parent_workhours_w'} >= 30) {
							if ($in->{'child'.$i.'_age'} < 2) {
								$medically_needy_childcare_deduction += &least(200, $out->{'cc_expenses_child'.$i}/12)
							} else { #older children or incapacitated adults (not yet included here)
								$medically_needy_childcare_deduction += &least(175, $out->{'cc_expenses_child'.$i}/12)
							}
						} else { #the least working parent works part-time.
							if ($in->{'child'.$i.'_age'} < 2) {
								$medically_needy_childcare_deduction += &least(150, $out->{'cc_expenses_child'.$i}/12)
							} else { #older children or incapacitated adults (not yet included here)
								$medically_needy_childcare_deduction += &least(135, $out->{'cc_expenses_child'.$i}/12)
							}
						}
					}
				}
				
				$medically_needy_earnedincome_deduction = &least(90, $out->{'parent1_earnings_m'}) + &least(90, $out->{'parent2_earnings_m'});
				$medically_needy_childsupport_deduction = &least(50, $out->{'child_support_paid_m'});
				
				$medically_needy_net_income = pos_sub($medically_needy_gross_income, $medically_needy_childcare_deduction + $medically_needy_earnedincome_deduction + $medically_needy_unearnedincome_deduction + $medically_needy_childsupport_deduction);

				if ($medically_needy_net_income - $health_expenses / 12 < $medically_needy_incomelimit && $medically_needy_assets < $medically_needy_assetlimit) {
					
					for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
						if ($in->{'parent'.$i.'_age'} < 21) {
							$medically_needy_eligible_expenses_afdc_pathway += ${'parent'.$i.'_health_expenses'};
							#Need to mark that we are potentially counting this adult's health expenses, so that we don't duplicate this reduction in costs when looking at young adults who are disabled, via the SSI-related Medically Needy pathway.						
							${'parent'.$i.'_potential_afdc_coverage'} = 1;
						}
					}
					
					#After figuring out what expenses can be covered by Medically Needy program, the below calculation (a) first separates the expenses ineligible for coverage under the Medically Needy Program, which is the difference between total health expenses and  the expenses potentially covered by Medically Needy Medicaid, and then (b) adds in the Medically Needy expenses up to the point that equals the difference between the budget unit's Medically Needy income calculation and the Medically Needy income limit. Any additional costs are covered by the Medically Needy Medicaid program.
					$health_expenses_afdc_pathway = pos_sub($health_expenses, $medically_needy_eligible_expenses_afdc_pathway) + &least(pos_sub($medically_needy_net_income * 12, $medically_needy_incomelimit * 12), $medically_needy_eligible_expenses_afdc_pathway);
					
					$health_expenses = $health_expenses_afdc_pathway;
					
					#For graphing purposes but also to confer categorical eligibility for other programs (like WIC), we determine whether some of the household's costs are, indeed, covered by the Medically Needy program.
					if ($medically_needy_eligible_expenses_afdc_pathway > pos_sub($medically_needy_net_income, $medically_needy_incomelimit)) {
						$medically_needy = 1;
						#What we are confirming below is that in cases where families qualify for AFDC-related Medically Needy assistance, any adult under 21 will covered by that program. Below, we will use this variable to prevent double-counting these costs among young adults who are disabled. 
						for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
							if (${'parent'.$i.'_potential_afdc_coverage'} == 1) {
								${'parent'.$i.'_afdc_coverage'} = 1;
							}
						}
					}
				}
			}
			
			if ($in->{'disability_parent1'} + $in->{'disability_parent2'} > 0) {
				#NOTE: a limitiation to the consideration of SSI-related Medically Needy determinationsis that we are assuming parents are paying for Medicaid for kids with disabilities who are not on SSI throught the Medically Needy AFDC pathway, not the SSI pathway. Families can optimize but the number of permutations to consider here are just too vast for now. Since the MNIL will be lower for the SSI-related category, it also may be  unlikely that someone who wasn't eligible for medical spend-down under the child option would be eligible or would have more costs that are eligible under the SSI-related category, but it does seem possible because of the significant disregards and deductions used in determining SSI eligibiltiy, which are used in the SSI-related category.


				$medically_needy_unit_size = $in->{'family_structure'}; #The kids are not counted as part of the budget unit in the SSI-related Medically Needy pathway.
				
				$medically_needy_incomelimit = $medically_needy_incomelimit_array[$in->{'family_structure'}]; 
				$medically_needy_assetlimit = $medically_needy_assetlimit_array[$in->{'family_structure'}]; 

				#N.J. Admin. Code § 10:71-5.3 bases its deductions, disregards, and deeming on SSI rules. So we can just use the ssi_income output from the SSI code for the net income amount. The SSI codes have since been revised to generate this variable regardless of whether the family receives SSI or whether they have selected SSI as a benefit flag:
				$medically_needy_net_income = $out->{'ssi_income'};
				
				if ($medically_needy_net_income - $health_expenses / 12 < $medically_needy_incomelimit && $medically_needy_assets < $medically_needy_assetlimit) {
					#Instead of using a for-loop like we do for AFDC-related Medically Needy eligibility for children, we can use several binary variables as dummy variables in one fell swoop, below;
					$medically_needy_eligible_expenses_ssi_pathway = $parent1_health_expenses * $in->{'disability_parent1'} * (1 - $in->{'parent1_unqualified'}) * (1 - $parent1_afdc_coverage) + $parent1_health_expenses * $in->{'disability_parent2'} * (1 - $in->{'parent1_unqualified'}) * (1 - $parent1_afdc_coverage); 
				}
				
				#Since this is run after the health expenses for the AFDC Medically Needy pathway is run, we can use that as the new health expenses calculation.
				$health_expenses = pos_sub($health_expenses_afdc_pathway, $medically_needy_eligible_expenses_ssi_pathway) + &least(pos_sub($medically_needy_net_income * 12, $medically_needy_incomelimit * 12), $medically_needy_eligible_expenses_ssi_pathway);
				
				#For graphing purposes but also to confer categorical eligibility for other programs (like WIC), we determine whether some of the household's costs are, indeed, covered by the Medically Needy program.
				if ($medically_needy_eligible_expenses_ssi_pathway > pos_sub($medically_needy_net_income, $medically_needy_incomelimit)) {
					$medically_needy = 1;
				}
				
			}
		}
	}
	
	#Finally, add in unqualified immigrant health costs. These are not regulated by Medicaid rules or ACA protections.
		
	$health_expenses_qualified_members = $health_expenses; 

	if ($in->{'privateplan_type'} eq 'individual' && $nongroup_nonmarketplace_cost_parent1 +  $nongroup_nonmarketplace_cost_parent2 +  $nongroup_nonmarketplace_cost_children > 0) { #Excluding user-entered plans and employer plans for now from this.
		$health_expenses += 12* ($nongroup_nonmarketplace_cost_parent1 +  $nongroup_nonmarketplace_cost_parent2 +  $nongroup_nonmarketplace_cost_children);
		if ($hlth_cov_child_all eq 'Medicaid') {
			$hlth_cov_child_all = 'Medicaid and private';
		} 		
	}

	# Start debug
	$hlth_plan = $in->{'hlth_plan'};
	# End debug

	# outputs
	foreach my $name (qw(firstrunchildcare hlth_cov_parent hlth_cov_child_all hlth_cov_child1 hlth_cov_child2 hlth_cov_child3 hlth_cov_child4 hlth_cov_child5 hlth_cov_parent1 hlth_cov_parent2 health_expenses premium_credit_recd health_expenses_before_oop parent_cost family_cost medically_needy
	child1_premium
	child2_premium
	child3_premium
	child4_premium	
	child5_premium
	nongroup_nonmarketplace_cost_parent1 
	nongroup_nonmarketplace_cost_parent2 
	nongroup_nonmarketplace_cost_child1 
	nongroup_nonmarketplace_cost_child2 
	nongroup_nonmarketplace_cost_child3 
	nongroup_nonmarketplace_cost_child4 
	nongroup_nonmarketplace_cost_child5 
	nongroup_nonmarketplace_cost_children 
	health_expenses_qualified_members 
	parent1_health_expenses
	parent2_health_expenses
	child1_health_expenses
	child2_health_expenses
	child3_health_expenses
	child4_health_expenses
	child5_health_expenses
	)) { 
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;