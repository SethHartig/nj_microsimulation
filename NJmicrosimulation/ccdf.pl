# =============================================================================#
#  CCDF Module -- 2021 – NJ
#=============================================================================#
# Inputs referenced in this module:
#       ccdf
#       disability_parent1 
#       disability_parent2
#
#     FROM BASE:
#       earnings
#       earnings_monthly
#		summerweeks_estimate
#		ccdf_copay_alt 					#policy modeling option - "Model the suspension of child care co-payments for people receiving CCDF subsidies?"
#		ccdf_threshold_alt				#policy modeling option - "Model an increase in CCDF eligibility from 250% of FPL to ___%?"
#		ccdf_threshold_user_input		user entered field.
#		
#   FROM INTEREST
#       interest
#       
#   FROM TANF
#       child_support_recd_m
#       tanf_recd_m
#
#   FROM PARENTAL WORK EFFORT
#       parent_workhours_w
#       parent1_transhours
#       parent1_employedhours
#       parent2_transhours
#       parent2_employedhours
#
# 	FROM CHILD CARE
# 		unsub_all_children
# 		spr_all_children
#		spr_child#
# 		day#care_child#	
# 		summerday#care_child#
# 		child#_weekly_cc_hours
# 		child#_weekly_cc_hours_summer
# 		spr_child#
# 		fullcost_child#
# 		fullcost_all_children
#		weeks_off			
#
#	FROM SSI
# 		child_ssi_recd
#		child#_ssi_recd (possibly may need this, unsure, see LOOK AT ME note below)
#

sub ccdf
{
    my $self = shift; #It appears that the line my "$self = @_;" also does the same exact thing here. I'm not sure which is more efficient.
    my $in = $self{'in'};
    my $out = $self{'out'};

    
  # outputs created
    our $cc_subsidized_flag = 0;          # flag indicating whether or not child care is  subsidized
    our $ccdf_eligible_flag = 0;          # flag indicating whether eligible
    our $child_care_recd = 0;             # annual value of child care subsidies (cost  of care minus family expense)
    our $ccdf_threshold = 2.50;           # ccdf income exit eligibility limit as a percent of poverty    
    our @ccdf_85smi_array = (0,60404,74317,94389,112802,120452,128102,135752,143402,151502); # The SMIs included in the NJ DHS eligibiltiy schedule; the source included is the Census Median Family Income figures for family size as of 11/1/20.  
    our $ccdf_85smi = $ccdf_85smi_array[$in->{'family_size'}]; 
	our $ccdf_chargeabovecopay = 1; #Some states, like NJ, allow providers to charge parents an overage amount of the difference between the SPR and the equivalent rate they would have charged without subsidies.
	our $ccdfhoursmin_working = 30; #work requirements for CCDF eligibility
	our $ccdfhoursmin_training = 20; #training for this amount of hours per week (or being a full-time student) also qualifies a parent for being eligible for child care subsidies.
  # determined in module
    our $ccdf_income = 0;                 # income used to determine ccdf eligibility and copay 
    our $ccdf_income_m = 0;
	our $ccdf_poverty_percent = 0;        # family income as percent of poverty
  	our $ccdf_copay = 0;                   # annual copay charged to family (if copay exceeds state reimbursement for all children, then model assumes that family opts out of ccdf program)
	our $overage_payment = 0; #This variable will be the difference between SPRs and unsubsidized child care, which child care providers can charge parents as long as ccdf_chargeabovecopay =1.
	our $ccdf_phaseout_income = 0;
	our $cc_fulltime_count = 0;
	our $cc_parttime_count = 0;
	our $summer_cc_fulltime_count = 0;
	our $summer_cc_parttime_count = 0;
	our $fulltime1 = 0;
	our $fulltime2 = 0;
	our $parttime1 = 0;
	our $parttime2 = 0;
	our $summerweeks = 0;
 	our $child_care_expenses = 0; # total annual child care expenses
 	our $child_care_expenses_m = 0; 
	our $spr_ccdf_eligible_children = 0;
	our $fullcost_ccdf_eligible_children = 0;
	our $unqualified_child_care_expenses = 0;
	
	#We need to establish the following variables to feed the child support code correctly in its second run.
	our $cc_expenses_child1 = 0; 
	our $cc_expenses_child2 = 0; 
	our $cc_expenses_child3 = 0;
	our $cc_expenses_child4 = 0;
	our $cc_expenses_child5 = 0;
	our $ccdf_child_count = 0;

	my $sql = "SELECT DISTINCT summerweeks FROM FRS_Locations WHERE state = ? && year = ? && id = ?";
	my $stmt = $dbh->prepare($sql) || 
		&fatalError("Unable to prepare $sql: $DBI::errstr");
		$stmt->execute($in->{'state'}, $in->{'year'}, $in->{'residence'}) ||
		&fatalError("Unable to execute $sql: $DBI::errstr");
		$summerweeks = $stmt->fetchrow();

	# STEP 1: Test if there is any child care need.
    if ($out->{'unsub_all_children'} == 0 || $in->{'ccdf'} == 0) {	
        $cc_subsidized_flag = 0;
        $ccdf_eligible_flag = 0;
        $child_care_recd = 0;
	#} elsif ($in->{'child_number'} == $in->{'unqualified_immigrant_child_count'} ) {	#Added check for  whether all children are unqualified. These inputs are created in frs.pm. Only the child's immigration status is relevant for eligibility determination because the child is considered the primary beneficiary of CCDBG.  See 2016 final rule for CCDF eligibility (page 24) https://www.govinfo.gov/content/pkg/FR-2016-09-30/pdf/2016-22986.pdf and https://www.clasp.org/sites/default/files/public/resources-and-publications/publication-1/Immigrant-Eligibility-for-ECE-Programs.pdf. 
	#But this seems unnecessary given the checks below, and also because we are including TANF eligibiltiy for certain federally unqualified children, meaning we have to model the provision of child care for these families.
	#	$cc_subsidized_flag = 0;
    #    $ccdf_eligible_flag = 0;
    #    $child_care_recd = 0;
	} else {
		#  STEP 2: DETERMINE FINANCIAL ELIGIBILITY FOR CCDF SUBSIDIES
		# From NJ CCDF state plan: Income is defined as the amount of current gross income earned by all members of the family unit through the receipt of wages including overtime, tips, bonuses or commissions from activities in which he/she is engaged as an employee from his/her self-employment. Unearned income such as social security, pensions, retirement, unemployment, worker's compensation, public assistance, child support, alimony and any other income required for federal and state tax reporting purposes is calculated in the income. foster care payments are not included because they are not taxable income.
		#
		# Note: although Social Security income is included in income tabulations, child SSI is explicitly exempted, but adult SSI is not. 
		#Investigate whether it's only the children that are receiving ccdf (age < 13) whose ssi income is exempted or if it's all child ssi income that is excluded (even if age > 13). No official documentation on this is easily accessible, but kept as below, with all child ssi income is excluded. In this application for care assistance online, provider does not ask about any child's earned or unearned income, only the parents/adults: https://ccrnj.org/wp-content/uploads/2021/03/Entire-Application-File-3.1.2021.pdf. 

		$ccdf_income = $out->{'earnings'} + $out->{'interest'} + $out->{'child_support_recd'} + $out->{'tanf_recd'} + ($out->{'ssi_recd'} - $out->{'child_ssi_recd'}) + $out->{'fli_plus_tdi_recd'} + $out->{'ui_recd'} + $in->{'spousal_support_ncp'}; #Assuming that fli and tdi benefits are treated the same way as UI.
		$ccdf_poverty_percent = $ccdf_income / $in->{'fpl'};
		
		# 
		# Page 43  of the child care subsidy manual clarifies exit eligibility income requirements. Technically, this also includes assets not exceeding $1,000,000, but I think we can leave out the millionaires for now. Return to include assets in this, time permitting.

		# One possible policy option for either reducing co-pays or qualifying for child care subsidies might be to use policy triggers to incentivize businesses to offer dependent care flexible spending accounts to their employees, which allow employees to deposit pre-tax earnings into an account dedicated to paying for costs such as child care. Having access to an account like this would seem to allow employee earnings to fall below income eligibility thresholds for a number of programs (e.g. CCDF, SNAP, and TANF), which would be helpful  if cash or near-cash benefits from those programs increase net resources by more than the amount that families might lose by no longer qualifying for the child and dependent care tax credit, which I think would no longer be available if enrolled in a dependent care FSA. For all these benefit programs, we'd also have to check whether funds in a dependent care FSA count as assets (or if assets that spent in the same month they are received are not actually assets).

		# Note: I noticed this while writing the CCDF requirements, but as currently construed our family structures do not include non-parent adult dependents (e.g., attending college). Consider revising in later iterations of the FRS.
		#FOSTER FAMILIES are categorically eligible for ccdf as long as their income is less than 250% of fpl. See NJAC 10:15-5.3 - about out-of-home placement. foster care is a type of out of home placement - see definitions of foster home and out of home placement in section 10:15-1.2. 
		
		
		if ($in->{'ccdf_threshold_alt'}==1){
			$ccdf_threshold = $in->{'ccdf_threshold_user_input'}/100;
		}
		
		if($ccdf_poverty_percent > $ccdf_threshold && $ccdf_income > $ccdf_85smi && $out->{'tanf_recd'} == 0 && $in->{'recent_tanf_exit_flag'} == 0) {
			$cc_subsidized_flag = 0;
			$ccdf_eligible_flag = 0;
			$child_care_recd = 0;
			
		} else {
			#NOTE WHETHER FAMILIY IS IN THE "PHASE-OUT" PERIOD
			if($ccdf_poverty_percent > $ccdf_threshold && $ccdf_income <= $ccdf_85smi) {
				#"The second tier is set at the equivalent of 85% of SMI. NJ's Graduated Phase-Out Period of Assistance is a one year period of continued assistance that is granted when a family's income has exceeded 250 percent of the FPL but remains below 85 percent of the SMI at re-determination, The Graduated Phase-Out Period of Assistance is a one year period of continued assistance that is granted when a family's income has exceeded 250 percent of the FPL but remains below 85 percent of the SMI at re-determination. A Graduated Phase-Out Period of Assistance commences at the beginning of a new eligibility period." - NJ CCDF State Plan.
				#While this distinction for the wehen income is between  250% FPL and 85% SMI is not relveant for the online FRS -- which has a one-year outlook -- it may be important for the FRS microsimulation, in that after a year at this income level, the family will lose CCDF subsidies. Marking this with a variable here in case it comes in handy later on.
				$ccdf_phaseout_income = 1
			}
			# STEP 3: CHECK WORK REQUIREMENTS

			#From our reading of Section 10 90-5.2 of the New Jersey administrative code, it seems that New Jersey’s WFNJ/TANF program will provide access to child care pay for all child care free of charge for TANF recipients. "Payment of child care services, including after-school child care in the case of a child over six years of age and care for children with special needs, shall be available for WFNJ/TANF eligible dependent children during the recipient's period of eligibility and for the 24 consecutive months following ineligibility for cash benefits as a result of earned income or other circumstances as described in this subchapter. Depending upon the type of child care program, payment for child care services will be provided in accordance with N.J.A.C. 10:15 and appropriate child care co-payment procedures at N.J.A.C. 10:15-9." So this is not free child care, but ensures child care at the rates specified  via CCDF eligibiltiy and allows a family coming off TANF to not be bound by CCDF work requirements. 
			
			if ($out->{'tanf_recd'} > 0 || $in->{'recent_tanf_exit_flag'} == 1) { #If a family is currently receiving TANF or has received TANF in the past 24 months:
				$ccdf_eligible_flag = 1;
			} elsif ($in->{'family_structure'} == 1) { #1-parent family not on TANF or recently on TANF
			# Previously had "|| ($out->{'parent2_incapacitated'} == 1 && $out->{'tanf_recd'} > 0)) {" added to this condition, which may have been legacy code, but was clearly intended to assign potential CCDF eligibility to two-parent families that included one parent with a disability severe enough that they are not capable of child care themselves. This likely allows for CCDF eligibitiy in some states. But in NJ, any family receiving TANF never pays for child care, or at least is eligible for free child care, so this is irrelevant -- the condition will never be invoked because their child care is already free, as indicated in the code above.
				if ($out->{'parent1_transhours_w'} < $ccdfhoursmin_working && $in->{'parent1_transhours_w'} < $ccdfhoursmin_training && $in->{'parent1_ft_student'} == 0 && ($out->{'tanf_recd'} == 0 || $in->{'tanfwork'} == 0)) { #Note the parent student variables are currently (as of 2021) inputs generated as 0's by the frs.pm program.
					$cc_subsidized_flag = 0;
					$ccdf_eligible_flag = 0;
					$child_care_recd = 0;
				} else {
					$ccdf_eligible_flag = 1;
				}
			} else { #2-parent family not on TANF or recently on TANF:
				if ($out->{'parent1_transhours_w'} < $ccdfhoursmin_working && $in->{'parent1_transhours_w'} < $ccdfhoursmin_training && $in->{'parent1_ft_student'} == 0 && $out->{'parent2_transhours_w'} < $ccdfhoursmin_working && $out->{'parent2_transhours_w'} < $ccdfhoursmin_training && $in->{'parent2_ft_student'} == 0 && ($out->{'tanf_recd'} == 0 || $in->{'tanfwork'} == 0)) {
					$cc_subsidized_flag = 0;
					$ccdf_eligible_flag = 0;
					$child_care_recd = 0;
				} else {
					$ccdf_eligible_flag = 1;
				}
			}
		
			#
			#"The co-payment scale shall consider family income, family size, hours of care needed, and number of children in care. If more than two children in a family are receiving child care services, no co-payment shall be required for the third and subsequent children in the family. The Client Income Eligibility and Co-Payment Schedule for Subsidized Child Care Assistance or Services set forth as the chapter Appendix shall be revised on an annual basis through a notice of administrative change published in the New Jersey Register. The co-payment chart calculation is based on the Health and Human Services (HHS) Poverty Guidelines, which accounts for last (calendar) year's increase in prices as measured by the Consumer Price Index. The HHS Poverty Guidelines is updated and published annually in the Federal Register as a General Notice. The co-payment is a portion of family income that is paid by an eligible family toward the cost of child care that provides for cost sharing by families that receive Child Care and Development Fund (CCDF) child care services. The amount of the required co-payment is based on a family's gross annual, income, family size, hours of care needed, and the number of children in care."
			
			#  STEP 4: DETERMINE VALUE OF SUBSIDIZED CARE AND FAMILY COPAYMENT
			#

			#The co-pay schedule for 2021-22 (and for others) includes separate co-pay rates for fulltime vs parttime care, with full-time care defined as being above 6 hours per day. The copay rates, however, are weekly and monthly. However, the NJ adminstrative code clarifies that full-time care is also defined as 30 hours per week. So we will use the weekly rates.

			if ($ccdf_eligible_flag == 1) {
				#Use the co-pay table to determine rates for full-time care for one child, full-time care for an additional child, part-time care for one child (if no child needs full-time care), and part-time care for a second child.
				for ($ccdf_poverty_percent) {
					$fulltime1 =
						($_ <= 1)		? 0 :	
						($_ <= 1.05)	? 8.84 :
						($_ <= 1.1 )	? 9.01 :
						($_ <= 1.15)	? 9.19 :
						($_ <= 1.2 )	? 9.36 :
						($_ <= 1.25 )	? 9.7 :
						($_ <= 1.3 )	? 10.04 :
						($_ <= 1.35 )	? 10.38 :
						($_ <= 1.4 )	? 10.72 :
						($_ <= 1.45 )	? 11.23 :
						($_ <= 1.5 )	? 11.74 :
						($_ <= 1.55 )	? 12.25 :
						($_ <= 1.6 )	? 12.76 :
						($_ <= 1.65 )	? 13.44 :
						($_ <= 1.7 )	? 14.12 :
						($_ <= 1.75 )	? 14.8 :
						($_ <= 1.8 )	? 15.48 :
						($_ <= 1.85 )	? 16.33 :
						($_ <= 1.9 )	? 17.18 :
						($_ <= 1.95 )	? 18.03 :
						($_ <= 2 	)	? 18.88 :
						($_ <= 2.05 )	? 19.9 :
						($_ <= 2.1 )	? 20.92 :
						($_ <= 2.15 )	? 21.94 :
						($_ <= 2.2 )	? 22.96 :
						($_ <= 2.25 )	? 24.15 :
						($_ <= 2.3 )	? 25.34 :
						($_ <= 2.35 )	? 26.53 :
						($_ <= 2.4 )	? 27.72 :
						($_ <= 2.45 )	? 29.08 :
						($_ <= 2.5 )	? 30.44 :
						($_ <= 2.55 )	? 68.12 :
						($_ <= 2.6 )	? 69.48 :
						($_ <= 2.65 )	? 70.84 :
						($_ <= 2.7 )	? 72.2 :
						($_ <= 2.75 )	? 73.57 :
						($_ <= 2.8 )	? 74.93 :
						($_ <= 2.85 )	? 76.29 :
						($_ <= 2.9 )	? 77.65 :
						($_ <= 2.95 )	? 79.02 :
						($_ <= 3 )		? 80.38 :
						($_ <= 3.05 )	? 81.74 :
						($_ <= 3.1 )	? 83.1 :
						($_ <= 3.15 )	? 84.47 :
						($_ <= 3.2 )	? 85.83 :
						($_ <= 3.25 )	? 87.19 :
						($_ <= 3.3 )	? 88.55 :
						($_ <= 3.35 )	? 89.91 :
						($_ <= 3.4 )	? 91.28 :
						($_ <= 3.45 )	? 92.64 :
						($_ <= 3.5 )	? 94 :
						($_ <= 3.55 )	? 95.36 :
						($_ <= 3.6 )	? 96.73 :
						($_ <= 3.65 )	? 98.09 :
						($_ <= 3.7 )	? 99.45 :
						($_ <= 3.75 )	? 100.81 :
						($_ <= 3.8 )	? 102.18 :
						($_ <= 3.85 )	? 103.54 :
						($_ <= 3.9 )	? 104.9 :
						($_ <= 3.95 )	? 106.26 :
						($_ <= 4 )		? 107.62 :
						($_ <= 4.05 )	? 108.99 :
						($_ <= 4.1 )	? 110.35 :
						($_ <= 4.15 )	? 111.71 :
						($_ <= 4.2 )	? 113.07 :
						($_ <= 4.25 )	? 114.44 :
						($_ <= 4.3 )	? 115.8 :
						($_ <= 4.35 )	? 117.16 :
						($_ <= 4.4 )	? 118.52 :
						($_ <= 4.45 )	? 119.89 :
						($_ <= 4.5 )	? 121.25 :
						($_ <= 4.55 )	? 122.61 :
						($_ <= 4.6 )	? 123.97 :
						($_ <= 4.65 )	? 125.33 :
						125.33; #If their income is higher than 465% poverty but still under 85% SMI or if they are a recent TANF recipient, they will pay the maximum copay, not 0.

					$fulltime2 = 
						($_ <= 1 )		? 0 :
						($_ <= 1.05 )	? 6.63 :
						($_ <= 1.1 )	? 6.76 :
						($_ <= 1.15 )	? 6.89 :
						($_ <= 1.2 )	? 7.02 :
						($_ <= 1.25 )	? 7.28 :
						($_ <= 1.3 )	? 7.53 :
						($_ <= 1.35 )	? 7.79 :
						($_ <= 1.4 )	? 8.04 :
						($_ <= 1.45 )	? 8.42 :
						($_ <= 1.5 )	? 8.81 :
						($_ <= 1.55 )	? 9.19 :
						($_ <= 1.6 )	? 9.57 :
						($_ <= 1.65 )	? 10.08 :
						($_ <= 1.7 )	? 10.59 :
						($_ <= 1.75 )	? 11.1 :
						($_ <= 1.8 )	? 11.61 :
						($_ <= 1.85 )	? 12.25 :
						($_ <= 1.9 )	? 12.89 :
						($_ <= 1.95 )	? 13.52 :
						($_ <= 2 )		? 14.16 :
						($_ <= 2.05 )	? 14.93 :
						($_ <= 2.1 )	? 15.69 :
						($_ <= 2.15 )	? 16.46 :
						($_ <= 2.2 )	? 17.22 :
						($_ <= 2.25 )	? 18.11 :
						($_ <= 2.3 )	? 19.01 :
						($_ <= 2.35 )	? 19.9 :
						($_ <= 2.4 )	? 20.79 :
						($_ <= 2.45 )	? 21.81 :
						($_ <= 2.5 )	? 22.83 :
						($_ <= 2.55 )	? 51.09 :
						($_ <= 2.6 )	? 52.11 :
						($_ <= 2.65 )	? 53.13 :
						($_ <= 2.7 )	? 54.15 :
						($_ <= 2.75 )	? 55.18 :
						($_ <= 2.8 )	? 56.2 :
						($_ <= 2.85 )	? 57.22 :
						($_ <= 2.9 )	? 58.24 :
						($_ <= 2.95 )	? 59.26 :
						($_ <= 3	 )	? 60.28 :
						($_ <= 3.05 )	? 61.31 :
						($_ <= 3.1 )	? 62.33 :
						($_ <= 3.15 )	? 63.35 :
						($_ <= 3.2 )	? 64.37 :
						($_ <= 3.25 )	? 65.39 :
						($_ <= 3.3 )	? 66.41 :
						($_ <= 3.35 )	? 67.44 :
						($_ <= 3.4 )	? 68.46 :
						($_ <= 3.45 )	? 69.48 :
						($_ <= 3.5 )	? 70.5 :
						($_ <= 3.55 )	? 71.52 :
						($_ <= 3.6 )	? 72.54 :
						($_ <= 3.65 )	? 73.57 :
						($_ <= 3.7 )	? 74.59 :
						($_ <= 3.75 )	? 75.61 :
						($_ <= 3.8 )	? 76.63 :
						($_ <= 3.85 )	? 77.65 :
						($_ <= 3.9 )	? 78.67 :
						($_ <= 3.95 )	? 79.7 :
						($_ <= 4 )		? 80.72 :
						($_ <= 4.05 )	? 81.74 :
						($_ <= 4.1 )	? 82.76 :
						($_ <= 4.15 )	? 83.78 :
						($_ <= 4.2 )	? 84.81 :
						($_ <= 4.25 )	? 85.83 :
						($_ <= 4.3 )	? 86.85 :
						($_ <= 4.35 )	? 87.87 :
						($_ <= 4.4 )	? 88.89 :
						($_ <= 4.45 )	? 89.91 :
						($_ <= 4.5 )	? 90.94 :
						($_ <= 4.55 )	? 91.96 :
						($_ <= 4.6 )	? 92.98 :
						($_ <= 4.65 )	? 94 :
						94;
						
					$parttime1 = 
						($_ <= 1 )		? 0 :
						($_ <= 1.05 )	? 4.42 :
						($_ <= 1.1 )	? 4.51 :
						($_ <= 1.15 )	? 4.59 :
						($_ <= 1.2 )	? 4.68 :
						($_ <= 1.25 )	? 4.85 :
						($_ <= 1.3 )	? 5.02 :
						($_ <= 1.35 )	? 5.19 :
						($_ <= 1.4 )	? 5.36 :
						($_ <= 1.45 )	? 5.62 :
						($_ <= 1.5 )	? 5.87 :
						($_ <= 1.55 )	? 6.13 :
						($_ <= 1.6 )	? 6.38 :
						($_ <= 1.65 )	? 6.72 :
						($_ <= 1.7 )	? 7.06 :
						($_ <= 1.75 )	? 7.4 :
						($_ <= 1.8 )	? 7.74 :
						($_ <= 1.85 )	? 8.17 :
						($_ <= 1.9 )	? 8.59 :
						($_ <= 1.95 )	? 9.02 :
						($_ <= 2 )		? 9.44 :
						($_ <= 2.05 )	? 9.95 :
						($_ <= 2.1 )	? 10.46 :
						($_ <= 2.15 )	? 10.97 :
						($_ <= 2.2 )	? 11.48 :
						($_ <= 2.25 )	? 12.08 :
						($_ <= 2.3 )	? 12.67 :
						($_ <= 2.35 )	? 13.27 :
						($_ <= 2.4 )	? 13.86 :
						($_ <= 2.45 )	? 14.54 :
						($_ <= 2.5 )	? 15.22 :
						($_ <= 2.55 )	? 34.06 :
						($_ <= 2.6 )	? 34.74 :
						($_ <= 2.65 )	? 35.42 :
						($_ <= 2.7 )	? 36.1 :
						($_ <= 2.75 )	? 36.78 :
						($_ <= 2.8 )	? 37.46 :
						($_ <= 2.85 )	? 38.15 :
						($_ <= 2.9 )	? 38.83 :
						($_ <= 2.95 )	? 39.51 :
						($_ <= 3 )		? 40.19 :
						($_ <= 3.05 )	? 40.87 :
						($_ <= 3.1 )	? 41.55 :
						($_ <= 3.15 )	? 42.23 :
						($_ <= 3.2 )	? 42.91 :
						($_ <= 3.25 )	? 43.59 :
						($_ <= 3.3 )	? 44.28 :
						($_ <= 3.35 )	? 44.96 :
						($_ <= 3.4 )	? 45.64 :
						($_ <= 3.45 )	? 46.32 :
						($_ <= 3.5 )	? 47 :
						($_ <= 3.55 )	? 47.68 :
						($_ <= 3.6 )	? 48.36 :
						($_ <= 3.65 )	? 49.04 :
						($_ <= 3.7 )	? 49.73 :
						($_ <= 3.75 )	? 50.41 :
						($_ <= 3.8 )	? 51.09 :
						($_ <= 3.85 )	? 51.77 :
						($_ <= 3.9 )	? 52.45 :
						($_ <= 3.95 )	? 53.13 :
						($_ <= 4 )		? 53.81 :
						($_ <= 4.05 )	? 54.49 :
						($_ <= 4.1 )	? 55.17 :
						($_ <= 4.15 )	? 55.86 :
						($_ <= 4.2 )	? 56.54 :
						($_ <= 4.25 )	? 57.22 :
						($_ <= 4.3 )	? 57.9 :
						($_ <= 4.35 )	? 58.58 :
						($_ <= 4.4 )	? 59.26 :
						($_ <= 4.45 )	? 59.94 :
						($_ <= 4.5 )	? 60.62 :
						($_ <= 4.55 )	? 61.3 :
						($_ <= 4.6 )	? 61.99 :
						($_ <= 4.65 )	? 62.67 :
						62.67;

					$parttime2 = 
						($_ <= 1 )		? 0 :
						($_ <= 1.05 )	? 3.31 :
						($_ <= 1.1 )	? 3.38 :
						($_ <= 1.15 )	? 3.44 :
						($_ <= 1.2 )	? 3.51 :
						($_ <= 1.25 )	? 3.64 :
						($_ <= 1.3 )	? 3.77 :
						($_ <= 1.35 )	? 3.89 :
						($_ <= 1.4 )	? 4.02 :
						($_ <= 1.45 )	? 4.21 :
						($_ <= 1.5 )	? 4.4 :
						($_ <= 1.55 )	? 4.59 :
						($_ <= 1.6 )	? 4.79 :
						($_ <= 1.65 )	? 5.04 :
						($_ <= 1.7 )	? 5.3 :
						($_ <= 1.75 )	? 5.55 :
						($_ <= 1.8 )	? 5.81 :
						($_ <= 1.85 )	? 6.12 :
						($_ <= 1.9 )	? 6.44 :
						($_ <= 1.95 )	? 6.76 :
						($_ <= 2 )		? 7.08 :
						($_ <= 2.05 )	? 7.46 :
						($_ <= 2.1 )	? 7.85 :
						($_ <= 2.15 )	? 8.23 :
						($_ <= 2.2 )	? 8.61 :
						($_ <= 2.25 )	? 9.06 :
						($_ <= 2.3 )	? 9.5 :
						($_ <= 2.35 )	? 9.95 :
						($_ <= 2.4 )	? 10.4 :
						($_ <= 2.45 )	? 10.91 :
						($_ <= 2.5 )	? 11.42 :
						($_ <= 2.55 )	? 25.54 :
						($_ <= 2.6 )	? 26.05 :
						($_ <= 2.65 )	? 26.57 :
						($_ <= 2.7 )	? 27.08 :
						($_ <= 2.75 )	? 27.59 :
						($_ <= 2.8 )	? 28.1 :
						($_ <= 2.85 )	? 28.61 :
						($_ <= 2.9 )	? 29.12 :
						($_ <= 2.95 )	? 29.63 :
						($_ <= 3 )		? 30.14 :
						($_ <= 3.05 )	? 30.65 :
						($_ <= 3.1 )	? 31.16 :
						($_ <= 3.15 )	? 31.67 :
						($_ <= 3.2 )	? 32.19 :
						($_ <= 3.25 )	? 32.7 :
						($_ <= 3.3 )	? 33.21 :
						($_ <= 3.35 )	? 33.72 :
						($_ <= 3.4 )	? 34.23 :
						($_ <= 3.45 )	? 34.74 :
						($_ <= 3.5 )	? 35.25 :
						($_ <= 3.55 )	? 35.76 :
						($_ <= 3.6 )	? 36.27 :
						($_ <= 3.65 )	? 36.78 :
						($_ <= 3.7 )	? 37.29 :
						($_ <= 3.75 )	? 37.8 :
						($_ <= 3.8 )	? 38.32 :
						($_ <= 3.85 )	? 38.83 :
						($_ <= 3.9 )	? 39.34 :
						($_ <= 3.95 )	? 39.85 :
						($_ <= 4 )		? 40.36 :
						($_ <= 4.05 )	? 40.87 :
						($_ <= 4.1 )	? 41.38 :
						($_ <= 4.15 )	? 41.89 :
						($_ <= 4.2 )	? 42.4 :
						($_ <= 4.25 )	? 42.91 :
						($_ <= 4.3 )	? 43.42 :
						($_ <= 4.35 )	? 43.94 :
						($_ <= 4.4 )	? 44.45 :
						($_ <= 4.45 )	? 44.96 :
						($_ <= 4.5 )	? 45.47 :
						($_ <= 4.55 )	? 45.98 :
						($_ <= 4.6 )	? 46.49 :
						($_ <= 4.65 )	? 47 :
						47;
				}
				
				#STEP 3B: determine how many children require full-time care and part-time care.
				
				#need to recalculate spr and full cost of care for only ccdf eligible children
				$spr_ccdf_eligible_children = $out->{'spr_all_children'};
				$fullcost_ccdf_eligible_children = $out->{'fullcost_all_children'};

				our	$partial_fulltime_count == 0;
				our	$partial_parttime_count == 0;

				for(my $i=1; $i<=5; $i++) {
					if ($in->{'child'.$i.'_age'} > -1 && ($in->{'child'.$i.'_immigration_status'} eq 'undocumented_or_other' || ($in->{'allow_immigrant_tanfeligibility_alt'} == 0 && ($in->{'child'.$i.'_immigration_status'} eq 'daca' || $in->{'child'.$i.'_immigration_status'} eq 'newer_greencard')))) { #Allowing LPR or DACA children access to child care subsidies when policy option allows them to receive TANF. This will model the impact of child care services provided through TANF funds, not CCDF funds.
						$spr_ccdf_eligible_children -= $out->{'spr_child'.$i};
						$fullcost_ccdf_eligible_children -= $out->{'fullcost_child'.$i}; #These formulas subtract the number of unqualified children from the total number of children and the child care costs of the unqualified children from the total number of qualified children
						$unqualified_child_care_expenses += $out->{'unsub_child' . $i}; #We need this in order to add it to child care expenses at the end.
					} elsif ($in->{'child'.$i.'_foster_status'} == 0) { #foster children do not have to pay a co-pay for ccdf care.
						$ccdf_child_count ++; 
						if ($out->{'child'.$i.'_weekly_cc_hours'} >= 30) {
							$cc_fulltime_count++; #increase this variable by 1.
							if ($in->{'child'.$i.'_age'} == 0) {
								$partial_fulltime_count += 1;
							}
						} elsif (${'child'.$i.'_weekly_cc_hours'} >= 0) {				
							$cc_parttime_count++;
							if ($in->{'child'.$i.'_age'} == 0) {
								$partial_parttime_count += 1;
							}
						}
						if ($out->{'child'.$i.'_weekly_cc_hours_summer'} >= 30) {
							$summer_cc_fulltime_count++;
						} elsif ($out->{'child'.$i.'_weekly_cc_hours_summer'} >= 0) {				
							$summer_cc_parttime_count++;
						}
					}
				}
				
				$cc_parttime_count = &least(pos_sub(2, $cc_fulltime_count), $cc_parttime_count); 
				$summer_cc_parttime_count = &least(pos_sub(2, $summer_cc_fulltime_count), $summer_cc_parttime_count); 

				#We now iteratively increase the CCDF copay by type of care needed, up to two children, using the copay table costs
				if ($in->{'children_under1'} == 0 && $in->{'unqualified_immigrant_child_count'} == 0) {
					#Simple version below. It seems mathematically sound to skip this block and go straight to the calculation inclusive of time off and infants, but since it's complicated, it makes sense to keep the main calculations below, and add complication for the subset of families that have infants. This model assumes that if a parent has a newborn and an older child, the older child will be sent to child care while the parent bonds with the newborn. Because the below scenario is (or should be) mathematically consistent with the below block, we can leave the determinations of copays among families with mixed immigration statuses to the below chunk. In that case, the below chunk will include considerations of families with infants who are also unqualified for CCDF partipation.  
#LOOK AT ME: Not sure about unqualified child care part in consideration of potential TANF eligibiltiy for certain immigrant children.
					if ($cc_fulltime_count >= 1) {
						$ccdf_copay += $fulltime1 * (52 - $summerweeks);
					}
					
					if ($cc_fulltime_count >= 2) {
						$ccdf_copay += $fulltime2 * (52 - $summerweeks);
					}

					if ($cc_parttime_count >= 1 && $cc_fulltime_count == 0) {
						$ccdf_copay += $parttime1 * (52 - $summerweeks);
					}

					if (($cc_parttime_count == 1 && $cc_fulltime_count == 1) || $cc_parttime_count == 2) {
						$ccdf_copay += $parttime2 * (52 - $summerweeks);
					}
				} else { 
					#We have to tally copays based on number of children in full-time care and part-time care during all weeks of the year. This means that we have to separate the weeks of the year devoted to infant bonding from the weeks of the year that the newborn may be in child care.
					if ($cc_fulltime_count >= 1) {
						$ccdf_copay += $fulltime1 * (52 - $summerweeks - $out->{'weeks_off'});
						if ($cc_fulltime_count - $partial_fulltime_count >= 1) {
							$ccdf_copay += $fulltime1 * ($out->{'weeks_off'});
						}
					}					
					
					if ($cc_fulltime_count >= 2) {
						$ccdf_copay += $fulltime2 * (52 - $summerweeks - $out->{'weeks_off'});
						if ($cc_fulltime_count - $partial_fulltime_count >= 2) {
							$ccdf_copay += $fulltime2 * ($out->{'weeks_off'});
						}
					}

					if ($cc_parttime_count >= 1 && $cc_fulltime_count == 0) {
						$ccdf_copay += $parttime1 * (52 - $summerweeks - $out->{'weeks_off'});
						if ($cc_parttime_count - $partial_parttime_count >= 1 && $cc_fulltime_count - $partial_fulltime_count == 0) {
							$ccdf_copay += $parttime1 * ($out->{'weeks_off'});
						}
					}

					if (($cc_parttime_count == 1 && $cc_fulltime_count == 1) || $cc_parttime_count == 2) {
						$ccdf_copay += $parttime2 * (52 - $summerweeks  - $out->{'weeks_off'});
						if (($cc_parttime_count - $partial_parttime_count == 1 && $cc_fulltime_count - $partial_fulltime_count == 1) || $cc_parttime_count - $partial_parttime_count == 2) {
							$ccdf_copay += $parttime2 * ($out->{'weeks_off'});
						}
					}
				}
				#The same operation in the summer. As indicated in the child_care code, we are assuming newborns are born in January. We can revisit this assumption at a later time.
				if ($summer_cc_fulltime_count >= 1) {
					$ccdf_copay += $fulltime1 * $summerweeks;
				}
				
				if ($summer_cc_fulltime_count >= 2) {
					$ccdf_copay += $fulltime2 * $summerweeks;
				}

				if ($summer_cc_parttime_count >= 1 && $cc_fulltime_count == 0) {
					$ccdf_copay += $parttime1 * $summerweeks;
				}

				if (($summer_cc_parttime_count == 1 && $summer_cc_fulltime_count == 1) || $summer_cc_parttime_count == 2) {
					$ccdf_copay += $parttime2 * $summerweeks;
				}



				#The co-pay cannot exceed the cost of care or the amount that the state pays to the child care provider.
				
				
				
				$ccdf_copay = &least($ccdf_copay,$spr_ccdf_eligible_children);

				if ($in->{'ccdf_copay_alt'} == 1) { 	#POLICY MODELING OPTION: "Model a suspension of CCDF co-pays?"
					$ccdf_copay = 0;
				}
				
				#
				# 4. DETERMINE VALUE OF CARE (AND COMPARE TO COPAY)
				#
				if($ccdf_copay >= $fullcost_ccdf_eligible_children) { #QUESTION FOR SETH - because the above formula will calculate the ccdf_copay as the lesser of the ccdf_copay and spr for ccdf eligible children, there seems like there should be no scenario where the ccdf_copay would be higher than the spr for all ccdf eligible children. Should this be moved up to before &least formula?
					# In this case, the unsubsidized cost of child care is cheaper, so the family will opt for that.
					$cc_subsidized_flag = 0;
					# skip to step 5
				} else {
					$cc_subsidized_flag = 1;
					#if ($ccdf_copay > ) {
					#	# This elsif will be true, and the above if will be false, if the user selects a cheaper subdized child care settting  than unsubdsidized setting, and in the event that both are more expensive than total ccdf co-pays.
					#	$cdf_copay = $out->{'spr_all_children'}; 
					# } else { 
					# $cc_subsidized_flag = 1;
					$overage_payment = $ccdf_chargeabovecopay * &pos_sub($fullcost_ccdf_eligible_children,$spr_ccdf_eligible_children); #Since ccdf_chargeabovecopay is a dummy variable, the overage payment will be the difference between unsubsidized care and the state payment rate in states that operate this policy, and will be 0 in states that don't. 
					$child_care_expenses = $ccdf_copay + $overage_payment + $unqualified_child_care_expenses;
					# I'm not sure what the point of dividing the child care expenses between the covered children are at this point. It's also somewhat complicated because we're only counting children who receive child care, not just children under 13. So, taking this code out. If for some reason it's relevant, we can figure it out and put it back in.
					$child_care_recd = $spr_ccdf_eligible_children - $ccdf_copay;
				}
			}
		}
	}
    #
    # STEP 5. DETERMINE UNSUBSIDIZED COST OF CARE
    #
    if($cc_subsidized_flag == 0) {
		# While some of this SQL-calling code can likely be used for the operation requested right before the calculation of $spr_child#, not necessary at this step, because based on how DC did their market study, the SPR rate is the same as the unsubsidized cost of care.

		$child_care_expenses = $out->{'unsub_all_children'};
		$child_care_recd = 0;
	}

 	$child_care_expenses_m = $child_care_expenses / 12;       
 	$child_care_expenses_m = $child_care_expenses / 12;
	# For the child support code, we need to proportion out subsidized child care expenses across children in the house.
	for(my $i=1; $i<=5; $i++) {	
		if ($child_care_expenses > 0) {
			if ($in->{'child'.$i.'_unqualified'} == 1 || $child_care_recd == 0) {
				${'cc_expenses_child'.$i} = $out->{'unsub_child' . $i};
			} else { #child is qualified for child care subsidies.
				${'cc_expenses_child'.$i} = ($ccdf_copay + $overage_payment)  / $ccdf_child_count; 
			}
		} else {
			${'cc_expenses_child'.$i} = 0;
		}
	} 
	
  # outputs
    foreach my $name (qw(child_care_expenses child_care_expenses_m  cc_subsidized_flag ccdf_eligible_flag child_care_recd cc_expenses_child1 cc_expenses_child2 cc_expenses_child3 cc_expenses_child4 cc_expenses_child5 unqualified_child_care_expenses)) {
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}


1;