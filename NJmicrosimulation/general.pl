# "GENERAL" CODE, NJ 2021, for microsimulation analysis only. Derived from frs.pm code.

#=============================================================================#
#	INPUTS AND OUTPUTS NEEDED FROM OTHER CODES
#
#	INPUTS FROM FRS INPUTS FILE (incomplete list - fill this out eventually or as needed for debugging)
#		residence_nj
#		family_structure
#		child_number
#		housing_override
#		housing_override_amt
#		family_size
#
#=============================================================================#

# NOTE: Unlike other FRS codes, this code (like the frs.pm code in the online FRS) is only run once per family simulation. It defines a few variables needed for other codes to run, but is only run once per family, not over and over again as the value of family earnings increases.
sub general {

#TODO CSV LOOKUP: Need to include lookup of id by residence_nj in general_nj or elsewhere.
#TODO CSV LOOKUP: Need to figure out a way to code in bundles of policy changes based on policy_option in policy_option_profiles 

    my $self = shift; #It appears that the line my "$self = @_;" also does the same exact thing here. I'm not sure which is more efficient.
    my $in = $self{'in'};
    my $out = $self{'out'};

	# Defining the outputs generated in this module:


	#Need to figure out residence value from string data in data file. Note that this is one of the few variables here that is not a replication of the online frs.pm file, as, for the online FRS, residence id # has already been identified as an input through the PHP in the code.

	$sql = "SELECT id from FRS_Locations WHERE state = ? AND year = ? AND name = ?";
    my $stmt = $dbh->prepare($sql) ||
        &fatalError("Unable to prepare $sql: $DBI::errstr");
    my $result = $stmt->execute($in->{'state'}, $in->{'year'}, $in->{'residence_nj'}) ||
        &fatalError("Unable to execute $sql: $DBI::errstr");
    $in->{'residence'} = $stmt->fetchrow();
    $stmt->finish();

	#Fill out policy variables from policy_option_profiles lookup sheet.
	#NOTE TO CHONG: I'm modeling this lookup as if there was a SQL table for this list, so that if you find an easy find-and-replace soluation to chaneg all the SQL queries to csv queries, you can do the same here. There is no table like this in the current FRS MySQL database, though. I know there is also likely an easier way to do this for a csv file, similar to hwo the runfrsnj.pl extracts data from the ACS data sheet.

	foreach my $policy_option (qw(sanctioned exclude_abawd_provision covid_medicaid_expansion medicaidchip_all_immigrant_children restore_medicaid_premiums covid_fsp_work_exemption covid_ea_allotment remove_shelter_deduction_cap_alt minben_increase_alt minben_user_input covid_sfsp_sso_expansion covid_eitc_expansion covid_ctc_expansion covid_cdctc_expansion exclude_covid_ptc_expansion covid_ptc_ui_expansion covid_ui_expansion eitc_itin_alt eitc_alt state_eitc_user_input empire_state_ctc_alt tax_credit_alt tax_credit_user_input covid_broadband_benefit child_months_cont_alt months_cont_tanf_user_input onetime_tanfpayment_alt onetime_tanfpayment_user_input pct_increase_tanf_alt pct_increase_tanf_user_input cs_disregard_alt cs_disregard_full_alt housing_subsidy_tanf_alt earnedincome_dis_alt earnedincome_dis_user_input allow_immigrant_tanfeligibility_alt lower_state_workreq lower_state_childunder6_workreq waive_childunder1_workreq covid_ui_disregard expanding_cep_eligiblity_alt weekend_meals_alt ccdf_copay_alt ccdf_threshold_alt ccdf_threshold_user_input)) {
		$sql = "SELECT ".$in->{'alternate_policy_profile'}." from policy_option_profiles WHERE policy_option = ?";
		my $stmt = $dbh->prepare($sql) ||
			&fatalError("Unable to prepare $sql: $DBI::errstr");
		$stmt->execute($policy_option) ||
			&fatalError("Unable to execute $sql: $DBI::errstr");
		$in->{$policy_option} = $stmt->fetchrow();
	}
	
	#Alternatively, something like this, which is the basic set of commands for extracting data from frs_input csv file used in teh runfrsnj.pl file. But this needs work, hence commenting it out for now.
	
	#open(TEST3, '<', 'C:\Users\Bank Street\Dropbox\FRS\Perl\NJmicrosimulation\policy_option_profiles.csv') or die "Couldn't open policy options file $!";
	#while (my $line = <TEST3>) {
		# For now, during the code debugging phase, I am manually checking each variables needed and assigning its value based on the column in the input CSV code. Eventually, once the input names match, I plan to write a simple script that extracts the values based on column name instead of column number.
	#	my @fields = split "," , $line;

		#Tihs part is using the names in the first row to create a set of input names, and then using the order of those input names to assign the input values of the subsequent rows.
	#	if ($. == 1) {
	#		my $listorder = 0;
	#		foreach my $nameofinput (@fields) { 
	#			$inputs[$listorder] = $nameofinput;
	#			$listorder += 1;
	#		}
	#	} else {
	#		my $valueorder = 0;
	#		foreach my $name (@fields) {
	#			$self{'in'}->{$inputs[$valueorder]} = $name;
	#			$valueorder += 1;	
	#		}
	#	}
	#}
	
  # set general values
    $in->{'child_number'} = 0; 
	if ($in->{'year'} >= 2020) { #Beginning in 2020, we are allowing users to model families with no children.
		if($in->{'child1_age'} != -1) { $in->{'child_number'}++; $in->{'child1'} = 1; }        # first child
	} else {
		$in->{'child_number'}++; #Before 2020, simulators always assumed at least one child.
	}
    if($in->{'child2_age'} != -1) { $in->{'child_number'}++; $in->{'child2'} = 1; }        # second child
    if($in->{'child3_age'} != -1) { $in->{'child_number'}++; $in->{'child3'} = 1; }        # third child
	if($in->{'year'} >= 2017){ 
		if($in->{'child4_age'} != -1) { $in->{'child_number'}++; $in->{'child4'} = 1; }        # fourth child
		if($in->{'child5_age'} != -1) { $in->{'child_number'}++; $in->{'child5'} = 1; }        # fifth child
	}

	
    $in->{'family_size'} = $in->{'family_structure'} + $in->{'child_number'};
        
    $in->{'child1_under1'} = ($in->{'child1_age'} < 1 && $in->{'child1_age'} != -1 ? 1 : 0);
    $in->{'child2_under1'} = ($in->{'child2_age'} < 1 && $in->{'child2_age'} != -1 ? 1 : 0);
    $in->{'child3_under1'} = ($in->{'child3_age'} < 1 && $in->{'child3_age'} != -1 ? 1 : 0);
    $in->{'child4_under1'} = ($in->{'child4_age'} < 1 && $in->{'child4_age'} != -1 && $in->{'year'} >= 2017 ? 1 : 0); 
    $in->{'child5_under1'} = ($in->{'child5_age'} < 1 && $in->{'child5_age'} != -1 && $in->{'year'} >= 2017 ? 1 : 0); 

	$in->{'children_under1'} = $in->{'child1_under1'} + $in->{'child2_under1'} + $in->{'child3_under1'} + $in->{'child4_under1'} + $in->{'child5_under1'};

    $in->{'child1_under2'} = ($in->{'child1_age'} < 2 && $in->{'child1_age'} != -1 ? 1 : 0);
    $in->{'child2_under2'} = ($in->{'child2_age'} < 2 && $in->{'child2_age'} != -1 ? 1 : 0);
    $in->{'child3_under2'} = ($in->{'child3_age'} < 2 && $in->{'child3_age'} != -1 ? 1 : 0);
    $in->{'child4_under2'} = ($in->{'child4_age'} < 2 && $in->{'child4_age'} != -1 && $in->{'year'} >= 2017 ? 1 : 0); 
    $in->{'child5_under2'} = ($in->{'child5_age'} < 2 && $in->{'child5_age'} != -1 && $in->{'year'} >= 2017 ? 1 : 0); # 

    $in->{'children_under2'} = $in->{'child1_under2'} + $in->{'child2_under2'} + $in->{'child3_under2'} + $in->{'child4_under2'} + $in->{'child5_under2'};

    $in->{'child1_under6'} = ($in->{'child1_age'} < 6 && $in->{'child1_age'} != -1 ? 1 : 0);
    $in->{'child2_under6'} = ($in->{'child2_age'} < 6 && $in->{'child2_age'} != -1 ? 1 : 0);
    $in->{'child3_under6'} = ($in->{'child3_age'} < 6 && $in->{'child3_age'} != -1 ? 1 : 0);
	$in->{'child4_under6'} = ($in->{'child4_age'} < 6 && $in->{'child4_age'} != -1 && $in->{'year'} >= 2017 ? 1 : 0); # 5/8/18: added year condition so as not to affect pre-DC 2017 simulators.
    $in->{'child5_under6'} = ($in->{'child5_age'} < 6 && $in->{'child5_age'} != -1 && $in->{'year'} >= 2017 ? 1 : 0); # 5/8/18: added year condition so as not to affect pre-DC 2017 simulators.

	$in->{'children_under6'} = $in->{'child1_under6'} + $in->{'child2_under6'} + $in->{'child3_under6'} + $in->{'child4_under6'} + $in->{'child5_under6'};

    $in->{'child1_under13'} = ($in->{'child1_age'} < 13 && $in->{'child1_age'} != -1 ? 1 : 0);
    $in->{'child2_under13'} = ($in->{'child2_age'} < 13 && $in->{'child2_age'} != -1 ? 1 : 0);
    $in->{'child3_under13'} = ($in->{'child3_age'} < 13 && $in->{'child3_age'} != -1 ? 1 : 0);
    $in->{'child4_under13'} = ($in->{'child4_age'} < 13 && $in->{'child4_age'} != -1 && $in->{'year'} >= 2017 ? 1 : 0); 
    $in->{'child5_under13'} = ($in->{'child5_age'} < 13 && $in->{'child5_age'} != -1 && $in->{'year'} >= 2017 ? 1 : 0); 
	
    $in->{'children_under13'} = $in->{'child1_under13'} + $in->{'child2_under13'} + $in->{'child3_under13'} + $in->{'child4_under13'} + $in->{'child5_under13'};

    $in->{'child1_under17'} = ($in->{'child1_age'} < 17 && $in->{'child1_age'} != -1 ? 1 : 0);
    $in->{'child2_under17'} = ($in->{'child2_age'} < 17 && $in->{'child2_age'} != -1 ? 1 : 0);
    $in->{'child3_under17'} = ($in->{'child3_age'} < 17 && $in->{'child3_age'} != -1 ? 1 : 0);
	$in->{'child4_under17'} = ($in->{'child4_age'} < 17 && $in->{'child4_age'} != -1 && $in->{'year'} >= 2017 ? 1 : 0); 
    $in->{'child5_under17'} = ($in->{'child5_age'} < 17 && $in->{'child5_age'} != -1 && $in->{'year'} >= 2017 ? 1 : 0); 

	$in->{'children_under17'} = $in->{'child1_under17'} + $in->{'child2_under17'} + $in->{'child3_under17'} + $in->{'child4_under17'} + $in->{'child5_under17'};

    $in->{'parent_number'} = $in->{'family_structure'};

  # get the value of the rent -- we need fmr no matter what for the other expenses calculation
    my $sql = "SELECT rent FROM FRS_Locations WHERE state = ? AND year = ? AND id = ? AND number_children = ?";
    my $stmt = $dbh->prepare($sql) ||
        &fatalError("Unable to prepare $sql: $DBI::errstr");
    my $result = $stmt->execute($in->{'state'}, $in->{'year'}, $in->{'residence'}, $in->{'child_number'}) ||
        &fatalError("Unable to execute $sql: $DBI::errstr");
	$in->{'fmr'} = $stmt->fetchrow();
    if($in->{'housing_override'})
    {
        $in->{'rent_cost_m'} = $in->{'housing_override_amt'};
		$in->{'rent_cost'} = 12 *  $in->{'rent_cost_m'};
    }
    else
    {
        $in->{'rent_cost_m'} = $in->{'fmr'};
        $stmt->finish();
    }
	# set immigrant-related variables
	#calculate the number of household members not considered "qualified aliens" for TANF, CCDF, foster care, LIHEAP, Medicare, Medicaid (except assistance for emergency medical condition), CHIP, SSI, and refugee-specific HHS program. This is in accordance with PRWORA and HHS PRWORA guidance on programs for only qualified aliens: https://www.govinfo.gov/content/pkg/FR-1998-08-04/pdf/98-20491.pdf. SSI is not mentioned in this guidance but the definition of qualified alien for purposes of SSI mirrors that in the PRWORA: https://www.ssa.gov/ssi/text-eligibility-ussi.htm#qualified-alien.
	#qualified aliens in PRWORA defined as LPRs here for 5 or more years, U.S. citizens, refugees, asylees. See section 431 (defines qualified aliens) and section 402 (mentions 5 year ban) of PRWORA full text https://www.congress.gov/104/plaws/publ193/PLAW-104publ193.pdf. 
	#More info on this at NILC article: https://www.nilc.org/issues/economic-support/overview-immeligfedprograms/ NOTE: "Children who receive federal foster care and COFA migrants are exempt from the five-year bar in the Medicaid program." So this would need to be recalculated in the Medicaid module to ensure that we are not exempting any immigrant LPR children for less than 5 years in foster care from CHIP/Medicaid eligibility. The below child and parent inputs can be used for TANF, CCDF, and LIHEAP modules. The parent inputs can additionally be used for the Medicaid module. 
	

   foreach my $name (qw(unqualified_immigrant_total_count unqualified_immigrant_child_count newer_greencard_child_count undocumented_child_count daca_child_count  unqualified_immigrant_adult_count newer_greencard_adult_count undocumented_adult_count daca_adult_count disabled_older_children)) { 
        $in->{$name} = 0;
    }
	
	if ($in->{'year'} >= 2021) {
		for (my $i = 1; $i <= 5; $i++) { 
			if($in->{'child'.$i.'_age'} != -1) {
				if ($in->{'child'.$i.'_immigration_status'} eq 'undocumented_or_other' || $in->{'child'.$i.'_immigration_status'} eq 'daca' || $in->{'child'.$i.'_immigration_status'} eq 'newer_greencard') {
					$in->{'unqualified_immigrant_child_count'} += 1;
					$in->{'unqualified_immigrant_total_count'} += 1;
					$in->{'child'.$i.'_unqualified'} = 1; #flag for whether a child is considered a unqualified alien under PRWORA - will need to check for this and foster child status for eligibility for chip/medicaid and ssi.
				} else {
					$in->{'child'.$i.'_unqualified'} = 0;
				}
				if 	($in->{'child'.$i.'_immigration_status'} eq 'newer_greencard') {
					$in->{'newer_greencard_child_count'} += 1;
				}
				if ($in->{'child'.$i.'_immigration_status'} eq 'undocumented_or_other') {
					$in->{'undocumented_child_count'} +=	1;
				}
				if ($in->{'child'.$i.'_immigration_status'} eq 'daca') {
					$in->{'daca_child_count'} += 1;
				}
			}
		}
		
		for (my $i = 1; $i <= $in->{'family_structure'}; $i++)	{
			if($in->{'parent'.$i.'_age'} > 17) {
				if ($in->{'parent'.$i.'_immigration_status'} eq 'undocumented_or_other' || ($in->{'parent'.$i.'_immigration_status'} eq 'daca') || $in->{'parent'.$i.'_immigration_status'} eq 'newer_greencard') {
					$in->{'unqualified_immigrant_adult_count'} += 1;
					$in->{'unqualified_immigrant_total_count'} += 1;
					$in->{'parent'.$i.'_unqualified'} = 1; #flag for whether a parent is a qualified/unqualified immigrant under this rule. This is used in the edited LIHEAP code.
				} else {
					$in->{'parent'.$i.'_unqualified'} = 0;
				}
				if ($in->{'parent'.$i.'_immigration_status'} eq 'newer_greencard') {
					$in->{'newer_greencard_adult_count'} += 1;
				}
				if ($in->{'parent'.$i.'_immigration_status'} eq	'undocumented_or_other') {
					$in->{'undocumented_adult_count'} +=1;
				}
				if ($in->{'parent'.$i.'_immigration_status'} eq	'daca') {
					$in->{'daca_adult_count'} +=1;
				}
			}
		}


		#Counting the number of children with disabilities who are older than 13 (needed for child_care and ccdf calculations):
		for($i=1; $i<=5; $i++) {
			if($in->{'child'.$i.'_age'} >= 13) {
				if ($in->{'disability_child'.$i} == 1) { 
					$in->{'disabled_older_children'} += 1;
				}
			}
		}

		if ($in->{'bnbc_oop_flag'} == 0) { #This is necessary to avoid overriding the non-aggregated hlth_costs_oop_m variable in the BNBC.
			$in->{'hlth_costs_oop_m'} = 0;
			$in->{'disability_medical_expenses_mnth'} = 0;
			for(my $i=1; $i<=$in->{'family_structure'}; $i++) {
				$in->{'hlth_costs_oop_m'} += $in->{'parent'.$i.'_hlth_costs_oop_m'};
				if ($in->{'disability_parent'.$i} == 1) { 
					$in->{'disability_medical_expenses_mnth'} += $in->{'parent'.$i.'_hlth_costs_oop_m'};
				}
			}
			for($i=1; $i<=5; $i++) {
				if($in->{'child'.$i.'_age'} > -1) {
					$in->{'hlth_costs_oop_m'} += $in->{'child'.$i.'_hlth_costs_oop_m'};
					if ($in->{'disability_child'.$i} == 1) { 
						$in->{'disability_medical_expenses_mnth'} += $in->{'child'.$i.'_hlth_costs_oop_m'};
					}
				}
			}
		}
		
		#The rest of these expansions we assume will be affected by user choices, but we start by assigning them an "off" value of 0 in this code.
		#TEMPORARY - delete once these are set as inputs.	
		foreach my $name (qw(include_covid_policies_ending_1221 include_covid_policies_ending_0921 selfemployed_netprofit_total alimony_paid_m other_income_m unearn_gross_mon_inc_amt_ag parent1_ft_student parent2_ft_student parent3_ft_student parent4_ft_student parent1_pt_student parent2_pt_student parent3_pt_student parent4_pt_student gift_income_m)) { 
			$in->{$name} = $in->{$name} // 0;
		}

		#For defensive modeling we need to establish input variables as having values even if they were not checked in step 4.
		foreach my $name (qw(exclude_covid_ptc_expansion restore_medicaid_premiums)) { 
			$in->{$name} = $in->{$name} // 0;
		}
		
		#We also need to establish these policy modeling options as default options, since there is no checkboxes for them except the ones above that would negate them.
		foreach my $name (qw(covid_ptc_expansion eliminate_medicaidchip_premiums)) {  
			$in->{$name} = $in->{$name} // 1;
		}
		
		#Also add to inputs:

		if ($in->{'exclude_covid_ptc_expansion'} == 1) {
			$in->{'covid_ptc_expansion'} = 0;			#Of all the temporary changes due to COVID, we are treating the expansion of the premium tax credit to be one that cannot be changed. It lasts through the end of 2022. Maybe move this somewhere else
		} else {
			$in->{'covid_ptc_expansion'} = 1;			#Of all the temporary changes due to COVID, we are treating the expansion of the premium tax credit to be one that cannot be changed. It lasts through the end of 2022. Maybe move this somewhere else
		}

		#Same operation as above, but for defensive modeling of NJ's recent decision to eliminate Medicaid premiums, at least temporarily:
		if ($in->{'restore_medicaid_premiums'} == 1) {
			$in->{'eliminate_medicaidchip_premiums'} = 0;	
		} else {
			$in->{'eliminate_medicaidchip_premiums'} = 1;			#Of all the temporary changes due to COVID, we are treating the expansion of the premium tax credit to be one that cannot be changed. It lasts through the end of 2022. Maybe move this somewhere else
		}
		
	}
	
  # get state-specific values
    $sql = "SELECT fpl, smi, passbook_rate from FRS_General WHERE state = ? AND year = ? AND size = ?";
    my $stmt = $dbh->prepare($sql) ||
        &fatalError("Unable to prepare $sql: $DBI::errstr");
    my $result = $stmt->execute($in->{'state'}, $in->{'year'}, $in->{'family_size'}) ||
        &fatalError("Unable to execute $sql: $DBI::errstr");
    ($in->{'fpl'}, $in->{'smi'}, $in->{'passbook_rate'}) = $stmt->fetchrow();
    $stmt->finish();
	
    $sql = "SELECT fpl from FRS_General WHERE state = ? AND year = ? AND size = ?";
    my $stmt = $dbh->prepare($sql) ||
        &fatalError("Unable to prepare $sql: $DBI::errstr");
    my $result = $stmt->execute($in->{'state'}, $in->{'year'}, 1) ||
        &fatalError("Unable to execute $sql: $DBI::errstr");
    $in->{'fpl_1person'} = $stmt->fetchrow();
    $stmt->finish();
	
   $sql = "SELECT fpl from FRS_General WHERE state = ? AND year = ? AND size = ?";
     my $stmt = $dbh->prepare($sql) ||
        &fatalError("Unable to prepare $sql: $DBI::errstr");
    my $result = $stmt->execute($in->{'state'}, $in->{'year'}, 2) ||
        &fatalError("Unable to execute $sql: $DBI::errstr");
    $in->{'fpl_2people'} = $stmt->fetchrow();
    $stmt->finish();
	
	
	# outputs
	# Most variables described in this are used as inputs, but this is where we'd include outputs.

	#It seemed important in the NH 2021 codes to also create an fmr variable within the output set. Not sure why, may delete if found to be unncecessary. But should be harmless.
	$self{'out'}->{'fmr'} = $in->{'fmr'}; 


    foreach my $name (qw(residence 
	child_number
	child1
	child2
	child3
	child4
	child5
	family_size
	child1_under1
	child2_under1
	child3_under1
	child4_under1
	child5_under1
	children_under1
	child1_under2
	child2_under2
	child3_under2
	child4_under2
	child4_under2
	children_under2
	child1_under6
	child2_under6
	child3_under6
	child4_under6
	child5_under6
	children_under6
	child1_under13
    child2_under13
    child3_under13
    child4_under13
    child5_under13
 	children_under13
	child1_under17
	child2_under17
	child3_under17
	child4_under17
	child5_under17	
	children_under17
	fmr
	rent_cost_m
	rent_cost
	unqualified_immigrant_total_count unqualified_immigrant_child_count newer_greencard_child_count undocumented_child_count daca_child_count  unqualified_immigrant_adult_count newer_greencard_adult_count undocumented_adult_count daca_adult_count disabled_older_children	
	child1_unqualified
	child2_unqualified
	child3_unqualified
	child4_unqualified
	child5_unqualified					
	parent1_unqualified
	parent2_unqualified
	hlth_costs_oop_m
	disability_medical_expenses_mnth
	include_covid_policies_ending_1221 include_covid_policies_ending_0921 selfemployed_netprofit_total alimony_paid_m other_income_m unearn_gross_mon_inc_amt_ag parent1_ft_student parent2_ft_student parent3_ft_student parent4_ft_student parent1_pt_student parent2_pt_student parent3_pt_student parent4_pt_student gift_income_m
	exclude_covid_ptc_expansion restore_medicaid_premiums
	fpl smi passbook_rate
	fpl_1person
	fpl_2people
	)) { 
		$self{'in'}->{$name} = $in->{$name}; #Note this is again similar, but slightly different, than how the online Perl codes are set up. The above line is identical, though. The online Perl codes read as follows: " $out->{$name} = ${$name} || ''; ".
	}
	
	return(%self); # Note this is also diffferent from the online version of the codes, which has the following return: "return(0);". It's unclear how this could work online, but it does.

}

1;
