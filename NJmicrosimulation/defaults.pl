# Defaults NJ 2021

sub defaults {

    my $self = shift;

	# The below "order" defines the sequencing of the various individual Perl codes. There are some repetitions based on how families can optimally use various programs. For example, in many places TANF includes a child care deduction, but also can lead to work requirements that increase child care need, so in those areas it may be optimal for a family to first assess their child care need before enrolling in TANF, see their child care need increase due to work requirements, and then allow them to claim a larger TANF child care deduction that will increase their TANF cash assistance. 

	#Start with the basic order/sequence for families that do not engage in an array of programs that may cause very  many loops. This baseline scenario covers all scenarios except for families that receive child support or families that include a child with a disability. We still run child_support because it includes the definitions of some variables and keeping this order intact will help debugging for situations when the array is appended. 
	@{$self->{'order'}} = qw(interest parent_earnings fostercare fli_tdi ssdi unemployment child_care ssp ssi fed_hlth_insurance hlth child_support tanf work child_care ccdf hlth sec8 fsp_assets liheap fsp work afterschool schoolsummermeals wic fedtax eitc  payroll ctc statetax food lifeline salestax other); 
	
	#Note we repeat hlth after child care above because child care costs are needed to determine Medically Needy eligibility in NJ.

	if ($in->{'cs_flag'} == 1 || $in->{'disability_child1'} + $in->{'disability_child2'} + $in->{'disability_child3'} + $in->{'disability_child4'} + $in->{'disability_child5'} > 0) { 
		if ($in->{'disability_child1'} + $in->{'disability_child2'} + $in->{'disability_child3'} + $in->{'disability_child4'} + $in->{'disability_child5'} > 0)	{
			#Beginning in 2021, we are making the sequence of programs dependent on whether the family includes a child with a disability. There does not appear to be an optimal or steady-state order of benefit enrollment or recertification for families that include children with disabilities but also apply for TANF. We are still looking into what happens in this case. But in the meantime, we are running another round of many of the above programs to account for tanf income in at least the child disabiltiy cases where parental income is not high enough to lead to this endless loop. This will likely result in some errors in calculations among families who qualify for TANF when their child is included in the TANF unit but don't when the child is excluded. By running tanf after ssi a second time, this appended array assumes that the state will exclude parents from TANF receipt in deference to child SSI receipt (which makes sense from a state budget perspective) in this case. But still needs checking.
			push @{$self->{'order'}}, qw(ssi fed_hlth_insurance hlth);
		}

		if ($in->{'cs_flag'} == 1) {
			#Child support court order formulas require taxable income and tax credit numbers that can only be attained after the income tax modules are run. So we append the 'order' array to start at child support again. In reality, there is no steady state to this, as child support order formulas use previous years' tax filings, and not current year filings. This means there will always be a pretty significant room for error in estimating actual costs families face, especially as children grow older and out of care.
			push @{$self->{'order'}}, qw(hlth child_support);
		}

		#Now that outputs from these appended modules may impact later determinations, we run those later determinations again.
		
		push @{$self->{'order'}}, qw(tanf work child_care ccdf sec8 fsp_assets liheap fsp work afterschool schoolsummermeals wic fedtax eitc  payroll ctc statetax food lifeline salestax other);
		
		#Note that the following order could be used, but because of the multiple iterations of several long codes, including child_care, we are using "push" to append the order, at least for now, so as not to result in long load times for the results when trying to model families that do not satisfy the above conditions. It may be worth exploring at a later time whether it would be easier simply to run this order instead of conditional orders as described above. For families that do not satisfy these conditions or whcih satisfy one or the other, the output should be the same.
		# @{$self->{'order'}} = qw(interest parent_earnings fli_tdi unemployment child_care ssp ssi fed_hlth_insurance hlth child_support tanf work child_care ccdf sec8 fsp_assets liheap fsp work afterschool schoolsummermeals wic fedtax eitc  payroll ctc statetax food lifeline salestax other ssi fed_hlth_insurance hlth child_support tanf work child_care ccdf sec8 fsp_assets liheap fsp work afterschool schoolsummermeals wic fedtax eitc  payroll ctc statetax food lifeline salestax other); 
			
	}
	
  # define variables to be used for creating charts
	#Note: How to add a benefit to the eligibility bar chart. First, most obviously, you need to create the output variable. For example, beginning in 2021 we are modeling (for NJ) a variable that joins FLI and TDI benefits, called "fli_plus_tdi_recd", so that needs to be outputed in a perl code, meaning that it is added to the $out-> hash. Importantly, you also need to output a flag variable that reflects the user choice to model this benefit, even if the family they are modeling is actually never eligible for it in the income ranges seleted. This must also be an output variable. For some variables (e.g. liheap), this means that the perl must, somewhere, convert that input ($in->{'liheap'}) to an output ($out->{'liheap'}. For other variables, that output may need to be created within the perl codes, e.g. "fli_tdi_flag" or "child_nutrition_flag." Both the output variable representing receipt and the flag variable representing the user selection must be included in the "chart" csv, by adding it to the below  @{$self->{'chart'}}  array. See note in chart_functions.php for how that's incorporated in the flags and arrays in that code. 

      @{$self->{'chart'}} = qw(disability_parent1 disability_parent2 disability_expenses family_size unit_size ccdf fsp hlth sec8 tanf eitc state_eitc ctc state_cadc state earnings earnings_posttax earnings_plus_interest taxes  
    federal_tax state_tax local_tax payroll_tax fpl child_support_recd eitc_recd ctc_total_recd tanf_recd fsp_recd rent_paid child_care_expenses 
    food_expenses housing_recd child_care_recd hlth_cov_parent hlth_cov_child1 hlth_cov_child2 hlth_cov_child3 hlth_cov_child4 hlth_cov_child5 fpl ccdf_eligible_flag lifeline lifeline_recd other_expenses 
    trans_expenses premium_tax_credit premium_credit_recd public_hlth_prem health_expenses health_expenses_before_oop child1_age child2_age child3_age child4_age child5_age state_eic_recd state_cadc_recd debt_payment 
    federal_tax_gross cadc cadc_recd tax_after_credits state_tax_gross local_tax_gross federal_tax_credits state_tax_credits local_tax_credits net_resources wic_recd child_foodcost_red_total ssi_recd liheap_recd afterschool_expenses salestax upd_recd child_nutrition_flag fli_plus_tdi_recd fli_tdi_flag medically_needy foster_child_payment); 

  # define variables to be included in private CSV output file
    @{$self->{'private_csv'}} = qw(fuel_source tanf_earned_ded_recd tanf_earnings ostp parent1_premium_ratio a27yo_premium_ratio family_costfrs parent_costfrs permealcost nsbp frpl fsmp child1_foodcost_red  child2_foodcost_red child3_foodcost_red child4_foodcost_red child5_foodcost_red family_structure parent_number child_number salestax day3_cc_hours_child3 day3_cc_hours_child4 day3_cc_hours_child5 day2_cc_hours_child3 day2_cc_hours_child4 day2_cc_hours_child5 day1_cc_hours_child3 day2_cc_hours_child3 day3_cc_hours_child3 day4_cc_hours_child3 day5_cc_hours_child3 day5_cc_hours_child4 day5_cc_hours_child5 day1hours day2hours day3hours day5hours day4hours family_size unit_size ssi_recd ssi_recd_mnth ccdf fsp hlth sec8 tanf eitc ssi wic nsbp prek sanctioned state_eitc ctc state_cadc earnings earnings_posttax child_support_recd eitc_recd tanf_recd fsp_recd rent_paid 
    housing_recd last_received_sec8 hlth_recd child_care_recd federal_tax state_tax county_tax federal_tax_gross payroll_tax cadc_real_recd state_eic_recd home support
    child_care_expenses food_expenses family_foodcost hlth_cov_parent hlth_cov_child1 hlth_cov_child2 hlth_cov_child3 hlth_cov_child4 hlth_cov_child5 ctc_additional_recd ctc_total_recd
    lifeline lifeline_recd other_expenses trans_expenses premium_tax_credit premium_credit_recd public_hlth_prem health_expenses ctc_nonref_recd cadc cadc_recd ccdf_eligible_flag interest debt_payment exempt_number filing_status
    parent1_earnings parent2_earnings parent_workhours_w state_nrcadc_recd state_nrcadc_base state_cadc_recd wic_recd afterschool_expenses disability_work_expenses disability_medical_expenses_mnth disability_personal_expenses disability_expenses salestax child_foodcost_red_total liheap_recd federal_tax_income tax_before_credits income expenses cs_flag child1_support child2_support child3_support child4_support child5_support fli_plus_tdi_recd fli_recd tdi_recd child_nutrition_flag medically_needy foster_child_payment); 

  # define variables to be recorded in public CSV output file
    @{$self->{'public_csv'}} = qw(earnings net_resources eitc state_eitc state_cadc child_support_recd tanf_recd fsp_recd federal_tax_credits state_tax_credits local_tax_credits
    public_hlth_prem premium_credit_recd health_expenses child_care_expenses trans_expenses rent_paid food_expenses family_foodcost lifeline_recd other_expenses debt_payment payroll_tax 
    tax_before_credits tax_after_credits federal_tax_gross eitc_recd ctc_total_recd cadc cadc_recd state_tax_gross state_eic_recd
    state_cadc_recd hlth_cov_parent hlth_cov_child1 hlth_cov_child2 hlth_cov_child3 hlth_cov_child4 hlth_cov_child5 interest wic_recd afterschool_expenses disability_expenses salestax child_foodcost_red_total ssi_recd liheap_recd fli_plus_tdi_recd fli_recd tdi_recd child_nutrition_flag foster_child_payment); 

  # define the captions to be used in the public CSV output file
    %{$self->{'csv_labels'}} =
    (
        'earnings'         =>       'Earnings',
		'taxes'            =>       'Taxes',
        'earnings_posttax' =>       'Post-tax Earnings',
        'net_resources'	   =>       'Net Resources',
        'child_support_recd' =>     'Child Support',
		'eitc_recd'        =>       'Federal EITC',
		'cadc_recd'		   =>		'Federal CADC',
        'state_eic_recd'   =>       'State EITC',
        'state_cadc_recd'  =>       'State Child and Dependent Care Tax Credit',
        'ctc_total_recd'   =>       'Child Tax Credit',
        'tanf_recd'        =>       'TANF',
        'fsp_recd'         =>       'SNAP/Food Stamps',
        'public_hlth_prem' =>		'Public Health Insurance Premiums',
        'health_expenses'  =>       'Health Expenses',
        'child_care_expenses' =>    'Child Care Expenses',
        'trans_expenses'   =>       'Transportation Expenses',
        'rent_paid'        =>       'Housing Expenses',
		'heap_recd'        =>       'Heap Benefits',
        'food_expenses'    =>       'Food Expenses',
        'family_foodcost'  =>       'Unsubsidized Food Expenses',
		'lifeline_recd'    =>       'Lifeline Subsidy',
        'other_expenses'   =>       'Expenses for Other Necessities',
        'federal_tax'      =>       'Federal Tax',
        'state_tax'        =>       'State Tax',
        'payroll_tax'      =>       'Payroll Tax',
        'debt_payment'     =>       'Debt Payment',
        'local_tax'        =>       'Local Tax',
        'federal_tax_credits' =>	'Fed Tax Credits',
        'state_tax_credits'	=>		'State Tax Credits',
        'local_tax_credits'	=>		'Local Tax Credits',
        'federal_tax_gross' =>		'Fed Gross Tax',
        'state_tax_gross'	=>		'State Gross Tax',
        'hlth_cov_parent'	=>		'Parent\'s Health Coverage',
        'hlth_cov_child1'	=>		'1st Child\'s Health Coverage',
        'hlth_cov_child2'	=>		'2nd Child\'s Health Coverage',
        'hlth_cov_child3'	=>		'3rd Child\'s Health Coverage',
		'hlth_cov_child4'	=>		'4th Child\'s Health Coverage', 
		'hlth_cov_child5'	=>		'5th Child\'s Health Coverage', 
        'tax_before_credits' =>		'Tax Excluding Credits',
        'tax_after_credits' =>		'Tax Including Credits',
      #  'private_max'       =>      'Federal Health Insurance',
        'eitc'              =>      'Receives Federal EITC when eligible',
        'state_eitc'        =>      'Recieves State EITC when eligible',
        'cadc'              =>      'Receives Federal CDCTC when eligible',
        'state_cadc'        =>      'Recieves State CDCTC when eligible',
		'fli_recd'			=>		'NJ Family Leave Insurance Benefits',
		'tdi_recd'			=>		'NJ Temporary Disability Insurance Benefits',
		'interest'			=>      'Interest from Savings',
        'premium_credit_recd' =>	'Premium Tax Credit',
    #    'heap'              =>      'Home Energy Assistance Program',
		'ssi_recd'			=>		'Supplemental Security Insurance', 
		'disability_expenses' =>	'Disability personal and work expenses', 
		'salestax'			=>		'Sales Tax', 
		'wic_recd'			=>		'Value of WIC benefits', 
		'child_foodcost_red_total' => 'Savings from free or reduced-price meals for children', 
		'ssi_recd'			=> 		'SSI cash assistance', 
		'liheap_recd'		=>		'Savings from LIHEAP', 
		'afterschool_expenses'	=>	'Afterschool costs',
#		'udp_recd'			=>		'Savings from DC\'s Utility Discount Program',
		'child_nutrition_flag' =>	'Child nutrition programs',
		'foster_child_payment' => 'Foster child board payments',

		
    );

}

1;

