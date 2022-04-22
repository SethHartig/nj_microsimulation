#=============================================================================#
#  FLI and TDI (Family Leave Insurance and Temporary Disability Insurance) Module – 2021 
#=============================================================================#
#
# Inputs referenced in this module:
#
#	FROM BASE
#	fli       	
#	tdi  
#	mother_timeoff_for_newborn
#	other_parent_timeoff_for_newborn
#	fosterchild_flag
#	parent1_time_off_foster 	to add to Step 3: "How many weeks does parent 1 take off to bond with newly placed foster child(ren)?"
#	parent2_time_off_foster		to add to Step 3: "How many weeks does parent 2 take off to bond with newly placed foster child(ren)?"
#
#	FROM PARENT_EARNINGS
#	parent1_earnings_w
#	parent2_earnings_w
#
#	SOURCES:
#		Expansion of FLI/TDI in 2019: P.L. 2019, Chapter 37, approved Feb 19 2019:  https://www.njleg.state.nj.us/Bills/2018/AL19/37_.PDF 
#		https://www.myleavebenefits.nj.gov/worker/fli/#:~:text=Claimants%20are%20paid%2085%25%20of,rate%20is%20%24903%20per%20week
#=============================================================================#

sub fli_tdi
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};

	#FLI/TDI module
	#determine FLI eligibility based on average weekly wage,

	#Policy variables
	our $wage_replacement_rate = .85; #NJ workers get 85% of their average weekly wage in FLI and TDI.
	our $maximum_fli_weeks = 12; #Length of paid family leave allowed, in weeks
	our $typical_tdi_weeks = 6; #Typical length of TDI taken after the birth fo a newborn. (This is often coupled with 4 weeks of leave taken before the birth of a newborn, but we are not yet building in pregnancy into the FRS tool. May be worth adjusting this so that it's an input instead of a set amount, as depending on the mother's condition after childbirth, this can be up to 20+ weeks.
	our $max_fli_benefit_w = 903; #Max weekly benefit, based on average weekly wage for NJ residents.  See https://www.myleavebenefits.nj.gov/worker/fli/#:~:text=Claimants%20are%20paid%2085%25%20of,rate%20is%20%24903%20per%20week.
	our $max_tdi_benefit_w = 903; #Max weekly benefit, based on average weekly wage for NJ residents. Same as max FLI benefit.
	our $minimum_weekly_earnings = 220; #Must have earned $220 over 20 weeks or combined total of $11,000 in the base period:
	
	#outputs
	our $fli_recd_parent1_w = 0;
	our $fli_recd_parent2_w = 0;
	our $tdi_recd_parent1_w = 0;
	our $fli_recd = 0;
	our $parent1_tdi_recd = 0;
	our $parent2_tdi_recd = 0; #for now, this will remain 0 because we are only modeling the first parent taking tdi leave. 
	our $tdi_recd = 0;
	our $fli_plus_tdi_recd = 0;
	our $parent1_fli_recd = 0;
	our $parent2_fli_recd = 0;
	our $fli_tdi_flag = 0;
	
	#Other intermediary variables
	our $remaining_tdi_time = 0;
		
	#FLI and TDI
	
	#First, check if an infant child is present. Initially at least, we are only considering families with newborn for the FLI and TDI model.
	
	#debugs
	our $mother_timeoff_for_newborn = $in->{'mother_timeoff_for_newborn'}; 
	
	if (($in->{'children_under1'} > 0 || $in->{'fosterchild_flag'} == 1) && $in->{'undocumented_adult_count'} != $in->{'family_structure'}) {
		if ($in->{'fli'} == 1) {
			$fli_tdi_flag = 1;
			#First, determine the amount in FLI received per week:
			if ($out->{'parent1_earnings_w'} >= $minimum_weekly_earnings && $in->{'parent1_immigration_status'} ne 'undocumented_or_other') {
				$fli_recd_parent1_w = &least($wage_replacement_rate * $out->{'parent1_earnings_w'}, $max_fli_benefit_w);
			}

			if($in->{'parent2_age'} >= 18) {
				if ($out->{'parent2_earnings_w'} >= $minimum_weekly_earnings && $in->{'parent2_immigration_status'} ne 'undocumented_or_other') {
					$fli_recd_parent2_w = &least($wage_replacement_rate * $out->{'parent2_earnings_w'}, $max_fli_benefit_w);
				}
			}
			
			#Total the weekly benefit amounts based on how much time off they need, capped at the maximum allowable FLI length
			$parent1_fli_recd = &least($maximum_fli_weeks, $in->{'mother_timeoff_for_newborn'} + $in->{'parent1_time_off_foster'}) * $fli_recd_parent1_w; 
			
			if($in->{'parent2_age'} >= 18) {
				$parent2_fli_recd  = &least($maximum_fli_weeks, $in->{'other_parent_timeoff_for_newborn'} +$in->{'parent2_time_off_foster'}) * $fli_recd_parent2_w; #this interpretation of policy indicates that a parent cannot take more than 12 weeks off in a year, even if they have two different qualifying reasons for taking FLI.
			}
			$fli_recd = $parent1_fli_recd + $parent2_fli_recd; 
			
			#Determine how much they need in potentially medically-covered time off. This will be the time that FLI doesn't cover if they take FLI, and the typical TDI time, in cases that don't take TDI.
			$remaining_tdi_time = pos_sub($in->{'mother_timeoff_for_newborn'} + $in->{'parent1_time_off_foster'}, $maximum_fli_weeks); #even though you can't take TDI for a new foster child, the time we assign as how much FLI can cover for the birth of a newborn is reduced by how much time the parent spends bonding with a foster child. 
		} else {
			$remaining_tdi_time = &least($in->{'mother_timeoff_for_newborn'}, $typical_tdi_weeks);
		}
		#The benefits/time off is capped at 12 times the individual's weekly benefit in a 12 month period, regardless of whether you have two reasons for taking leave. "Claims beginning July 1, 2020 or after, can receive benefits for up to twelve consecutive weeks (84 days) or up to eight weeks (56 days) of intermittent leave in a 12-month period, provided one-third (1/3) of the total gross base year earnings is the higher benefit amount. The 12-month period begins on the first day of the child's placement or adoption.If you have not claimed your maximum benefit amount, you may reestablish a claim within the same 12-month period to care for a family member, or during or following employment with a different employer." -  https://www.myleavebenefits.nj.gov/labor/myleavebenefits/worker/fli/index.shtml. #"The maximum total benefits payable to any 4 eligible individual for any period of family temporary disability leave commencing on or after July 1, 2  2020, shall be twelve times the individual's weekly benefit amount; provided that the maximum amount shall be computed in the next lower multiple of $1.00, if not already a multiple thereof." - https://www.njleg.state.nj.us/Bills/2018/AL19/37_.PDF 
		
		if ($in->{'tdi'} == 1 && $in->{'children_under1'} > 0) { #if they are only taking off to bond with a foster child, tdi is neither needed nor taken.
			$fli_tdi_flag = 1;
			#Do a similar operation as above for TDI, but only for the birth mother, as the other parent does not need time to recover from childbirth.
			if ($out->{'parent1_earnings_w'} >= $minimum_weekly_earnings && $in->{'parent1_immigration_status'} ne 'undocumented_or_other') {
				$tdi_recd_parent1_w = &least($wage_replacement_rate * $out->{'parent1_earnings_w'}, $max_tdi_benefit_w);
			}
			$parent1_tdi_recd = &least($typical_tdi_weeks, $remaining_tdi_time) * $tdi_recd_parent1_w;
			$tdi_recd = $parent1_tdi_recd;
		} 
	}
	
	#Total them up in case this helps for other programs.
	$fli_plus_tdi_recd = $fli_recd + $tdi_recd;
	
	# outputs
	foreach my $name (qw(fli_recd_parent1_w fli_recd_parent2_w tdi_recd_parent1_w fli_recd tdi_recd fli_plus_tdi_recd maximum_fli_weeks parent1_fli_recd parent2_fli_recd parent1_tdi_recd parent2_tdi_recd fli_tdi_flag)) {
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}
1;
