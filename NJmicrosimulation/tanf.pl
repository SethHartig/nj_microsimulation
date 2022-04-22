#=============================================================================#
#  TANF – 2021 NJ - adapated from KY 2020
#=============================================================================#
# Inputs and outputs referenced in this module:
#
#	INPUTS NEEDED:
#	tanf
#	ccdf
#	child_number
#	family_size
#	family_structure
#	disability_parent				#For NJ, we should also add an input to determine whether the parent with the disability can care for a child and/or work, rather than making an assumption (see below). 
#	disability_personal_expenses_m
#	child#_age
#	sanctioned
#	savings
#	tanfwork
#	onetime_tanfpayment_alt  		#policy flag for: Policy Change: Model a one-time payment of $____ to all TANF recipients?
#	onetime_tanfpayment_user_input	#amount of one time payment if policy flag for: Policy Change: Model a one-time payment of $____ to all TANF recipients? default is $1700
#	pct_increase_tanf_alt			#policy flag for whether users choose to input a change in tanf benefits based on % of FPL
#	pct_increase_tanf_user_input	#policy flag for: Policy Change: Change TANF benefits by a percentage of the federal poverty level (current benefits are ~30% of FPL for a family of three)to __% FPL.
#	cs_disregard_alt				#policy modeling flag for: Policy Change: Model increasing the child support pass through to $200 (currently $100) for families with two or more children? Users should NOT be allowed to select both this and cs_disregard_full_alt below.
#	cs_disregard_full_alt			#policy modeling flag for: Policy Change: Allow TANF recipients to receive the full amount of child support?
#	child_months_cont_alt			#policy modeling flag for:	Allow children whose parents are sanctioned to recieve TANF benefits, for ___ months.
#	months_cont_tanf_user_input		# Policy change: Allow children whose parents are sanctioned to recieve TANF benefits, for ___ months.
#	earnedincome_dis_alt			# policy modeling flag for: Change the TANF earned income disregard from 50 to ___ %.
#	earnedincome_dis_user_input		#Policy Change: Change the TANF earned income disregard from 50 to ___ %.
#	allow_immigrant_tanfeligibility_alt 	#Policy Change: Allow all lawfully present immigrant children and parents to be eligible for TANF?
#	spousal_support_ncp
#
#	OUTPUTS NEEDED:
#
#	FROM PARENT_EARNINGS
#	earnings
#	earnings_mnth
#	parent#_earnings_m
#	parent2_max_hours_w
#	parent#_transhours_w
#	shifts_parent#
#	multipleshifts_parent#
#
#	FROM SSI
#	ssi_recd
#	ssi_recd_count
#
#	FROM CHILD_SUPPORT
#	child_support_paid_m	#in NJ, standard child support pass through is $100/month
#
#	FROM CHILD_CARE
#	unsub_child#
#
#	FROM FOSTER CARE
#		foster_children_count
#	
#	POLICY MODELING OPTIONS
#		allowing immigrants to be eligible for this
#		allowing children to be eligible for this past the five year limit and if parents are noncompliant
#		allow employed families to receive full TANF benefits for 2 months
#		exclude rule-abiding parents from 5-yr TANF limit
#		one time payment of $1700 to TANF recipients (in effect in July 2021)
#
#	SOURCES
#	NJ state plan for TANF FFY 2021-2023: https://www.state.nj.us/humanservices/providers/grants/public/publicnoticefiles/NJ%20TANF%20State%20Plan%20FFY%2021%20-%20FFY%2023%20DRAFT.pdf 
# NJ WorkFirst Handbook: https://www.state.nj.us/humanservices/dfd/programs/workfirstnj/wfnj_handbook1219.pdf 
#NJ Administrative Code: https://nj.gov/state/dos-statutes.shtml and : https://casetext.com/regulation/new-jersey-administrative-code/ Title 10 - Chapter 90 - Work First NJ Program.  
#Maximum allowable income eligibility and benefit payment levels for assistance units eligible for WFNJ benefits appear at N.J.A.C. 10:90-3.
#=============================================================================#

sub tanf 
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};


	# POLICY VARIABLES:         
    our $tanf_asset_limit = 2000;       # TANF asset limit for NJ (same as KY)
	# Upon review of administrative code and TANF state plan - 
	our $cs_disregard = 100; # maximum child support pass-through per month in NJ
	our $max_passthrough_claims = 2; #See explanation below. The highest number of children claimed for the child support pass-through is 2, according to Maura Sanders. Following up to see where she got this from.
    our $earnedincome_dis= .5; 	#The earned income disregard, reducing countable income above the amount of the work expense deduction by this portion of earnings. For NJ 2021: "In computing the monthly cash assistance benefit, WFNJ/TANF allows for the application of certain disregards for earned income. If a recipient is employed 20 hrs+/week, 100% of gross earned income is disregarded for the full month, 75% is disregarded for 6 months and 50% is disregarded for each additional month of employment thereafter." NJ Admin Code 10:90-3.8. For now we are only programming in the 50% earned income disregard. Earned income disregards not applicable to sanctioned ppl. 
	our @tanf_maxben_array = (0,214,425,559,644,728,814,894); #UPDATED for NJ 2021. Redetermination level - The unit continues to be eligible if countable income is less than applicable benefit level. (Note: in terms of redetermination, "countable" income includes the reductions in income from various deductions and disregards, which is why the max benefit level is lower than the initial income at determination.   https://www.state.nj.us/humanservices/providers/grants/public/publicnoticefiles/NJ%20TANF%20State%20Plan%20FFY%2021%20-%20FFY%2023%20DRAFT.pdf , but see note below. This usage of the term "countable" is also helpful in understanding the below interpretations of policy regarding ongoing recipient eligibility and treatment of child support.
	our @tanf_maxben_array_nochildren = (0,185,254); #Employable ABAWDs and couples without children are eligible for NJ Work First General Assistance services and cash assistance (see NJ Admin Code 10:90-3.2 and 10:90-3.5) but an updated schedule of benefits (Schedules III and IV) did not accompany the latest state plan or the one from 2018-19. s of January 2022, thee benefit levels in Schedule IV, for ABAWDS/Couples without children, had not been updated beyond the $140 and $193 levels that were seemingly part of this initial legislation, but were included in INFORMATIONAL TRANSMITTAL NO.: 19-21, provided to us by Maura Sanders at Legal Services New Jersey. The updated benefit levels on this page https://bcbss.com/general-assistance/.  
	#Note that We will not be using the eligibility/max benefit payment levels for WFNJ/FA unemployable single adults and couples without dependent children because we assume that unemployable single adults and couple would be on SSI, as their benefits would be higher than on TANF.

	#Additional policy variables, further described in work.pl:
	our $workreq_age_limit = 62;
	our $tanf_abawd_workreq = 30;
	our $singleparent_childunder6_workreq = 30;
	our $singleparent_nochildunder6_workreq = 30;
	our $twoparent_mostworking_nonpooled_workreq = 30;
	our $twoparent_leastworking_nonpooled_workreq = 20;
	our $twoparent_mostworking_nochildcare_nonpooled_workreq = 35;
	our $twoparent_leastworking_nochildcare_nonpooled_workreq = 30;

	#ALTERNATIVE POLICY VARIABLES:
	our $cs_disregard_amt_alt = 200; #related to policy modeling option for increasing child support pass through to $200 from $100 for families with 2 or more children. 

	#defined in macro:
    our $tanf_perchild_cc_ded_pt = 0;    # Max per child care deduction, for employment less than 30 hrs/week - NJ does not appear to have any child care deductions. 
	our $tanf_perchild_cc_ded_ft = 0;    # Max per child care deduction, for employment at least 30 hrs/week - NJ does not appear to have any cc deductions
    our $tanf_under2_cc_ded = 0;       # Additional per child care deduction for child < 2 -NJ does not appear to have any cc deductions 
	#our $medicaid_fmap = 0; #The Medicaid matching rate. This was written in for KY - the portion of escrow child support that KY pays the federal government; the remainder is passed through to the family. - this does not appear to apply in NJ. 
	our $passthrough_max = 0; # maximum child support pass-through per month - nj has a pass through max of $100, but it is written in the below using the cs_disregard variable (as it is called a disregard in policy), rather than this variable. 
	our $optimize_cs = 0;	#flag for whether the state or this program forces a family receiving child support and TANF to opt for receiving child support when child support is greater than potential TANF cash assistance. - This does not appear to happen in NJ. You receive your full child support payment once you are off welfare and are working. (see TANF state plan and handbook).

	#OUTPUTS
	our $tanf_recd  = 0;    
    our $tanf_recd_m    = 0;    
    our $child_support_recd = 0;    
    our $child_support_recd_m   = 0;
  	our $tanf_sanctioned_amt = 0;     

	#INTERMEDIARY VARIABLES
	our $tanf_maxben = 0;
    our $tanf_sanctioned_amt = 0; 	 # The amount a family receiving at least some TANF cash assistance has lost because at least one member of the household is on sanctions.
	our $ratable_reduction_pct = 0; # percent reduction from the TANF net income limit that generates TANF receipt. -  zero-d out for NJ, not applicable.
	our $workexpense_ded = 0; 	#The first income deduction, of up to the first $90 earned per TANF unit member. NJ does not appear to have a deduction like this.
	our $tanf_stipend_amt = 0;  
	# our $sanction_reduction = 0; 	#The percentage reduction of a family’s TANF grant when work requirements are not met. Some states reduce TANF cash assistance by a percentage for sanctioned family. We're keeping this in here for now in order to eventually universalize the code. The below code also allows for a "sanctioned" input that we are not including below, because toggling tanf = 1 or 0 effectively does this, at leat for now (1/14/20). For states for which we're not modeling TANF sanctions or that do not impose TANF sanctions that reduce TANF cash assistance receipt,  we can hard-code this to 0 or comment it out, as we've done here. This is important for all states because SNAP benefits are affected by the TANF cash assistance that a family on TANF would have received, even if sanctions reduce the cash assistance to 0. See below discussion of sanctions in NJ.
	our $tanf_incapacity_exlcusion = 0; #Some states like DC exclude incapacitated adults from the TANF unit regardless of the status of any SSI application (or at least that's how this was modeled in 2017). KY and NJ seem to only exclude incapacitated adults if the family successfully attains SSI for these disabilities. To account for potential state differences in an effort to make the TANF code more universal, we are keeping this variable in here as a potential policy option. SSI recipients are not eligible for TANF benefits in NJ.
	# 	our $tanfworkbonus_approx = 200;	 # Approximate TANF work bonus for DC in 2017. There was actually a formula for this, but at the request of DC DHS we initially used $600 as an approximate bonus, then after further consultation with DC DHS, decided to reduce this approximation to $200. Commenting this out for 2020 and 2021 -- although it was interesting to try to model in 2017, it became clear that modeling it was problematic. Conceivably it could help smooth out a cliff on a temporary basis.
	our $tanf_fulltime_hrs = 0; #the number of hours considered full time for the TANF child care deduction. Not applicable for NJ, because there is no child care deduction.
	our $tanf_recd_proxy = 0; #Setting this to zero as another binary variable, so that the SSI code can use it initially to assume all parental income is excluded because of assumed TANF receipt (because this variable will be an output variable in parent_earnings, set at 1), at first run. Once TANF eligibiltiy and benefit receipt is determined, in this code, outputs below redefine the tanf_poxy variable to 0, so that the ssi code for children can use the real tanf_amounts. This sequence will have the effect of maximizing SSI at first, resulting in possibly excluded individuals from TANF receipt in this code, which will either have no change on TANF benefits in this code or increase the possibility of receipt, but if at the end of this code tanf_recd equals 0, parental income will be reincluded in child SSI calculations, which may result in a recalculation against child SSI receipt, resulting in higher TANF benefits when this code is recalculated after the second run of SSI.
	
	# CALCULATED IN MACRO
    our $parent2_incapacitated = 0;
    our $tanf_family_structure = 0;
    our $unit_size = 0;
	our $child1_care_tanf_m = 0;
	our $child2_care_tanf_m = 0;
	our $child3_care_tanf_m = 0;
	our $child4_care_tanf_m = 0;
	our $child5_care_tanf_m = 0;	
    our $tanf_cc_ded_recd = 0;          # tanf child care deduction
    our $tanf_earned_ded_recd = 0;      # earned income deduction
    our $tanf_earnings = 0;             # adjusted (monthly) earnings for tanf benefits, after child care and earnings ded
	our $tanf_income = 0;            # Normally, adjusted (monthly) income for tanf benefits. KY has several income definitions, though, so we are excluding this variable to make the code more readable. This was coded back in for NJ 2021
	our $tanf_gross_income = 0;
	our $tanf_net_income_nocc_ded = 0;
	our $tanf_net_income_cc_ded = 0;
    our $tanf_excluded_income = 0; 	# parental income excluded from TANF calculations when parent is on SSI.
    our $tanf_parent1_earnings_m = 0; 	# non-excluded parent 1 earnings
    our $tanf_parent2_earnings_m  = 0;	# non-excluded parent 2 earnings
	# our $tanf_earned_ded_entry = 0; 	# Represents income deduction for entry requirements. There is no separate income test at entry compared to exit for KY, so we are commenting this out for now. 
	#our $tanf_earnings_entry = 0;		# Represents earnings calculation for entry. There is no separate income test at entry compared to exit for KY, so we are commenting this out for now. For NJ, there is a separate income test at entry (150% of the max benefit), but we are not including this at this time. 					   
    our $parent1_exactworkdays = 0; # This variable was used in the DC code to help model the impact of transportation subsidies in their TANF program. Although there appears to be no transportation subsidies for TANF recipients in KY, this may be a useful variable, so we are keeping it in the model for now.
    our $parent2_exactworkdays = 0; # 
    our $stipend_perday = 6; # Transportation subsidies. (KY didn't have transportation subsidies, but DC did, at $15.) NJ has transportation allowances of up to $6 a day for people who need it and participate in WFNJ work or work readiness activities (and have no other source of support) "Employed post-TANF recipients are eligible for a subsidized bus or train pass. These services are funded as separate State program expenditures and counted as MOE". LOOK AT ME: Need to figure out for how long they receive this stipend and if it should be forever as long as the new user option askign whether family has been on TANF in last two years is selected. Also see bug - this shoudl be moved to a separate module. 
	our $tanflock = $out->{'tanflock'};	#Pertains to the correct calculation of child care expenses used for families that use child support, which the codes clarify as acual child care expenses. See separate documentation for why we are using this.
	our $unit_fpl = 0;
	our $tanf_child_number = 0;
	our $meetsworkreq = 0;
	our $tanf_children_under1 = 0;
	our $tanf_children_under6 = 0;
	our $tanf_oneparent_id = 0;
	our $tanf_recd_debug1 = 0;
	our $tanf_recd_debug2 = 0;


	#Redefining some work requrement variables with policy options. #LOOK AT ME: Need to includethese conditions in tanf.pl as well:
	if ($in->{'lower_state_childunder6_workreq'} == 1) {
		# S541 would change $singleparent_childunder6_workreq to 20
		$singleparent_childunder6_workreq = 20;
	}
	if ($in->{'lower_state_workreq'} == 1) {
		# S541 would change other work requirements from 40 to 30. 
		$twoparent_mostworking_nochildcare_nonpooled_workreq = 30;
	}

	# ADDITIONAL VARIABLES DEFINED BY NON-INCOME BASED INPUTS:

	#if ($in->{'family_structure'} == 2 && $in->{'disability_parent2'} == 1 && $out->{'parent2_max_hours_w'} == 0) {
	#	$parent2_incapacitated = 1; #OLD NOTE: NEED TO CHANGE THIS VARIABLE TO AN INPUT RATHER THAN AN OUTPUT CALCULATED HERE: For 2020, we are changign this variable to allow parents with disabilities in 2-parent families to take care of children at home; rendering them as incapacitated would mean that they need care and are unable to care for their children. It should be an input. It is logical that a second parent with a non-incapacitated disablity may choose to stay at home while the second parent is working in order to take care of the children and reduce child care costs. We need it in the TANF code in KY (and likely some other states) because incapacitated parents can receive TANF dependent care deductions. In some states, they are also automatically excluded from the family unit, regardless of whether they are registered for SSI or SSDI. 2021 NOTE: See bugs doc; this seems only relevant to ccdf. So commenting this out until further clarification of what, if anything, is needed for ccdf code to work derivable from tanf.
	#}		
	 
	# Any individual on SSI are excluded from the TANF unit (I believe across all TANF programs, but at least in KY and DC AND NJ). So we exclude their income for TANF calculations and remove the parent receiving SSI from the family unit. 
	
	#For NJ 2021: 
	
	#REMOVING DISABLED INDIVIDUALS AND CERTAIN IMMIGRANTS FROM ASSISTANCE UNITS: children receiving SSI and ineligible immigrants are removed from TANF assistance units. See NJ admin. Code 10:90-2.8 https://casetext.com/regulation/new-jersey-administrative-code/title-10-human-services/chapter-90-work-first-new-jersey-program/subchapter-2-non-financial-eligibility-requirements/section-1090-28-individuals-ineligible-for-wfnj-tanfga
	
	#NATIVE RESIDENTS: the only mention of native residents is in the state plan, in that the STate "will provide each member of an Indian tribe...and not eligible for assistance under a Tribal Family Assistance Plan...with equitable acess to assistance under ths State program.." - page 55 of state plan.
	
	#LOOK AT ME re felony convictions: Individuals convicted of a drug felon on or after Aug 22, 1996 convicted of any offense committed on or after 8/22/96 are not eligible (unless they enroll in and actively participant in RSATP (?) and certified as drug free).  Juvenile drug convinctions not classified as felonies, high misdemeanors or crimes - this is not grounds for ineligibility for WFNJ or NJ SNAP benefits. NEED TO DISCUSS. See NJ Admin Code 10:90-18.6 https://casetext.com/regulation/new-jersey-administrative-code/title-10-human-services/chapter-90-work-first-new-jersey-program/subchapter-18-substance-abuse/section-1090-186-eligibility-rules-for-convicted-drug-felons 


	#set up the default options before any exclusions. Some of these variables are adjusted below, depending on the characteristics of household members.
	$tanf_child_number = $in->{'child_number'}; #start by assigning all children to the tanf family unit.
	$tanf_children_under1 = $in->{'children_under1'};
	$tanf_children_under6 = $in->{'children_under6'};
	$unit_size = $in->{'family_size'};
	$tanf_family_structure = $in->{'family_structure'};
	$tanf_parent1_earnings_m = $out->{'parent1_earnings_m'};
	$tanf_parent2_earnings_m = $out->{'parent2_earnings_m'};	   
	
	#Check for policy modeling option to increase pass through to $200.
	if ($in->{'cs_disregard_alt'} == 1) {
		$cs_disregard = $cs_disregard_amt_alt;
	}
	
	if ($out->{'ssi_recd'} > 0 || $in->{'unqualified_immigrant_total_count'} > 0 || $out->{'foster_children_count'} > 0) { #"Any child for whom a payment or subsidy is received from CP&P, including, but not limited to, a resource family care payment, guardianship subsidy, or adoption subsidy, shall not be included in the eligible assistance unit. Such child's parent(s) may be eligible to receive cash assistance for himself or herself and all other eligible children in the household." - 
		for (my $i = 1; $i <= 5; $i++)	{
			if ($out->{'child'.$i.'_ssi_recd'} > 0 || $in->{'child'.$i.'_foster_status'} >= 1 || $in->{'child'.$i.'_immigration_status'} eq 'undocumented_or_other' || ($in->{'allow_immigrant_tanfeligibility_alt'} == 0 && ($in->{'child'.$i.'_immigration_status'} eq 'daca' || $in->{'child'.$i.'_immigration_status'} eq 'newer_greencard'))) { 
				#"Any child for whom a payment or subsidy is received from CP&P, including, but not limited to, a resource family care payment, guardianship subsidy, or adoption subsidy, shall not be included in the eligible assistance unit. Such child's parent(s) may be eligible to receive cash assistance for himself or herself and all other eligible children in the household." - NJAC 10:90 2.7
				#POLICY OPTION: Allow lawfully present immigrant children and parents, including DACA recipients, to be eligible for TANF? and who otherwise meet TANF eligibility standards. States can use state funds but not federal TANF funds for those immigrants who were made ineligible or excluded for five years under the 1996 law. 
				$unit_size -= 1;
				$tanf_child_number -= 1;
				if ($in->{'child'.$i.'_age'} == 0) {
					$tanf_children_under1 -= 1;
				} 
				if ($in->{'child'.$i.'_age'} < 6) {
					$tanf_children_under6 -= 1;
				}
			}
		}
		
		for (my $i = 1; $i <= $in->{'family_structure'}; $i++)	{
			if ($in->{'parent'.$i.'_immigration_status'} eq 'undocumented_or_other' || ($in->{'allow_immigrant_tanfeligibility_alt'} == 0 && ($in->{'parent'.$i.'_immigration_status'} eq 'daca' || $in->{'parent'.$i.'_immigration_status'} eq 'newer_greencard'))) { #POLICY OPTION: Allow lawfully present immigrant children and parents, including DACA recipients, to be eligible for TANF? and who otherwise meet TANF eligibility standards. States can use state funds but not federal TANF funds for those immigrants who were made ineligible or excluded for five years under the 1996 law. 
				$unit_size -= 1;
				$tanf_family_structure -= 1;
			} elsif ($out->{'parent'.$i.'_ssi'} == 1) { # removed "|| $in->{'parent'.$i.'_unqualified'} == 1" condition here, because: # unqualified immigrants are not eligible for ssi.
				$unit_size -= 1;
				$tanf_family_structure -= 1;
				#N.J. Admin. Code § 10:90-3.12: (d) If the noneligible individual is an illegal alien parent or noneligible alien parent and has citizen or eligible alien children, his or her income shall be considered available to the eligible assistance unit and shall be calculated in accordance with the parent to minor parent deeming formula at 10:90-3.16 at initial determination and redetermination of eligibility. See https://casetext.com/regulation/new-jersey-administrative-code/title-10-human-services/chapter-90-work-first-new-jersey-program/subchapter-3-financial-eligibility-income-resources-benefits/section-1090-312-treatment-of-income-and-resources-from-eligible-and-noneligible-individuals-in-the-wfnj-tanfga-household-as-appropriate. 
				$tanf_excluded_income += $out->{'parent'.$i.'_earnings_m'};
				#Redefine parent earnings as 0 for this parent.
				${'tanf_parent'.$i.'_earnings_m'} = 0;
				if ($i == 1) {#if parent1_ssi == 1
					$tanf_excluded_income += $out->{'spousal_support_ncp'}/12; #the FRS assumes that spousal support is paid to parent 1.
				}
			}
		}		
	} 

	#Determine the appropriate TANF maximum benefit amount based on unit size and whether children are in the TANF household unit.
	if ($tanf_child_number > 0) { 
		$tanf_maxben = $tanf_maxben_array[$unit_size];  # max TANF benefit (monthly)	
	} else {
		$tanf_maxben = $tanf_maxben_array_nochildren[$unit_size]; #utilizing ongoing eligibility formula/levels 
	}
	
	if($in->{'tanf'} == 0 || $unit_size == 0 || $in->{'child_number'} == $out->{'foster_children_count'}) { #FOSTER CHILDREN: Included in individuals who are ineligible for assistance and not considered to be member of the assistance units: "A resource family parent who is unable to prove a legal or blood relationship with a child in resource family care, (as defined at N.J.A.C. 10:90-2.7(a)1), when there are no other eligible children in the household;" - a resource family parent is NJ's term for foster parents.  - See NJAC 10:90-2.8
		$tanf_recd = 0;
		$tanf_recd_m = 0;
		$child_support_recd = $out->{'child_support_paid_m'} * 12; 
		$child_support_recd_m = $out->{'child_support_paid_m'}; 					
	

	# 1. PERFORM TANF ASSET TEST
	#																		 
	} elsif($in->{'savings'} > $tanf_asset_limit) { 
		#NOTE: Of the assets defined as resources in WFNJ/TANF, only savings is currently included in the FRS. Income tax refunds are exempt, along with SSI benefits and EITC.
		$tanf_recd = 0;
		$tanf_recd_m = 0;
		$child_support_recd = $out->{'child_support_paid_m'} * 12; 
		$child_support_recd_m = $out->{'child_support_paid_m'}; 
		
	} else {
		$sql = "SELECT fpl from FRS_General WHERE state = ? AND year = ? AND size = ?";
		my $stmt = $dbh->prepare($sql) ||
			&fatalError("Unable to prepare $sql: $DBI::errstr");
		my $result = $stmt->execute($in->{'state'}, $in->{'year'}, $unit_size) ||
			&fatalError("Unable to execute $sql: $DBI::errstr");
		$unit_fpl = $stmt->fetchrow();
		$stmt->finish();

		#POLICY MODELING OPTION FOR NJ: recalculate tanf benefit according to user entered input on % of fpl for unit size. according to unit size for policy modeling. 
		if ($in->{'pct_increase_tanf_alt'} == 1) {
			#Recalculate fpl according to unit size, rather than family_size. 

			$tanf_maxben = ($unit_fpl/12)*($in->{'pct_increase_tanf_user_input'}/100);
		}			#
		#NJ 2021: If a recipient is employed 20 hrs+/week, 100% of gross earned income is disregarded for the full month, 75% is disregarded for 6 months and 50% is disregarded for each additional month of employment thereafter. For now we are only programming in the 50% earned income disregard. Earned income disregards not applicable to sanctioned ppl.  
		# 2. CALCULATE DEPENDENT CARE DEDUCTION (TANF_CC_DED_RECD)
		# Different states calculate the TANF dependent care deduction differently, or don't have one. NJ doesn't have one. If deciding to put this deduction back into the code, KY 2020 has a recent version of this deduction in Perl. 
	
		#
		# 3. CALCULATE EARNED INCOME DEDUCTION
		#Removing the below potential policy changes for now 
		#if($in->{'workexpense_ded_alt'}) { 
		#	$workexpense_ded = $in->{'workexpense_ded_user_input'};
		#}
		if($in->{'earnedincome_dis_alt'}) {
			$earnedincome_dis = ( $in->{'earnedincome_dis_user_input'} / 100 );
		}
				 
		$tanf_earned_ded_recd = &least($tanf_parent1_earnings_m, ($workexpense_ded + (&pos_sub($tanf_parent1_earnings_m, $workexpense_ded) * $earnedincome_dis)));
		if($in->{'family_structure'} == 2) {
			$tanf_earned_ded_recd += &least($tanf_parent2_earnings_m, ($workexpense_ded + (&pos_sub($tanf_parent2_earnings_m, $workexpense_ded) * $earnedincome_dis))); #for NJ 2021, workexpense_ded is zero-d out and should not affect the above code.
		}				

		# 4. INCOME TEST FOR RECIPIENTS

		# We need to reduce the TANF income of this group by the income of the adults receiving SSI. 
		
		#Notes on interpretation of child support:
			#Child support paid is included in initial determiniation of eligibility.
			#Once eligibility is established, the intial TANF benefit amount disregards $50 (in KY) of any escow child support income. Since we are unable to calculate escrow child support at the point of initially determinig a TANF cash assistance amount (see below), the below code is based on a $0 escrow amount. Adjustment to account for the escrow amount will be made later in this code.

		#INCOME TEST FOR ONGOING ELIGIBILITY: 
		#NJ 2021: "Once initial financial eligibility is determined, as long as the total countable income of a WFNJ/TANF or WFNJ/GA assistance unit (with benefit of the appropriate disregards at N.J.A.C. 10:90-3.8 for earned income) is less than the maximum benefit payment level for the appropriate eligible assistance unit size in accordance with Schedule II at N.J.A.C. 10:90-3.3, Schedule IV at N.J.A.C. 10:90-3.5 or Schedule V at N.J.A.C. 10:90-3.6, as appropriate, financial eligibility shall exist until such income equals or exceeds the maximum benefit payment level for the appropriate unit size except for cases with earned income that are subject to six-month reporting requirements. Such cases need not report changes in earned income until such time as the assistance unit's total income exceeds 130 percent of the Federal Poverty Level (FPL) as published by the Department of Health and Human Services in the Federal Register. However, if the assistance unit does report a change, the county/municipal agency shall act on that change." 
		$tanf_gross_income = &pos_sub($out->{'earnings_mnth'} + $out->{'interest_m'} + $out->{'ui_recd'} + $out->{'fli_plus_tdi_recd'} + $in->{'spousal_support_ncp'}/12, $tanf_excluded_income);  
		#countable income in NJ - child support, commissions, earnings, alimony, interest, ui. and exclude the income from SSI recipients and unqualified immigrants from this income, but only earned and unearned income is counted in recipient eligibility. Child support amounts do not appear to be considered. This is consistent with  the wording of the state plan, it seems that child support is considered initially, but since not all child support is passed through to the parent, it is not income that the parent gets and therefore cannot be counted as income.
			
		#Re child support not being counted here, see §10:90-3.8(h): "An eligible assistance unit in receipt of child support income is eligible for a disregard of up to $ 100.00 per month provided that the total amount of child support received for that month is less than the monthly WFNJ grant amount. After an assistance unit has passed the initial eligibility test indicated in 10:90-3.1(b) and is verified as being in receipt of child support, the following disregards shall apply: 1. If the amount of child support verified as being received is less than $ 100.00 per month, the assistance unit shall receive the actual amount of child support received and the actual amount received shall be disregarded when calculating the cash assistance benefit; or 2. If the amount of child support verified as being received is $ 100.00 or more per month, the assistance unit shall receive $ 100.00 and that $ 100.00 shall be disregarded when calculating the cash assistance benefit. The total amount of child support disregarded shall not exceed $ 100.00 per month per eligible assistance unit." Child support payments up to the the pass-through amount is disregarded from determining the TANF amount (but included for the purposes of eligibility.) Seems that this supports code that makes tanf_recd_m = 0 when child_support_paid_m exceeds tanf_recd_m and  removal of child_support_m from tanf_gross_income. This is because even though child support is treated as income in determining initial eligibility, it is seized by the state after and only provided to recipients as a pass-through, and that pass-through is disregarded from tanf income. Maura Sanders from LSNJ confirmed that child support income is used to determine ongoing eligibility, but not the benefit amount. We compare child support to tanf amounts in later parts of the code, to zero out tanf when the calculated cash asssistnace is lower than the potential child support received.

		#Keeping the indents here even though the commenting out of this check against gross income has also been commented out. If there's agreement on removing this gross income test, will remove indents; if not, will remove the commenting out of the condition.
		
		#if($tanf_gross_income >= $tanf_maxben && $tanf_gross_income > $unit_fpl * 1.3) { 
			#$tanf_recd = 0;
			#$tanf_recd_m = 0;	

			#Initially had this check when checking recipient eligibility for tanf. However, upon further review, it seems clear that the check here is that "total countable income" includes earned income AFTER disregards are applied, as indicated in the above definition of the TANF max benefit arrray. So the statement below that "financial eligibility shall exist until such income equals or exceeds the maximum benefit..." is simply a mathematical statement rather than an additional test. In this sense, for TANF recipients, the variable "tanf_income" below is a measure of "total countable income" referenced in § 10:90-3.1(c), as follows:
			
			# § 10:90-3.1(c) Once initial financial eligibility is determined, as long as the total countable income of a WFNJ/TANF or WFNJ/GA assistance unit (with benefit of the appropriate disregards at 10:90-3.8 for earned income) is less than the maximum benefit payment level for the appropriate eligible assistance unit size in accordance with Schedule II at 10:90-3.3, Schedule IV at 10:90-3.5 or Schedule V at 10:90-3.6, as appropriate, financial eligibility shall exist until such income equals or exceeds the maximum benefit payment level for the appropriate unit size except for cases with earned income that are subject to six-month reporting requirements. Such cases need not report changes in earned income until such time as the assistance unit's total income exceeds 130 percent of the Federal Poverty Level (FPL) as published by the Department of Health and Human Services in the Federal Register. However, if the assistance unit does report a change, the county/municipal agency shall act on that change.
			#The  130% threshold is only for people facing a 6-month reporting requirement, according to NJAC § 10:90-3.1. From state plan FFY 2021, p21: "New Jersey requires that recipients report all changes that may affect their eligibility within 10 days of the date of the change except for cases with earned income that are subject to simplified reporting requirements. Only assistance units with countable earned income are eligible for simplified reporting. Such cases need not report changes in earned income until such time as the assistance unit’s total income exceeds 130 percent of the Federal Poverty Level (FPL) or until the next redetermination, whichever occurs first." N.J. Admin. Code § 10:90-3.22 indicates redeterminations occur at least once per year. So we should really not be including the check against 130% FPL. What this means is that for TANF recipients with earned income, increases in earned income do not affect TANF benefit amounts for a maximum of 6 months, but no longer than that.
			
		#} else { #See above explanation; there is no gross income test separate from the determination of benefit amount being greater than 0 for recipients, except with regard to child support, described futher below.
			
			$tanf_income = &pos_sub($tanf_gross_income, $tanf_earned_ded_recd); 
	 
			# 5. CALCULATE TANF BENEFIT LEVEL FOR ELIGIBLE RECIPIENTS
			#
			# The tanf_recd_m calculation must be a rounded-down difference between tanf_maxben and tanf_earnings. for NJ 2021, it is the rounded down difference between the tanf_maxben and tanf_income. 
			
			#Otherwise, calculate TANF received based on the TANF income calculations:
			#if ($tanf_net_income_nocc_ded < $tanf_standardofneed) {
			
			use POSIX; #Perl's POSIX package -- part of the normal Perl distribution -- has a floor function that rounds down. Not sure if this "use" invocation is necessary since I think POSIX may carry over codes, and it's used earlier than this tanf subroutine.
			
			$tanf_recd_m = floor(&pos_sub($tanf_maxben, $tanf_income));
			$tanf_recd_debug1 = 	$tanf_recd_m;
			# We now reduce a family’s TANF grant if they are under sanctions. Not modeling this in KY or NJ.
			#if ($sanction_reduction > 0) {
			#	if ($in->{'sanctioned'}) {
			#		$tanf_sanctioned_amt = $sanction_reduction*$tanf_recd_m;
			#		$tanf_recd_m = (1- $sanction_reduction)*$tanf_recd_m;
			#	}
			#}
			# Note: We can now also account for TANF transportation stipends, which are actually subsidies rather than reimbursements. 
						
			# DC NOTE, possibly helpful for NJ: We can take an average to approximate the transit stipends, although this might be worth looking at more closely because in some cases, a parent might be working much more on one day than on the next day, but because of how we model shifts, might not get the transportation stipend for that long day. It’s probably worth comparing this to the child care hours to make sure we’re not missing anything, or if this code should be more complicated. Per conversation with DC DHS 7/20, we are only modeling travel stipends when parent(s) in the family is/are not working, but are in training. Because parent1_transhours_w and parent2_transhours will always end up being 0 at the $0 earnings level, so during the first run of tanf, stipend_amt (here tanf_stipend_amt to universalize the code - SH note for NJ) will always be 0. After that first run, the work module may increase these amounts depending on whether the family follows tanf work requirements. The below calculation will then shift upward if the family is indeed following work requirements.
			
			
			#Eventually, this stipend_amt part should be added to the code that we're planning to add for other stipends or tanf bonuses, maybe just something like "tanf_stipends." It shouldn't really be here because it seems to apply to at least some TANF exiters as well as current TANF recipients.
			if ($tanf_family_structure == 0) {
				$tanf_stipend_amt = 0; #child-only tanf recipients should not be receiving work expense allowances. 
			} elsif ($tanf_recd_m > 0 && $stipend_perday >0 && $out->{'parent1_transhours_w'} + $out->{'parent2_transhours_w'} > 0) { #Changed from making "travelstipends" an input to just whether there's a positive stipend per day, to universalzie this code.
				if ($out->{'shifts_parent1'}>0 && $in->{'parent1_unqualified'} == 0) { 
					$parent1_exactworkdays = ceil($out->{'shifts_parent1'} - $out->{'multipleshifts_parent1'}); 
					if ($out->{'parent1_transhours_w'} / $parent1_exactworkdays >= 4) { 
						$tanf_stipend_amt = $stipend_perday * $parent1_exactworkdays * 4.33; #changed from 15 to stipend_perday
					} 
				} 
				if ($out->{'shifts_parent2'}>0 && $in->{'parent2_unqualified'} == 0) { 
					$parent2_exactworkdays = ceil($out->{'shifts_parent2'} - $out->{'$multipleshifts_parent2'}); 
					if ($out->{'$parent2_transhours_w'} / $parent2_exactworkdays >= 4) { 
						$tanf_stipend_amt += $stipend_perday * $parent2_exactworkdays * 4.33; #changed from 15 to stipend_perday 
					} 
				}
			}
						
		#} #remove once poliy interpretation si confirmed.
		#
		#programming in sanctions for NJ 2021:
		$tanf_recd_debug2 = $tanf_recd_m;


		#Establishing the tanf_oneparent_id variable, which is helpful for work requirement calculations:
		
		if ($tanf_family_structure == 1) {
			if ($in->{'family_structure'} == 1) {
				$tanf_oneparent_id = 1;
			} elsif ($in->{'family_structure'} == 2) {
				#Determine which parent not to count:
				for(my $i = 1; $i <= $in->{'family_structure'}; $i++) {
					if ($in->{'parent'.$i.'_ssi'}  == 0 && $in->{'parent'.$i.'_unqualified'} == 0) {
						$tanf_oneparent_id = $i;
					}
				}
				
				if ($tanf_oneparent_id == 0) { #if this id has not been assigned, the policy change to allow recent greencard holders to receive TANF needs to be incorporated here.
					for(my $i = 1; $i <= $in->{'family_structure'}; $i++) {
						if ($in->{'parent'.$i.'_ssi'}  == 0 && $in->{'parent'.$i.'_immigration_status'} ne	'undocumented_or_other' && $in->{'parent'.$i.'_immigration_status'} ne	'daca') {
							$tanf_oneparent_id = $i;
						}
					}
				}
			}
		}
		
		if ($in->{'sanctioned'} == 1) {
			# THE REVISED QUESTION FOR WHETHER SANCTIONED == 1 IS WHETHER THE HOUSEHOLD IS ON SANCTIONS "IF THEY DON'T MEET TANF WORK REQUIREMENTS". PERHAPS THE NAME OF VARIABLE SOULD BE ADJUSTED. BUT ASSUMING THAT WE WANT TO KEEP THAT WORDING AND ACTUALLY WANT TO MODELT THAT, WE SHOULD BUILD IN A CHECK ABOVE HERE FOR WHETHER THE FAMILY MEETS WORK REQUIREMENTS THAT PROBABLY REPEATS MUCH OF THE LOGIC EVENTUALLY IN THE WORK PL MODULE. WE CAN THEN OUTPUT THAT CHECK AS $meetsworkreq = 1 or 0, AND SET IT AUTOMATICALLY TO 1 WHEN $in->{'tanfwork'} == 1, SINCE THE WORK MODULE WILL ADD EXTRA HOURS IN THAT CASE. BUT OTHERWISE, WE'D TEST HERE WHETHER THE FAMILY MEETS WORK REQUIREMENTS. THEN, HERE AND BELOW, REPLACE THE CONDITION "if ($in->{'sanctioned'} == 1" WITH "if ($in->{'sanctioned'} == 1 &&  $meetsworkreq == 1)" Seth is building this in to the code after working on work pl.
			#The sanctioned input was used for KY 2020, and this type could be revived for NJ with the language: "Is the household sanctioned due to noncompliance with work activities?". "In an assistance unit with one adult, if the adult fails to cooperate with the program or participate in work activities without good cause, the cash assistance benefit provided to the assistance unit shall be reduced by the pro-rata share of the noncompliant adult for one month." For now, we are simply zero-ing out the household's tanf benefit because it gets complicated with months. See https://casetext.com/regulation/new-jersey-administrative-code/title-10-human-services/chapter-90-work-first-new-jersey-program/subchapter-4-wfnj-work-requirements/section-1090-413-sanctions for policy guidance.
			if ($in->{'tanfwork'} == 1 || ($tanf_children_under1 > 0 && $in->{'waive_childunder1_workreq'} == 1)) {
				$meetsworkreq = 1;
			} else {
				
				#See notes in work about these justifications:
				if ($tanf_child_number == 0) {
					$meetsworkreq = 1; #may revise this later on: just setting this binary variable to 1 in this case, then to 0 if any of the conditions for either potential adult in the home do not satisfy work requirements. 
					
					#TANF ABAWD WORK REQUIREMENTS
					if ($in->{'parent1_ssi'} + $in->{'disability_parent1'} == 0 && ($in->{'parent1_unqualified'} == 0 || ($in->{'parent1_immigration_status'} eq 'newer_greencard' && $in->{'allow_immigrant_tanfeligibility_alt'} == 1)) && $in->{'parent1_age'} < $workreq_age_limit && $out->{'parent1_employedhours_w'} < $tanf_abawd_workreq)  { 
						$meetsworkreq = 0;
					}
					#Test for parent 2:
					if ($in->{'parent2_age'} > 17 && $in->{'parent2_ssi'} + $in->{'disability_parent2'} == 0 && ($in->{'parent2_unqualified'} == 0 || ($in->{'parent2_immigration_status'} eq 'newer_greencard' && $in->{'allow_immigrant_tanfeligibility_alt'} == 1)) && $in->{'parent2_age'} < $workreq_age_limit && $out->{'parent2_employedhours_w'} < $tanf_abawd_workreq)  { 
						$meetsworkreq = 0;
					}
					
					
				} elsif ($tanf_family_structure == 1) {
					# If a single parent with a child younger than 12 months old, parent is not subject to TANF work requirements. This is true in DC, KY, and possibly a federal rule. (Previous DC code assumed that for parents under 20,  the child is under 12 weeks old, exempting them from school attendance requirements. This seems like an ill-founded assumptino.)  
					if($tanf_children_under1 > 0  || $in->{'parent'.$tanf_oneparent_id.'_age'} >= $workreq_age_limit) { 
						$meetsworkreq  = 1; 
					} elsif($tanf_children_under6 > 0) { #In a state where parents with children under 6 have different work requirements than children that do not, this will need ot be recalculated based on children eligible for TANF. But in NJ, it doesn't matter.
						if ($out->{'parent'.$tanf_oneparent_id.'_employedhours_w'} >= $singleparent_childunder6_workreq) { #In NJ, parents with children under 6 have to work just as much as parents with children over 6. When we add in a state that treats these parents differently, we may have to build in a rule here to determine whether the child is part of the TANF family unit or not, but that rule search is irrelevant in NJ since the age does not matter.
							$meetsworkreq = 1;
						} else {
							$meetsworkreq = 0;
						}
					} else { #no child under 6.
						if ($out->{'parent'.$tanf_oneparent_id.'_employedhours_w'} >= $singleparent_nochildunder6_workreq) { #In NJ, parents with children under 6 have to work just as much as parents with children over 6. When we add in a state that treats these parents differently, we may have to build in a rue here to determine whether the child is part of the TANF family unit or not, but that rule search is irrelevant in NJ since the age does not matter.
							$meetsworkreq = 1;
						} else {
							$meetsworkreq = 0;
						}
					}
				} else { #family structure = 2, a 2-parent family. No parents are excluded from TANF.
					#"Each parent in a two-parent WFNJ/TANF family shall be required to participate in one or more activities for a minimum of 35 hours per week up to a maximum hourly total of 40 hours per week, unless otherwise deferred in accordance with 10:90-4.9." -NJ administrative codes. Deferrals includes individuals ages 62 or older and individuals certified as being medically or mentally unable to work.
					if ($in->{'parent1_age'} >= $workreq_age_limit && $in->{'parent2_age'} >= $workreq_age_limit) {
						#Both parents are over the age limit and therefore do not have to satisfy work requirements.
							$meetsworkreq = 1;
					
					# See work.pl module: $workreq_pooling_policy = 0. So we are skipping conditions for meeting work requirements when work requiremennts can be pooled. 
					} else { #if (($in->{'disability_parent1'} + $in->{'disability_parent2'} == 0) && $in->{'children_under13'} > 0) { #See note in work.pl for why disability and children_under13 are ignored here.
						if ($out->{'parent1_employedhours_w'} >= $out->{'parent2_employedhours_w'}) {
							#Parent 1 completes all the work rquirements.
							if ($in->{'parent2_age'} >= $workreq_age_limit) {
								#Since parent2 is over the age limit, they do not have to do work requirements, and parent 1 does not see an uptick in their work requirements. 
								if ($out->{'parent1_employedhours_w'} >= $singleparent_nochildunder6_workreq) {
									$meetsworkreq = 1;
								} else {
									$meetsworkreq = 0;
								}
							} else { 
								if($tanf_children_under6 > 0) { #In NJ, parents with children under 6 have to work just as much as parents with children over 6, but when child care would be needed for the second parent in a couple to work (when the first parent is working partially to satisfy TANF work requirements), the work requirements for one parent can be reduced by those child care hours, essentially reducing from 35 to 20. While we could try to loop back child care need variables derived from the child_care code, including child care needed during the summer vs. non-summer weeks, etc., we are using a simplified proxy here of whether the child is under 6 to model this rule. It seems safe to assume that when that first parent needs to attend nonpaid work activities to satisfy work requirements, those work requirements will be offered during the school day, meaning it seems difficult for the "second" parent in this situation to take advantage of this clause to claim that child care was used in this manner.
									if ($out->{'parent1_employedhours_w'} >= $twoparent_mostworking_nonpooled_workreq && $out->{'parent2_employedhours_w'} >= $twoparent_leastworking_nonpooled_workreq) {
										$meetsworkreq = 1;
									} else {
										$meetsworkreq = 0;
									}										
								} else {
									if ($out->{'parent1_employedhours_w'} >= $twoparent_mostworking_nochildcare_nonpooled_workreq && $out->{'parent2_employedhours_w'} >= $twoparent_leastworking_nochildcare_nonpooled_workreq) {
										$meetsworkreq = 1;
									} else {
										$meetsworkreq = 0;
									}										
								}
							}
						} else { #parent 2 works more than parent 1.
							if ($in->{'parent1_age'} >= $workreq_age_limit) {
								if ($out->{'parent2_employedhours_w'} >= $singleparent_nochildunder6_workreq) {
									$meetsworkreq = 1;
								} else {
									$meetsworkreq = 0;
								}
							} else { 
								if($in->{'children_under6'} > 0) { 
									if ($out->{'parent2_employedhours_w'} >= $twoparent_mostworking_nonpooled_workreq && $out->{'parent1_employedhours_w'} >= $twoparent_leastworking_nonpooled_workreq) {
										$meetsworkreq = 1;
									} else {
										$meetsworkreq = 0;
									}										
								} else {
									if ($out->{'parent2_employedhours_w'} >= $twoparent_mostworking_nochildcare_nonpooled_workreq && $out->{'parent1_employedhours_w'} >= $twoparent_leastworking_nochildcare_nonpooled_workreq) {
										$meetsworkreq = 1;
									} else {
										$meetsworkreq = 0;
									}										
								}
							}
						}
					}
				}
			}

			if ($meetsworkreq == 0) {
				$tanf_recd_m = 0;
				$tanf_recd = 0;
				$child_support_recd_m = $out->{'child_support_paid_m'};
				$child_support_recd = $child_support_recd_m *12;
			}
		}				
		#POLICY MODELING OPTION: modeling continuing benefits for child if parents gets sanctioned. Current policy is that if an adult fails to cooperate with program/work activities without good cause, the tanf benefit is reduced by the pro-rata share of the noncompliant adult for one month. If they fail to be in compliance by the end of the month, the assistance unit's case is suspended (no cash assistance in 2nd month out of compliance). If they fail to be in compliance by the end of the 2nd month, their case is closed and they will have to reapply for tanf benefits. This option models continuing benefits for the child(ren) of the assistance unit if the parent(s) are sanctioned and allows the user to enter the number of months for which the children can get continued benefits (up to 12 months). 
		
		#The below code currently assumes that when sanctioned, both parents are sanctioned in a two parent tanf assistance unit, although the policy allows for only one parent to be sanctioned and reduction of the tanf benefit by the pro-rata share of the noncompliant adult only. However, for the sake of not adding another question (which parent is sanctioned), we assume both parents are sanctioned if this policy option is selected and there are two parents in the tanf unit.

		#AS indicated above the main thing we need to change here is determining which, if any, parents meet work requirements and adjusting this code to reduce benefits by the pro rata share of each parent on sanctions. If we do the work requirement check I outline above, that will be relatively straightforward. This will test whether both parents are on sanctions or not.
		
		if ($in->{'sanctioned'} == 1 && $meetsworkreq == 1 && $in->{'child_months_cont_alt'} == 1 && $in->{'months_cont_tanf_user_input'} > 0) { 
			$tanf_sanctioned_amt = $tanf_family_structure * ($tanf_recd_m/$unit_size);
			$tanf_recd_m = $tanf_recd_m - $tanf_sanctioned_amt;	
			$tanf_recd = $in->{'months_cont_tanf_user_input'} * $tanf_recd_m; #user can enter how many months (up to 12) children in a sanctioned unit can continue receiving tanf benefits after parent(s) are sanctioned. proposed question to user: "Adopt policy change: Continue tanf benefits for children of sanctioned households. Enter the number of months for continued benefits (between 1-12)".
		} 
	}

	# 6. CALCULATE FINAL TANF RECEIVED AND CHILD SUPPORT RECEIVED

	#policy modeling option to allow full amt of child support to pass through to assistance unit.
	if ($in->{'cs_disregard_full_alt'} == 1) { 
		$child_support_recd_m = $out->{'child_support_paid_m'};
	} else {
		#The following calculations are consistent with Maura Sanders from LSNJ's description of this, and with NJAC 10:90-3.1(c). According to §10:90-3.8(h) (copied and pasted above), a family is eligible to receive this child support disregard as long as the amount of child support received falls below the the tanf grant amount. So we make tanf_recd_m = 0 when child_support_paid_m exceeds tanf_recd_m, and remove child_support_paid_m from tanf_gross_income, calculated above. This is because even though child support is treated as income in determining initial eligibility, it is seized by the state after and only provided to recipients as a pass-through, and that pass-through is disregarded from tanf income.
		if ($out->{'child_support_paid_m'} > $tanf_recd_m) {
			$tanf_recd_m = 0;
			$child_support_recd_m = $out->{'child_support_paid_m'};
		} elsif ($tanf_recd_m > 0) { 
			
			#Calculate child support received via NJ's pass-trhough policy:
			$child_support_recd_m = least($cs_disregard * &least($out->{'cs_child_number'}, $max_passthrough_claims), $out->{'child_support_paid_m'}); 
			# Email from Maura Sanders at Legal Services New Jersey: "For current recipients, the first $100 per child, received in [child support] a month, is turned over to the family.  (so for a parent and 1 child, it’s $100 per month.  For a parent and 2 children, it’s $200 per month.  For a parent with 3 or more children, it’s still $200 per month.)" Not in statutes, so trying to see where she got this from.

		} else { #It is likely this following last calcuation is only invoked to redefine child_support_recd_m as equal to child_support_paid_m when the latter is equal to 0 and tanf_recd is also equal to 0. 
			$child_support_recd_m = $out->{'child_support_paid_m'}; 
		}
	}
	
	$tanf_recd = 12 * $tanf_recd_m;
	$child_support_recd =  $child_support_recd_m * 12; 		
	
	#POLICY MODELING OPTION: modeling the one time $1700 payment to TANF recipients for COVID relief. 
	if ($in->{'onetime_tanfpayment_alt'} == 1 && $tanf_recd_m > 0){
		$tanf_recd = (12 * $tanf_recd_m) + $in->{'onetime_tanfpayment_user_input'};
	}		

	# Note: In DC, in order to avoid a nonsensical scenario in which the second run of child_support leads to increased child_support_paid_m due to  higher child care needs, with that increase enough to make tanf_recd = 0, we adjust the variable tanflock that is initially set to 0 in the parent_earnings code. Otherwise, a family could have been e paying for increased child care need to satisfy TANF work requirements without actually receiving TANF. What this means in terms of our model is that we had been assuming that the court system will not increase a child support order to the point that a family whose child care needs are increased due to TANF work requirements will end up losing eligibility for TANF cash assistance. That seemed like a reasonable assumption for DC. However, it appears that in KY, the child care calculation in the child support would not include training undertaken solely to maintain TANF eligibilty. "The court shall allocate between the parents, in proportion to their combined monthly adjusted parental gross income, reasonable and necessary child care costs incurred due to employment, job search, or education leading to employment, in addition to the amount ordered under the child support guidelines." (from KY statute 403.211, at https://apps.legislature.ky.gov/law/statutes/statute.aspx?id=47691). It is unclear whether "education leading to employment" would include training to satisfy TANF work requirements. It would be fairly punitive if it did not. This is something to clarify with Kris at KYSTATS, but for now we are assuming that it does include training, especially since the calculation for CCDF allows child care coverage to include coverage for TANF training. Otherwise, the court would never include TANF-mandated additional training hours when determinig chid support need. See note below for more about this loop.
	
	# We also set tanflock to 1, so that child_support_recd is only recalculated if the family is first found ineligible for TANF.

	# We then invoke the earlier tanflock variable to make sure that TANF is not lost due to changes in child support and child care need. Because reverting TANF to 0 due to TANF work requirements adjusting the values of those, this avoids the nonsensical result of a family working more to satisfy TANF work requirements while not on TANF. It may be easier for us to simply use $out->{'tanf_recd'}>0 as the condition here instead of tanflock = 1.
		
	#See note in defaults: deciding against use of tanflock for now.
	#if ($out->{'tanflock'} == 1 && $tanf_recd_m == 0) {
	#	foreach my $name (qw(tanf_recd tanf_recd_m child_support_recd child_support_recd_m parent2_incapacitated tanf_family_structure unit_size tanf_stipend_amt tanflock tanf_recd_proxy tanf_sanctioned_amt)) { #These should match the outputs below, so any additions to those variables should be reflected in this line. 
	#		${$name} = $out->{$name};
	#	}
	#} 

	#if ($tanf_recd_m > 0) {
	#	$tanflock = 1;
	#}


	# outputs
    foreach my $name (qw(tanf_recd tanf_recd_m child_support_recd child_support_recd_m parent2_incapacitated tanf_family_structure  tanf_child_number unit_size tanf_stipend_amt tanflock tanf_recd_proxy tanf_sanctioned_amt tanf_children_under1 tanf_children_under6 tanf_oneparent_id)) { #These should match the outputs in the tanflock condition above, so any additions to these variables should also be added to that foreach statement. 
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;

 # NOTE FOR RESTRUCTURING OF ORDER OF EXECUTION: Because participation in TANF work requirements may increase the child care needs of families, we need to run the child care expenses code again, for families in which parent1_transhours > $parent1_employedhours OR  $parent2_transhours > $parent2_employedhours.

 # NOTE REGARDING TANFLOCK (from Kentucky FRS):
 # We use the variable tanflock here because of the following interactions between tanf, child care, child support, and tanf work requirements. Consider this sequence of events and why codes need to be rerun more than once:
 #1. Family works hours (parent_earnings). (We set tanflock=0 in parent_earnings.)
 #2. Hours family works calculated for unsubsidized child care need (child_care)
 #3. Unsubsidized Child care need used for child support order calculations (child_support) 
 #4. Child support used in tanf gross income to estimate tanf benefits (tanf). (As above, if tanf_recd>0, tanflock=1.) 
 #5. Family works hours recalculated due to work requirements (work)
 #6. Child care recalculated to include work requirements (child_care - 2nd run)
 #7. CCDF subsidies calculated based on child care need from work hours plus training hours (ccdf)
 #8. Child support recalculated based on actual child care expenses (child_support -2nd run). Because of the situation in the note below, this recalculation will only affect people who are receiving ccdf subsidies but not on TANF; their child support could be higher or lower as a result. (Return recalculated child_support paid only if tanf=1 and tanflock=0.) 
 #9. TANF eligibility could be recalculated based on recalculated child support (tanf - 2nd run). There are three possible results: TANF benefits can either remain calculated at the same value, TANF could be reduced to 0, or the family could be newly eligible for TANF because the child support order is lowered. This is because the TANF child care deduction will be unchanged at this point (it would not be taken if a family has checked the ccdf flag and is satisfying TANF work requirements), and the only time the amount of the child support order is invoked is in the gross income test to determine eligibility, not the net income test to determine benefits. A loss of TANF at this point would be nonsensical, as the family is only making more child support because it is abiding by TANF work requirements. But the only instance a family would gain TANF at this point but be ineligible for it earlier is if they are already receiving CCDF subsidies, meaning that they are working at least 20 hours/week, and have a large enough family that working 20 hours a week at a very low wage would make them TANF-eligible. This is the only case that matters; otherwise it’s nonsensical. (Return revised tanf outputs only if tanflock = 0.)
 #10. Because TANF work requirements are slightly greater than ccdf work requirements, recalculate work costs based on TANF work requirements. This could increase transportation needs (work - 2nd run).
 #11. Although child care need may increase, child care expenses will not change because the family is receiving subsidized child care, and CCDF subsidies will not change – if family is on TANF, they will be making little enough money that they will not be responsible for any copays.
 #12. This also means that they will not be eligible to receive more or less child support.
 #13. TANF will also stay the same at this point in this situation. 

 