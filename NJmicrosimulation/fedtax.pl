#=============================================================================#
#  Federal Income Taxes Module -- 2021 (modified from 2020 & 2017, including 2017 tax bill reforms and 2021 ARPA changes) for TY 2021.
#=============================================================================#
# Script edited using 2016 tax rules, and the latest available tax rates (2017). 
# Inputs referenced in this module:
#
#   FROM BASE:
#     Inputs:
#       family_structure
#       child_number
#       child1_age
#       child2_age
#       child3_age
#       child4_age
#       child5_age
#       children_under13
#       children_under17
#       cadc            # flag
#       ctc             # flag
#       disability_parent2
#       disability_personal_expenses  
#		child#_immigration_status
# 		itin			#NEW flag to add. itin == 1 if the user selects yes to the question: "Do household members without a Social Security Number (SSN) have an Individual Taxpayer Identification Number (ITIN)?" Choices: yes/No. This would only show up if the user selects that any of the adults are undocumented. If this is selected, the FRS will assume all undocumented members of the household have ITINs, including children.
#		spousal_sup_ncp
#		
# 	FROM FRS.PM
#		undocumented_adult_count
#		undocumented_child_count
#
# 	FROM EARNINGS:
#       parent2_max_hours_w  	
#     Outputs:
#       earnings
#
#   FROM INTEREST:
#       interest
#
#   FROM SSI:
#       ssi_recd			
#   FROM TANF:
#       tanf_recd
#       child_support_recd
#
#   FROM CCDF:
#       child_care_expenses
#		cc_expenses_child#
#
#	FROM AFTERSCHOOL:
#		afterschool_expenses
#		afterschool_child#_copay
#
#   FROM FOOD STAMPS:
#       fsp_recd
#
#   FROM PARENTAL WORK EFFORT:
#       parent2_earnings
#
#   FROM LIHEAP (CO, FL, DC) 
#       liheap_recd
#
#   FROM HEAP/PIPP (OH)
#       heap_recd
#
#	FLI_TDI
#		parent#_fli_recd
#		parent#_tdi_recd
#
#	UI
#		ui_recd
#
#=============================================================================#

sub fedtax
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};

	# outputs created
    our $federal_tax_gross = 0;      # gross federal taxes, before subtracting CADC and CTC
    our $federal_tax_credits = 0;    # [Fed Tax Credits]  
    our $federal_tax = 0;        # annual federal tax liability, NOT including the CTC or the EITC
    our $cadc_recd = 0;          # [Fed CADC] annual value of child and dependent tax care credit
                                 # (cannot be less than pre-CADC tax liability; does not take into account CTC)
    our $cadc_base = 0;          # Qualified child care expenses for determining CADC credit
    our $ctc_nonref_recd = 0;    # annual child tax credit, non-refundable portion
                                 # (cannot be less than pre-CTC tax liability; does take into account CADC)
    our $cadc_real_recd = 0;     # "real" value of CADC, given eligibility for child tax credit
                                 # (i.e., this is what the value of the CADC would be if the Child Tax Credit were subtracted 
                                 # from gross tax liability first)
    our $filing_status = 0;      # filing status
    our $federal_tax_income = 0;     # adjusted income for calculating taxes
	our $federal_adjusted_gross_income = 0; #AGI. It's been annoying and inefficient that we didn't previously have this number broken out. It's important.

    # Additional variables used within the macro
    our $cadc_max_claims = 3000; # maximum child care expenses that can be claimed (per child, up to 2)
    our $ctc_per_child   = 2000; # 2019 max child tax credit (per child)
	our $odc_dependent_add = 500; 		#additional dependent add-on for non-child dependents and child dependents with ITINs for other dependent credit (ODC). SS added from mtrc code on 7.16.21
	our $ctc_per_child_arpa = 3000; #Max ARPA CTC for children 6 or over is $3000. SS added from mtrc code on 7.16.21
	our $ctc_arpa_under6_add = 600; #Addition ARPA provides for children under 6. SS added from mtrc code on 7.16.21
    our $ded_per_exempt  = 4050; # deduction amount per exemption #5/11: changed this to $4,050 to represent change in tax policy beginning in 2016.
    our $tax_rate1       = 0.10; #  tax rate for income bracket 1
    our $tax_rate2       = 0.12; #  tax rate for income bracket 2
    our $tax_rate3       = 0.22; #  tax rate for income bracket 3
    our $tax_rate4       = 0.24; #  tax rate for income bracket 4
	our $tax_rate5       = 0.32; #  tax rate for income bracket 5
    our $tax_rate6       = 0.35; #  tax rate for income bracket 6
    our $tax_rate7       = 0.37; #  tax rate for income bracket 7
	our $base_amt_ssdi = 0; 	#base amount to compare SSDI benefits to determine whether benefits are taxable
	our $ssdi_taxable_test = 0;

	# variables set
    our $home = 0;               # parent(s) meet the test of keeping up a home (1|0)
    our $support = 0;            # parent(s) meet the test of supporting a child (1|0)
	#    our $exempt_number = 0;      # number of exemptions family can claim. Excluded beginning in 2019 because 2017 tax reform (beginning in 2018 tax year) removed exemptions.
    our $standard_deduction = 0; # standard deduction
    our $max_taxrate1 = 0;       # max adjusted income for tax rate 1
    our $max_taxrate2 = 0;       # max adjusted income for tax rate 2
    our $max_taxrate3 = 0;       # max adjusted income for tax rate 3
    our $max_taxrate4 = 0;       # max adjusted income for tax rate 4
    our $max_taxrate5 = 0;       # max adjusted income for tax rate 5
    our $max_taxrate6 = 0;       # max adjusted income for tax rate 6


    our $federal_tax_cadc = 0;   # federal tax liability after subtracting cadc, but before ctc
    our $cadc_gross = 0;         # gross CADC amount (i.e., before comparing to tax liability)
    our $cadc_percentage = 0;
    our $ctc_max_income = 0;     # income limit for max child tax credit (varies by filing status)
	our $ctc_max_income_covid = 0; #additional income limit for max child tax credit as expanded by ARPA. SS added from mtrc code on 7.16.21

    our $ctc_number = 0;     # number of children eligible for child tax credit
    our $ctc_potential = 0;      # max potential child tax credit family may be eligible for (ie, ctc_per_child * ctc_number)
    our $ctc_reduction = 0;      # reduction amount for filers w/income above ctc_max_income (line 7 in ctc worksheet)
    our $ctc_potential_red = 0;  # max potential child tax credit, after subtracting ctc_reduction
	our $other_dependent_credit = 0; #portion of the CTC that is the credit for other (non-child) dependents. SS added from mtrc code on 7.16.21
	our $ctc_potential_recd_nonother = 0; #SS added from mtrc code on 7.16.21

    our $cadc = $in->{'cadc'};
	our $cadc_dis = 0;	#the only values for cadc_dis would be 0 and 1 to indicate whether or not 2nd parent is disabled and care for the parents would qualify for cadc
	our $cadc_eligible_child_count = 0;		#the number of children under 13 in HH eligible for cadc
	our $ctc_eligible_children_count = 0;
	our $ctc_eligible_children_under6_count  = 0;
	our $parent1_taxable_earnings = 0;	#parents' taxable earnings. this is 0 if the parent is undocumented and doesn't have an ITIN.
	our $parent2_taxable_earnings = 0;
	our $parent1_other_taxable_income = 0;
	our $parent2_other_taxable_income = 0;
	our $countable_cadc_cc_expenses = 0;				#need to calculate eligible children's child care expenses. 
	our $taxable_ssdi = 0;			#the amount of annual SSDI benefits that is taxable.
	our $line12_ssdi = 0;
	our $line14_ssdi = 0;
	our $line15_ssdi = 0;
	our $line16_ssdi = 0;
	our $line17_ssdi = 0;
	
	# 1. Determine filing status, number of exemptions, and number of children for child tax credit
	# (note: to be claimed for the child tax credit, a child must be claimed as a dependent)

	# (We are only including cash and near-cash benefits in our calculation of public support
	# for the home and dependent support tests -- this is in keeping with common practice among tax preparers.)

	# Note beginning in 2019:All children in the FRS are considered "qualifying children" for tax purposes because they earn no income of their own. According to the 1040 instructions, this means that they are a qualifying child on someone's tax return. For single parents, they are a qualifying child either on the custodial parent's return or noncustodial parent's return, but regardless they are still a "qualifying child." This  means that all single-parent families being modeled in the FRS - at least up to 2019 - qualify as heads of household. In order to claim head of household, the child has to be young enough (under 19, all cases in the FRS), staying in the same home as the parent (all cases), and not paying more than half of the expenses that they themselves incur. This last condition is not the same as a condition that the single parent pays more than half of the child's expenses, it only means that THE CHILD HIMSELF OR HERSELF DOES NOT PAY more than half of their expenses. Previous versions of the FRS code (possibly of IRS code) compared earnigns and income against child support and TANF or other payments, but this is not correct. Whether or not a parent paid more than half of a child's expenses may be important in determining whether a child is dependent, though, which is explored later.

	# The following code uses Table “Federal Income Taxes tables”, worksheet I to determine:
	# - Filing_status
	# - Exempt_number
    # After the determination of filing status, the following if-block replicate the “Federal Income Taxes tables”, worksheet II to determine:
    # Use Table “Federal Income Taxes tables”, worksheet II to determine:
    # - Standard_deduction
    # - Max_taxrate1
    # - Max_taxrate2
    # - Max_taxrate3
    # - Max_taxrate4
	# - Max_taxrate5
	# - Max_taxrate6
    # - CTC_max_income

    if($in->{'family_structure'} == $in->{'undocumented_adult_count'} && $in->{'itin'} == 0) {
		$ctc_potential = 0;
		$cadc_gross = 0;
		$federal_tax_income = 0;
		$federal_tax = 0;
		$ctc_nonref_recd = 0;
		$federal_tax_cadc = 0;
	} else {
		if ($in->{'family_structure'} == 1) { #if there is a one parent family or a one parent family with an itin. 
		# We are waiting on adding additional filing units to the home until after the NJ FRS 2021 is tentatively completed and online.
		# $exempt_number = 1 + $in->{'child_number'}; # 2017 tax reform removed personal exemptions, possibly temporarily. Commenting out but keeping in code in case exemptions are restored.
			if($in->{'child_number'} >= 1) {
				$filing_status = "Head of Household";
			} else {
				$filing_status = "Single";
			}
		} elsif ($in->{'itin'} == 0 && $in->{'undocumented_adult_count'} == 1) { #if there is a two parent family and one is undocumented without an ITIN and the other is not we assume they would file as a filing unit that is most advantageous to them, which is either head of household or single. 
			if($in->{'child_number'} >= 1) {
				$filing_status = "Head of Household";
			} else {
				$filing_status = "Single";
			}
		} else { #we assume if itin = 1 in a two married family, they would file as married filing jointly.
			$filing_status = "Married";
			# $exempt_number = 2 + $in->{'child_number'}; # 2017 tax reform removed personal exemptions, possibly temporarily. Commenting out but keeping in code in case exemptions are restored.
		}
		
		# determine standard deduction, max adjusted income, and income limit for child tax credit
		if($filing_status eq 'Head of Household') {
			$standard_deduction = 18800; 
			$max_taxrate1 = 14200;
			$max_taxrate2 = 54200;
			$max_taxrate3 = 86300;
			$max_taxrate4 = 164900;
			$max_taxrate5 = 209400;
			$max_taxrate6 = 523600;
			$ctc_max_income_covid = 112500;
			$ctc_max_income = 200000; 
			$base_amt_ssdi = 25000;
			$ssdi_taxable_test = 9000;
		} elsif($filing_status eq 'Married') {
			$standard_deduction = 25100; 
			$max_taxrate1 = 19900;
			$max_taxrate2 = 81050;
			$max_taxrate3 = 172750;
			$max_taxrate4 = 329850;
			$max_taxrate5 = 418850;
			$max_taxrate6 = 628300;
			$ctc_max_income_covid = 150000;
			$ctc_max_income = 400000; 
			$base_amt_ssdi = 32000;		#amount from Worksheet 1 in 2021 Publication 915, page 16
			$ssdi_taxable_test = 12000;				
		} else { 
			$standard_deduction = 12550;
			$max_taxrate1 = 9950;
			$max_taxrate2 = 40525;
			$max_taxrate3 = 86375;
			$max_taxrate4 = 164925;
			$max_taxrate5 = 209425;
			$max_taxrate6 = 523600;
			$ctc_max_income_covid = 75000;
			$ctc_max_income = 200000; 
			$base_amt_ssdi = 25000;
			$ssdi_taxable_test = 9000;				
		} 	

		# 2 Determine gross federal tax (before CADC and Child Tax Credit)
		
		#$federal_tax_income = $out->{'earnings'} + $out->{'interest'} - $standard_deduction - ($exempt_number * $ded_per_exempt); #pre-2018 formula, kept in case exemptions are eventually reincluded.
		for (my $i = 1; $i <= $in->{'family_structure'}; $i++)	{
			if ($in->{'itin'} == 0 && $in->{'parent'.$i.'_immigration_status'} eq 'undocumented_or_other') {	#we need to zero out the undocumented parent's income for income tax purposes if itin = 0.
				${'parent'.$i.'_taxable_earnings'} = 0;
			} else {
				${'parent'.$i.'_taxable_earnings'} = $out->{'parent'.$i.'_earnings'};
				${'parent'.$i.'_other_taxable_income'} = $out->{'parent'.$i.'_tdi_recd'} + $out->{'parent'.$i.'_fli_recd'} + $out->{'ui_recd'}/$in->{'family_structure'} ; #New Jersey TDI benefits (which include fli and tdi) are treated as third party sick pay and subject to federal Social Security (FICA) taxes and income tax as wages but are not subject to state income taxes https://www.nj.gov/labor/roles/empupdte/TaxReporting.html#:~:text=An%20Internal%20Revenue%20Service%20ruling,as%20third%2Dparty%20sick%20pay.&text=Temporary%20Disability%20benefits%20and%20Unemployment,New%20Jersey%20state%20income%20tax.#FLI is not subject to NJ state tax, but it is subject to federal income taxes. https://www.nj.gov/labor/forms_pdfs/tdi/WPR-119%20(1-18).pdf #LOOK AT ME: once we program in UI, we need to make sure to parse it out by parent# and add it to parent#_taxable_earnings above. 

				#NOTE: ARPA allows taxpayers whose modified adjusted gross income is less than $150,000 to exclude up to $10,200 in unemployment compensation paid in 2020. See 2020 TY instructions for more details. This is not, however, applicable to TY 2021 - see instructions. Therefore, we are leaving it out for now. We are not using the NJ 2021 FRS to model 2020 net resources, neither here nore in any microsimulation model.

			}
		}
		
		
		$federal_adjusted_gross_income = $parent1_taxable_earnings + $parent2_taxable_earnings + $parent1_other_taxable_income + $parent2_other_taxable_income + $out->{'interest'} + $in->{'spousal_sup_ncp'}; #AGI. spousal_sup_ncp = spousal support paid by non-custodial parent to custodial parent. 
		
		#1.5 Determine the taxable portion of SSDI benefits 
		#Source: https://www.irs.gov/pub/irs-pdf/p915.pdf, following worksheet 1.
		if ($out->{'ssdi_recd'} > 0) {
			if (.5 * $out->{'ssdi_recd'} + $federal_adjusted_gross_income > $base_amt_ssdi) { #line 6/line 8. line 9 = base_amt_ssdi.
				$line12_ssdi = pos_sub((pos_sub(.5 * $out->{'ssdi_recd'} + $federal_adjusted_gross_income, $base_amt_ssdi)), $ssdi_taxable_test);
				$line14_ssdi = least($ssdi_taxable_test, pos_sub(.5 * $out->{'ssdi_recd'} + $federal_adjusted_gross_income, $base_amt_ssdi))*.5;
				$line15_ssdi = least(.5 * $out->{'ssdi_recd'}, $line14_ssdi);
				$line16_ssdi = $line12_ssdi *.85;
				$line17_ssdi = $line15_ssdi + $line16_ssdi; 
				$taxable_ssdi = least($line17_ssdi, .85 * $out->{'ssdi_recd'});
			}
		}
		
		$federal_adjusted_gross_income += $taxable_ssdi;
		
		$federal_tax_income = $federal_adjusted_gross_income - $standard_deduction; #Note that  2017 tax reform removed exemptions. 

		if($federal_tax_income <= 0) {
			$federal_tax_income = 0;
			$federal_tax_gross = 0;
		} else {
			if($federal_tax_income <= $max_taxrate1) {
				$federal_tax_gross = $tax_rate1 * $federal_tax_income;
			} elsif($federal_tax_income <= $max_taxrate2) {
				$federal_tax_gross = ($tax_rate2 * ($federal_tax_income - $max_taxrate1)) + ($tax_rate1 * $max_taxrate1);
			} elsif($federal_tax_income <= $max_taxrate3) {
				$federal_tax_gross = ($tax_rate3 * ($federal_tax_income - $max_taxrate2))
								   + ($tax_rate2 * ($max_taxrate2 - $max_taxrate1))
								   + $tax_rate1 * $max_taxrate1;
			} elsif($federal_tax_income <= $max_taxrate4) {
				$federal_tax_gross = ($tax_rate4 * ($federal_tax_income - $max_taxrate3))
								   + ($tax_rate3 * ($max_taxrate3 - $max_taxrate2))
								   + ($tax_rate2 * ($max_taxrate2 - $max_taxrate1))
								   + $tax_rate1 * $max_taxrate1;
			} elsif($federal_tax_income <= $max_taxrate5) {
				$federal_tax_gross = ($tax_rate5 * ($federal_tax_income - $max_taxrate4))
								   + ($tax_rate4 * ($max_taxrate4 - $max_taxrate3))
									  + ($tax_rate3 * ($max_taxrate3 - $max_taxrate2))
								   + ($tax_rate2 * ($max_taxrate2 - $max_taxrate1))
								   + $tax_rate1 * $max_taxrate1;
			} elsif($federal_tax_income <= $max_taxrate6) {
				$federal_tax_gross = ($tax_rate6 * ($federal_tax_income - $max_taxrate5))
								   + ($tax_rate5 * ($max_taxrate5 - $max_taxrate4))
								   + ($tax_rate4 * ($max_taxrate4 - $max_taxrate3))
									  + ($tax_rate3 * ($max_taxrate3 - $max_taxrate2))
								   + ($tax_rate2 * ($max_taxrate2 - $max_taxrate1))
								   + $tax_rate1 * $max_taxrate1;
			} elsif($federal_tax_income > $max_taxrate6) {
				$federal_tax_gross = ($tax_rate7 * ($federal_tax_income - $max_taxrate6))
								   + ($tax_rate6 * ($max_taxrate6 - $max_taxrate5))  
									+ ($tax_rate5 * ($max_taxrate5 - $max_taxrate4))
								   + ($tax_rate4 * ($max_taxrate4 - $max_taxrate3))
									  + ($tax_rate3 * ($max_taxrate3 - $max_taxrate2))
								   + ($tax_rate2 * ($max_taxrate2 - $max_taxrate1))
								   + $tax_rate1 * $max_taxrate1;
			}
		}       
		# 3.  Determine CADC and “final” federal tax liability (not including EITC or CTC)
		if ($in->{'cadc'} != 1) {
			$cadc_recd = 0;
		} elsif ($in->{'itin'} == 0 && $in->{'undocumented_child_count'} == $in->{'child_number'}) { #you cannot claim the credit if all dependents do not have an ITIN or SSN or if you don't have any children. 
			$cadc_recd = 0;
		} else {
			$cadc_eligible_child_count = $in->{'children_under13'};
			$countable_cadc_cc_expenses = $out->{'child_care_expenses'} + $out->{'afterschool_expenses'};
			if ($in->{'undocumented_child_count'} > 0) {
				for (my $i = 1; $i <= 5; $i++) { 
					if ($in->{'child'.$i.'_immigration_status'} eq 'undocumented_or_other' && $in->{'child'.$i.'_age'} < 13 && $in->{'itin'} == 0) {
							 #if the hh is headed by parent with legal status, but there are multiple mixed status children in the household. All parties must at least have an itin to claim the CADC https://www.irs.gov/pub/irs-pdf/p503.pdf. This is to recalculate the number of cadc eligible children in the household and their child care expenses if there are some children who are undocumented without an ITIN and some who have legal status in the same HH.
						$cadc_eligible_child_count -= 1;
						$countable_cadc_cc_expenses -= $out->{'cc_expenses_child'.$i} + $out->{'afterschool_child'.$i.'_copay'};
					}
				}
			}
        
			# Note: Separate from the question of whether a filer can file as head of household or single, children and other relatives int the home may be classified as dependents for the tax filer to claim certain tax credits. In the FRS model, all children listed in the household for whom the parent(s) pay half the support for qualify as a dependent. In addition, a spouse who has a disability that is severe enough that they cannot work and possibly require expenses for proper care can also be classified as a dependent.

			#The CADC/CDCTC is available for a maxmium of twice the maximum amount allowable for care for one individual.	The below code allows for the CADC/CDCTC to be claimed by a family that includes an adult is incapacitated because of disability. 	If an adult is disabled and not working, we assume that the other parents pay for someone to provide care for the  disabled spouse and their care expenses qualify for cadc. 
	
			if ($in->{'covid_cdctc_expansion'} == 1) {  
				$cadc_max_claims = 6000; #ARPA raised the max amount of child or dependent care claimed from $3000 to $6000. 
			}
		

			if ($in->{'family_structure'} == 1) {
				$cadc_base = &least($countable_cadc_cc_expenses, $cadc_eligible_child_count * $cadc_max_claims, 2 * $cadc_max_claims, $parent1_taxable_earnings); #The below code could be simplified -- for example, using a "parent_incapacitated_total" variable, but keeping the below in for now because it works and also provides useful information (the cadc_dis variable) for either debugging or use in state codes. 
			} else {
				$cadc_base = &least($countable_cadc_cc_expenses, $cadc_eligible_child_count * $cadc_max_claims, 2 * $cadc_max_claims, $parent2_taxable_earnings, $parent1_taxable_earnings);  

				if($in->{'disability_parent2'} == 1 && $in->{'parent2_max_hours_w'}==0 && ($in->{'itin'} == 1 || $in->{'parent2_immigration_status'} ne	'undocumented_or_other')) { 
					$cadc_dis = 1;         
					$cadc_base = &least($countable_cadc_cc_expenses + 12 * $in->{'disability_personal_expenses_m'}, ($cadc_eligible_child_count + $cadc_dis) * $cadc_max_claims, 2 * $cadc_max_claims,  $parent1_taxable_earnings );
				}

				#SH created a “parent2_incapacitated” variable in the TANF code, with the value of 0 (not incapacitated) or 1 (incapacitated). The above follows the same determination. Parent2 is incapacitated because of disability, i.e. when disability_parent2 = a and parent2_max_hours_w and parent2_max_hours_w=0, since that means that parent2 is both disabled and will never be earning income. 
				#if the 2nd parent is disabled and not working, we assume that you pay for someone to provide care for #your disabled spouse and their care expenses qualify for cadc. We need to ensure that the user knows #this when entering the amount into disability_personal_expenses. 
				# In addition, previous iterations of the code were based on old parent_earnings calculations wherein which the second parent’s earnings would never be higher than the first parent’s. Since the new 2017 methods allow for parent 2 to earn more than parent 1, we include both parent’s earnings in the formulas.	 
			}

			# determine cadc_percentage. (These are available at https://www.irs.gov/pub/irs-pdf/p503.pdf for 2018 and seemingly beyond.)
			#below block copied and pasted from mtrc code by S 7.16.21. 
			# determine cadc_percentage. (These are available at https://www.irs.gov/pub/irs-pdf/p503.pdf for 2018 and beyond.) Checked for 2021.

			if ($in->{'covid_cdctc_expansion'} == 1) {
				#ARPA drastically expands the maximum CDCTC claimed.
				for ($parent1_taxable_earnings + $parent2_taxable_earnings + $out->{'interest'}) {	#This is gross income, and should be modified accordingly if we add tax filing units or additional types of income.
					$cadc_percentage = ($_ <= 125000)  ?   0.50   :
										 ($_ <= 127000)  ?   0.49   :
										 ($_ <= 129000)  ?   0.48   :
										 ($_ <= 131000)  ?   0.47   :
										 ($_ <= 133000)  ?   0.46   :
										 ($_ <= 135000)  ?   0.45   :
										 ($_ <= 137000)  ?   0.44   :
										 ($_ <= 139000)  ?   0.43   :
										 ($_ <= 141000)  ?   0.42   :
										 ($_ <= 143000)  ?   0.41   :
										 ($_ <= 145000)  ?   0.40   :
										 ($_ <= 147000)  ?   0.39   :
										 ($_ <= 149000)  ?   0.38   :
										 ($_ <= 151000)  ?   0.37   :
										 ($_ <= 153000)  ?   0.36   :
										 ($_ <= 155000)  ?   0.35   :
										 ($_ <= 157000)  ?   0.34   :
										 ($_ <= 159000)  ?   0.33   :
										 ($_ <= 161000)  ?   0.32   :
										 ($_ <= 163000)  ?   0.31   :
										 ($_ <= 165000)  ?   0.30   :
										 ($_ <= 167000)  ?   0.29   :
										 ($_ <= 169000)  ?   0.28   :
										 ($_ <= 171000)  ?   0.27   :
										 ($_ <= 173000)  ?   0.26   :
										 ($_ <= 175000)  ?   0.25   :
										 ($_ <= 177000)  ?   0.24   :
										 ($_ <= 179000)  ?   0.23   :
										 ($_ <= 181000)  ?   0.22   :
										 ($_ <= 183000)  ?   0.21   :
										 ($_ <= 400000)  ?   0.20   :
										 ($_ <= 402000)  ?   0.19   :
										 ($_ <= 404000)  ?   0.18   :
										 ($_ <= 406000)  ?   0.17   :
										 ($_ <= 408000)  ?   0.16   :
										 ($_ <= 410000)  ?   0.15   :
										 ($_ <= 412000)  ?   0.14   :
										 ($_ <= 414000)  ?   0.13   :
										 ($_ <= 416000)  ?   0.12   :
										 ($_ <= 418000)  ?   0.11   :
										 ($_ <= 420000)  ?   0.10   :
										 ($_ <= 422000)  ?   0.09   :
										 ($_ <= 424000)  ?   0.08   :
										 ($_ <= 426000)  ?   0.07   :
										 ($_ <= 428000)  ?   0.06   :
										 ($_ <= 430000)  ?   0.05   :
										 ($_ <= 432000)  ?   0.04   :
										 ($_ <= 434000)  ?   0.03   :
										 ($_ <= 436000)  ?   0.02   :
										 ($_ <= 438000)  ?   0.01   :
															 0;
				}
			} else {
				for ($parent1_taxable_earnings + $parent2_taxable_earnings + $out->{'interest'}) {	#Again, this is gross income,  may need to do this later if we include more filing units in the same household. 
				  $cadc_percentage = ($_ <= 15000)  ?   0.35   :
									 ($_ <= 17000)  ?   0.34   :
									 ($_ <= 19000)  ?   0.33   :
									 ($_ <= 21000)  ?   0.32   :
									 ($_ <= 23000)  ?   0.31   :
									 ($_ <= 25000)  ?   0.30   :
									 ($_ <= 27000)  ?   0.29   :
									 ($_ <= 29000)  ?   0.28   :
									 ($_ <= 31000)  ?   0.27   :
									 ($_ <= 33000)  ?   0.26   :
									 ($_ <= 35000)  ?   0.25   :
									 ($_ <= 37000)  ?   0.24   :
									 ($_ <= 39000)  ?   0.23   :
									 ($_ <= 41000)  ?   0.22   :
									 ($_ <= 43000)  ?   0.21   :
														0.20;
				}
			}	
			our $cadc_nonref_recd = 0;
			$cadc_gross = $cadc_percentage * $cadc_base;
			if ($in->{'covid_cdctc_expansion'} == 1) {
				$cadc_recd = $cadc_gross; #ARPA made the CDCTC (also called CADC credit) fully refundable.
				$cadc_nonref_recd = 0;
			} else {
				$cadc_recd = &least($federal_tax_gross, $cadc_gross);
				$cadc_nonref_recd = $cadc_recd;
			}	
		}
		$federal_tax_cadc = pos_sub($federal_tax_gross, $cadc_nonref_recd); #This value is used below for determining the nonrefundable portion of the CTC, which, as indicated below, is determined by subtracting potential CTC from tax liability less the nonrefundable CADC. (Prior to 2021, the CADC was completely nonrefundable.) THis is important because the maximum value of the nonrefundable CTC is higher than the refundable one.
		$federal_tax = $federal_tax_cadc; #LOOK AT ME: Find out where fedeal_tax is used and if this is problematic that it's calculated AFTER deducting the CADC.

		# 4 Determine ctc_nonref_recd
		# Refer to CTC_max_income according to filing status from federal income taxes tables 2021. Use child tax credit worksheet in instructions for form 1040.

		if($in->{'ctc'} == 0) {
			$ctc_potential = 0;
			$ctc_nonref_recd = 0;	
		} else {
			$ctc_eligible_children_count = $in->{'children_under17'}; 
			$ctc_eligible_children_under6_count = $in->{'children_under6'};
			if ($in->{'undocumented_child_count'} > 0) { #we need to recalculate the number of children eligible for the CTC in the household. Qualifying children must have an SSN. Children with ITINs may be considered as a qualified dependent for ODC, Other Dependent Credit.  https://www.irs.gov/pub/irs-pdf/p972.pdf 
				for (my $i = 1; $i <= 5; $i++) { 
					if($in->{'child'.$i.'_age'} < 6 && $in->{'child'.$i.'_immigration_status'} eq 'undocumented_or_other' ) {
						$ctc_eligible_children_under6_count -= 1;
					}
					if($in->{'child'.$i.'_age'} < 17 && $in->{'child'.$i.'_immigration_status'} eq 'undocumented_or_other' ) {						
						$ctc_eligible_children_count -= 1; 
					}
				}
			}	
			if ($in->{'covid_ctc_expansion'} == 1) {
				for (my $i = 1; $i <= 5; $i++) { 
					if($in->{'child'.$i.'_age'} == 17 && $in->{'child'.$i.'_immigration_status'} ne 'undocumented_or_other') {  
					#ARPA amends the IRS tax code by allowing 17 year olds to be eligible for the CTC. This is for 2021 only. For years before or after 2021, need to use children_under17 variable. https://www.congress.gov/bill/117th-congress/house-bill/1319/text 
						$ctc_eligible_children_count += 1;
					}
				}	
				$ctc_potential = $ctc_per_child_arpa * $ctc_eligible_children_count; 
				$ctc_potential += $ctc_arpa_under6_add * $ctc_eligible_children_under6_count; #ARPA adds $600 to the credit (to total $3,600) for children under 6. 
			} else {	
				$ctc_potential = $ctc_per_child * $ctc_eligible_children_count; 
			}

			# Adding in the tax credit for other dependents (which is only nonrefundable. ARPA did not make this credit refundable.)	
			if ($in->{'undocumented_child_count'} > 0 && $in->{'itin'} == 1) {
				$ctc_potential += $odc_dependent_add * $in->{'undocumented_child_count'}; # $out->{'adult_children'}; #We are not currently including adult children in the 2021 FRS, but since this was programmed into a version of this code elsewhere (the 2021 MTRC tool), keeping it here, commented out, for potential future reference. 
			
				$other_dependent_credit = $odc_dependent_add * $in->{'undocumented_child_count'}; #$out->{'adult_children'}; #See note above -- the other dependent credit is nonrefundable and cover dependents who are not covered by the child tax credit. This includes adult children and cannot include a tax filer's spouse. While we are working on expanding the FRS to include adult children or other dependents, the 2021 online version of the FRS does not include them. Since the other dependent credit is important for tax calculations and can get complicated, and we developed the logic for its use in the MTRC and Community Change calculator, we incorporate it below, but the value of this variable will always be zero for now. 
			}

			if($parent1_taxable_earnings + $parent2_taxable_earnings + $out->{'interest'} <= $ctc_max_income && $in->{'covid_ctc_expansion'} == 0) { 
				$ctc_reduction = 0; 
				#Determination of the ctc does not include fli/ui/tdi income. See federal instructions for ctc.
			} else {
				use POSIX;  # to get the ceil function to round up to nearest multiple of 1000. So $425 would be #$1000
				if ($in->{'covid_ctc_expansion'} == 1) {  
					$ctc_reduction = &least(0.05 * 1000 * ceil(pos_sub($parent1_taxable_earnings + $parent2_taxable_earnings + $out->{'interest'}, $ctc_max_income_covid)/1000), &pos_sub($ctc_potential,$ctc_per_child * $ctc_eligible_children_count + $other_dependent_credit)); #Above the new ARPA threshold, the CTC is reduced until the amount of the CTC equals (old: the pre-COVID max of $2000) (new:) the amount of the credit without regard to the additional expansions in ARPA, but seemingly based on the ARPA definition of eligible children. So the first argument in this "least" collection is the ARPA-specific reduction from the ARPA-inflated maximum amount, but the second argument is the difference betweeen the maximum amount under ARPA and the maximum amount under pre-ARPA rules, inclusive of the inclusion of 17-year-olds as qualifying children. Again, earnings plus interest is used for now for gross income.
				}

				$ctc_reduction += 0.05 * 1000 * ceil(pos_sub($parent1_taxable_earnings + $parent2_taxable_earnings + $out->{'interest'},$ctc_max_income)/1000);
			}

			$ctc_potential_red = pos_sub($ctc_potential, $ctc_reduction); 
			$ctc_potential_recd_nonother = pos_sub($ctc_potential_red, $other_dependent_credit); #This is the value of the CTC separate from the CTC that can be claimed for other dependents.

			if($ctc_potential_red <= 0) { 
				$ctc_nonref_recd = 0; 
			} elsif ($in->{'covid_ctc_expansion'} == 1) {	

				$ctc_nonref_recd = &least(greatest(0,$federal_tax_cadc), $ctc_potential_recd, $other_dependent_credit); #We subtract from federal_tax_cadc. At least according to tax rules in 2019, remaining federal tax liability is calculated in teh CTC worksheet by deducting a range of nonrefundable credits, includign the CADC, from federal tax liability.
				#For ARPA policy scenarios, this  will make the nonrefundable CTC $0 unless there's a non-child dependent in the home, but still generates a nonrefundable credit if there are non-child dependents (including, for MTRC purposes, an adult student or incapacitated adult.) In the ctc.pl code, we use the refundable variable there to make the remaining credit refundable based upon the value of ctc_potential_recd less this potential nonrefundable amount. Similar to pre-ARPA rules, we still need to compare the value of the nonrefundable credit against federal tax liability, as nonrefundable credits cannot in total exceed tax liability. 

			} else { 
				$ctc_nonref_recd = &least($federal_tax_cadc, $ctc_potential_red); 
			} 
		}
	}

	# I believe cadc_real_recd may be a legacy piece of information from when we didn't determine federal tax liability (including all nonrefundable credits) and the various tax credits iteratively, or perhaps ebfore we adjusted the ctc codes to be compared against federal_tax_cadc, but I've gone back to 2011 and can't figure out why it's not just cadc_recd. It seems to be comparing remainining tax liability after the total between the nonrefundable CTC and the refundable credit are applied to tax liability prior to the application of CADC, but I'm not sure what value that really has. Its relevance may be bygone. If tax liability pre-CDCTC minus the total value of the refundable and nonrefundable child tax credits exceed are lower than the potential CDCTC, I don't see what the reasoning is for some number that adjusts to that amount beyond cadc_recd. Even if tax liability is 0 after the nonrefundable portion of the CTC is applied, that reduction to am amount further pushed to  0 is still valuable because the remainder of the CTC betweent the potential amount and the nonrefundable amount is still important, since that can increase the redundable portion of the CTC. LOOK AT ME Does this have to do with the ongoing horizontal bar chart error of cadc not showing up at very low incomes?
	if ($in->{'covid_cdctc_expansion'} == 1) {
		$cadc_real_recd = $cadc_gross; #Seems like we could just make this cadc_recd to, and rid ourselves of this condition.
	} else {
		#$cadc_real_recd = &least($cadc_gross, &pos_sub($federal_tax_gross, $ctc_potential_red)); #old version
		$cadc_real_recd = $cadc_recd; 	
	}

	# Start debug variables (which are harmless here, but that we don't need unless we're trying to figure out a problem, in which these might come in handy and could be added to the list of default variables below. To make the code more efficient, these could be removed from here and from the foreach list of default variables.
    our $earnings = $out->{'earnings'};
    our $interest = $out->{'interest'};
    our $tanf_recd = $out->{'tanf_recd'};
    our $fsp_recd = $out->{'fsp_recd'};
    our $child_support_recd = $out->{'child_support_recd'};
    our $child_care_expenses = $out->{'child_care_expenses'};
    our $children_under13 = $in->{'children_under13'};
    our $children_under17 = $in->{'children_under17'};
    our $parent2_earnings = $out->{'parent2_earnings'};
    our $family_structure = $in->{'family_structure'};
    our $child_number = $in->{'child_number'};
    our $ctc = $in->{'ctc'};
	# End debug variables

	# outputs
    foreach my $name (qw(federal_tax federal_tax_gross cadc_recd ctc_nonref_recd cadc_real_recd filing_status home support ctc_potential ctc_reduction ctc_potential_red federal_tax_cadc cadc_gross federal_tax_income federal_tax_credits cadc_base cadc cadc_real_recd ctc_potential_recd_nonother parent1_taxable_earnings parent2_taxable_earnings cadc_eligible_child_count ctc_eligible_children_count cadc_dis parent1_other_taxable_income  parent2_other_taxable_income federal_adjusted_gross_income taxable_ssdi)) { 
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;