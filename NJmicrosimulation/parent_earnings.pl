#=============================================================================#
#  Parent Earnings -- 2021 (copy of 2020)
#=============================================================================#
# Inputs referenced in this module:
#
#  FROM BASE:
#  Inputs:
#  family_structure
#  parent1_first_max  #  The user-entered variable answering the question, only if family_structure = 2, “How many hours will the first parent work in a week before the second parent begins working? Default: 40. 
# parent1_max_work # If family_structure = 1, the answer to the question “How many hours is the maximum amount of time the parent works in a week?” If family_structure = 2, the answer to the question “How many hours is the maximum amount of time the first parent works in a week?” Default = 40, maximum = 168. This allows greater earnings at set hourly wages but also result in more child care incurred. The program would have to stop the user to reenter amounts if parent1_max_work < parent1_first_max or if parent1_max_work is set to 0. This cannot exceed 24*maxworkweek_parent1.
#																								  
# parent2_max_work_override_amt: Default = 40, max = 168. Default = 40, max = 168. For two-parent families, the calculation for parent_workhours_w is partially based on parent2_max_hours, which equals 0, 20, or 40 depending, respectively, on whether parent2_max_work = N, H, or F. This variable will allow us to adjust parent2_max_hours away from these three categories, either from 0-40 or even above 40 (which could be the case for two jobs or undocumented work). It is important to note here that as currently constructed, parent_workhours_w is not bounded by the 40-hour assumed workweek, since it is imputed from earnings; as earnings incrementally increase above the sum of 40 and parent2_max hours (based on the interval variable),  parent1_employedhours_w rises to reach weekly earnings. This seems to be a clever trick that effectively results in earnings first being tracked to rising hours worked between the working parents, and then being tracked to the appearance of rising wages after maximum hours worked are reached, even though actually it’s the hours that continue to rise (even to above the number of hours in a week). This cannot exceed 24*maxworkweek_parent2. 
#       parent2_max_work	#user selected in Step 3 – ‘N’ means second parent doesn’t work, ‘H’ means the # parent works part-time, or 20 hours a week.
#  		maxshiftlength_parent1 
# 		maxshiftlength_parent2 
# 		maxworkweek_parent1 
# 		maxworkweek_parent2 
# 		backtobackshifts_parent1 
#		backtobackshifts_parent2 

#       wage_1
#       wage_parent2
	 
#     Outputs:
#       earnings
#
#=============================================================================#

sub parent_earnings
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};

	# outputs created
    our $parent1_employedhours_w = 0; # number of hours/week parent 1 works in paid employment
    our $parent2_employedhours_w = 0; # number of hours/week parent 2 works in paid employment
    our $parent1_transhours_w = 0;   # This variable is unchanged in this code, but we need to establish it as 0 here in order for the revised child care codes to work successfully. The child care module will likely be run twice, first before the work module recalculates this variable based on tanf participation and then again, after. Changes in these variables are indicators of participation in TANF work requirements, so the child care module will be able to detect  this change the second time it is run.
    our $parent2_transhours_w = 0; # same justification as parent1_transhours above
    our $parent1_earnings = 0;        # parent 1's earnings per year
    our $parent2_earnings = 0;        # parent 2's earnings per year
    our $parent1_earnings_m = 0;	  # parent 1's earnings per month
    our $parent2_earnings_m = 0;      # parent 2's earnings per month
	our $parent_workhours_w = 0; 
	our	$caregiver_workshifts_w = 0; 
	our	$caregiver_maxworkweek = 0; 
	our	$caregiver_maxshiftlength = 0; 
	our	$caregiver_backtobackshifts= 0; 
	our $parent_otherhours_w = 0; 
	# variables used in this script
    our $wage1_annualized = 0;           # hourly wage rate * 52 weeks/year
                                        # if you divide parent 1's earnings by this figure, you will
                                        # get the number of hours worked per week
    our $wage2_annualized = 0;           # hourly wage rate * 52 weeks/year
                                        # if you divide parent 2's earnings by this figure, you will
                                        # get the number of hours worked per week
    our $parent2_max_hours_w = 0;        # max hours worked by second parent per week
    our $parent1_fulltime_earn = 0;      # annual earnings of first parent at the point at which the
                                        # parent reaches maximum-time employment
                                        # (ie, 35 hours/week, 52 weeks/year)
    our $parent2_maxtime_earn = 0;       # annual earnings of second parent at the point at which the
                                        # parent reaches maximum-time employment
    our $parent1_first_earn = 0; # This is the amount that the first parent earns after which the second parent begins working.
    our $firstrunchildcare = 1; # I think we need something like this in order for the child care codes to run either if it’s the first time through or if tanf work requirements need to be enacted.
	our $tanflock = 0; #this may be necessary to avoid a nonsensical scenario during the second run of tanf, depending on what state-level policies use tanf receipt as an input. Developed in 2017 because necessary for proper modeling of DC policies.
	our $shifts_parent1 = 0;
	our $shifts_parent2 = 0;
	our $multipleshifts_parent1 = 0;
	our $multipleshifts_parent2 = 0;
		
	# We now also add zero-value definitions for a slew of variables that need to be defined early in the code in order for the loop incorporating child support, child care, tanf, and tanf work requirements to run correctly. Se tanf code for further explanation on this.

	our $child_support_paid = 0; # Since we will need to invoke these output variables in the child_support code, we need to establish them as output variables in earlier code, e.g. here.  (I think this is legacy code? -SH 3/11)
	our $child_support_paid_m = 0;  # Since we will need to invoke these output variables in the child_support code, we need to establish them as output variables in earlier code, e.g. here. (I think this is legacy code? -SH 3/11)
	our $tanf_recd = 0;
	our $tanf_recd_m = 0;
	our $tanf_recd_proxy = 1; #Setting this as another binary variable, so that the SSI code can use this to initially assume all parental income is excluded because of assumed TANF receipt, at first run. Once TANF eligibiltiy and benefit receipt is determined, the tanf code will set this tanf_poxy variable to 0, and use the real tanf_amounts.
	our $child_support_recd = 0;
	our $child_support_recd_m = 0;
	our $parent2_incapacitated = 0;
	our $tanf_family_structure = 0;
	our $unit_size = 0;
	our $stipend_amt = 0;
	our $tanf_sanctioned_amt = 0;
	our $fsp_recd = 0;
	our $prop_tax_credit_recd = 0;
	our $state_cadc_recd = 0;
	our $ctc_total_recd = 0;
	our $tax_before_credits = 0; #Need this variable defined for first run of child_support in NJ.
	our $child_care_expenses = 0;
	our $cc_expenses_child1 = 0;
	our $cc_expenses_child2 = 0;
	our $cc_expenses_child3 = 0;
	our $cc_expenses_child4 = 0;
	our $cc_expenses_child5 = 0;	
	our $gift_income_m = 0;
	our $gift_income = 0;

	#Additional variables to accommodate FLI and TDI code, introduced for NJ in 2021:
	our $parent1_workweeksperyear = 0;
	our $parent2_workweeksperyear = 0;
	our $parent1_earnings_w = 0;
	our $parent2_earnings_w = 0;
	
	
	# This is where we set the variables that feed into the nontraditional work schedule modeling to default (traditional) values, if the user has selected that family members work traditional schedules. 
  
	if ($in->{'nontraditionalwork'} == 0) { 
		our $in->{'parent1_max_work'} = 40;
		our $in->{'maxshiftlength_parent1'} = 8;
		our $in->{'maxworkweek_parent1'} = 5;
		our $in->{'backtobackshifts_parent1'} = 0;
		our $in->{'weekenddaysworked'} = 0;
		our $in->{'maxweekendshifts'} = 0;
		our $in->{'workdaystart'} = 9;
		our $in->{'maxshiftlength_parent2'} = 8;
		our $in->{'maxworkweek_parent2'} = 5;
		our $in->{'parent1_first_max'} = 40;
		our $in->{'backtobackshifts_parent2'} = 0;
		our $in->{'breadwinner_wkday_hometime'} = 0;
		our $in->{'breadwinner_wkend_hometime'} = 0;
	}
  
	# determine maximum hours worked by second parent
    if($in->{'family_structure'} == 1) {
        $parent2_max_hours_w = 0;
		$in->{'parent1_first_max'} = $in->{'parent1_max_work'}; 
  
    } elsif($in->{'parent2_max_work_override_amt'} && $in->{'nontraditionalwork'} == 1) {
         $parent2_max_hours_w = $in->{'parent2_max_work_override_amt'};
 
	} else {
        if($in->{'parent2_max_work'} eq 'N') { $parent2_max_hours_w = 0; }
        elsif($in->{'parent2_max_work'} eq 'H') { $parent2_max_hours_w = 20; }
        else { $parent2_max_hours_w = 40; }
    }


	#Calculate number of weeks worked. This is important for families who take time off for a newborn:
	if ($in->{'children_under1'} > 0) {
		$parent1_workweeksperyear = 52 - $in->{'mother_timeoff_for_newborn'} - $in->{'parent1_time_off_foster'}; 
		$parent2_workweeksperyear = 52 - $in->{'other_parent_timeoff_for_newborn'} - $in->{'parent2_time_off_foster'}; 
		
 	} else {
		$parent1_workweeksperyear = 52;
		$parent2_workweeksperyear = 52;
	}
		
	# determine parents' work hours and earnings
    $wage1_annualized = $in->{'wage_1'} * $parent1_workweeksperyear;
    $wage2_annualized = $in->{'wage_parent2'} * $parent2_workweeksperyear;
    $parent1_first_earn = $wage1_annualized * $in->{'parent1_first_max'}; 
    $parent1_fulltime_earn = $wage1_annualized * $in->{'parent1_max_work'};  
    $parent2_maxtime_earn = $wage2_annualized * $parent2_max_hours_w;

    if( $out->{'earnings'} <= $parent1_first_earn) {
        $parent1_employedhours_w = $out->{'earnings'} / $wage1_annualized;
        $parent1_earnings = $out->{'earnings'};
        $parent2_employedhours_w = 0;
        $parent2_earnings = 0;
	 
    } elsif( $out->{'earnings'} <= $parent1_first_earn + $parent2_maxtime_earn) {
        $parent1_employedhours_w = $in->{'parent1_first_max'}; 
        $parent1_earnings = $parent1_first_earn;
        $parent2_earnings = $out->{'earnings'} - $parent1_earnings;
        $parent2_employedhours_w = $parent2_earnings / $wage2_annualized;
	 
    } elsif( $out->{'earnings'} <= $parent1_fulltime_earn + $parent2_maxtime_earn) {

        $parent1_employedhours_w = ($out->{'earnings'} - $parent2_maxtime_earn)/ $wage1_annualized;
        $parent1_earnings = $out->{'earnings'} - $parent2_maxtime_earn;
        $parent2_employedhours_w = $parent2_max_hours_w; 
        $parent2_earnings = $parent2_maxtime_earn;
    } else {
	   
        $parent2_employedhours_w = $parent2_max_hours_w;
        $parent2_earnings = $parent2_maxtime_earn;
        $parent1_earnings = $out->{'earnings'} - $parent2_earnings;
        $parent1_employedhours_w = $in->{'parent1_max_work'};  
    }
    
    $parent1_earnings_m = $parent1_earnings / 12;
    $parent2_earnings_m = $parent2_earnings / 12;
	$parent1_transhours_w = $parent1_employedhours_w;
	$parent2_transhours_w = $parent2_employedhours_w;										  

	$parent1_earnings_w =  $parent1_earnings / $parent1_workweeksperyear;
	$parent2_earnings_w =  $parent2_earnings / $parent2_workweeksperyear;


	if ($in->{'maxshiftlength_parent1'} > 0) {
		$shifts_parent1 = $parent1_transhours_w / $in->{'maxshiftlength_parent1'};
	}
	if ($in->{'maxshiftlength_parent2'} > 0) {
		$shifts_parent2 = $parent2_transhours_w / $in->{'maxshiftlength_parent2'};
	}	
	$multipleshifts_parent1 = pos_sub($shifts_parent1, $in->{'maxworkweek_parent1'});
	$multipleshifts_parent2 = pos_sub($shifts_parent2, $in->{'maxworkweek_parent2'});	
	
	if ($in->{'family_structure'} == 1) { 
		$parent_workhours_w =  $parent1_employedhours_w;
		$caregiver_workshifts_w = $shifts_parent1;
		$caregiver_maxworkweek = $in->{'maxworkweek_parent1'};
		$caregiver_maxshiftlength = $in->{'maxshiftlength_parent1'};
		$caregiver_backtobackshifts= $in->{'backtobackshifts_parent1'};

	} else {
		$parent_workhours_w = &least($parent2_employedhours_w, $parent1_employedhours_w);
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
	
	#Adding in gift income:
	$gift_income_m = $in->{'gift_income_m'};	
	$gift_income = 12 * $gift_income;
	
    
  # outputs
    foreach my $name (qw(firstrunchildcare parent1_employedhours_w parent2_employedhours_w parent1_earnings parent2_earnings parent1_earnings_m parent2_earnings_m parent1_transhours_w parent2_transhours_w  shifts_parent1 shifts_parent2 multipleshifts_parent1 multipleshifts_parent2 parent_otherhours_w caregiver_workshifts_w caregiver_maxworkweek caregiver_maxshiftlength caregiver_backtobackshifts parent_workhours_w child_support_paid child_support_paid_m tanf_recd tanf_recd_m child_support_recd child_support_recd_m parent2_incapacitated tanf_family_structure unit_size stipend_amt tanflock tanf_sanctioned_amt fsp_recd gift_income_m gift_income tanf_recd_proxy parent1_earnings_w parent2_earnings_w child_care_expenses prop_tax_credit_recd state_cadc_recd ctc_total_recd tax_before_credits cc_expenses_child1 cc_expenses_child2 cc_expenses_child3  cc_expenses_child4 cc_expenses_child5 )) { 
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;