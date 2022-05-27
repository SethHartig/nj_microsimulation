#=============================================================================#
#  Lifeline (telephone subsidies) Module -- 2019 and 2020 (with minimal change from 2017)
#=============================================================================#
#
# Inputs referenced in this module:
#
#   FROM BASE
#       lifeline            # This is a flag representing whether users select “lifeline” as a potential benefit to receive on the “public benefits” checklist.
#       earnings
#       fpl
#		covid_broadband_benefit			# new flag representing whether users select “emergency broadband benefit” as a potential benefit to receive on the “public benefits” checklist. "The Emergency Broadband Benefit is an emergency program developed in response to the COVID-19 pandemic. The program will end once the program funds are exhausted, or six months after the Department of Health and Human Services declares an end to the pandemic, whichever comes first." fcc.gov/consumer-faq-emergency-broadband-benefit 
#
# 	FROM INTEREST
#		interest
#
#   FROM HEALTH
#       hlth_cov_parent
#       hlth_cov_child#
#       medically_needy        
#
#   FROM FOOD STAMPS
#       fsp_recd
#
# FROM SSI
#   ssi_recd
#
#   FROM SECTION 8
#       housing_recd
#
#   FROM TANF
#       tanf_recd
#
#=============================================================================#
# The 2016 revisions to Lifeline rules, effective December 1, 2016, are described at https://www.fcc.gov/general/lifeline-program-low-income-consumers. These changes include excluding eligibility for TANF, LIHEAP and NSLP from categorical eligibility for Lifeline. The FCC pages at https://www.fcc.gov/consumers/guides/lifeline-support-affordable-communications are also helpful, but includes antiquated rules without the adjustments made in 2016.
# This site also seems helpful: https://nationalverifier.service-now.com/lifeline. It's currently the subject of a soft launch of a national eligibility verifier that also connects households to eligible tellecommunication carriers in their state.

sub lifeline
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};

    # outputs created
	our $lifeline_cost = 0; #In NJ, at least Assurance Wireless offers free talk and text as well as free data through Emergency Broadband. https://www.assurancewireless.com/lifeline-services/states/new-jersey-lifeline-free-government-phone-service #Also, this is true in KS and so far every state we've done since 2020; Assurance's reach seemns broad.  We are tentatively making this a federal code.
    our $lifeline_subsidy = 9.25;       #   The monthly subsidy for those participating in the Lifeline program
    our $lifeline_inc_limit = 1.35;     #   The income eligibility limit as a % of federal poverty guideline
    our $lifeline_recd = 0;
    # outputs calculated in macro
    our $lifeline_recd = 0;             #   The federal subsidy applied to a family’s phone bill via participation in the Lifeline program
	our $ebb_benefit_m = 50;			#monthly benefit for those who qualify for the emergency broadband benefit plan (EBB) outside of lifeline eligibility.
	our $ebb_recd = 0;		#output for how much is received under ebb program annually. The Emergency Broadband Benefit is an emergency program developed in response to the COVID-19 pandemic. The program will end once the program funds are exhausted, or six months after the Department of Health and Human Services declares an end to the pandemic, whichever comes first.
	
    our $lifeline = $in->{'lifeline'};

    # Start debug variables:
	# End debug variables
    #
    # 1: Check for Lifeline flag
    #
    if ($in->{'lifeline'} == 0)  {
        $lifeline_recd = 0;
    } else {
        #
        # 2: Check for Determine subsidy if eligible
        #
        # Eligibility criteria based on requirements listed in Federal Register / Vol. 77, No. 42 / Friday, March 2, 2012, § 54.409, with adjustments based on changes as part of the Lifeline modernization plan enacted in 2016 (see https://www.fcc.gov/general/lifeline-program-low-income-consumers). Note a change for 2019 is that we have reinserted categorical eligibility for medically needy programs, such as Florida had in 2015; this is technically Medicaid.
		if (($out->{'earnings'} + $out->{'interest'} + $out->{'ui_recd'} + $out->{'child_support_recd'} + $in->{'spousal_support_ncp'})/ $in->{'fpl'} <= $lifeline_inc_limit || $out->{'hlth_cov_parent'} eq 'Medicaid' || $out->{'hlth_cov_parent'} eq 'Medicaid and private' || $out->{'hlth_cov_child1'} eq 'Medicaid' || $out->{'hlth_cov_child2'} eq 'Medicaid' || $out->{'hlth_cov_child3'} eq 'Medicaid'   || $out->{'hlth_cov_child4'} eq 'Medicaid' || $out->{'hlth_cov_child5'} eq 'Medicaid' || $out->{'fsp_recd'} > 0 || $out->{'housing_recd'} > 0 || $out->{'ssi_recd'} > 0 || $out->{'medically_needy'} == 1 ) { #SS 10.12.21  - added interest to the countable income for lifeline. See https://www.ecfr.gov/current/title-47/chapter-I/subchapter-B/part-54/subpart-E/section-54.400#p-54.400(f) and https://www.govinfo.gov/content/pkg/USCODE-2019-title26/pdf/USCODE-2019-title26-subtitleA-chap1-subchapB-partI-sec61.pdf. 
		#(1) foster care payments - not counted as income because it is explicitly excluded from income in this list: https://www.law.cornell.edu/uscode/text/26/subtitle-A/chapter-1/subchapter-B/part-III. 
		#(2) UI benefits, spousal support, and child support are counted as income because the govinfo.gov source says to include any income from any source

			#children with disabilities - there appears to be no mention of SSI from either parents or kids in terms of what is counted for income test. 
			#IMMIGRANTS: there appear to be no mention of immigrants in the lifeline program, and it not specifically named as a program that only qualified aliens can receive in clarifications about the PRWORA. From the below NILC article it seems that PRWORA didn't specify which programs were covered, so that goes to each federal benefit-granting agency to make decisions about whether the qualified immigrant rule applies to their programs. While HHS issued guidance on which of their programs are under the qualified immigrant rule, FCC, who runs the lifeline program, has not appeared to issue such guidance.  Therefore, no immigrant check is written into the code.
				#NILC article: https://www.nilc.org/issues/economic-support/overview-immeligfedprograms/
				#HHS PRWORA guidance on programs for only qualified aliens: https://www.govinfo.gov/content/pkg/FR-1998-08-04/pdf/98-20491.pdf
			#NATIVE POPULATIONS: There are some additional lifeline/emergency broadband benefits that go to people living on tribal lands, regardless of whether they are tribal members. BUT there are no tribal lands in NJ eligible for this benefit. See map of eligible tribal lands here: https://getemergencybroadband.org/_res/documents/fcc_tribal_lands_map.pdf

			$lifeline_recd = $lifeline_subsidy * 12;
		} else {
			$lifeline_recd = 0;
		} 

	}
	if ($in->{'covid_broadband_benefit'} == 1)  {
		if (($out->{'earnings'} + $out->{'interest'}) / $in->{'fpl'} <= $lifeline_inc_limit || $out->{'hlth_cov_parent'} eq 'Medicaid' || $out->{'hlth_cov_parent'} eq 'Medicaid and private' || $out->{'hlth_cov_child1'} eq 'Medicaid' || $out->{'hlth_cov_child2'} eq 'Medicaid' || $out->{'hlth_cov_child3'} eq 'Medicaid'   || $out->{'hlth_cov_child4'} eq 'Medicaid' || $out->{'hlth_cov_child5'} eq 'Medicaid' || $out->{'fsp_recd'} > 0 || $out->{'housing_recd'} > 0 || $out->{'ssi_recd'} > 0 || $out->{'medically_needy'} == 1 || $out->{'child_foodcost_red_total'} > 0 || $lifeline_recd > 0) {
			$ebb_recd = ($ebb_benefit_m *12); # We are not including the EBB one time benefit of up to $100 to purchase a tablet or laptop. Also, there are three additional ways to qualify for EBB, but we are not including those at this time. These pathways are (1) receipt of federal pell grant during the current award year, and (2) experience of "a substantial loss of income due to job loss or furlough since February 29, 2020 and the household had a total income in 2020 at or below $99,000 for single filers and $198,000 for joint filers;" and (3) "Meets the eligibility criteria for a participating provider's existing low-income or COVID-19 program." https://www.fcc.gov/broadbandbenefit. https://www.congress.gov/bill/116th-congress/house-bill/133/text https://www.law.cornell.edu/cfr/text/47/54.409 
		}		
	} 
  # outputs
    foreach my $name (qw(lifeline lifeline_subsidy lifeline_inc_limit lifeline_recd lifeline_cost ebb_recd)) {
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;