#=============================================================================#
#  WIC (Women, Infants and Children) Module – 2021 (updated from 2020)
#=============================================================================#
#
# Inputs referenced in this module:
#
#  FROM BASE
#  WIC            	
# child#_age 
# breastfeeding 
# earnings
# fpl
# child#_foster_status
#
# FROM INTEREST
# interest
#
# FROM SSI
# ssi_recd
# 
#   FROM HEALTH
#  hlth_cov_parent	[since there is “automatic” eligibility for Medicaid-eligible individuals]
#  hlth_cov_child#
#  medically_needy         # from FL only – can exclude for now until we do Florida again.
#
#  FROM FOOD STAMPS
#  fsp_recd		[since there is “automatic” eligibility for SNAP-eligible individuals]
#
#  FROM TANF
#  tanf_recd 		[for categorical eligibility]
#  child_support_recd
#
#  FSP ASSETS
#	wic_denial_unqualified_immigrants 
#=============================================================================#

sub wic
{
    my $self = shift;
    my $in = $self->{'in'};
    my $out = $self->{'out'};
	#  my $dbh = $self->{'dbh'};

	# outputs created

	# The DC 2017 model used estimates that included no methodology. The 2019 estimates come from  https://fns-prod.azureedge.net/sites/default/files/ops/WICFoodPackageCost2014.pdf, a much more rigorous study that included greater specificity. We have simplified the data from Table 3.2 for FRS users. This also assumes that a child just turned the age they are. (For exmaple, an infant is modeled as being just born; a 4-yo is not modeled as ever turning 5. Mothers are either partially or fully breastfeeding, but not partially breastfeeding. Conceivably we could build greater specficity into the model.) There was a 2018 update to the 2014 report: https://www.fns.usda.gov/wic/participant-program-characteristics-2018-food-packages-costs-report, incorporated below.
	
	# our $wic_pregnant = 0;	#adding this as a placeholder but commenting out for now because we are not yet including added benefits for pregnancy in the FRS (but are modeling benefits for newborns and new parents.
    our $wic_breastfeeding = 48.92; #Group VII: Women who are fully breastfeeding [or] pregnant with, or partially (mostly) breastfeeding multiples; #  There seems to be a grammar errror introduced in the 2018 report compared to the 2014 report, but elsewhere the report clarifies that Group VII indeed includes fully breastfeeding women. #SS 7.16.21 - updated with mtrc number
    our $wic_notbreastfeeding =32.27;   	# Was 38.23 in 2014, estimated monthly food package costs for Group VI, "Nonbreastfeeding postpartum; partially (minimally) breastfeeding (up to 6 months postpartum)." #SS 7.16.21 - updated with mtrc number
    our $wic_breastfedinfants = 44; # Was 70.44 in 2014, estimated monthly food package costs for Group II-BF, fully breastfed infants 6-11.9 months. Note that the benefit is only for 6 months, since the infant is breastfed before then.  #SS 7.16.21 - updated with mtrc number
    our $wic_formulafedinfants = 168.43; # Was 144.51, estimated monthly food package costs for Group II-FF, fully formula-fed infants. This represents a weigthed average based on costs for formula fed infants 0-3.9 months (group II-FF-A), 4-5.9 months (group II-FF-B), and 6-11.9 months (group II-FF), to account for a monthly average. In 2018: (175.27 * 4 +  188.54 * 2 + 157.16 * 6) / 12 = 168.43 #SS 7.16.21 - updated with mtrc number
    our $wic_1yochild = 33.64;   	# Was 38.6 in 2014, estimated monthly food package costs for Group IV-A, Children 1-1.9 years. #SS 7.16.21 - updated with mtrc number
    our $wic_2to4yochild = 33.65;   # Was 39.41 in 2014, estimated monthly food package costs for Group IV-B, Children 2-4.9 years.  #SS 7.16.21 - updated with mtrc number
	our $foodathomecpi2018 = 240.147; # Was 241.33 in 2014. Needed to account for inflation from WIC study. Food at home CPI for all urban customers, 9/2014. Source: https://fred.stlouisfed.org/series/CUSR0000SAF11, from US BLS CPI estimates. #SS 7.16.21 - updated variable name from $foodathomecpi2018 and with mtrc number
	our $foodathomecpi = 259.739; #Food at home CPI for all urban customers, 8/2021.  Source: https://fred.stlouisfed.org/series/CUSR0000SAF11, from US BLS CPI estimates.  Possibly eventually this shoudl be aligned with when we determine food costs. Updated 10/6/2021.
	#
    # our $wic_CVCmothers = 11;	# Commenting this out becaause it's factored into WIC study. May come in handy later. Vegetables and Fruit Cash-Value Check for new mothers. This assumes no multiples (twins, triplets, etc.); those mothers get $16.50/ month
    # our $wic_CVCchildren = 8;	# Commenting this out becaause it's factored into WIC study. May come in handy later. Vegetables and Fruit Cash-Value Check for young children per month.
    our $wic_inc_limit = 1.85;     	# The income eligibility limit as a % of federal poverty guideline.
    our $wic_income = 0;		# countable WIC income per FNS guidelines
    our $wic_recd = 0;             #  Estimated monetary value of WIC

	# RECERTIFICATION NOTE: Recertification occurs once  every 6 months to a year, see https://www.fns.usda.gov/wic/who-gets-wic-and-how-apply. Also according to that list, there can be waiting periods if enough people apply to WIC.
	#
	# POLICY NOTE REGARDING FARMER'S MARKET BENEFITS: In some areas, like DC, there are also farmer’s market nutrition program (FMNP), see https://www.fns.usda.gov/fmnp/wic-farmers-market-nutrition-program-fmnp. Upon inquiry in 2017-18, DC DHS clarified that they are not interested in us modeling farmer's market benefits this year, or at least for the parameters of this project. We have retained this practice of not including farmer's market benefits in 2019.

	# POLICY NOTE: WIC is not an entitlement. https://www.fns.usda.gov/wic/about-wic-wic-glance. But coverage rate is fairly high, according to USDA study posted on website, at about 60 percent of eligible, and about 85 percent of women and infants eligible.

	# In DC, the state/jurisdiction we first used for an FRS WIC module, we found that WIC Policy & Procedure Number 8.007, page 18, makes it clear that administrators assume nutritional or medical conditions are met for all WIC applicants with children of eligible ages. Despite clear guidelines on how to fill out the dietary and nutritional assessments, it appears that when families apply for WIC, nearly all pregnant and postpardum mothers, and all children under 6, are eligible for the program when dietary eligibility guidelines are appropriately followed by the certified professional administrators (CPAs) at WIC offices. For the time being, we are then assuming that all dietary eligibility guidelines are met. See "Estimating Eligibility and Participation for the WIC Program: Final Report," (2002), Chapter 7, at https://www.ncbi.nlm.nih.gov/books/NBK221951/#ddd00086. 

	# Certain applicants can be determined income-eligible for WIC based on their participation in certain programs. These included individuals: 
	# * eligible to receive SNAP benefits, Medicaid, for Temporary Assistance for Needy Families (TANF, formerly known as AFDC, Aid to Families with Dependent Children),
	# * in which certain family members are eligible to receive Medicaid or TANF, or
	# * at State agency option, individuals that are eligible to participate in certain other State-administered programs.
	# In other words, any individuals in families that receive SNAP or TANF meet the income requirement for WIC, and, assuming (as above) that criteria for nutritional risk are met, also will be able to receive WIC. Further, discussion of WIC rules at https://www.ncbi.nlm.nih.gov/books/NBK223563/ indicate that mothers and young children eligible for Medicaid ("certain family members") are eligible for WIC. It's not immediately clear if any states offer additional state programs also confer categorical eligibilty, though, but it seems that for the most part, there isn't much flexibility. In DC, for example, individuals  qualify for WIC income test in DC if they “[m]eet income guidelines or medical risk for your family as listed below or are participating in Medicaid, DC Healthy Families [CHIP], School Lunch Program, Temporary Assistance for Needy Families (TANF), or the Food Stamp Program.” But that guidance may be more for administrators than for actualy policy formula, as the school lunch program has identical income critera as WIC and I believe DC's CHIP program was merged with Medicaid.

	# POLICY NOTE: States with SNAP/TANF BBCE also increase WIC eligibility, and states can also confer WIC to families making under Medicaid income limits. Each child on Medicaid adds more to WIC benefits. There has been some literature on this but have concluded that Medicaid expansions above WIC guidelines likely do not increase WIC takeup because above 185% of poverty, most parents are on employer insurance.
	
	#IMMIGRANTS: The 1996 welfare reform restricted a number of immigrants from many public benefits, but WIC is not one of them. It's a state option for whether states allow immigrants to access WIC. This NILC source is the only thing I found about this (other that the PRWOA statute) https://www.nilc.org/issues/economic-support/overview-immeligfedprograms/#_ftn20. This same source is cited by Heather's report with NYU profs here: https://steinhardt.nyu.edu/sites/default/files/2019-10/Approaches%20to%20Protect%20Children%27s%20Access%20in%20an%20Era%20of%20Harsh%20Immigration%20Policy_0.pdf. See also this NJ state related guidance for benefits during covid: https://www.nj211.org/sites/default/files/documents/2020-06/immigrant-access-covid-19-relief-programs.pdf This code does not need to check for immigrant status.
			
	#CHILDREN WITH DISABILITIES - WIC assesses "nutrtional risk" in eligibility, but we do not assess this. The program does not appear, at the federal level, to have special rules related to children with disabilities (no differences in how household size is counted or what income is counted). Also, we are not currently programming adult children (over age of 18) with disabilities into the FRS, but if we do, the definition of children in the Hunger free kids act includes adults older than 18 who have been determined to have a disability by a state educational agency or who is participating in a public/nonprofit private shool program est for individuals who have a disability. There is no mention of children with disabilities being treated differently in WIC. 
	
	#TREATMENT OF SSI: from the eligibility guidance, it appears that income, including social security benefits, from all family members is countable for WIC eligibility https://www.fns.usda.gov/sites/default/files/2013-3-IncomeEligibilityGuidance.pdf.
		
	#NATIVE POPULATIONS: applicants served in areas where WIC is administered by an Indian Tribal Organization (ITO) must meet residency requirements. This is the same for others.  https://www.fns.usda.gov/wic/wic-eligibility-requirements. Individuals benefiting from the Food Distribution Program on Indian Reservations are automatically eligible for WIC: https://fns-prod.azureedge.net/sites/default/files/2013-3-IncomeEligibilityGuidance.pdf. We are not counting this at the time. There are a number of payments made to certain tribes and confederations of tribes listed in the guidance that is specifically named as excluded income:https://www.ecfr.gov/current/title-7/subtitle-B/chapter-II/subchapter-A/part-246/subpart-C/section-246.7#p-246.7(d). It does not appear to have different eligibility guidelines for Indian/Native residents. There is no check currently for native status in this code. 
	
	#ADULT STUDENTS: they are eligible, and most federal student financial assistance is excluded from countable income.
	
	#EXPECTING/PREGNANT PARENTS: #based on discussion between SH and SS on 10.12.21, we are not including pregnant parents at this time. the info here is for if we end up including it later: new parents are already programmed into WIC. Pregnant parents - we need to discuss adding an input asking whether the mother is pregnant but did we want to ask whether each adult is pregnant in the household - the latter option gets complicated because then we would need to ask which child in the household is theirs. If we do the former, just need to add the food cost estimate for pregnant individuals. ALSO - a pregnant applicant who doesn't meet income eligibility guidelines can be considered eligible if they would be eligible should they increase the household size to include the number of fetuses in utero: "Income eligibility of pregnant women.  A pregnant woman who is ineligible for participation in the program because she does not meet income guidelines shall be considered to have satisfied the income guidelines if the guidelines would be met by increasing the number of individuals in her family by the number of embryos or fetuses in utero. The same increased family size may also be used for any of the pregnant woman's categorically eligible family members. The State agency shall allow applicants to waive this increase in family size." 
	
	#CTC expansions under ARPA are not counted as income for purposes of determining eligibility for WIC.https://www.fns.usda.gov/wic/income-exclusions-under-arpa. 
	
	#ITEMS TO DISCUSS OR ADD LATER:
	#FOSTER CHILDREN: The Hunger free kids act of 2010 made foster children categorically eligible for WIC benefits if they are under age 5. Older foster children who are pregnant, postpartum, or breastfeeding are also eligible, but they will not be included in the FRS at this time because that would involve additional questions about the pregnancy status of each child in the hypothetical household. https://wic.fns.usda.gov/wps/pages/preScreenTool.xhtml. The child nutrition act of 1966 indicates that states must submit a plan each fiscal year to obtain wic funds, including "plan to provide program benefits under this section to unserved infants and children under the care of foster parents, protective services, or child welfare authorities, including infants exposed to drugs perinatally." Also, on the USDA prescreening tool for WIC eligibility, it says, "Please contact your WIC local agency for additional information regarding foster children and household size." From this, it appears that states and/or WIC local agency have their own rules when it comes to determining household size for assessing eligibility and WIC benefits for foster children. This is only an issue when there is both foster and non-foster children in the household. For now, programming in that a household with foster children is categorically eligible to receive WIC. #States may exclude payments to foster parents/grandparents as countable income in assessing income eligibility: https://www.ecfr.gov/current/title-7/subtitle-B/chapter-II/subchapter-A/part-246/subpart-C/section-246.7#p-246.7(d), but I haven't been able to find NJ rules re how foster payments are counted for WIC. We also haven't been able to find a schedule for what foster payments might be. 
	
	#TREATMENT OF TDI/FLI BENEFITS: these benefits may be treated the same at UI benefits. code incorporates this, but is hashed out for now until these outputs are defined/calculated. "Benefits based on service in employment defined in subparagraphs (B) and (C) of R.S.43:21-19 (i)(1) shall be payable in the same amount and on the terms and subject to the same conditions as benefits payable on the basis of other service subject to the "unemployment compensation law"; except that, notwithstanding any other provisions of the "unemployment compensation law"" - https://www.myleavebenefits.nj.gov/labor/myleavebenefits/assets/pdfs/Pamphlet_version_P.L.2019_c.37.pdf 
	
	#INDIVIDUALS CONVICTED OF A FELONY AND/OR FORMERLY INCARCERATED INDIVIDUALS: so there are wic programs that serve incarcerated women and their children. There appears to be no mention of different treatment for individuals who have been formerly incarcerated and/or convicted of a criminal offense/felony in the various statutes/guidance documents.  We are not including people who commit fraud/abuse in public benefit programs. For now, we are assuming that anyone, regardless of criminal background, can apply for WIC. need to double check this.
	
	# Determine eligibility for each family members
	
	# For the mother, we first determine eligibility and then estimate WIC benefit based on the “approximate cost benefit” of the WIC food packages at https://doh.dc.gov/page/sample-food-packages. When we did this for DC in 2017, the numbers were much higher than the average monthly benefit per person calculations by US FNS at https://www.fns.usda.gov/pd/wic-program. Why was unclear -- presumably include cost savings based on competitive bidding by DC -- but the new way we're doing this is more exact:
	#
	# 1: Check for WIC flag
	#
	# WIC
	if ($in->{'wic'} == 0) {
		$wic_recd = 0;
	} else {
		# Determine countable income for determining WIC eligibility. Per https://www.fns.usda.gov/sites/default/files/2013-3-IncomeEligibilityGuidance.pdf.

		$wic_income  = $out->{'earnings'} + $out->{'ssi_recd'}+ $out->{'interest'}+ $out->{'tanf_recd'}+$out->{'child_support_recd'} + $out->{'ui_recd'} + $out->{'gift_income'} + $in->{'selfemployed_netprofit_total'} + $out->{'fli_plus_tdi_recd'} + $in->{'spousal_support_ncd'}; #Revised to include gift income (set to zero in parent_earnings code), and self-employed net profit is defined in the frs.pm code (as 0 for now). Revised to include tdi/fli income as well (it is treated like ui income). 10/18/21 - need to check whether pandemic unemplyoment assistance is counted for wic income. 
		
		#LOOK AT ME - foster care - we assume that foster care payments are not used to assess eligibility for other members of the household. We haven't been able to find NJ-specific rules about how foster care payments are counted. 
			
		#Note about Medicaid and disability, for comparison with previos years: The way that the FRS incoprporated disabiltiy intho  the Medicaid code earlier, we had a single variable ($hlth_cov_parent) for Medicaid coverage of both parents for a family size of 2. This meant that for parents with disabilities, we had to create a new category of hlth_cov_parent called "Medicaid and private" for when one parent got Medicaid through SSI and another parent did not. We also did not distinguish ssi_recd between the two parents. So for WIC purposes, when hlth_cov_parent equaled "Medicaid and private", it was important to figure out if the parent being tested here was on the Medicaid side of that equation (meaning they were eligible to receive WIC) and which one was on private (marketplace or employer) insurance, in which case they were not categorically eligible for WIC. The approach of using hlth_cov_parent like that became increasingly problematic the more family characterisics we built into the tool, so we eventually (SH thinks for the NH 2021 code) split out hlth_cov_parent so that there's an output for Medicaid coverage for each parent ($hlth_cov_parent.$j). This makes codes like this much easier to comprehend.

		#The use of parent-specific hlth_cov_parent does not, however, resolve the issue of which parent we're talking about here. Because we do not ask specifically who the mother of the child is in the input questions, let's continue (for now) the practice we used in the below commented-out code, of assuming parent 1 is the mother.  

		# if (($in->{'child1_age'}==0 || $in->{'child2_age'}==0 || $in->{'child3_age'}==0 || $in->{'child4_age'}==0 || $in->{'child5_age'}==0 ) && ($wic_income / $in->{'fpl'} <= $wic_inc_limit || $out->{'hlth_cov_parent'} eq 'Medicaid' || ($out->{'hlth_cov_parent'} eq 'Medicaid and private' && ($in->{'parent1_age'}==18 || $in->{'disability_parent1'} == 1))  || $out->{'fsp_recd'} > 0 || $out->{'tanf_recd'} > 0))  { 
			

		#1 . Mothers of infants:
		for(my $i=1; $i<=5; $i++) {
			if($in->{'child' . $i . '_age'} == 0) {
				#It seems safe to assume that if the household is receiving WIC, one and exactly one individual in the household will qualify for WIC by merit of being the mother of infant(s) in the household.  
				if ($wic_income / $in->{'fpl'} <= $wic_inc_limit || $out->{'hlth_cov_parent1'} eq 'Medicaid' || $out->{'fsp_recd'} > 0 || $out->{'tanf_recd'} > 0 || $in->{'child'.$i.'_foster_status'} >= 1) { #This seems to match federal regulations for income, as captured in regulations for other states as well.
					if ($in->{'breastfeeding'}==1 && $in->{'child'.$i.'_foster_status'} == 0) { #Making it so that if an infant is a foster child and the user accidentally selects yes for breastfeeding we still calculate the not breastfeeding amount. Later consideration: whether we need to have a minimum age for foster children.  
						$wic_recd += $wic_breastfeeding * 12;
					} else {
						# Non-breastfeeding mothers are only eligible to receive up to 6 months of WIC.
						$wic_recd += $wic_notbreastfeeding  * 6;
					}
				}
			}
		}

		# 2: Determine eligibility and benefit for children.
		
		for(my $i=1; $i<=5; $i++) {
			if($in->{'child' . $i . '_age'} != -1 && $in->{'child' . $i . '_age'} < 5) {
				if ($wic_income / $in->{'fpl'} <= $wic_inc_limit || $out->{'fsp_recd'} > 0 || $out->{'tanf_recd'} > 0 || $out->{'hlth_cov_child'. $i } eq 'Medicaid' || ($out->{'wic_elig_nslp'} == 1 && ${'child' . $i . '_lunch_red'} > 0)  || $in->{'child'.$i.'_foster_status'} >= 1) { 
					#Note regarding CHIP: in previous codes, we had conferred categorical eligibility for WIC (called "adjunctive" eligibility in the WIC program) for children who had "Medicaid/CHIP' coverage, a short cut that simplified the health codes in that it did not require distinguishing between when children were enrolled in Medicaid coverage and when they were enrollled in CHIP coverage. However, if children are not eligible for Medicaid coverage but are covered (and presumably enrolled) in CHIP coverage, they are not adjunctively eligible for WIC. So we have removed that designation, and will be adjusting the health codes (as we do in the MTRC tool) to distinguish whether a child is covered through Medicaid, a CHIP program, or neither. See https://www.fns.usda.gov/wic/impact-chip-wic-adjunct-income-eligibility for more about this policy.
					#Additional note: This is one reason why states may want to opt to join their CHIP coverage with Medicaid -- it expands coverage under WIC.
					
					#Additional note reqarding school lunch: Some states (such as DC and VA) have published policies that confer adjunctive eligibiltiy to WIC beneifts among children receiveing free or reduced price meals. This does not appear to be the case in NJ.
					
					if ($in->{'child' . $i . '_age'} ==0) {
						if ($in->{'breastfeeding'}==1 && $in->{'child'.$i.'_foster_status'} == 0) { #SS 10.18.21 making it so that if an infant is a foster child and the user accidentally selects yes for breastfeeding we still calculate the not breastfeeding amount. See above.
							$wic_recd = $wic_recd + $wic_breastfedinfants * 6; 
						} else {
							$wic_recd = $wic_recd + $wic_formulafedinfants * 12;
						}
					} elsif ($in->{'child' . $i . '_age'} == 1) {
							$wic_recd = $wic_recd + $wic_1yochild * 12;
					} else {
						$wic_recd = $wic_recd + $wic_2to4yochild * 12;
					}
				}
			}
		}
		# Adjust for inflation since 2014.
		$wic_recd = &round($wic_recd * $foodathomecpi / $foodathomecpi2018);
	}
	
	#CHECK FOR WIC STATE POLICY OPTION TO DENY BENEFITS TO UNQUALIFIED IMMIGRANTS
	if ($out->{'wic_denial_unqualified_immigrants'} == 1) { #There is a state policy option to deny WIC benefits to unqualified immigrants. Federal law allows states to exclude immigrants from WIC participation based on the same immigrant groupings excluded from TANF and SNAP participation, but as of October 2021 no state has opted to exclude any immigrant populations from receiving WIC benefits or participating in WIC Programs. See https://www.ecfr.gov/current/title-7/subtitle-B/chapter-II/subchapter-A/part-246#subpart-C,  https://crsreports.congress.gov/product/pdf/R/R44115, https://www.fns.usda.gov/wic/immigration-participation, and https://www.nilc.org/issues/economic-support/overview-immeligfedprograms/#_ftnref21.  
		if ($in->{'unqualified_immigrant_total_count'} > 0) { #This may need to be adjusted if a state decides to restrict households with only unqualified immigrant adults versus children, but for now, we are interpreting this to be a restriction of wic benefits if any household member is an unqualified immigrant.
			$wic_recd = 0;
		}
	}
	


	#END WIC 

	
	# outputs
	foreach my $name (qw(wic_recd)) {
		$out->{$name} = ${$name};
		$self->saveDebugValues("wic", $name, ${$name});
	}
	foreach my $variable (qw(wic_income wic_recd)) { 
		$self->saveDebugValues("wic", $variable, $$variable, 1);
	}

	return(0);
}

1;
