#=============================================================================#
#  Food Stamp Asset Module -- NJ 2021 
#=============================================================================#
#
# Inputs referenced in this module:
#
#   FROM BASE
#     Inputs:
#       vehicle#_value
#       vehicle#_owed
#		child_number
#		heat_fuel_source
#		cooking_fuel_source
#		home_type
#		unqualified_immigrant_adult_count
#		daca_child_count
#		undocumented_child_count
#	   	housing_subsidy_tanf_alt	#policy modeling flag: Policy Change: Model a one-time housing subsidy of $200 given to TANF recipients without housing assistance?
#
#	SEC 8
#		housing_recd
#	
#	TANF
#		tanf_recd
#=============================================================================#

sub fsp_assets
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};


	# This subroutine can be considered to include the full array of potential state variations to the federal SNAP program.

	# outputs created

	#BBCE policies
	our $fs_vehicle1 = 0;
	our $fs_vehicle2 = 0;
	our $bbce_no_netincome_limit = 1; #This indicates whether the state has a BBCE policy that removes the net income test for SNAP applicants. Although not tracked via federal sources, states apparently have discretion over whether to set a net income test within their TANF MOE program, to confer categorical eligibility for SNAP. All states that have been confirmed to have a policy have a net income test within their BBCE program use the federal SNAP net income limits for their state program, at 100% FPL.
	our $bbce_categorical_no_netincome_limit = 1; #This indicates whether the state has used BBCE rules to waive the net income test for people who are categorically eligible but who are not eligible under expanded, broad-based categorical eligibility rules. There is at least one state (Virginia) that has a net income test for people who are categoricallly eligible who are not BBCE-eligible.
	our $bbce_gross_income_pct = 1.85;		# % of poverty used for SNAP gross income eligibility test. 
	our $bbce_no_asset_limit = 1;			# “1” for a state that has no asset limit as part of its BBCE program. 
	our $bbce_asset_limit = 0;				# For states that have a BBCE asset limit, this is where that would be.			
	our $bbce_disability_no_asset_limit = 1; #  Some states that have broad-based categorical eligibility (BBCE) policies do not exempt households that include people who are elderly or people with disabilities from federal asset limit at incomes higher than 200% of the poverty level. These families face no gross income limit based on federal policy, but do face asset limits. BBCE allows states to exempt the assets of these families at gross incomes below 200% of the federal poverty level and also allows states the choice of whether to use the federal standard for families above this level. PA and KY choose to use the federal asset limit at higher incomes. NH and DC exempts assets for all applicant families, so this variable would equal 1.

	#Categorical eligibility of free school meals among children receiving free meals.
	our $wic_elig_nslp = 0; #This is a state policy variable indicating whether there is categorical eligibilty for WIC for young children who receive free school lunches. This is a policy in some areas (like DC and VA) but is not explicitly a federal policy. It is not a policy in KY and does not seem like a policy in NJ, in that there is no record of any state agency or nonprofit agency promoating eligibility to WIC through school lunch programs.

	#Standard Utility Allowance policiies
	# See https://casetext.com/regulation/new-jersey-administrative-code/title-10-human-services/chapter-87-new-jersey-supplemental-nutrition-assistance-program-nj-snap-manual/subchapter-5-financial-eligibility-income/section-1087-510-income-deductions. 
	our $heatandeat_nominal_payment = 0;	#Heat-and-eat nominal payment amount. This is a small amount of LIHEAP benefits that states can give to SNAP recipients to qualify them for the 'standard utility allowance' deduction when calculating their SNAP net adjusted income, even in cases where the family does not pay for their own heat (which would typically disqualify them from getting the SUA deduction). This serves to increase the amount of SNAP benefits that the family gets. NJ does not provide nominal LIHEAP payments to increase SNAP participation, according to their most recent LIHEAP plan. 
	our $optional_sua_policy = 0;			# Whether the state allows families to have the option of claiming their actual costs instead of the SUA. NH does not do this. This is clear from the SNAP policy manual and from the most recent federally published SNAP Policy Options report.
	our $sua_heat = 548; #Based on NJ Medicaid documentation (which uses this same utility allowance), and verified by federal documentation.
	our $sua_utilities_only = 338; #This is the SUA for "utilities only," "non-heating," "limited utility allownance" in some states, the latter in NJ
	our $sua_phoneandinternet_only = 29; #This is the allowance / SUA for homes that just incur telephone and internet expenses but no other utilities. Some states count internet as a separate utility cost, meaning people paying for telephone and internet separately can receive a higher utility allowance, but NJ does not. SEe 

	#Average electic and gas (utility) expenses
	our $average_electric_cost = 105.07; #from eia.gov
	our $average_naturalgas_cost = 820/12; #from aga.org.	

	#State choices related to treatment of ineligible 'alien' household members. See https://www.law.cornell.edu/cfr/text/7/273.11. 7 CFR 273.11 (c)(3).  
	
	our $ineligible_immigrant_prorata_grossincome = 1; #This indicates whether the state counts a prorated amount of the ineligible immigrant's income for the gross income test. If this is 0, then all of the income of the ineligible immigrant is counted for the purposes of the gross income test. 
	
	#"a prorata share is calculated by first subtracting the allowable exclusions from ineligible members' income and then dividing the income evenly among the household members, including the ineligible member(s). All but the ineligible members' share is counted as income to the remaining household members" NJAC 10:87-7.7.
	our $ineligible_immigrant_prorata_netincome = 1;
	# This indicates whether the state counts a prorated amount of the ineligible immigrant's income for the net income and determining benefit level. If this equals 0, it means the state counts all of the income of the ineligible immigrant for net income and level of benefits. 
	
	#Federal policy allows for states to choose whether to count (1) all OR (2) a pro rata share of the ineligible immigrant's income and deductible expenses and all of their resources resources. States may count all of the ineligible immigrant's income for the gross income test and count only a pro rata share to apply the net income test and determine level of benefits. 
	#In NJ, this policy is outlined in 10:87-3.10 and 10:87-7.7(c). All resources of ineligible immigrant are counted. The income of the ineligible immigrant is counted in its entirety and the allowable 20% earned income, standard, medical, dependent care, child support payments, and excess shelter deductions will apply to remaining household members. The ineligible member isn't included in the household size for comparing household's resources with resource eligibility limits, comparing monthly income with income eligibility standards, OR assigning a benefit level to the household. 

	#For LPRs here less than 5 years, states can either (1) count all of their resouces and all but a pro-rated share of their income/deductible expenses OR (2) count all of the resources, count none of their income/deductible expenses, count any money payment made to at least one eligible household member, and cap resulting benefit amt for the household size that includes the ineligible immigrant member.  

	#For undocumented immigrants (DACA recipients too), states must count (1) all  or (2) a pro-rata share of the ineligible immigrants' income and deductible expenses and all of their resources. The state may count all of the immigrant's income for purposes of applying the gross income test while only counting all but a pro-rata share to apply the net income test and the benefit level.

	# Six states allow unqualified immigrants access to food assistance via state funding, which is why this is calculated in the fsp_assets and not in the main fsp code.  https://www.nilc.org/issues/economic-support/overview-immeligfedprograms/. Qualified immigrant children are eligible for SNAP without a 5 year waiting period: https://www.fns.usda.gov/snap/eligibility/citizen/non-citizen-policy

	our $snap_state_immigrant_option = 0;
	
	our $snap_foster_child_option = 0; 	#States may have different policies for whether foster children are counted in the family's SNAP application. When this variable equals 0, it indicates that the state allows families to choose whether foster children are included in the family size for the snap application. If they are included, then the board and clothing allowances are considered as income to the family in determining eligibility. Since the board payments are so high, the FRS assumes that the family would opt to exclude the foster children from the application to maximize SNAP benefits. See regulation: https://www.nj.gov/dcf/policy_manuals/CPP-III-C-2-425.pdf and NJAC 10:87-2.3. Foster children excluded from the household are treated as boarders and therefore not eligible for apply for SNAP as a separate household - or at least, this is Suma's interpretation of the provisions in NJAC 10:87-2.3(2-6).
	
	our $wic_denial_unqualified_immigrants = 0;	#There is a state policy option to deny WIC benefits to unqualified immigrants. Federal law allows states to exclude immigrants from WIC participation based on the same immigrant groupings excluded from TANF and SNAP participation, but as of October 2021 no state has opted to exclude any immigrant populations from receiving WIC benefits or participating in WIC Programs. See https://www.ecfr.gov/current/title-7/subtitle-B/chapter-II/subchapter-A/part-246#subpart-C,  https://crsreports.congress.gov/product/pdf/R/R44115, https://www.fns.usda.gov/wic/immigration-participation, and https://www.nilc.org/issues/economic-support/overview-immeligfedprograms/#_ftnref21.  
	
	#Inputs or outputs generated in code below
	our $pha_ua = 0; # Estimating or incorporating energy costs is important for estimating SNAP becuase we the fair market rents we use incorporate utilities, but SNAP calculations separate rent from utilities. So we need to separate rent from utilities here as well. These estimations vary by state but this variable is used in the upcoming FSP code.
	#For at least the MTRC, starting with Allegheny County, we are moving away from relying on PHA UAs for estimating utility costs. Most people using this tool for their own situations will likely be entering their own costs anyway. But relying on PHA UAs has also become problematic because it require digging deep into not commonly available public information, especially for large states with many PHAs. So we are moving toward a more general approach of just incorporating average gas and electric costs makes sense. Perhaps we could also adjust these based on the difference between fair market rent and the median or average bedroom size of a state or at the national level.
	our $pha_region = 0; 
	
	our $tanf_recd = $out->{'tanf_recd'}; #MAY MOVE THIS LATER. See below note for why we are redefining tanf_reced in this code.
	our $tanf_housing_subsidy_alt = 200;	# a policy modeling option for NJ 2021. 
	
	
	
	# calculate assets    
	$fs_vehicle1 = 0;						# value of vehicle 1 to be counted in the food stamp asset test. This calculation is a bit more complicated in states that count assets.
	$fs_vehicle2 = 0;						# value of vehicle 2 to be counted in the food stamp asset test. This calculation is a bit more complicated in states that count assets.

	$pha_ua = $average_electric_cost + $average_naturalgas_cost; # Let's try this for now. It saves us a lot of work, for a figure that isn't necessarily right. May change this variable name soon, since it's no longer tied to public housing authorities, but keeping it in for now to help make sure all the codes work correctly.
		
	#This is the SNAP assets module, but since this is run after both sec8 and tanf, we can use this to model the shallow housing subsidy given to tanf recipients who do not receive housing assistance. REASSESS once final order of programs is determined. This could also go in the LIHEAP code.
	
	if ($in->{'housing_subsidy_tanf_alt'}==1) {
		if ($tanf_recd > 0 && $out->{'housing_recd'} == 0) {
			$tanf_recd += $tanf_housing_subsidy_alt;	#QUESTION FOR SETH - IS THIS SOMETHING WE COULD DO HERE? THIS POLICY MODELING OPTION CANNOT BE WRITTEN INTO THE TANF MODULE BECAUSE SEC 8 IS RUN AFTER TANF.
		}	
	
	}	

  # outputs
    foreach my $name (qw(fs_vehicle1 fs_vehicle2 bbce_gross_income_pct bbce_no_asset_limit bbce_disability_no_asset_limit bbce_asset_limit  bbce_no_netincome_limit bbce_categorical_no_netincome_limit heatandeat_nominal_payment optional_sua_policy wic_elig_nslp pha_ua pha_region sua_heat sua_utilities_only average_naturalgas_cost average_electric_cost sua_phoneandinternet_only snap_state_immigrant_option ineligible_immigrant_prorata_grossincome ineligible_immigrant_prorata_netincome tanf_recd snap_foster_child_option wic_denial_unqualified_immigrants )) {
		         
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}
1;