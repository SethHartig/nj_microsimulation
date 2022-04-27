#=============================================================================#
#  Section 8 Module – 2020 (modified from 2017) 
#=============================================================================#
# Calculates section 8 benefits
# Inputs referenced in this module:
#
#   FROM BASE
#     Inputs:
#       sec8
#       child_number
#       interval
#       rent_cost_m
#       state                      
#       residence                   
#       family_size    
#       last_received_sec8 
#       disability_parent1
#       disability_parent2
#       disability_work_expenses_m      # This is also a new user-entered input. We need to make explicit that we are assuming that this amount is what is used to enable the disabled parent(s) to work. 
#		child#_foster_status
#	
#	FROM FOSTERCARE:
#		foster_children_count 
#
# Outputs:
#       earnings
#     
#   FROM INTEREST
#       interest
#
#  FROM PARENT EARNINGS
#       parent1_earnings
#       parent2_earnings
# 
#   FROM SSI
#       ssi_recd
#
#   FROM TANF
#       tanf_recd
#       child_support_recd
#	max_housing_allowance_m
#
#   FROM CHILD CARE
#       child_care_expenses
#
#	FROM FLI_TDI
#		fli_plus_tdi_recd
#
#=============================================================================#

sub sec8
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};


  # outputs created
    our $rent_paid = 0;               # Annual rent paid by family: Tenant rent burden or full rent for families w/out subsidies
    our $rent_paid_m = 0;             # Monthly rent paid by family
    our $housing_recd = 0;            # Housing subsidy (Section 8 voucher) value, annual
    our $housing_subsidized = 0;      # a logical value indicating whether housing is subsidized
	
  # Variables used here
    our $sec8_dependent_ded     = 480;  	# exemption per dependent 
    our $sec8_dis_ded = 400; 		#exemption for any disabled family member 
    our $sec8_dis_ded_recd = 0; 		#amount received from exemption for any disabled family member in sec8 calcs.
  # Variables created
    our $sec8_cc_ded_recd   = 0;     # child care deduction
    our $sec8_gross_income  = 0;    # gross income for determining tenant rent burden
    our $sec8_net_income    = 0;      # adjusted income for determining tenant rent burden
    our $rent_preliminary   = 0;     # preliminary rent [assuming (continuing) eligibility for vouchers]
    our $sec8_payment_standard = 0;  # HUD payment standard used to determine subsidy, based on Fair Market Rents.
#    our $verylow_income_limit = 0;   #	very-low income limit used by HUD as a base to determine entrance eligibility
#    our $low_income_limit = 0;      # low income limit used by HUD as a base to determine exit eligibility
# OUTDATED (See below note):		   
#    our $ami_adjustment  = qw(0 0.7 0.8 0.9 1 1.08 1.16 1.24)[$in->{'family_size'}];       # The family-size adjustment factors that HUD uses to determine income limits based on the 4-person base numbers. Source: see page 4 in https://www.huduser.gov/portal/datasets/il/il17/HUD-sec8-FY17.pdf 
#    our $base_50_percent_ami = 0;
#    our $base_80_percent_ami = 0;
    our $dis_asst_ded = 0;			# disability expenses deduction for determining net income
    our $med_expenses_ded = 0; 		#medical expenses deduction for determining net income 
#    our $ratable_reduction_percent = 0.496;   # VT % to reduce housing allowance amount   
	our $sec8_eligible_dependents = 0;

    # Start debug variables
    our $earnings = $out->{'earnings'};
    our $child_care_expenses = $out->{'child_care_expenses'};
     # End debug variables
    our $rent_difference = 0; #2019 addition, to account for voucher programs where renters can pay the difference between Section 8 standards and available rent costs.

	#NOTE: In previous FRS iterations and originally in this code, we used the initial entrance criteria (50% of the AMI) and a perceived exit income criteria (80% of the AMI) to determine continuing eligibiltiy and eligibility for reentry into Section 8. However, upon further review of HUD 2019 documentation, we found that these criteria are inappropriate to use in this context. Once you are in Section 8 or HCVP, no more income tests are applied. The benefit of the program can go down to 0 as adjusted income rises, or go back up again if adjusted income drops as gross income rises (e.g. if the family loses child care subsidies, raising the value of HCVP's child care deduction), but there is no income above which people lose their voucher or their project-based apartment. I have commented out the relevant codes and indicated where notes are outdated below.
	
	#IMMIGRANT ELIGIBILITY:  only documented immigrants are eligible for Section 8 housing. 
	
     # OUTDATED Intro Note 1: The last_received_sec8 variable indicates the earnings level that family last had 
     # their rent subsidized by section 8 housing subsidies. It is assigned a value of 0 in the base program 
     # (frs.pl), and retains that value unless/until it is changed in this (the Section 8) module. If changed 
     # in the Section 8 module, it should keep the new value unless/until it is changed again in this same 
     # (Section 8) module again at a different earnings level. It is through this variable that we are able to 
     # disallow families no longer eligible for the program at one earnings level above entrance eligibility 
     # criteria from receiving section 8 once their earnings exceed entrance eligibility criteria, even if that 
     # earnings level is below the exit eligibility criteria but they qualify via a negative adjusted income shock 
     # (such as would happen if they lose child care subsidies).

    # OUTDATED Intro Note 2: It seems important to note that in the frs.pm program, rent_cost_m is (or seems to be) calculated 
    # either as (a) housing_override_amt, if the housing_override input flag is selected, or (b) rent, from the base tables, 
    # based on id (location) and number_children. It is therefore not necessarily equal to the fair market rent.

    # Intro Note 3: Because the 2015 FRS does not include VT or NY, I have commented out the code that refers solely to those states.

    if($in->{'sec8'} != 1) {
        $rent_paid = $in->{'rent_cost_m'} * 12;
        $rent_paid_m = $rent_paid / 12;
        $housing_recd = 0;

        # END
	} elsif ($in->{'family_size'} == $in->{'daca_adult_count'} + $in->{'undocumented_adult_count'} + $in->{'daca_child_count'} + $in->{'undocumented_child_count'}) { #only citizens and immigrants with legal status are eligible for housing programs. However, mixed status immigrants are still eligible. 
		$rent_paid = $in->{'rent_cost_m'} * 12;
        $rent_paid_m = $rent_paid / 12;
        $housing_recd = 0;
    } else {
        # Determine the number of countable dependents - "Household, for purposes of 24 CFR part 5, subpart I, and parts, 960, 966, 882, and 982, means the family and PHA-approved live-in aide." The definition of family includes child(ren) who is/are temporarily away from the home b/c of placement in foster care. - 24 CFR 5.403 - Definitions.
		#Foster children are not considered dependents in a family and payments received for foster care are not counted as income in determining eligibility or subsidy amount. See 24 CFR 5.603 - Definitions. https://www.law.cornell.edu/cfr/text/24/5.603 and 24 CFR 5.609 - Annual Income.  https://www.law.cornell.edu/cfr/text/24/5.609. Therefore, we re-calculate the number of children in the family to remove the foster children.
		
		$sec8_eligible_dependents = $in->{'child_number'} - $out->{'foster_children_count'};
	
		
		# Determine eligibility

        # Use "Locations" tab in the base table to determine fair market rent, used for the section 8 payment standard, based on year, state, residence, and number_children, labeling the associated value as sec8_payment_standard. Because we are shifting from  model in previous years that limited locations to a new approach of modeling many more residences in a single state, we have adjusted this SQL code to include lookups for 1-br, 2-br, 3-br, and 4-br FMRs based on family size, rather than building those different values in multiple rows for the same locality in SQL There may be a more elegant way to do this SQL call but this shoudl get the job done.

		$sec8_payment_standard = &csvlookup($in->{'dir'}.'\FRS_Locations.csv', 'rent', 'name', $in->{'residence_nj'}, 'number_children', $in->{'child_number'});

		if (1 == 0) { #EquivalentSQL

			my $sql = "SELECT rent FROM FRS_Locations WHERE state = ? AND year = ? AND id = ? AND number_children = ?";
			my $stmt = $dbh->prepare($sql) ||
				&fatalError("Unable to prepare $sql: $DBI::errstr");
			my $result = $stmt->execute($in->{'state'}, $in->{'year'}, $in->{'residence'}, $sec8_eligible_dependents) ||
				&fatalError("Unable to execute $sql: $DBI::errstr");

			$sec8_payment_standard = $stmt->fetchrow();
		}
		
		# 2017 note: In DC, the payment standard is up to 175% of the FMR for all size units (see 14 DCMR 8300).The below if-block therefore adjusts the payment standard previously attained from the area rent listed in the SQL tables. The consequence of this change will be that when users manually enter a family's rent as higher than the FMR that family will still be eligible for section 8 up to 175% of FMR. 
		# This is set up specifically for DC, for new sections please set up an if statement 
		if ($in->{'state'} eq 'DC') { 
			$sec8_payment_standard = 1.75 * $sec8_payment_standard; 
		}

		# OUTDATED:
        # Use "Locations" tab in the base table to determine "base50percentAMI" and "base80percentAMI" based on year, state, and residence..
        # my $sql = "SELECT DISTINCT base_50_percent_ami, base_80_percent_ami FROM FRS_Locations WHERE state = ? AND year = ? AND id = ?";
        # my $stmt = $dbh->prepare($sql) ||
        #    &fatalError("Unable to prepare $sql: $DBI::errstr");
        #my $result = $stmt->execute($in->{'state'}, $in->{'year'}, $in->{'residence'}) ||
        #    &fatalError("Unable to execute $sql: $DBI::errstr");

        # ($base_50_percent_ami, $base_80_percent_ami) = $stmt->fetchrow();

        # Use "income_limits" tab in the Section 8 table to determine AMI_adjustment, based on family_size.

        # $verylow_income_limit = round_to_nearest_50($base_50_percent_ami * $ami_adjustment); # rounded to the nearest 50
        #$low_income_limit = round_to_nearest_50($base_80_percent_ami * $ami_adjustment); # rounded to the nearest 50 

        # Compute gross income
        $sec8_gross_income = $out->{'earnings'} + $out->{'tanf_recd'} + $out->{'child_support_recd'} + $out->{'interest'} + $out->{'ssi_recd'} + $out->{'gift_income'} + $in->{'selfemployed_netprofit_total'} + &pos_sub($out->{'ui_recd'}, $out->{'fpuc_recd'}) + $out->{'fli_plus_tdi_recd'} + $in->{'spousal_support_ncp'};
	
        # We first calculate rent for instances either when the user accepts the fair market rent (the FRS default value) or when the user-entered rent value is lower than fair market rate. (We must also be explicit in the main interface of the 2017 DC FRS that if users enter a rent higher than 175% of the fair market rent, they will not be eligible for Section 8). Otherwise, at $0 earnings, the family would be paying more than 40% of their earnings on rent they need to pay the landlord, since that will be the difference between the payment standard (the maximum subsidy) and the rent on the unit. We are assuming that this family, once having earnings of $0, still lives in an appropriate unit that would meet this federal standard. As far as including ssi income for eligibility determination, there is a memo from 2012 that indicates as such. 

		#Income counted include: 24 CFR § 5.609 - Annual income.
		#types of income counted include SSI, as described in in subpart K 982.516 https://www.ecfr.gov/cgi-bin/text-idx?SID=db1fea8115baa15484288904baa7548e&mc=true&node=se24.4.982_1516&rgn=div8

		# SSI income is included as  income for eligibility determination, there is a memo from 2012 that indicates as such. 
																 
		# Further note about evoluation of this code: As we now (beginning in 2020) include homeownership in the FRS/MTRC model, it is importnat to note that homeownership does not exclude individuals from Section 8 / HCV participation. On the contrary, HUD can help you pay for maintenance as well as mortgage payments. As we are working to use the "rent" variable to capture these costs, since rent capture the entirety of shelter costs, the section 8 code works the same way for homeowners as it does for renters.

		#Gifts note: The HUD definition of income for Section 8 (24 CFR, Part 5, Subpart F (Section 5.609)) specifically excludes lump sum gift income but includes recurring gift income. 
		
		#COVID legislation note: FPUC (the federal $300/wk supplement to UI payments) is exempt from Section 8 income calculations acccording to HUD guidelines.

		# 2019 adjustment: I think the above is too restrictive and may just be for place-based section 8, and not the voucher program. It also removes people from Section 8 eligibiltiy when the section 8 payment standards in certain areas, like Allegheny County, are lower than the fair market rents, which we use as defaults.
		
        if ($in->{'rent_cost_m'} > $sec8_payment_standard) {
        #    $rent_paid = $in->{'rent_cost_m'} * 12; #see above note on 2019 adjustment
        #    $rent_paid_m = $rent_paid / 12; #see above note on 2019 adjustment
        #    $housing_recd = 0;
        #    goto END; 
			$rent_difference = $in->{'rent_cost_m'} - $sec8_payment_standard;
            #END
        }

		# OUTDATED: We then determine whether the family exceeds the low-income limit, which HUD uses to determine exit eligibility.
		
		# if ($sec8_gross_income > $low_income_limit) {
		#    $rent_paid = $in->{'rent_cost_m'} * 12;
		#    $rent_paid_m = $rent_paid / 12;
		#    $housing_recd = 0;
		#    goto END; #NOte: Even though the Perl code uses this "goto END" commmand, it's not necessary given some adjustments we've made over the years, in terms of proper bracketing. It could be ignored in terms of translating this to R or another language.
		#END
		#}
	  
		# if receipt of section 8 has not been continuous and the family is above the entrance eligibility limit,
		# then family should not get it

		# elsif ($in->{'last_received_sec8'} > 0 && ($out->{'earnings'} - $in->{'last_received_sec8'} > $in->{'interval'})
		#        && $sec8_gross_income > $verylow_income_limit) {
		#    $rent_paid = $in->{'rent_cost_m'} * 12;
		#    $rent_paid_m = $rent_paid / 12;
		#    $housing_recd = 0;
		#    goto END; #See above; this is a shortcut to avoide a SQL call, but isn't necessary.
			# END
		#} else {

		# Calculate child care deduction
		$sec8_cc_ded_recd = &least($out->{'child_care_expenses'}, $sec8_gross_income); 
		
		#Calculate disabled household allowance, disability assistance expenses, and medical expenses allowances for non-disabled populations.  There is only one household allowance, even if both parents are disabled. This is just for adults / heads of household; it is not for households where the children of the head of household are disabled. See 5-28 in HCV guidebook. Disabled households = where the head or spouse is disabled.
		

		if ($in->{'disability_parent1'} == 0 && $in->{'disability_parent2'} == 0)  {
			$sec8_dis_ded_recd = 0;
			$dis_asst_ded = 0; 
			$med_expenses_ded = 0;

		} else {
			$sec8_dis_ded_recd = $sec8_dis_ded;

			#Calculate disability assistance expenses and medical expenses deductions for disabled households. While there are separate calculations for each, when a household qualifies for both (which would be the case if any parent is disabled), then there are specific instructions. 
			#The disability assistance expenses deduction is for unreimbursed expenses to cover any expenses that allow a family member 18 years of age or older to be employed, which we assume is disability_work_expenses_m. The allowance is capped at the amount of income made by the disabled individual. See HCV guidebook 5-30/33.  #There is no separate deduction for children who are disabled.

			if ($in->{'disability_parent1'}  == 1)    {
				$dis_asst_ded = &least (&pos_sub($in->{'disability_work_expenses_m'}*12, $sec8_gross_income*.03), $out->{'parent1_earnings'});  
			} 

			# If there are any remaining disability_work_expenses, we apply them to the second parent if they also have a disability. 
			if ($in->{'disability_parent2'} == 1) {
				$dis_asst_ded += &least(&pos_sub(&pos_sub($in->{'disability_work_expenses_m'}*12,$dis_asst_ded), $sec8_gross_income*.03), $out->{'parent2_earnings'});
			}

			#Calculate medical expenses deduction. This deduction is only available to "elderly or disabled households," but, similar to the other disability-related deductions, the definition of that is restricted to households where the head of household is elderly or disabled, not their dependents. However, for these households, the medical expenses covered by the medical expense deduction include expenses for all family members. 
			$med_expenses_ded = &pos_sub($out->{'health_expenses'}, &pos_sub($sec8_gross_income*.03, $dis_asst_ded));
			
		}

		#Calculate medical expenses deduction. This deduction is only available to elderly or disabled households. Any unreimbursed medical expenses the family incurs, regardless of whether medical expenses are for people with disabilities, are eligible for this deduction.


		# Compute adjusted income
		$sec8_net_income = &pos_sub($sec8_gross_income, ($sec8_dependent_ded * $sec8_eligible_dependents + $sec8_cc_ded_recd + $sec8_dis_ded_recd + $dis_asst_ded + $med_expenses_ded)); 

		# 2. DETERMINE RENT

	  
		# While we use the variable name rent_preliminary below, this is actually a calculation of the "Total Tenant Payment" (TTP) per HUD guidelines. When rent_cost_m is equal to the rent listed in the base tables, and that rent is based on the 50th percentile market rate  (fair market rent), we can use it as the “Payment Standard” that constitutes the maximum subsidy that HUD provides through the Housing Choice Voucher Program. 

		$rent_preliminary = &greatest( (0.3 * $sec8_net_income), (0.1 * $sec8_gross_income) );
		$rent_paid = &least($rent_preliminary + $rent_difference * 12, $in->{'rent_cost_m'} * 12); #Note: rent_difference is added beginning in 2019 and beyond. This will allow better modeling of non-project based Section 8 vouchers.

		if ($rent_paid < $in->{'rent_cost_m'} * 12) {
			$housing_subsidized = 1;
		} else {
			$housing_subsidized = 0;
		}

		$rent_paid_m = $rent_paid / 12;

		#     }

		# 3. DETERMINE SUBSIDY VALUE
		$housing_recd = &pos_sub($in->{'rent_cost_m'} * 12, $rent_paid);

		#4. DETERMINE SUBSIDY VALUE FOR HOUSEHOLDS WITH MIXED STATUS FAMILY MEMBERS	
		if ($in->{'undocumented_adult_count'} + $in->{'daca_adult_count'} + $in->{'daca_child_count'} + $in->{'undocumented_child_count'} > 0) {
			
			$housing_recd = $housing_recd * (($in->{'family_size'} - ($in->{'undocumented_adult_count'} + $in->{'daca_adult_count'} + $in->{'daca_child_count'} + $in->{'undocumented_child_count'}))/$in->{'family_size'}); # mixed status families receive a pro-rated assistance amount, although calculations of annual income includes income of all family members, regardless of immigration status. See https://www.law.cornell.edu/cfr/text/24/5.520. 24 CFR 5.520 - Proration of assistance. 
			
			#We use this prorated amount to extrapolate rent_paid_m and rent_paid.
			$rent_paid = &pos_sub($in->{'rent_cost_m'} * 12, $housing_recd);
			$rent_paid_m = &round($rent_paid / 12);
		
		}		
		# OUTDATED: Note that family has received section 8 at this income level
		# if($housing_recd > 0) {
		#    $in->{'last_received_sec8'} = $out->{'earnings'};
		#}
        #}
    }
    
	#OUTDATED		 
    # our $last_received_sec8 = $in->{'last_received_sec8'};
    

# END:
	# outputs
    foreach my $name (qw(rent_paid rent_paid_m housing_recd housing_subsidized rent_difference sec8_eligible_dependents)) { #  
 		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}
1;