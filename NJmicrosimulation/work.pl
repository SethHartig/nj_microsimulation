#=============================================================================#
#  Parental Work Effort and Transportation Costs -- NJ 2021
#=============================================================================#
# Inputs referenced in this module:
#   FROM BASE:
#	 Inputs:
#	   earnings
#	   family_structure
#	   residence_size 
#	   parent2_max_work
#	   other_cost_estimate	 (user entered)
#	   residence
#	   
#	Depending on the state, may also need ccdf, children_under6, children_under13
#
#   FROM PARENT_EARNINGS:
#	parent1_employedhours
#	parent2_employedhours
#
#   FROM TANF:
#	   tanf_recd
#
#=============================================================================#

sub work {
 
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};

	#FEDERAL POLICY VARIABLES
	our $snap_abawd_workreq = 80;
	our $twoparent_ccdf_pooled_workreq = 55; #The work requirement for each of two parents when pooling is allowed and the family is receiving federally subsidized child care. This is the federal standard and will never be active in the NJ code because it is only active when workreq_pooling_policy equals 1.	
	our $twoparent_noccdf_pooled_workreq = 35; #The work requirement for each of two parents when pooling is allowed and the family is not receiving federally subsidized child care. This is the federal standard and will never be active in the NJ code because it is only active when workreq_pooling_policy equals 1.	
	our $singleparent_nochildunder6_workreq = 30; #Federal standards differentiate work requirements for parents with chidlren under 6 and parents with no child under 6. Usually, as in NJ, the work requiremnet for parents with children over 6 is 30. 
	our $cost_per_mile = 0.56;	   # IRS cost per mile (varies by year). This is up to date as of tax year 2019. Have used IRS mileage in the past, at https://www.irs.gov/newsroom/irs-issues-standard-mileage-rates-for-2021.

	#STATE POLICY VARIABLES
	our $singleparent_childunder6_workreq = 30; #In NJ, all parents receiving TANF have to work 30 hours in allowable work activities such as employment or training. The federal minimum for this is 20, and that's what this variable would be for most states, but in NJ, it's 30, the same as the general work requirement for single parents.
	our $twoparent_mostworking_nonpooled_workreq = 30; #The work requirement for the most-working parent in a couple when there is no pooling policy. See Section Section 10:90-4.2(e)(1) of the NJ Administrative Code. The work requireent is actually 35 hours, but only 30 of those hours include qualifying work activities that can be interpreted as potentially requiring transportation or child care. 
	our $twoparent_leastworking_nonpooled_workreq = 20; #The work requirement for the least-working parent in a couple when there is no pooling policy.  See Section Section 10:90-4.2(e)(2) of the NJ Administrative Code. The work requireent is actually 35 hours, but only 20 of those hours include qualifying work activities that can be interpreted as potentially requiring transportation or child care. The other 15 hours can include child care for a TANF recipient participating in work requirement activities, i.e. the other parent. Check 
	our $twoparent_mostworking_nochildcare_nonpooled_workreq = 35; #The work requirement for the most-working parent in a couple when there is no pooling policy, when child care is not needd.  See Section Section 10:90-4.2(e)(2) of the NJ Administrative Code. The work requireent is actually 35 hours, but only 20 of those hours include qualifying work activities that can be interpreted as potentially requiring transportation or child care. (The variables here "switch" the "second" parent referred to in this statutes from the least-working to the most-working one.
	our $twoparent_leastworking_nochildcare_nonpooled_workreq = 30; #The work requirement for the most-working parent in a couple when there is no pooling policy. See Section Section 10:90-4.2(e)(1) of the NJ Administrative Code. The work requireent is actually 35 hours, but only 30 of those hours include qualifying work activities that can be interpreted as potentially requiring transportation or child care. 

	our $tanf_abawd_workreq = 30; #NJ policy.

	#Note: It seems that adult TANF recipients who are not parents (but living in a unit with at least one parent and a child) are required to work 40 hours a week. This is potentially important for the ACS micronanalysis if we end up including families with adult childrne, but not for the online tool, which models only household composed of parents and their minor children.

	#our $twoparent_childunder6_workreq = 30; #In NJ, all parents receiving TANF have to work 30 hours in allowable work activities such as employment or training. The federal minimum for this is 20, and that's what this variable would be for most states, but in NJ, it's 30, the same as the general work requirement for single parents. NOT IN CODE -- in trying to generalize/universalize this, see if it needs to be. But there are so many 30-hour minimums in NJ, it's difficult to tell wehther initially noting this was more informational or if the plan was to include it below.

	our $workreq_age_limit = 62; #In NJ, parents ages 62 and older do not need to satisfy work requirements. This lmit seems to vary by state, as KY and DC had this limit at 60 as of 2020 and 2017, respectively, according to these codes.
	our $workreq_pooling_policy = 0; #This is a static policy variable indicating whether couples on TANF can pool their work hours to meet the work requirements for couples, or if the state requires each parent on TANF to work a minimum number of hours. All states modeled prior to NJ since 2015 (DC, FL, CO, OH, and KY) seem to allow pooling, but NJ does not. In working toward univesalizing this code, this and all other TANF policy variables could and should be noted in the TANF code and generated as outputs.
	our $teenparent_school_requirement = 0; # Some states seem to require teen parents receiving TANF to attend school. KY does not require this but allows it; see note below. We are using this binary (0 or 1) variable as a policy flag. NJ seems to require this but only for minor parents under 18. The FRS does not accommodate this population. See https://casetext.com/regulation/new-jersey-administrative-code/title-10-human-services/chapter-90-work-first-new-jersey-program/subchapter-2-non-financial-eligibility-requirements/section-1090-217-provisions-for-minor-parents. Eventually move teenparent variable TO tanf, to generalize this code. 

	#output variables
	our $trans_expenses = 0;		  # family transportation costs
	our $parent1_transhours_w = 0;	   # for transportation: number of hours per week that parent 1
										# spends in paid employment, in addition to hours that a TANF-recipient
										# parent spends in\ non-paid TANF work activities
	our $parent2_transhours_w = 0;	   # same as above for second parent.  Note: in CT, TANF work requirements
										# are low enough that  parent 2 never needs to participate in work activities
	our $parent1_transcost_full = 0;	 # parent 1's transportation costs when parent 1 is working full time
	our $parent2_transcost_full = 0;	 # ditto for second parent
	our $parent1_transcost = 0;		  # parent's transportation costs when parent is working full time
	our $parent2_transcost = 0;		  # ditto for second parent
	our $parent1_transdays_w = 0;		# number of days of transportation needed by parent 1, based on
										# parent1_transhours_2 (for prorating "full-time" transportation cost)
	our $parent2_transdays_w = 0;		# ditto for second parent
 
	#debug variables
	our $parent_workhours_w = $out->{'parent_workhours_w'};   # This variable has already been defined in parent_earnings, but may be revised based on TANF work requirements, below.
	our $parent1_employedhours_w = $out->{'parent1_employedhours_w'};   # Just to make the code below easier
	our $parent2_employedhours_w = $out->{'parent2_employedhours_w'}; # Just to make the code below easier
	our $shifts_parent1 = $out->{'shifts_parent1'}; # Might be revised here
	our $shifts_parent2 = $out->{'shifts_parent2'}; # Might be revised here
	our $transshifts_parent1 = 0;
	our $transshifts_parent2 = 0;
	our $multipleshifts_parent1 = 0;
	our $multipleshifts_parent2 = 0;
	our $parent_otherhours_w = $out->{'parent_otherhours_w'};
	our $caregiver_workshifts_w = $out->{'caregiver_workshifts_w'};
	our $caregiver_maxworkweek = $out ->{'caregiver_maxworkweek'};
	our $caregiver_maxshiftlength = $out ->{'caregiver_maxshiftlength'};
	our $caregiver_backtobackshifts= $out ->{'caregiver_backtobackshifts'};
	our $percent_nonsocial = 0;	   # percent of miles driven for "nonsocial" purposes (used to determine parent1's transportation costs)
	our $percent_work = 0;			# percent of miles driven for "work" purposes (used to determine parent2's transportation costs)
	our $avg_miles_driven = 0;		# avg annual miles driven, based on size of place of residence
	our $trans_type = 0;					# type of transportation used (car vs. public) based on place of residence
	our $public_trans_cost_d = 0;		 # daily cost of commuting (ie, cost of round-trip fare)
	our $public_trans_cost_max = 0;	   # maximum cost of public transportation (ie, cost of 12 monthly passes)
	our $publictrans_cost_d_dis = 0;  # daily cost of commuting (ie, cost of round-trip fare) for #people with disabilities
	our $publictrans_cost_max_dis = 0; # maximum cost of public transportation (ie, cost of 12 #monthly passes) for people with disabilities
	our $transcost_nonsocialnonwork = 0;
	our $nonsocialnonwork_portion_public = 0;
	our $transcost_nonsocialnonwork_dis = 0;
	our $residence_size = 0;
	our $publictrans_cost_d = 0;
	our $publictrans_cost_max = 0;
	our $debug1 = 0;
	our $debug2 = 0;
	our $debug3 = 0;
	our $debug4 = 0;
	our $debug5 = 0;
	our $debug6 = 0;
	our $debug7 = 0;


	#Redefining some work requrement variables with policy options.
	if ($in->{'lower_state_childunder6_workreq'} == 1) {
		# S541 would change $singleparent_childunder6_workreq to 20
		$singleparent_childunder6_workreq = 20;
	}
	if ($in->{'lower_state_workreq'} == 1) {
		# S541 would change other work requirements from 40 to 30. 
		$twoparent_mostworking_nochildcare_nonpooled_workreq = 30;
	}
	
  # 1. Determine number of hours the parents work (including time in TANF-required work activities) for the purposes of determining family child care needs and transportation costs
	if ($in->{'child_number'} == 0) {
		$parent_workhours_w = 0; #There is no child care need in this family, since there are no children, so this variable -- which is the amount of potential child care need based on parent work schedules -- will also be 0.
		$debug1 = 1;
		for(my $i = 1; $i <= $in->{'family_structure'}; $i++) { #The family_structure variable also doubles as the count of adults in the hourshold.

			#We check for work requirements for ABAWDs, first for SNAP and then for TANF> Families without children cannot receive TANF, at least in KY in 2020, when this code was first developed, but can get TANF in NJ, so TANF work requirements for ABAWDs are added below beginning in 2021. SNAP work requirements for ABAWD adjusts transhours based on attendance at SNAP E&T trainings in order to satisfy work requirements. We also check to see if the user has selected whether SNAP (E&T) trainings are available for satisfaction of work requirements:

			#SNAP ABAWD WORK REQUIREMENTS:
			if ($in->{'parent'.$i.'_age'} >= 18 && $in->{'parent'.$i.'_age'} <=49 && $out->{'fsp_recd'} > 0 && $in->{'exclude_abawd_provision'} == 1 && $in->{'snap_training'} == 1 &&  $in->{'covid_fsp_work_exemption'} == 0 && $out->{'parent'.$i.'ssi_recd'} == 0 ) {
			#We then check for satisfaction of ABAWD work requirements, along with whether user is modeling the exclusion of ABAWDS who don't satsify work requirements (exclude_abawd_provision) AND is not modeling the availability of training to ABAWDS when they work too few hours to qualify for SNAP work requirements (snap_training):
			#See the fsp code to see the explanation about the disability variables here.
				${'parent'.$i.'_transhours_w'} = &greatest($out->{'parent'.$i.'_employedhours_w'}, $snap_abawd_workreq/4.33);
			} else {
				${'parent'.$i.'_transhours_w'} = $out->{'parent'.$i.'_employedhours_w'};
			}
			
		}
	}
	
	if($out->{'tanf_recd'} > 0 && $out->{'tanf_child_number'} == 0 && $in->{'tanfwork'} == 1) {
		for(my $i = 1; $i <= $in->{'family_structure'}; $i++) { #The family_structure variable also doubles as the count of adults in the hourshold.
			if ($in->{'parent'.$i.'_ssi'} + $in->{'parent'.$i.'_unqualified'} + $in->{'disability_parent'.$i} == 0 && $in->{'parent'.$i.'_age'} < $workreq_age_limit)  { #NJ rules for whther a parent is included in the TANF family unit. Will need to revise when generalizing this code.
				
				#TANF ABAWD WORK REQUIREMENTS
				${'parent'.$i.'_transhours_w'} = &greatest($tanf_abawd_workreq, ${'parent'.$i.'_transhours_w'});
				#No parent_workhours_w, as there are no children needing child care.
			}
		}
	} elsif($out->{'tanf_recd'} == 0 || $out->{'tanf_family_structure'} == 0 || ($out->{'tanf_children_under1'} > 0 && $in->{'waive_childunder1_workreq'} == 1)) { #No TANF or no TANF going to adults in the home means adults just work (and need child care) for the time they are employed.
		$parent1_transhours_w = $parent1_employedhours_w;
		$parent2_transhours_w = $parent2_employedhours_w;
		if ($in->{'family_structure'} == 1) {
			$parent_workhours_w = $parent1_transhours_w;
		} else { #family structure = 2
			$parent_workhours_w = least($parent1_transhours_w, $parent1_transhours_w);
		}		
	} elsif($out->{'tanf_family_structure'} == 1) {
		$parent2_transhours_w = 0; 
		if($out->{'tanf_recd'} > 0 && $out->{'tanf_child_number'} > 0 && $in->{'tanfwork'} == 1) { 
			# If a single parent with a child younger than 12 months old, parent is not subject to TANF work requirements. This is true in DC, KY, and possibly a federal rule. (Previous DC code assumed that for parents under 20,  the child is under 12 weeks old, exempting them from school attendance requirements. This seems like an ill-founded assumptino.)  
			  
			if($out->{'tanf_children_under1'} > 0  || $in->{'parent'.$out->{'tanf_oneparent_id'}.'_age'} >= $workreq_age_limit) { 
				$parent_workhours_w = ${'parent'.$out->{'tanf_oneparent_id'}.'_employedhours_w'}; 
				${'parent'.$out->{'tanf_oneparent_id'}.'_transhours_w'} = ${'parent'.$out->{'tanf_oneparent_id'}.'_employedhours_w'}; 
			} elsif ($in->{'parent'.$out->{'tanf_oneparent_id'}.'_age'} < 20 && $teenparent_school_requirement == 1) {#NJ doesn't have this policy, as TANF recipients age 18 who are not in high school can opt to do work requirements instead of attending school. So the below code has not been updated to generalize this policy in states that do enforce school attendance to receive TANF.
				# In KY, a parent under 20 can either satisfy work/training reqs, or go to school and have their earned income excluded from TANF calculations. To avoid nonsensical situations (see saved note and archived email between Seth and Kris), we are assuming a teen parent 18-19 years old does not go to school.
				# In DC as of 2017, though, a parent under 20 does not have to participate in work activities if they are in school or have earned their high school diploma or GED. Conceivably, this could exempt one parent under 20 from participating in work requirements, but would not exempt a spouse who is 20 or older unless the teen parent is also head of household (that is, if they make more than the other parent). Since we are allowing users to choose whether the family satisfied TANF work requirements, we will assume (for DC and possibly other states that have this policy) that if tanfwork=1, all parents in the family need to satisfy work requirements, even though in our model only one parent will have their working hours extended to meet this requirement.
				# The parent in this situation would be single, under 20, does not have an infant child, and would not have a GED or high school diploma. This parent must therefore satisfy school attendance requirements, which seem to require an additional 30 hours per week on top of any income the parent is receiving. Based on feedback from Brian Campbell, we are assuming that an individual with these characteristics has no high school diploma or GED. If we don't want to assume that, we could add an additional condition of " && $in->{'ged'} == 0 ", which would require an additional input as to whether the youth has their ged/diploma. 
				$parent_workhours_w   = ${'parent'.$out->{'tanf_oneparent_id'}.'_employedhours_w'} + 30; 
				${'parent'.$out->{'tanf_oneparent_id'}.'_transhours_w'} = ${'parent'.$out->{'tanf_oneparent_id'}.'_employedhours_w'} + 30; 
			} elsif($out->{'tanf_children_under6'} > 0) { #In NJ, parents with children under 6 have to work just as much as parents with children over 6. When we add in a state that treats these parents differently, we may have to build in a rule here to determine whether the child is part of the TANF family unit or not, but that rule search is irrelevant in NJ since the age does not matter.
				$parent_workhours_w   = &greatest($singleparent_childunder6_workreq,  ${'parent'.$out->{'tanf_oneparent_id'}.'_employedhours_w'});
				${'parent'.$out->{'tanf_oneparent_id'}.'_transhours_w'} = &greatest($singleparent_childunder6_workreq,  ${'parent'.$out->{'tanf_oneparent_id'}.'_employedhours_w'});
			} else {
				$parent_workhours_w   = &greatest($singleparent_nochildunder6_workreq,  ${'parent'.$out->{'tanf_oneparent_id'}.'_employedhours_w'});
				${'parent'.$out->{'tanf_oneparent_id'}.'_transhours_w'} = &greatest($singleparent_nochildunder6_workreq,  ${'parent'.$out->{'tanf_oneparent_id'}.'_employedhours_w'});
			}
 
  		} else {
			$parent_workhours_w   = $parent1_employedhours_w;
			$parent1_transhours_w = $parent1_employedhours_w;
			$parent2_transhours_w = $parent2_employedhours_w; #This will likely always be zero, but not hardcoding it to zero just to cover our bases since employed hours for parent 2 will be zero anyway in 1-parent families.
		}
	} else { #family structure = 2, a 2-parent family.
		#"Each parent in a two-parent WFNJ/TANF family shall be required to participate in one or more activities for a minimum of 35 hours per week up to a maximum hourly total of 40 hours per week, unless otherwise deferred in accordance with 10:90-4.9." -NJ administrative codes. Deferrals includes individuals ages 62 or older and individuals certified as being medically or mentally unable to work.
		if ($out->{'tanf_recd'} > 0 && $in->{'parent1_age'} >= $workreq_age_limit && $in->{'parent2_age'} >= $workreq_age_limit) {
			#Both parents are over the age limit and therefore do not have to satisfy work requirements.
			$parent_workhours_w   = $parent2_employedhours_w;
			$parent1_transhours_w = $parent1_employedhours_w;
			$parent2_transhours_w = $parent2_employedhours_w;
		} elsif($out->{'tanf_recd'} > 0 && $out->{'tanf_child_number'} > 0 && $in->{'tanfwork'} == 1) {
			if ($workreq_pooling_policy == 1) { #Federal standards, distinct from custom rules like in NJ. For NJ rules, see else statement below.
			
				# Note: A two-parent family on CCDF where at least one parent has a disability is not required to do the extra 20 hours beyond the normal 35 for TANF work requirements. For DC, see ESA manual page 206. Fror KY, see MS 2321. Does not seem to be a rule for NJ.
			
				# Note: Older parents are exempt from work requirments, but can participate in them if they are exempt. If they are married to someone who is younger than the age limit for work reuqirements, the younger parent must still satisfy work requirements, as if they were a single parent. The below code addresses this situation by pushing work requirements to the younger parent, but allows for the possibiltiy of counting the older parent's work if that reduces the training time of the younger parent needed to satisfy work requirements. 

				if($in->{'ccdf'} && ($in->{'disability_parent1'} + $in->{'disability_parent2'} == 0) && $out->{'unsub_all_children'} > 0) {
					if ($parent1_employedhours_w >= $parent2_employedhours_w || $in->{'parent2_age'} >= $workreq_age_limit) {
						#Parent 1 completes all the work work rquirements.
						if ($in->{'parent2_age'} >= $workreq_age_limit) {
							#Since parent2 is over the age limit, they do not have to do work requirements, and parent 1 does not see an uptick in their work requirements. But in states that allow parents to pool their work hours (NOT allowable in NJ), it could behoove parents over 60 to submit to these requirements in order for the other parent not to work more.
							$parent1_transhours_w = &least(&greatest($singleparent_nochildunder6_workreq, $parent1_employedhours_w), $parent1_employedhours_w + pos_sub($twoparent_nonpooled_workreq, $parent1_employedhours_w + $parent2_employedhours_w));
						} else { 
							#It behooves parent 1 to do all the work for the family in states with a "pooling" policy.
							$parent1_transhours_w = $parent1_employedhours_w + pos_sub($twoparent_ccdf_pooled_workreq, $parent1_employedhours_w + $parent2_employedhours_w);
						} 
						$parent2_transhours_w = $parent2_employedhours_w;
					} else { #parent 2 works more than parent 1.
						if ($in->{'parent1_age'} >= $workreq_age_limit) { 
							$parent2_transhours_w = &least(&greatest($singleparent_nochildunder6_workreq, $parent2_employedhours_w), $parent2_employedhours_w + pos_sub($twoparent_ccdf_pooled_workreq, $parent1_employedhours_w + $parent2_employedhours_w));
						} else { 
							#It behooves parent 2 to do all the work for the family in states with a "pooling" policy.							
							$parent2_transhours_w = $parent2_employedhours_w + pos_sub($twoparent_ccdf_pooled_workreq, $parent1_employedhours_w + $parent2_employedhours_w); 
						} 
						$parent1_transhours_w = $parent1_employedhours_w;
					}
				} else { #No children under 13 and/or no CCDF, or, if CCDF is selected, no child care is needed.
					if ($parent1_employedhours_w >= $parent2_employedhours_w || $in->{'parent2_age'} >= $workreq_age_limit) { 
						if ($in->{'parent2_age'} >= $workreq_age_limit) { 
							$parent1_transhours_w = &least(&greatest($singleparent_nochildunder6_workreq, $parent1_employedhours_w), $parent1_employedhours_w + pos_sub($twoparent_noccdf_pooled_workreq, $parent1_employedhours_w + $parent2_employedhours_w));
						} else { 
							$parent1_transhours_w = $parent1_employedhours_w + pos_sub($twoparent_noccdf_pooled_workreq, $parent1_employedhours_w + $parent2_employedhours_w);
						} 
						$parent2_transhours_w = $parent2_employedhours_w;
					} else { #parent 2 works more than parent 1.
					#Eventually, maybe the above code should be cleaned up to reflect more of what's below, to reduce the repetetive invocation of the workreq_pooling_policy variable.
						$parent1_transhours_w = $parent1_employedhours_w;
						if ($in->{'parent1_age'} >= $workreq_age_limit) { 
							$parent2_transhours_w = &least(&greatest($singleparent_nochildunder6_workreq, $parent2_employedhours_w), $parent2_employedhours_w + pos_sub($twoparent_noccdf_pooled_workreq, $parent1_employedhours_w + $parent2_employedhours_w)); 
						} else { 
							$parent2_transhours_w = $parent2_employedhours_w + pos_sub($twoparent_noccdf_pooled_workreq, $parent1_employedhours_w + $parent2_employedhours_w); 
						} 
					}
				}			
			} else { #no work pooling possibility, like in NJ:

				# if(($in->{'disability_parent1'} + $in->{'disability_parent2'} == 0) && $in->{'ccdf'} && $in->{'unsub_all_children'} > 0) { Seems like because of NJ's policy of conferring subsidized child care to all TANF recipients, there is no distinction between TANF recipients that receive CCDF child care and those that do not. Similarly, as all people with a disability severe enough to receive SSI are excluded from the TANF unit, there is no additional consideration allowing TANF recipients with disabilties to not meet work requirements. This seems right but including the logic here, just commented out for now.
				if ($parent1_employedhours_w >= $parent2_employedhours_w) {
					#Parent 1 completes all the work work rquirements.
					if ($in->{'parent2_age'} >= $workreq_age_limit) {
						#Since parent2 is over the age limit, they do not have to do work requirements, and parent 1 does not see an uptick in their work requirements. 
						$parent1_transhours_w = &greatest($singleparent_nochildunder6_workreq, $parent1_employedhours_w); #Note that in NJ, the variables for work requirements for people with children under 6 are the same as for those with children over 6, so we are using the shorthand here to reference "nochildrenunder6" for now, to avoid too many variables that are repetitive. Perhaps adjust the name of this variable to make it clearer.
						$parent2_transhours_w = $parent2_employedhours_w;
					} else { 
						if($out->{'tanf_children_under6'} > 0) { #In NJ, parents with children under 6 have to work just as much as parents with children over 6, but when child care would be needed for the second parent in a couple to work (when the first parent is working partially to satisfy TANF work requirements), the work requirements for one parent can be reduced by those child care hours, essentially reducing from 35 to 20. While we could try to loop back child care need variables derived from the child_care code, including child care needed during the summer vs. non-summer weeks, etc., we are using a simplified proxy here of whether the child is under 6 to model this rule. It seems safe to assume that when that first parent needs to attend nonpaid work activities to satisfy work requirements, those work requirements will be offered during the school day, meaning it seems difficult for the "second" parent in this situation to take advantage of this clause to claim that child care was used in this manner.
							$parent1_transhours_w = &greatest($twoparent_mostworking_nonpooled_workreq, $parent1_employedhours_w);
							$parent2_transhours_w = &greatest($twoparent_leastworking_nonpooled_workreq, $parent2_employedhours_w);
						} else {
							$parent1_transhours_w = &greatest($twoparent_mostworking_nochildcare_nonpooled_workreq, $parent1_employedhours_w);
							$parent2_transhours_w = &greatest($twoparent_leastworking_nochildcare_nonpooled_workreq, $parent2_employedhours_w);
						}
					}
				} else { #parent 2 works more than parent 1.
					if ($in->{'parent1_age'} >= $workreq_age_limit) { 
						$parent2_transhours_w = &greatest($singleparent_nochildunder6_workreq, $parent2_employedhours_w);
						$parent1_transhours_w = $parent1_employedhours_w;
					} else { 
						if($in->{'children_under6'} > 0) { 
							$parent2_transhours_w = &greatest($twoparent_mostworking_nonpooled_workreq, $parent2_employedhours_w);
							$parent1_transhours_w = &greatest($twoparent_leastworking_nonpooled_workreq, $parent1_employedhours_w);
						} else {
							$parent2_transhours_w = &greatest($twoparent_mostworking_nochildcare_nonpooled_workreq, $parent2_employedhours_w);
							$parent1_transhours_w = &greatest($twoparent_leastworking_nochildcare_nonpooled_workreq, $parent1_employedhours_w);
						} 
					} 
				}	 
			}
		} else {
			$parent1_transhours_w = $parent1_employedhours_w;
			$parent2_transhours_w = $parent2_employedhours_w;
		}

		$parent_workhours_w = &least($parent1_transhours_w, $parent2_transhours_w);
	}
	
	# if we're in "budget" mode, make sure that the parent's workhours and transhours are at their maximum, no matter what the earnings level is
	#
	# NCCP note: Despite the variable changes, it seems appropriate to leave these at the traditional 40-hour/20-hour markings at this point. We can return to the BNBC assumptions once we get drafts of the FRS done.  Not including the following if-block in the testing sheet for now.

	if($in->{'mode'} eq 'budget') {
		$parent_workhours_w = 40; #11/1/17 note: This variable seems to be incorrectly written as "parent1_workhours_w" -- I believe it should just be "parent_workhours_w" -- but it appears to be legacy code going all the way back to at least 2007. But I'm making this note in case it becomes problematic or raises questions at some point. 8/16/21 note: It's bad code, it should be corrected and other code related to it corrected as well if problematic.
		$parent1_transhours_w = 40;
		if($in->{'family_structure'} == 2) {
			if($in->{'parent2_max_work'} eq 'F') {
				$parent2_employedhours_w = 40;
				$parent2_transhours_w = 40;
				$parent_workhours_w = 40;
			} elsif($in->{'parent2_max_work'} eq 'H') {
				$parent2_employedhours_w = 20;
				$parent2_transhours_w = 20;
				$parent_workhours_w = 20;
			} else {
				$parent2_employedhours_w = 0;
				$parent2_transhours_w = 0;
				$parent_workhours_w = 0;
			}
		} else {
			$parent_workhours_w = 40;
		}
	}
	
	
	# Since we are allowing for nontraditional work, the below reframes our calculation of transportation days (which are actually instances of round-trip travel) to account for nontraditional work schedules. This is also important for child care calculations. We can do this by first using the new variables to identify how many shifts each parent works, and then using a simplified version of the three scenarios identified by the backtobackshifts variables to determine how many additional trips are needed to travel between shifts. 

	$shifts_parent1 = ($parent1_transhours_w / $in->{'maxshiftlength_parent1'});
	$shifts_parent2 = ($parent2_transhours_w / $in->{'maxshiftlength_parent2'});
	$transshifts_parent1 = ceil($shifts_parent1); 
	$transshifts_parent2 = ceil($shifts_parent2); 
	$multipleshifts_parent1 = pos_sub($shifts_parent1, $in->{'maxworkweek_parent1'});  
	$multipleshifts_parent2 = pos_sub($shifts_parent2, $in->{'maxworkweek_parent2'}); 
	# For the child care code, we also need to create new variables that indicate the other parent’s working hours (in the case of two parent families, to use in instances when families are strategizing caregiving between two parents), and, for ease of the child care code, identify which parent’s work pattern to use in optimizing child care.

	if ($in->{'family_structure'} == 1) {										   
		$caregiver_workshifts_w = $shifts_parent1; 
		$caregiver_maxworkweek = $in->{'maxworkweek_parent1'};
		$caregiver_maxshiftlength = $in->{'maxshiftlength_parent1'};
		$caregiver_backtobackshifts=$in->{'backtobackshifts_parent1'}; 
	} else {
		if ($parent1_transhours_w >= $parent2_transhours_w) {
			$parent_otherhours_w = $parent1_transhours_w;
			$caregiver_workshifts_w = $shifts_parent2; 
			$caregiver_maxworkweek = $in->{'maxworkweek_parent2'};
			$caregiver_maxshiftlength = $in->{'maxshiftlength_parent2'};
			$caregiver_backtobackshifts= $in->{'backtobackshifts_parent2'}; 
		} else {
			$parent_otherhours_w = $parent2_transhours_w;
			$caregiver_workshifts_w = $shifts_parent1; 
			$caregiver_maxworkweek = $in->{'maxworkweek_parent1'};
			$caregiver_maxshiftlength = $in->{'maxshiftlength_parent1'};
			$caregiver_backtobackshifts= $in->{'backtobackshifts_parent1'}; 
		}
	}
	# We incorporate the transshifts variables in combination with the multipleshifts and backtobackshifts variables because the transdays variable is essentially the number of round trips each parent is making. Note that while these changes were conceived in relation to public transportation (all of DC, as a default setting), they also are used for determining costs when users override transportation costs, indicating that parents use cars. It may be worth specifying in the user interface that the override is the cost per round trip, not per day.  
 
	$parent1_transdays_w=$transshifts_parent1 - .5*(2 - &least(1, $in->{'backtobackshifts_parent1'}))* $multipleshifts_parent1; 
	$parent2_transdays_w=$transshifts_parent2 - .5*(2 - &least(1, $in->{'backtobackshifts_parent2'}))* $multipleshifts_parent2; 



	# determine transportation costs

	# look up value of avg_miles_driven from locations table
	my $sql = "SELECT trans_type, percent_nonsocial, percent_work, FRS_Transportation_v2.avg_miles_driven, publictrans_cost_d, publictrans_cost_max, publictrans_cost_d_dis, publictrans_cost_max_dis FROM FRS_Locations LEFT JOIN FRS_Transportation_v2 USING (residence_size, year) WHERE state = ? && year = ? && id = ?";
	my $stmt = $dbh->prepare($sql) ||
		&fatalError("Unable to prepare $sql: $DBI::errstr");
	$stmt->execute($in->{"state"}, $in->{"year"}, $in->{"residence"}) ||
		&fatalError("Unable to execute $sql: $DBI::errstr");
	($trans_type, $percent_nonsocial, $percent_work, $avg_miles_driven, $publictrans_cost_d, $publictrans_cost_max, $publictrans_cost_d_dis, $publictrans_cost_max_dis) = $stmt->fetchrow();
	$stmt->finish();
	
	#Temporary correction until MySQL error is fixed to make these numnbers annual instead of monthly:
	$publictrans_cost_max = $publictrans_cost_max  * 12;
	$publictrans_cost_max_dis = $publictrans_cost_max_dis  * 12;
	

	if($in->{'trans_override'}) {
		$trans_expenses = ($parent1_transdays_w/5) * $in->{'trans_override_parent1_amt'} * 12;
		if($in->{'family_structure'} == 2) {
			if ($in->{'parent2_max_work'} eq 'N') {
				$in->{'trans_override_parent2_amt'} = $in->{'trans_override_parent1_amt'};
			}
			$trans_expenses += ($parent2_transdays_w/5) * $in->{'trans_override_parent2_amt'} * 12;
		}
		# In the instance of a two-parent family with the second parent not 
		# employed and the family receives TANF, and the state requires that the second parent work, 
		# then the user-entered first parent’s transportation expense should also be used to 
		# calculate the second parent’s transportation expenses.
	} else {
	   # 2b Private or public transportation costs
	   # Use “Private transportation cost” table to determine percent_nonsocial, percent_work, and avg_miles_driven 
	   # according to residence_size.
	   if (lc($trans_type) eq 'car' || lc($trans_type) eq 'private' || $in->{'user_trans_type'} eq 'car') {
			#The user_trans_type input overrides the availability of public transportation in a geography that has public transportation options with the user's own selection to model using a car instead.
			#We assume below that one parent/adult, parent1 (who is always present in a household, unlike parent2 in the case of a single-adult family), requires additional transportation for social activities or things like child care, trips to the store, etc. So, for parent1, we use the higher "percent_nonsocial" figure, while we add additional transportation costs for a second parent to be working. This can be through an additional car or through additional trips on the same car. We are assuming here that parents do not travel to the same place, and that parents are not working from home.
			# $parent1_transcost_full = $percent_nonsocial * $avg_miles_driven * $cost_per_mile; #Old way of doing this.
	 		$transcost_nonsocialnonwork = ($percent_nonsocial - $percent_work) * $avg_miles_driven * $cost_per_mile;
			$parent1_transcost_full = $percent_work * $avg_miles_driven * $cost_per_mile;
			$parent2_transcost_full = $percent_work * $avg_miles_driven * $cost_per_mile;
			
			# WE assume most survey respondents in the national transportation survey work 5 days a week when they work, so we divide that by 5 to get get a single days' worth of drivign costs, then multiply that by the number of parent transdays toget the cost per parent.
		   $parent1_transcost = $transcost_nonsocialnonwork + ($parent1_transdays_w/5) * $parent1_transcost_full;
			$parent2_transcost = ($parent2_transdays_w/5) * $parent2_transcost_full;
			

		   
		} 
		elsif (lc($trans_type) eq 'public') {
			#We figure otu public transportation costs. But following a similar methodology as above, we need to assume that famlies are using public transportation for other activities like food shopping, going to the doctor, etc. 
			

			my $sql = "SELECT residence_size FROM FRS_Locations WHERE state = ? && year = ? && id = ?"; # id or residence?
			my $stmt = $dbh->prepare($sql) ||
				&fatalError("Unable to prepare $sql: $DBI::errstr");
			$stmt->execute($in->{'state'}, $in->{'year'},  $in->{'residence'}) ||
				&fatalError("Unable to execute $sql: $DBI::errstr");
			$residence_size = $stmt->fetchrow();

			# Then we calculate the portion of total trips using National Transportation Survey data that the family takes using public transportation, separate from work or other social activities. We should really use SQL for this but doing it in Perl in the interest of expediency.
			if ($residence_size eq 'upto250000') {
				$nonsocialnonwork_portion_public = 0.519;
			} elsif ($residence_size eq 'upto500000') {
				$nonsocialnonwork_portion_public = 0.472;
			} elsif ($residence_size eq 'upto1million') {
				$nonsocialnonwork_portion_public = 0.586;
			} elsif ($residence_size eq 'upto3million') {
				$nonsocialnonwork_portion_public = 0.424;
			} elsif ($residence_size eq 'over3million') {
				$nonsocialnonwork_portion_public =  0.341;
			} elsif ($residence_size eq 'rural') {
				$nonsocialnonwork_portion_public = 0.441;
			}
			#The above determination could and should just as easily be in the SQL file.

			$transcost_nonsocialnonwork = $nonsocialnonwork_portion_public * (5 * $publictrans_cost_d * 52); # This should be the equivalent of the portion of travel time a car-driving parent spends traveling for things outside of work. This would assume all appointments or stores you go to are not within walking distance. Not sure about this.
			$transcost_nonsocialnonwork_dis = $nonsocialnonwork_portion_public * (5 * $publictrans_cost_d_dis * 52);

			# Eventually, we might want to shift fixed transportation costs to the second parent in a two parent family when the first parent is disabled and the other is not. We need to consider each parent's public transportation costs within the context of the family unit because if one parent has a disability, we assume the other parent is taking trips needed primarily for shopping, appointemnts, etc. 
			if ($in->{'disability_parent1'} == 0) { 
					$parent1_transcost = &least($transcost_nonsocialnonwork + $parent1_transdays_w * $publictrans_cost_d * 52, $publictrans_cost_max);
			} else {
				# We decided against building in a user-entered flag as to whether this family accesses the public benefit of transit discounts for people with disabilities here, with the name the program. This could help illustrate the value of the program for people with disabilities. We could do this for a jurisdiction interested in quantifying this amount, or in adjusting the benefit. Here, that could be incorporated with a simple AND statement referring to this flag here, and possibly where disability is first mentioned as a condition above. - SH.
				$parent1_transcost = &least($transcost_nonsocialnonwork_dis + $parent1_transdays_w * $publictrans_cost_d_dis * 52, $publictrans_cost_max_dis); 
			}
			if ($in->{'family_structure'} == 2) {
				if ($in->{'disability_parent2'} == 0) { 
					$parent2_transcost = &least($parent2_transdays_w * $publictrans_cost_d * 52, $publictrans_cost_max); 
				} else {
					$parent2_transcost = &least($parent2_transdays_w * $publictrans_cost_d_dis * 52, $publictrans_cost_max_dis);
				}
			}
			
			#Shifting fixed transportation costs to the second parent in two parent families in which parent1 has a disabiltiy but parent2 does not:
			if ($in->{'family_structure'} == 2 && $in->{'disability_parent1'} == 1 && $in->{'disability_parent1'} == 0) {
				$parent1_transcost = &least($parent1_transdays_w * $publictrans_cost_d_dis * 52, $publictrans_cost_max_dis); 
				$parent2_transcost = &least($transcost_nonsocialnonwork + $parent2_transdays_w * $publictrans_cost_d * 52, $publictrans_cost_max); 
			}

		}
	$trans_expenses = pos_sub($parent1_transcost + $parent2_transcost, $out->{'tanf_stipend_amt'}); #Combine these amounts and reduce them by any tanf stipends, generated in the tanf code.
 	}

	# outputs
	foreach my $name (qw(parent_workhours_w parent1_employedhours parent2_employedhours parent1_earnings parent2_earnings trans_expenses parent1_transhours_w parent2_transhours_w parent_workhours_w 
						parent1_employedhours_w parent2_employedhours_w shifts_parent1 shifts_parent2 transshifts_parent1 transshifts_parent2 multipleshifts_parent1 multipleshifts_parent2 parent_otherhours_w 
						caregiver_workshifts_w caregiver_maxworkweek caregiver_maxshiftlength caregiver_backtobackshifts)) { 
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;