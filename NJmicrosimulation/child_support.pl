#=============================================================================#
#  Child Support – 2021 NJ adapted from 2020 KY
#=============================================================================#
# ASSUMTIONS:
# 1. We assume the custodial parent is paying child care expenses for all of their children under their support order and the ncps don't pay any of these costs.
# 2. We assume the custodial parent is responsible for paying the health insurance premiums and other medical costs for all their children under their child support order. 
# 3. We assume that all parents in the household being modeled have full custody of the children living in this household and the child does not stay with the NCP for two or more overnights/week (NJ 2021). 
# 4. We assume that the child support order will incorporate unsubdsidized costs of child care, not subsidized child care - KY and NCP
# 5. We assume that in a two-parent household, the court will not include the second parent's income in the child support order. (This is decided on a case-by-case basis in KY, and in NJ, the income from other household members are not counted if they are not legally responsible for the child subject to the support order.)
# 6. We assume that, in order to calculate the imputed amt of support paid by the custodial parent to children in the household older than the children in the hh under the cs order, we use the custodial parent (parent 1)'s income only. - this applies to KY only.
# 7. For NJ 2021 - we assume the ncp and cp doesn't pay child support or spousal support to any other family - for now. We may want to add more inputs - discuss 
# 8. For NJ 2021 - for now, we are not counting "derivative benefits" - benefits the child recieves as a result of parent disability or retirement or benefits related to military service or retirement. When we incorporate SSDI or if we model military families, this may be something we need to incorporate. (see https://www.njcourts.gov/attorneys/assets/rules/app9a.pdf).
#9. NJ 2021 - we will not impute income, in other words, we assume that if a parent is not working, it is with reasonable cause. 
#10. NJ 2021 - we assume that no one pays mandatory retirement contributions.
# INPUTS
#	FROM BASE:					(cs = child support; ncp = non-custodial parent; cp = custodial parent)
# 		cs_flag					#Whether the family receive child support from a non-custodial parent
# 		child#support  		
# 		child#_age				
# 		ncparent_earnings		#User-entered annual earnings of non-custodial parent. Wording for the input could be worded as follows: "Please enter the amount of the noncustodial parent's income counted for the child support order. This includes income after taxes, child tax credits, unemployment income, interest, and property tax credits, among others. Excluded from countable income are federal and state EITC, the NJ homestead rebate, SSI benefits, among others." QUESTION FOR SETH - DO WE WANT TO MAKE THIS LIST OF COUNTED AND EXCLUDED INCOME EXHAUSTIVE? 
#		child_number
#		child#_hlth_costs_oop_m
#		family_size
#		spousal_sup_ncp			#amount actually paid for court ordered 
								#maintenance for prior spouse(s) plus the amount of maintenance ordered in the current proceeding. In NJ 2021 - this amount reflects tax-deductible alimony paid for current and/or past relationships. NEW INPUT FOR NJ 2021.
#		child_support_ext_cp	#child support paid for prior born 
								#children - both court-ordered and not court ordered - NOT NEEDED for NJ 2021		
#		child_support_ext_ncp	#child support paid for prior born 
								#children - both court-ordered and not court ordered. This should also include child support amount imputed for prior born children residing with the parent (ncp) as well (3 different amts subsumed into one) - NOT NEEDED for NJ 2021
#
#	FROM INTEREST:
#		interest
#
#	FROM SSI:
#		parent1ssi_recd			#not needed for NJ 2021 - SSI income not counted
#
#	FROM PARENT EARNINGS:
#		parent1_earnings
#
#	FROM CCDF OR CHILD CARE
#		cc_expenses_child#
#
#	FROM HEALTH
#		hlth_cov_child_all
#		family_cost			#annual amt 
#		parent_cost			#annual amt
#		child#_health_expenses	#combined premium and oop costs from hlth
#
#	FROM STATETAX
#		state_cadc_recd
#		prop_tax_credit_recd
#	FROM CTC
#		ctc_total_recd
#	FROM UI
#		ui_recd
#Sources for NJ 2021 rules:
# https://www.njcourts.gov/attorneys/assets/rules/app9a.pdf 
# inputs that need to be created for UI/TI: spousal_sup_ncp - the amount of alimony or spousal support annually paid by the ncp to the cp.
# although we are modeling dynamic changes to the child support amount due to changes in the cp's income, generally, the child support order does not change unless there is "good cause" - “The guidelines may be modified or disregarded by the court only where  good cause is shown. Good cause shall consist of a) the considerations set forth in Appendix IX-A, or the presence of other relevant factors which may make the guidelines inapplicable or subject to modification, and b) the fact that an injustice would result from the application of the guidelines. In all cases, the determination of good cause shall be within the sound discretion of the court.” - Rule 5:6A- Child support guidelines, part V, Chapter II, specific civil actions. (doc titled as r5-6a in the resources folder for NJ).
#==============================================================================
sub child_support {
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};
	
	#OUTPUTS CREATED
	our $child_support_paid = 0;	#annual amount of child support paid by ncp to cp.
	our $child_support_paid_m = 0;	#monthly amount of child support paid by ncp to cp.
#	our $imputed_cs_amt = 0;		#amount of imputed cs obligation for children in hh older than the children under the cs order deducted from cp's income	
#	our $imputed_cs_oblig = 0;		#amt of child support obligation for imputed support for older children not subject to cs order
	our $ext_med_expenses = 0;		#calculation of annual extraordinary medical expenses
	our $ext_med_expenses_m = 0;		#monthly extraordinary medical expenses
	our $cs_obligation_com = 0;		#combined child support obligation, monthly
	our $cs_obligation_com_w = 0;		#combined child support obligation, weekly
	our $total_child_support_oblig_m = 0 ; 	#total monthly child support obligation, inclusive of child care and medical expenses
	our $cp_cs_obligation = 0;
	our $ncp_cs_obligation = 0;

	our $cs_cc_expenses_child1 = 0;		#annual child care costs for child 1
	our $cs_cc_expenses_child2 = 0;		#annual child care costs for child 2
	our $cs_cc_expenses_child3 = 0;		#annual child care costs for child 3
	our $cs_cc_expenses_child4 = 0;		#annual child care costs for child 4
	our $cs_cc_expenses_child5 = 0;		#annual child care costs for child 5	
	our $cs_cc_expenses_total = 0 ; 	#annual amt of child care costs for all children under the support order.
	our $cs_cc_expenses_total_m = 0;	#monthly amt of child care costs for all children (unsubsidized for now)
	#removed variables from KY 2020 related to imputation because not relevant for NJ 2021.

	#CALCULATED IN MACRO:
	our $cp_gross_income = 0;			#gross income of custodial parent
	our $ncp_gross_income = 0;		#gross income of non-custodial parent
	our $self_support_reserve_poverty_pct = 1.05;	#new for NJ 2021 - NJ's self support reserve is 105% of U.S. poverty guideline for one person. As of Jan 13, 2021, self support reserve is $260/week.
	our $fpl_forone = 12880;		#The 2021 federal poverty guideline for a family size of 1 to calculate  self-support reserve. Updated every two years. This is equal to the amount of the modified self-support reserve.https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/prior-hhs-poverty-guidelines-federal-register-references/2021-poverty-guidelines#guidelines.  
	our $cs_child_number = 0;			#number of children for whom the parents share a joint legal responsibility 
	our $perchild_premiumcost = 0;		#per child premium cost 	
	our $total_cs_premiumcost = 0;		#total amt of premiums for every child receiving support under the child support order
	our $total_cs_premiumcost_m = 0;	#total monthly cost of health insurance premiums for all children under the support order
	our $cp_adj_income = 0;			#net annual income of custodial parent for determining amount of child support to be paid 
	our $cp_adj_income_m = 0;			#net monthly income of custodial parent
	our $ncp_adj_income = 0;			#net annual income of non-custodial parent for determining amount of child support to be paid
	our $ncp_adj_income_m = 0;		#net monthly income of ncp
	our $combined_adj_income = 0; 		#combined annual adjusted incomes of both custodial and non custodial #parents
	our $combined_adj_income_m = 0;		#combined monthly adjusted incomes of both custodial and non custodial #parents	
	our $combined_adj_income_w = 0;		#combined weekly adjusted incomes of both parents. 
	our $cp_income_ratio = 0;			#proportion of the custodial parent’s income to the parents’ combined income
	our $ncp_income_ratio = 0;			#proportion of the non-custodial parent’s income to the parents’ combined income
	our $cp_gross_income_adj = 0;		#adjusted gross income if cp or ncp income ratio = 1
	our $ncp_gross_income_adj = 0;	#adjusted gross income if cp or ncp income ratio = 1
	our $child_support_min = 21.5;		#monthly min for child support in NJ 2021: "For combined net incomes that are less than $180 per week, the court shall establish a child support award based on the obligor’s net income and living expenses and the needs of the child. In these circumstances, the support award should be between $5.00 per week and the support amount at $180 combined net weekly income as shown on this schedule." not sure what the difference is between support award versus support amount, but going with $5/week, which is multiplied by 4.3 to obtain the monthly amount - $21.50. - see appendix IX-B and IX-C.
	our $cp_gross_income_w = 0;
	our $cs_child_health_expenses_total = 0;
	
	# our $child_support_paid_pretanf = 0; #See note below, commenting out this and other tanflock-related concerns below for now.
	# our $child_support_paid_m_pretanf = 0;			

	if ($in-> {'cs_flag'} == 1) {
		if ($in-> {'child_number'} == 0)  {
			$child_support_paid = 0;
			$child_support_paid_m = 0;
			$cs_child_number = 0;
			#end 
		} else {
			$cs_child_number = $in->{'child1support'} + $in->{'child2support'} + $in->{'child3support'} + $in->{'child4support'} + $in->{'child5support'}; 
			if 	($cs_child_number == 0) {
				$child_support_paid = 0;
				$child_support_paid_m = 0;
				#end
			} else {
				#if ($out->{'tanflock'} == 1 && $child_support_paid_m > $tanf_recd_m) { #Further explanation is provided at the end of this code for why this might a consideration down the line but for now is not.  
				#	$child_support_paid_pretanf = $out->{'child_support_paid'};
				#	$child_support_paid_m_pretanf = $out->{'child_support_paid_m'};			
				#}
				
				#CALCULATE gross income for cp and ncp.
				#In NJ, they count income after taxes plus some tax credits. There is a tax withholding table that we may be able to refer to, but might be better to do the loops. "This table accounts for Medicare tax and "Additional Medicare Tax."  The Medicare tax withholding rate for wage earners is 0.0145 for all incomes. In addition to the 1.45% Medicare tax, there is an Additional Medicare Tax of  0.9% applied to wages in excess of $200,000. The 0.9% Additional Medicare Tax also applies to self-employed persons (there is no employer share of Additional Medicare Tax)." Appendix IX-H
				#There is a separate formula to estimate income after taxes for self-employed people, but I don't think we are incorporating that into the FRS at this time. In case we do, the rules are as follows: "To estimate the combined tax for self-employed persons earning no more than $2,746 per week ($142,800 per year), multiply gross taxable weekly income by 0.0765 and add the result to the table amount.  For persons earning above $2,746 per week, multiply gross taxable weekly income by .0145 (Medicare), add $170 (Social Security max), and add the sum to the table amount.  IMPORTANT: Although this formula will provide an estimate of self-employment income taxes, a careful review of the most recent personal and business tax returns will provide a more accurate tax figure for self-employed persons. Also, see IRS Pubs 505 and SE and App. IX-B (Determining Income)." - Appendix IX-H

				$ncp_gross_income  = $in->{'ncparent_earnings'};  #we assume that all income from counted sources (ssi, interest, tax credits, etc) are included in the ncparent_earnings value.
				# The below formulation makes the assumption that in cases of child support, parent 1 is the custodial parent, and that parent 2 does not have any children who noncustodial parents are helping to support. We could incorporate separate children of parent 2 into this model if requested, but while that would not be a very complicated operation, it would require more questions on the user interface to delineate between parent 1’s children and parent 2’s children.  

				$cp_gross_income  = pos_sub($out->{'parent1_earnings'}, $out->{'tax_before_credits'}) + ($out->{'interest'}/$in->{'family_structure'}) + $out->{'ui_recd'} + $out->{'prop_tax_credit_recd'} + $out->{'state_cadc_recd'} + $out->{'ctc_total_recd'} + $out->{'fli_plus_tdi_recd'};	#For NJ 2021, they subtract the income tax from the gross taxable income. They include UI_recd, prop_tax_credit_recd, and state_cadc_recd. For LATER: need to add SSDI and self-employment income if we include it later on. Excluded income are income from federal/state EITC and homestead rebate, means-tested income (TANF, rent subsidies, food stamps, SSI, income from other household members). Note: we divide interest by family structure to allocate interest equally among the spousal unit if married. (This makes use of the  family structure variable being in effect the number of parents in the household.) LOOK AT ME: MAY NEED TO CHANGE ORDER OF EXECUTION OF MODULES SO CHILD SUPPORT IS CALCULATED AFTER STATETAX, FEDTAX, CHILD CARE AND HEALTH. DOUBLE CHECK THIS. LOOK AT ME.  See https://www.njcourts.gov/attorneys/assets/rules/app9b.pdf for guidance. 

				# Removed formulas related to IMPUTED CHILD NUMBER CALCS FOR NJ 2021. Does not appear to be necessary for NJ (child age does not matter).				
				#SS 5/21 moved calculations regarding the adjusted income to below the calculations for the deduction of imputed child support amt for prior-born children residing with the custodial parent. 
							# SS 5/21 - deleted the calcs for cp and ncp income ratios here because they were commented out anyway for KY 2020. 
				
				#ESTIMATE HEALTH CARE PREMIUMS: In NJ, the parents' net incomes and their income ratios, and their base child support obligation is calculated prior to adding child care and health expenses. We assume the cp pays all medical expenses, and the cost of medical expenses is shared by ncp and cp and added to child support obligation. 
				
				#ESTIMATE MONTHLY CHILD CARE AND HEALTH EXPENSES for each child under the child support order. For KY, they requested to keep at unsubsidized costs, but have refined this for child care to use subsidized child care costs for now, for  NJ 2021. They seem to be looking for the actual child care costs, and child support is also somewhat backward-looking so it's okay if this is a little off in terms of ccdf copays. This module should be run after child care expenses are calculated.
				for(my $i=1; $i<=5; $i++) {
					if ($in->{'child'.$i.'_age'} != -1) {
						if ($in->{'child'.$i.'support'} == 1){ 	
							$cs_cc_expenses_total += $out->{'cc_expenses_child'.$i}; #cc_expenses_child# is an annual amount.
							$cs_child_health_expenses_total += $out->{'child'.$i.'_health_expenses'}; #this is an annual amount from hlth module.
						}
					}
				}
				$cs_cc_expenses_total_m = $cs_cc_expenses_total/12;
#				
				#CALCULATE extraordinary health expenses/cash medical support after accounting for ncp's share of cost of extraodinary med expenses. 
				$ext_med_expenses = &pos_sub($cs_child_hlth_expenses_total, 250 * $cs_child_number); #expenses in excess of $250/child/year for each child under the order. We are assuming for now that the custodial parent pays all medical expenses. Changed from $100 to $250 to adjust for NJ 2021 policy. #LOOK AT ME: It's not quite clear from the child support formula guidelines whethe rthis is calculated indivdidually, per child, or in total? As in, if one child has $400 in medical expenses per year and another has $200, is this expense calculation equal to pos_sub(400 + 200, 250*2) = pos_sub(600, 500) = 100, or if it's pos_sub(400, 250) + pos_sub(200, 250) = 150 + 0 = 150? If the latter, we should just calculate this per chid, in the for-loop above. Ask expert if time permits, but okay to have this simplifying assupmtion for now.
				
				$ext_med_expenses_m = $ext_med_expenses/12; #SS 5/21 changed this variable to reflect monthly costs for all extraordinary medical expenses for all children under the child support order.
					
				#DETERMINE the ncp and cp's adjusted incomes. 
				$cp_adj_income = $cp_gross_income + $in->{'spousal_sup_ncp'}; #In NJ 2021, support to more than one family is adjusted at the court's discretion. Only alimony/spousal support paid to the current family (in this case, the cp and the ncp) is taken into account. "When applying the guidelines, the amount of alimony, maintenance or spousal support shall be deducted from the paying parent's income (after adjusting for tax benefits, if any) and added to the recipient's income to determine each parent's gross income. This transfer method reflects the availability of income to each parent for the purpose of paying child support." - guidelines Appendix IX-A, section 19. We will change the spousal_sup_ncp input to reflect only the amount annually paid by the ncp to the cp. 
				$ncp_adj_income = &pos_sub($ncp_gross_income, $in->{'spousal_sup_ncp'}); 
				#if the custodial parent has 100 percent of the combined monthly adj parental gross income, it provides a reduction in gross income for the entire amt of health insurance premiums incurred and paid for the child(ren) 

				#DETERMINE each parent's share of income

				$combined_adj_income = $cp_adj_income + $ncp_adj_income; 
				$combined_adj_income_w = round($combined_adj_income/52); #NJ calculates child support in weekly amounts. All dollars and percentages should be rounded to whole numbers.for example, $340.35 should be rounded down to $340.  LOOK AT ME - NEED TO ENSURE THIS FORMULA IS CORRECT (NOT SURE ABOUT 'ROUND' FUNCTION).
				if ($combined_adj_income_w < 180) {
					$child_support_paid_m = $child_support_min; #NJ 2021: "For combined net incomes that are less than $180 per week, the court shall establish a child support award based on the obligor’s net income and living expenses and the needs of the child. In these circumstances, the support award should be between $5.00 per week and the support amount at $180 combined net weekly income as shown on this schedule." not sure what the difference is between support award versus support amount. 
				} else {				
					$ncp_income_ratio = $ncp_adj_income/$combined_adj_income;	
					$cp_income_ratio = $cp_adj_income/$combined_adj_income; 
					$cp_adj_income_m = $cp_adj_income/12;
					$ncp_adj_income_m = $ncp_adj_income/12;
					$combined_adj_income_m = $combined_adj_income/12;
				}	
				#NJ 2021: "The parents' combined net income and the number of children for whom support is being determined are used to obtain the basic child support amount from the Appendix IX-F schedules. Appendix IX-F combined net incomes are provided in $10 increments. For incomes that fall between income increments, go to the next higher income increment if the amount is $5.00 or more (e.g., if the combined income is $446, use the award for $450 combined income; if it is $444, use the award for $440)." - Appendix IX-B.

				if ($cs_child_number == 1) {					
					for ($combined_adj_income_w) {				
						$cs_obligation_com_w = 			
						($_ < 	185	) ?  	50	:
						($_ < 	195	) ?  	53	:
						($_ < 	205	) ?  	56	:
						($_ < 	215	) ?  	59	:
						($_ < 	225	) ?  	62	:
						($_ < 	235	) ?  	65	:
						($_ < 	245	) ?  	68	:
						($_ < 	255	) ?  	71	:
						($_ < 	265	) ?  	74	:
						($_ < 	275	) ?  	77	:
						($_ < 	285	) ?  	80	:
						($_ < 	295	) ?  	82	:
						($_ < 	305	) ?  	85	:
						($_ < 	315	) ?  	88	:
						($_ < 	325	) ?  	91	:
						($_ < 	335	) ?  	94	:
						($_ < 	345	) ?  	96	:
						($_ < 	355	) ?  	99	:
						($_ < 	365	) ?  	102	:
						($_ < 	375	) ?  	104	:
						($_ < 	385	) ?  	107	:
						($_ < 	395	) ?  	110	:
						($_ < 	405	) ?  	112	:
						($_ < 	415	) ?  	115	:
						($_ < 	425	) ?  	117	:
						($_ < 	435	) ?  	120	:
						($_ < 	445	) ?  	122	:
						($_ < 	455	) ?  	125	:
						($_ < 	465	) ?  	127	:
						($_ < 	475	) ?  	130	:
						($_ < 	485	) ?  	132	:
						($_ < 	495	) ?  	135	:
						($_ < 	505	) ?  	137	:
						($_ < 	515	) ?  	139	:
						($_ < 	525	) ?  	142	:
						($_ < 	535	) ?  	144	:
						($_ < 	545	) ?  	146	:
						($_ < 	555	) ?  	149	:
						($_ < 	565	) ?  	151	:
						($_ < 	575	) ?  	153	:
						($_ < 	585	) ?  	155	:
						($_ < 	595	) ?  	158	:
						($_ < 	605	) ?  	160	:
						($_ < 	615	) ?  	162	:
						($_ < 	625	) ?  	164	:
						($_ < 	635	) ?  	166	:
						($_ < 	645	) ?  	168	:
						($_ < 	655	) ?  	170	:
						($_ < 	665	) ?  	172	:
						($_ < 	675	) ?  	174	:
						($_ < 	685	) ?  	177	:
						($_ < 	695	) ?  	179	:
						($_ < 	705	) ?  	181	:
						($_ < 	715	) ?  	182	:
						($_ < 	725	) ?  	184	:
						($_ < 	735	) ?  	186	:
						($_ < 	745	) ?  	188	:
						($_ < 	755	) ?  	190	:
						($_ < 	765	) ?  	192	:
						($_ < 	775	) ?  	194	:
						($_ < 	785	) ?  	196	:
						($_ < 	795	) ?  	198	:
						($_ < 	805	) ?  	199	:
						($_ < 	815	) ?  	201	:
						($_ < 	825	) ?  	203	:
						($_ < 	835	) ?  	205	:
						($_ < 	845	) ?  	207	:
						($_ < 	855	) ?  	208	:
						($_ < 	865	) ?  	210	:
						($_ < 	875	) ?  	212	:
						($_ < 	885	) ?  	213	:
						($_ < 	895	) ?  	215	:
						($_ < 	905	) ?  	217	:
						($_ < 	915	) ?  	218	:
						($_ < 	925	) ?  	220	:
						($_ < 	935	) ?  	222	:
						($_ < 	945	) ?  	223	:
						($_ < 	955	) ?  	225	:
						($_ < 	965	) ?  	226	:
						($_ < 	975	) ?  	228	:
						($_ < 	985	) ?  	230	:
						($_ < 	995	) ?  	231	:
						($_ < 	1005	) ?  	233	:
						($_ < 	1015	) ?  	234	:
						($_ < 	1025	) ?  	236	:
						($_ < 	1035	) ?  	237	:
						($_ < 	1045	) ?  	239	:
						($_ < 	1055	) ?  	240	:
						($_ < 	1065	) ?  	241	:
						($_ < 	1075	) ?  	243	:
						($_ < 	1085	) ?  	244	:
						($_ < 	1095	) ?  	246	:
						($_ < 	1105	) ?  	247	:
						($_ < 	1115	) ?  	248	:
						($_ < 	1125	) ?  	250	:
						($_ < 	1135	) ?  	251	:
						($_ < 	1145	) ?  	252	:
						($_ < 	1155	) ?  	254	:
						($_ < 	1165	) ?  	255	:
						($_ < 	1175	) ?  	256	:
						($_ < 	1185	) ?  	258	:
						($_ < 	1195	) ?  	259	:
						($_ < 	1205	) ?  	260	:
						($_ < 	1215	) ?  	262	:
						($_ < 	1225	) ?  	263	:
						($_ < 	1235	) ?  	264	:
						($_ < 	1245	) ?  	265	:
						($_ < 	1255	) ?  	266	:
						($_ < 	1265	) ?  	268	:
						($_ < 	1275	) ?  	269	:
						($_ < 	1285	) ?  	270	:
						($_ < 	1295	) ?  	271	:
						($_ < 	1305	) ?  	272	:
						($_ < 	1315	) ?  	274	:
						($_ < 	1325	) ?  	275	:
						($_ < 	1335	) ?  	276	:
						($_ < 	1345	) ?  	277	:
						($_ < 	1355	) ?  	278	:
						($_ < 	1365	) ?  	279	:
						($_ < 	1375	) ?  	280	:
						($_ < 	1385	) ?  	281	:
						($_ < 	1395	) ?  	282	:
						($_ < 	1405	) ?  	284	:
						($_ < 	1415	) ?  	285	:
						($_ < 	1425	) ?  	286	:
						($_ < 	1435	) ?  	287	:
						($_ < 	1445	) ?  	288	:
						($_ < 	1455	) ?  	289	:
						($_ < 	1465	) ?  	290	:
						($_ < 	1475	) ?  	291	:
						($_ < 	1485	) ?  	292	:
						($_ < 	1495	) ?  	293	:
						($_ < 	1505	) ?  	294	:
						($_ < 	1515	) ?  	295	:
						($_ < 	1525	) ?  	296	:
						($_ < 	1535	) ?  	297	:
						($_ < 	1545	) ?  	298	:
						($_ < 	1555	) ?  	299	:
						($_ < 	1565	) ?  	300	:
						($_ < 	1575	) ?  	301	:
						($_ < 	1585	) ?  	302	:
						($_ < 	1595	) ?  	303	:
						($_ < 	1605	) ?  	304	:
						($_ < 	1615	) ?  	304	:
						($_ < 	1625	) ?  	305	:
						($_ < 	1635	) ?  	306	:
						($_ < 	1645	) ?  	307	:
						($_ < 	1655	) ?  	308	:
						($_ < 	1665	) ?  	309	:
						($_ < 	1675	) ?  	310	:
						($_ < 	1685	) ?  	311	:
						($_ < 	1695	) ?  	312	:
						($_ < 	1705	) ?  	313	:
						($_ < 	1715	) ?  	314	:
						($_ < 	1725	) ?  	314	:
						($_ < 	1735	) ?  	315	:
						($_ < 	1745	) ?  	316	:
						($_ < 	1755	) ?  	317	:
						($_ < 	1765	) ?  	318	:
						($_ < 	1775	) ?  	319	:
						($_ < 	1785	) ?  	320	:
						($_ < 	1795	) ?  	321	:
						($_ < 	1805	) ?  	321	:
						($_ < 	1815	) ?  	322	:
						($_ < 	1825	) ?  	323	:
						($_ < 	1835	) ?  	324	:
						($_ < 	1845	) ?  	325	:
						($_ < 	1855	) ?  	326	:
						($_ < 	1865	) ?  	327	:
						($_ < 	1875	) ?  	327	:
						($_ < 	1885	) ?  	328	:
						($_ < 	1895	) ?  	329	:
						($_ < 	1905	) ?  	330	:
						($_ < 	1915	) ?  	331	:
						($_ < 	1925	) ?  	332	:
						($_ < 	1935	) ?  	332	:
						($_ < 	1945	) ?  	333	:
						($_ < 	1955	) ?  	334	:
						($_ < 	1965	) ?  	335	:
						($_ < 	1975	) ?  	336	:
						($_ < 	1985	) ?  	337	:
						($_ < 	1995	) ?  	338	:
						($_ < 	2005	) ?  	338	:
						($_ < 	2015	) ?  	339	:
						($_ < 	2025	) ?  	340	:
						($_ < 	2035	) ?  	341	:
						($_ < 	2045	) ?  	342	:
						($_ < 	2055	) ?  	343	:
						($_ < 	2065	) ?  	343	:
						($_ < 	2075	) ?  	344	:
						($_ < 	2085	) ?  	345	:
						($_ < 	2095	) ?  	346	:
						($_ < 	2105	) ?  	347	:
						($_ < 	2115	) ?  	348	:
						($_ < 	2125	) ?  	348	:
						($_ < 	2135	) ?  	349	:
						($_ < 	2145	) ?  	350	:
						($_ < 	2155	) ?  	351	:
						($_ < 	2165	) ?  	352	:
						($_ < 	2175	) ?  	353	:
						($_ < 	2185	) ?  	354	:
						($_ < 	2195	) ?  	354	:
						($_ < 	2205	) ?  	355	:
						($_ < 	2215	) ?  	356	:
						($_ < 	2225	) ?  	357	:
						($_ < 	2235	) ?  	358	:
						($_ < 	2245	) ?  	359	:
						($_ < 	2255	) ?  	360	:
						($_ < 	2265	) ?  	361	:
						($_ < 	2275	) ?  	362	:
						($_ < 	2285	) ?  	362	:
						($_ < 	2295	) ?  	363	:
						($_ < 	2305	) ?  	364	:
						($_ < 	2315	) ?  	365	:
						($_ < 	2325	) ?  	366	:
						($_ < 	2335	) ?  	367	:
						($_ < 	2345	) ?  	368	:
						($_ < 	2355	) ?  	369	:
						($_ < 	2365	) ?  	370	:
						($_ < 	2375	) ?  	371	:
						($_ < 	2385	) ?  	372	:
						($_ < 	2395	) ?  	373	:
						($_ < 	2405	) ?  	374	:
						($_ < 	2415	) ?  	375	:
						($_ < 	2425	) ?  	375	:
						($_ < 	2435	) ?  	376	:
						($_ < 	2445	) ?  	377	:
						($_ < 	2455	) ?  	378	:
						($_ < 	2465	) ?  	379	:
						($_ < 	2475	) ?  	380	:
						($_ < 	2485	) ?  	381	:
						($_ < 	2495	) ?  	382	:
						($_ < 	2505	) ?  	383	:
						($_ < 	2515	) ?  	385	:
						($_ < 	2525	) ?  	386	:
						($_ < 	2535	) ?  	387	:
						($_ < 	2545	) ?  	388	:
						($_ < 	2555	) ?  	389	:
						($_ < 	2565	) ?  	390	:
						($_ < 	2575	) ?  	391	:
						($_ < 	2585	) ?  	392	:
						($_ < 	2595	) ?  	393	:
						($_ < 	2605	) ?  	394	:
						($_ < 	2615	) ?  	395	:
						($_ < 	2625	) ?  	396	:
						($_ < 	2635	) ?  	397	:
						($_ < 	2645	) ?  	399	:
						($_ < 	2655	) ?  	400	:
						($_ < 	2665	) ?  	401	:
						($_ < 	2675	) ?  	402	:
						($_ < 	2685	) ?  	403	:
						($_ < 	2695	) ?  	404	:
						($_ < 	2705	) ?  	406	:
						($_ < 	2715	) ?  	407	:
						($_ < 	2725	) ?  	408	:
						($_ < 	2735	) ?  	409	:
						($_ < 	2745	) ?  	411	:
						($_ < 	2755	) ?  	412	:
						($_ < 	2765	) ?  	413	:
						($_ < 	2775	) ?  	414	:
						($_ < 	2785	) ?  	416	:
						($_ < 	2795	) ?  	417	:
						($_ < 	2805	) ?  	418	:
						($_ < 	2815	) ?  	419	:
						($_ < 	2825	) ?  	421	:
						($_ < 	2835	) ?  	422	:
						($_ < 	2845	) ?  	423	:
						($_ < 	2855	) ?  	425	:
						($_ < 	2865	) ?  	426	:
						($_ < 	2875	) ?  	428	:
						($_ < 	2885	) ?  	429	:
						($_ < 	2895	) ?  	430	:
						($_ < 	2905	) ?  	432	:
						($_ < 	2915	) ?  	433	:
						($_ < 	2925	) ?  	435	:
						($_ < 	2935	) ?  	436	:
						($_ < 	2945	) ?  	438	:
						($_ < 	2955	) ?  	439	:
						($_ < 	2965	) ?  	441	:
						($_ < 	2975	) ?  	442	:
						($_ < 	2985	) ?  	444	:
						($_ < 	2995	) ?  	445	:
						($_ < 	3005	) ?  	447	:
						($_ < 	3015	) ?  	448	:
						($_ < 	3025	) ?  	450	:
						($_ < 	3035	) ?  	452	:
						($_ < 	3045	) ?  	453	:
						($_ < 	3055	) ?  	455	:
						($_ < 	3065	) ?  	456	:
						($_ < 	3075	) ?  	458	:
						($_ < 	3085	) ?  	460	:
						($_ < 	3095	) ?  	461	:
						($_ < 	3105	) ?  	463	:
						($_ < 	3115	) ?  	465	:
						($_ < 	3125	) ?  	467	:
						($_ < 	3135	) ?  	468	:
						($_ < 	3145	) ?  	470	:
						($_ < 	3155	) ?  	472	:
						($_ < 	3165	) ?  	474	:
						($_ < 	3175	) ?  	476	:
						($_ < 	3185	) ?  	477	:
						($_ < 	3195	) ?  	479	:
						($_ < 	3205	) ?  	481	:
						($_ < 	3215	) ?  	483	:
						($_ < 	3225	) ?  	485	:
						($_ < 	3235	) ?  	487	:
						($_ < 	3245	) ?  	489	:
						($_ < 	3255	) ?  	491	:
						($_ < 	3265	) ?  	493	:
						($_ < 	3275	) ?  	495	:
						($_ < 	3285	) ?  	497	:
						($_ < 	3295	) ?  	499	:
						($_ < 	3305	) ?  	501	:
						($_ < 	3315	) ?  	503	:
						($_ < 	3325	) ?  	505	:
						($_ < 	3335	) ?  	507	:
						($_ < 	3345	) ?  	509	:
						($_ < 	3355	) ?  	511	:
						($_ < 	3365	) ?  	513	:
						($_ < 	3375	) ?  	516	:
						($_ < 	3385	) ?  	518	:
						($_ < 	3395	) ?  	520	:
						($_ < 	3405	) ?  	522	:
						($_ < 	3415	) ?  	524	:
						($_ < 	3425	) ?  	527	:
						($_ < 	3435	) ?  	529	:
						($_ < 	3445	) ?  	531	:
						($_ < 	3455	) ?  	534	:
						($_ < 	3465	) ?  	536	:
						($_ < 	3475	) ?  	538	:
						($_ < 	3485	) ?  	541	:
						($_ < 	3495	) ?  	543	:
						($_ < 	3505	) ?  	546	:
						($_ < 	3515	) ?  	548	:
						($_ < 	3525	) ?  	551	:
						($_ < 	3535	) ?  	553	:
						($_ < 	3545	) ?  	556	:
						($_ < 	3555	) ?  	558	:
						($_ < 	3565	) ?  	561	:
						($_ < 	3575	) ?  	563	:
						($_ < 	3585	) ?  	566	:
						($_ < 	3595	) ?  	569	:
						($_ < 	3605	) ?  	571	:			
								571									 
					}				
				} elsif ($cs_child_number == 2) {					
					for ($combined_adj_income_w) {				
						$cs_obligation_com_w = 			
						 ($_ < 	185	) ?  	59	:
							($_ < 	195	) ?  	62	:
							($_ < 	205	) ?  	66	:
							($_ < 	215	) ?  	69	:
							($_ < 	225	) ?  	72	:
							($_ < 	235	) ?  	75	:
							($_ < 	245	) ?  	78	:
							($_ < 	255	) ?  	82	:
							($_ < 	265	) ?  	85	:
							($_ < 	275	) ?  	88	:
							($_ < 	285	) ?  	91	:
							($_ < 	295	) ?  	94	:
							($_ < 	305	) ?  	97	:
							($_ < 	315	) ?  	100	:
							($_ < 	325	) ?  	103	:
							($_ < 	335	) ?  	106	:
							($_ < 	345	) ?  	109	:
							($_ < 	355	) ?  	112	:
							($_ < 	365	) ?  	114	:
							($_ < 	375	) ?  	117	:
							($_ < 	385	) ?  	120	:
							($_ < 	395	) ?  	123	:
							($_ < 	405	) ?  	126	:
							($_ < 	415	) ?  	128	:
							($_ < 	425	) ?  	131	:
							($_ < 	435	) ?  	134	:
							($_ < 	445	) ?  	137	:
							($_ < 	455	) ?  	139	:
							($_ < 	465	) ?  	142	:
							($_ < 	475	) ?  	145	:
							($_ < 	485	) ?  	147	:
							($_ < 	495	) ?  	150	:
							($_ < 	505	) ?  	152	:
							($_ < 	515	) ?  	155	:
							($_ < 	525	) ?  	157	:
							($_ < 	535	) ?  	160	:
							($_ < 	545	) ?  	162	:
							($_ < 	555	) ?  	165	:
							($_ < 	565	) ?  	167	:
							($_ < 	575	) ?  	170	:
							($_ < 	585	) ?  	172	:
							($_ < 	595	) ?  	174	:
							($_ < 	605	) ?  	177	:
							($_ < 	615	) ?  	179	:
							($_ < 	625	) ?  	181	:
							($_ < 	635	) ?  	184	:
							($_ < 	645	) ?  	186	:
							($_ < 	655	) ?  	188	:
							($_ < 	665	) ?  	191	:
							($_ < 	675	) ?  	193	:
							($_ < 	685	) ?  	195	:
							($_ < 	695	) ?  	197	:
							($_ < 	705	) ?  	199	:
							($_ < 	715	) ?  	201	:
							($_ < 	725	) ?  	204	:
							($_ < 	735	) ?  	206	:
							($_ < 	745	) ?  	208	:
							($_ < 	755	) ?  	210	:
							($_ < 	765	) ?  	212	:
							($_ < 	775	) ?  	214	:
							($_ < 	785	) ?  	216	:
							($_ < 	795	) ?  	218	:
							($_ < 	805	) ?  	220	:
							($_ < 	815	) ?  	222	:
							($_ < 	825	) ?  	224	:
							($_ < 	835	) ?  	226	:
							($_ < 	845	) ?  	228	:
							($_ < 	855	) ?  	230	:
							($_ < 	865	) ?  	232	:
							($_ < 	875	) ?  	234	:
							($_ < 	885	) ?  	235	:
							($_ < 	895	) ?  	237	:
							($_ < 	905	) ?  	239	:
							($_ < 	915	) ?  	241	:
							($_ < 	925	) ?  	243	:
							($_ < 	935	) ?  	244	:
							($_ < 	945	) ?  	246	:
							($_ < 	955	) ?  	248	:
							($_ < 	965	) ?  	250	:
							($_ < 	975	) ?  	251	:
							($_ < 	985	) ?  	253	:
							($_ < 	995	) ?  	255	:
							($_ < 	1005	) ?  	257	:
							($_ < 	1015	) ?  	258	:
							($_ < 	1025	) ?  	260	:
							($_ < 	1035	) ?  	261	:
							($_ < 	1045	) ?  	263	:
							($_ < 	1055	) ?  	265	:
							($_ < 	1065	) ?  	266	:
							($_ < 	1075	) ?  	268	:
							($_ < 	1085	) ?  	269	:
							($_ < 	1095	) ?  	271	:
							($_ < 	1105	) ?  	273	:
							($_ < 	1115	) ?  	274	:
							($_ < 	1125	) ?  	276	:
							($_ < 	1135	) ?  	277	:
							($_ < 	1145	) ?  	279	:
							($_ < 	1155	) ?  	280	:
							($_ < 	1165	) ?  	282	:
							($_ < 	1175	) ?  	283	:
							($_ < 	1185	) ?  	284	:
							($_ < 	1195	) ?  	286	:
							($_ < 	1205	) ?  	287	:
							($_ < 	1215	) ?  	289	:
							($_ < 	1225	) ?  	290	:
							($_ < 	1235	) ?  	291	:
							($_ < 	1245	) ?  	293	:
							($_ < 	1255	) ?  	294	:
							($_ < 	1265	) ?  	296	:
							($_ < 	1275	) ?  	297	:
							($_ < 	1285	) ?  	298	:
							($_ < 	1295	) ?  	300	:
							($_ < 	1305	) ?  	301	:
							($_ < 	1315	) ?  	302	:
							($_ < 	1325	) ?  	303	:
							($_ < 	1335	) ?  	305	:
							($_ < 	1345	) ?  	306	:
							($_ < 	1355	) ?  	307	:
							($_ < 	1365	) ?  	308	:
							($_ < 	1375	) ?  	310	:
							($_ < 	1385	) ?  	311	:
							($_ < 	1395	) ?  	312	:
							($_ < 	1405	) ?  	313	:
							($_ < 	1415	) ?  	315	:
							($_ < 	1425	) ?  	316	:
							($_ < 	1435	) ?  	317	:
							($_ < 	1445	) ?  	318	:
							($_ < 	1455	) ?  	319	:
							($_ < 	1465	) ?  	320	:
							($_ < 	1475	) ?  	322	:
							($_ < 	1485	) ?  	323	:
							($_ < 	1495	) ?  	324	:
							($_ < 	1505	) ?  	325	:
							($_ < 	1515	) ?  	326	:
							($_ < 	1525	) ?  	327	:
							($_ < 	1535	) ?  	328	:
							($_ < 	1545	) ?  	329	:
							($_ < 	1555	) ?  	330	:
							($_ < 	1565	) ?  	331	:
							($_ < 	1575	) ?  	333	:
							($_ < 	1585	) ?  	334	:
							($_ < 	1595	) ?  	335	:
							($_ < 	1605	) ?  	336	:
							($_ < 	1615	) ?  	337	:
							($_ < 	1625	) ?  	338	:
							($_ < 	1635	) ?  	339	:
							($_ < 	1645	) ?  	340	:
							($_ < 	1655	) ?  	341	:
							($_ < 	1665	) ?  	342	:
							($_ < 	1675	) ?  	343	:
							($_ < 	1685	) ?  	344	:
							($_ < 	1695	) ?  	345	:
							($_ < 	1705	) ?  	346	:
							($_ < 	1715	) ?  	347	:
							($_ < 	1725	) ?  	348	:
							($_ < 	1735	) ?  	349	:
							($_ < 	1745	) ?  	350	:
							($_ < 	1755	) ?  	351	:
							($_ < 	1765	) ?  	352	:
							($_ < 	1775	) ?  	353	:
							($_ < 	1785	) ?  	354	:
							($_ < 	1795	) ?  	355	:
							($_ < 	1805	) ?  	356	:
							($_ < 	1815	) ?  	356	:
							($_ < 	1825	) ?  	357	:
							($_ < 	1835	) ?  	358	:
							($_ < 	1845	) ?  	359	:
							($_ < 	1855	) ?  	360	:
							($_ < 	1865	) ?  	361	:
							($_ < 	1875	) ?  	362	:
							($_ < 	1885	) ?  	363	:
							($_ < 	1895	) ?  	364	:
							($_ < 	1905	) ?  	365	:
							($_ < 	1915	) ?  	366	:
							($_ < 	1925	) ?  	367	:
							($_ < 	1935	) ?  	367	:
							($_ < 	1945	) ?  	368	:
							($_ < 	1955	) ?  	369	:
							($_ < 	1965	) ?  	370	:
							($_ < 	1975	) ?  	371	:
							($_ < 	1985	) ?  	372	:
							($_ < 	1995	) ?  	373	:
							($_ < 	2005	) ?  	374	:
							($_ < 	2015	) ?  	375	:
							($_ < 	2025	) ?  	376	:
							($_ < 	2035	) ?  	376	:
							($_ < 	2045	) ?  	377	:
							($_ < 	2055	) ?  	378	:
							($_ < 	2065	) ?  	379	:
							($_ < 	2075	) ?  	380	:
							($_ < 	2085	) ?  	381	:
							($_ < 	2095	) ?  	382	:
							($_ < 	2105	) ?  	383	:
							($_ < 	2115	) ?  	384	:
							($_ < 	2125	) ?  	384	:
							($_ < 	2135	) ?  	385	:
							($_ < 	2145	) ?  	386	:
							($_ < 	2155	) ?  	387	:
							($_ < 	2165	) ?  	388	:
							($_ < 	2175	) ?  	389	:
							($_ < 	2185	) ?  	390	:
							($_ < 	2195	) ?  	391	:
							($_ < 	2205	) ?  	391	:
							($_ < 	2215	) ?  	392	:
							($_ < 	2225	) ?  	393	:
							($_ < 	2235	) ?  	394	:
							($_ < 	2245	) ?  	395	:
							($_ < 	2255	) ?  	396	:
							($_ < 	2265	) ?  	397	:
							($_ < 	2275	) ?  	398	:
							($_ < 	2285	) ?  	399	:
							($_ < 	2295	) ?  	400	:
							($_ < 	2305	) ?  	400	:
							($_ < 	2315	) ?  	401	:
							($_ < 	2325	) ?  	402	:
							($_ < 	2335	) ?  	403	:
							($_ < 	2345	) ?  	404	:
							($_ < 	2355	) ?  	405	:
							($_ < 	2365	) ?  	406	:
							($_ < 	2375	) ?  	407	:
							($_ < 	2385	) ?  	408	:
							($_ < 	2395	) ?  	409	:
							($_ < 	2405	) ?  	410	:
							($_ < 	2415	) ?  	411	:
							($_ < 	2425	) ?  	412	:
							($_ < 	2435	) ?  	413	:
							($_ < 	2445	) ?  	414	:
							($_ < 	2455	) ?  	414	:
							($_ < 	2465	) ?  	415	:
							($_ < 	2475	) ?  	416	:
							($_ < 	2485	) ?  	417	:
							($_ < 	2495	) ?  	418	:
							($_ < 	2505	) ?  	419	:
							($_ < 	2515	) ?  	420	:
							($_ < 	2525	) ?  	421	:
							($_ < 	2535	) ?  	422	:
							($_ < 	2545	) ?  	423	:
							($_ < 	2555	) ?  	424	:
							($_ < 	2565	) ?  	425	:
							($_ < 	2575	) ?  	426	:
							($_ < 	2585	) ?  	427	:
							($_ < 	2595	) ?  	428	:
							($_ < 	2605	) ?  	430	:
							($_ < 	2615	) ?  	431	:
							($_ < 	2625	) ?  	432	:
							($_ < 	2635	) ?  	433	:
							($_ < 	2645	) ?  	434	:
							($_ < 	2655	) ?  	435	:
							($_ < 	2665	) ?  	436	:
							($_ < 	2675	) ?  	437	:
							($_ < 	2685	) ?  	438	:
							($_ < 	2695	) ?  	439	:
							($_ < 	2705	) ?  	440	:
							($_ < 	2715	) ?  	441	:
							($_ < 	2725	) ?  	443	:
							($_ < 	2735	) ?  	444	:
							($_ < 	2745	) ?  	445	:
							($_ < 	2755	) ?  	446	:
							($_ < 	2765	) ?  	447	:
							($_ < 	2775	) ?  	448	:
							($_ < 	2785	) ?  	450	:
							($_ < 	2795	) ?  	451	:
							($_ < 	2805	) ?  	452	:
							($_ < 	2815	) ?  	453	:
							($_ < 	2825	) ?  	454	:
							($_ < 	2835	) ?  	456	:
							($_ < 	2845	) ?  	457	:
							($_ < 	2855	) ?  	458	:
							($_ < 	2865	) ?  	459	:
							($_ < 	2875	) ?  	461	:
							($_ < 	2885	) ?  	462	:
							($_ < 	2895	) ?  	463	:
							($_ < 	2905	) ?  	464	:
							($_ < 	2915	) ?  	466	:
							($_ < 	2925	) ?  	467	:
							($_ < 	2935	) ?  	468	:
							($_ < 	2945	) ?  	470	:
							($_ < 	2955	) ?  	471	:
							($_ < 	2965	) ?  	472	:
							($_ < 	2975	) ?  	474	:
							($_ < 	2985	) ?  	475	:
							($_ < 	2995	) ?  	477	:
							($_ < 	3005	) ?  	478	:
							($_ < 	3015	) ?  	479	:
							($_ < 	3025	) ?  	481	:
							($_ < 	3035	) ?  	482	:
							($_ < 	3045	) ?  	484	:
							($_ < 	3055	) ?  	485	:
							($_ < 	3065	) ?  	487	:
							($_ < 	3075	) ?  	488	:
							($_ < 	3085	) ?  	490	:
							($_ < 	3095	) ?  	491	:
							($_ < 	3105	) ?  	493	:
							($_ < 	3115	) ?  	494	:
							($_ < 	3125	) ?  	496	:
							($_ < 	3135	) ?  	497	:
							($_ < 	3145	) ?  	499	:
							($_ < 	3155	) ?  	501	:
							($_ < 	3165	) ?  	502	:
							($_ < 	3175	) ?  	504	:
							($_ < 	3185	) ?  	505	:
							($_ < 	3195	) ?  	507	:
							($_ < 	3205	) ?  	509	:
							($_ < 	3215	) ?  	510	:
							($_ < 	3225	) ?  	512	:
							($_ < 	3235	) ?  	514	:
							($_ < 	3245	) ?  	516	:
							($_ < 	3255	) ?  	517	:
							($_ < 	3265	) ?  	519	:
							($_ < 	3275	) ?  	521	:
							($_ < 	3285	) ?  	523	:
							($_ < 	3295	) ?  	524	:
							($_ < 	3305	) ?  	526	:
							($_ < 	3315	) ?  	528	:
							($_ < 	3325	) ?  	530	:
							($_ < 	3335	) ?  	532	:
							($_ < 	3345	) ?  	534	:
							($_ < 	3355	) ?  	536	:
							($_ < 	3365	) ?  	537	:
							($_ < 	3375	) ?  	539	:
							($_ < 	3385	) ?  	541	:
							($_ < 	3395	) ?  	543	:
							($_ < 	3405	) ?  	545	:
							($_ < 	3415	) ?  	547	:
							($_ < 	3425	) ?  	549	:
							($_ < 	3435	) ?  	551	:
							($_ < 	3445	) ?  	553	:
							($_ < 	3455	) ?  	555	:
							($_ < 	3465	) ?  	557	:
							($_ < 	3475	) ?  	560	:
							($_ < 	3485	) ?  	562	:
							($_ < 	3495	) ?  	564	:
							($_ < 	3505	) ?  	566	:
							($_ < 	3515	) ?  	568	:
							($_ < 	3525	) ?  	570	:
							($_ < 	3535	) ?  	573	:
							($_ < 	3545	) ?  	575	:
							($_ < 	3555	) ?  	577	:
							($_ < 	3565	) ?  	579	:
							($_ < 	3575	) ?  	582	:
							($_ < 	3585	) ?  	584	:
							($_ < 	3595	) ?  	586	:
							($_ < 	3605	) ?  	589	:
									589
					}				
				} elsif ($cs_child_number == 3) {					
					for ($combined_adj_income_w) {				
						$cs_obligation_com_w = 			
							($_ < 	185	) ?  	68	:
							($_ < 	195	) ?  	72	:
							($_ < 	205	) ?  	76	:
							($_ < 	215	) ?  	80	:
							($_ < 	225	) ?  	84	:
							($_ < 	235	) ?  	88	:
							($_ < 	245	) ?  	92	:
							($_ < 	255	) ?  	96	:
							($_ < 	265	) ?  	100	:
							($_ < 	275	) ?  	103	:
							($_ < 	285	) ?  	107	:
							($_ < 	295	) ?  	111	:
							($_ < 	305	) ?  	115	:
							($_ < 	315	) ?  	118	:
							($_ < 	325	) ?  	122	:
							($_ < 	335	) ?  	126	:
							($_ < 	345	) ?  	129	:
							($_ < 	355	) ?  	133	:
							($_ < 	365	) ?  	136	:
							($_ < 	375	) ?  	140	:
							($_ < 	385	) ?  	143	:
							($_ < 	395	) ?  	147	:
							($_ < 	405	) ?  	150	:
							($_ < 	415	) ?  	154	:
							($_ < 	425	) ?  	157	:
							($_ < 	435	) ?  	160	:
							($_ < 	445	) ?  	164	:
							($_ < 	455	) ?  	167	:
							($_ < 	465	) ?  	170	:
							($_ < 	475	) ?  	174	:
							($_ < 	485	) ?  	177	:
							($_ < 	495	) ?  	180	:
							($_ < 	505	) ?  	183	:
							($_ < 	515	) ?  	186	:
							($_ < 	525	) ?  	190	:
							($_ < 	535	) ?  	193	:
							($_ < 	545	) ?  	196	:
							($_ < 	555	) ?  	199	:
							($_ < 	565	) ?  	202	:
							($_ < 	575	) ?  	205	:
							($_ < 	585	) ?  	208	:
							($_ < 	595	) ?  	211	:
							($_ < 	605	) ?  	214	:
							($_ < 	615	) ?  	217	:
							($_ < 	625	) ?  	220	:
							($_ < 	635	) ?  	223	:
							($_ < 	645	) ?  	225	:
							($_ < 	655	) ?  	228	:
							($_ < 	665	) ?  	231	:
							($_ < 	675	) ?  	234	:
							($_ < 	685	) ?  	237	:
							($_ < 	695	) ?  	239	:
							($_ < 	705	) ?  	242	:
							($_ < 	715	) ?  	245	:
							($_ < 	725	) ?  	247	:
							($_ < 	735	) ?  	250	:
							($_ < 	745	) ?  	253	:
							($_ < 	755	) ?  	255	:
							($_ < 	765	) ?  	258	:
							($_ < 	775	) ?  	261	:
							($_ < 	785	) ?  	263	:
							($_ < 	795	) ?  	266	:
							($_ < 	805	) ?  	268	:
							($_ < 	815	) ?  	271	:
							($_ < 	825	) ?  	273	:
							($_ < 	835	) ?  	276	:
							($_ < 	845	) ?  	278	:
							($_ < 	855	) ?  	281	:
							($_ < 	865	) ?  	283	:
							($_ < 	875	) ?  	285	:
							($_ < 	885	) ?  	288	:
							($_ < 	895	) ?  	290	:
							($_ < 	905	) ?  	292	:
							($_ < 	915	) ?  	295	:
							($_ < 	925	) ?  	297	:
							($_ < 	935	) ?  	299	:
							($_ < 	945	) ?  	301	:
							($_ < 	955	) ?  	304	:
							($_ < 	965	) ?  	306	:
							($_ < 	975	) ?  	308	:
							($_ < 	985	) ?  	310	:
							($_ < 	995	) ?  	312	:
							($_ < 	1005	) ?  	315	:
							($_ < 	1015	) ?  	317	:
							($_ < 	1025	) ?  	319	:
							($_ < 	1035	) ?  	321	:
							($_ < 	1045	) ?  	323	:
							($_ < 	1055	) ?  	325	:
							($_ < 	1065	) ?  	327	:
							($_ < 	1075	) ?  	329	:
							($_ < 	1085	) ?  	331	:
							($_ < 	1095	) ?  	333	:
							($_ < 	1105	) ?  	335	:
							($_ < 	1115	) ?  	337	:
							($_ < 	1125	) ?  	339	:
							($_ < 	1135	) ?  	341	:
							($_ < 	1145	) ?  	343	:
							($_ < 	1155	) ?  	345	:
							($_ < 	1165	) ?  	347	:
							($_ < 	1175	) ?  	349	:
							($_ < 	1185	) ?  	350	:
							($_ < 	1195	) ?  	352	:
							($_ < 	1205	) ?  	354	:
							($_ < 	1215	) ?  	356	:
							($_ < 	1225	) ?  	358	:
							($_ < 	1235	) ?  	360	:
							($_ < 	1245	) ?  	361	:
							($_ < 	1255	) ?  	363	:
							($_ < 	1265	) ?  	365	:
							($_ < 	1275	) ?  	367	:
							($_ < 	1285	) ?  	368	:
							($_ < 	1295	) ?  	370	:
							($_ < 	1305	) ?  	372	:
							($_ < 	1315	) ?  	373	:
							($_ < 	1325	) ?  	375	:
							($_ < 	1335	) ?  	377	:
							($_ < 	1345	) ?  	378	:
							($_ < 	1355	) ?  	380	:
							($_ < 	1365	) ?  	382	:
							($_ < 	1375	) ?  	383	:
							($_ < 	1385	) ?  	385	:
							($_ < 	1395	) ?  	386	:
							($_ < 	1405	) ?  	388	:
							($_ < 	1415	) ?  	390	:
							($_ < 	1425	) ?  	391	:
							($_ < 	1435	) ?  	393	:
							($_ < 	1445	) ?  	394	:
							($_ < 	1455	) ?  	396	:
							($_ < 	1465	) ?  	397	:
							($_ < 	1475	) ?  	399	:
							($_ < 	1485	) ?  	400	:
							($_ < 	1495	) ?  	402	:
							($_ < 	1505	) ?  	403	:
							($_ < 	1515	) ?  	405	:
							($_ < 	1525	) ?  	406	:
							($_ < 	1535	) ?  	408	:
							($_ < 	1545	) ?  	409	:
							($_ < 	1555	) ?  	410	:
							($_ < 	1565	) ?  	412	:
							($_ < 	1575	) ?  	413	:
							($_ < 	1585	) ?  	415	:
							($_ < 	1595	) ?  	416	:
							($_ < 	1605	) ?  	417	:
							($_ < 	1615	) ?  	419	:
							($_ < 	1625	) ?  	420	:
							($_ < 	1635	) ?  	422	:
							($_ < 	1645	) ?  	423	:
							($_ < 	1655	) ?  	424	:
							($_ < 	1665	) ?  	426	:
							($_ < 	1675	) ?  	427	:
							($_ < 	1685	) ?  	428	:
							($_ < 	1695	) ?  	430	:
							($_ < 	1705	) ?  	431	:
							($_ < 	1715	) ?  	432	:
							($_ < 	1725	) ?  	434	:
							($_ < 	1735	) ?  	435	:
							($_ < 	1745	) ?  	436	:
							($_ < 	1755	) ?  	437	:
							($_ < 	1765	) ?  	439	:
							($_ < 	1775	) ?  	440	:
							($_ < 	1785	) ?  	441	:
							($_ < 	1795	) ?  	442	:
							($_ < 	1805	) ?  	444	:
							($_ < 	1815	) ?  	445	:
							($_ < 	1825	) ?  	446	:
							($_ < 	1835	) ?  	447	:
							($_ < 	1845	) ?  	449	:
							($_ < 	1855	) ?  	450	:
							($_ < 	1865	) ?  	451	:
							($_ < 	1875	) ?  	452	:
							($_ < 	1885	) ?  	454	:
							($_ < 	1895	) ?  	455	:
							($_ < 	1905	) ?  	456	:
							($_ < 	1915	) ?  	457	:
							($_ < 	1925	) ?  	458	:
							($_ < 	1935	) ?  	460	:
							($_ < 	1945	) ?  	461	:
							($_ < 	1955	) ?  	462	:
							($_ < 	1965	) ?  	463	:
							($_ < 	1975	) ?  	464	:
							($_ < 	1985	) ?  	466	:
							($_ < 	1995	) ?  	467	:
							($_ < 	2005	) ?  	468	:
							($_ < 	2015	) ?  	469	:
							($_ < 	2025	) ?  	470	:
							($_ < 	2035	) ?  	471	:
							($_ < 	2045	) ?  	473	:
							($_ < 	2055	) ?  	474	:
							($_ < 	2065	) ?  	475	:
							($_ < 	2075	) ?  	476	:
							($_ < 	2085	) ?  	477	:
							($_ < 	2095	) ?  	478	:
							($_ < 	2105	) ?  	480	:
							($_ < 	2115	) ?  	481	:
							($_ < 	2125	) ?  	482	:
							($_ < 	2135	) ?  	483	:
							($_ < 	2145	) ?  	484	:
							($_ < 	2155	) ?  	485	:
							($_ < 	2165	) ?  	487	:
							($_ < 	2175	) ?  	488	:
							($_ < 	2185	) ?  	489	:
							($_ < 	2195	) ?  	490	:
							($_ < 	2205	) ?  	491	:
							($_ < 	2215	) ?  	492	:
							($_ < 	2225	) ?  	494	:
							($_ < 	2235	) ?  	495	:
							($_ < 	2245	) ?  	496	:
							($_ < 	2255	) ?  	497	:
							($_ < 	2265	) ?  	498	:
							($_ < 	2275	) ?  	499	:
							($_ < 	2285	) ?  	501	:
							($_ < 	2295	) ?  	502	:
							($_ < 	2305	) ?  	503	:
							($_ < 	2315	) ?  	504	:
							($_ < 	2325	) ?  	505	:
							($_ < 	2335	) ?  	507	:
							($_ < 	2345	) ?  	508	:
							($_ < 	2355	) ?  	509	:
							($_ < 	2365	) ?  	510	:
							($_ < 	2375	) ?  	511	:
							($_ < 	2385	) ?  	513	:
							($_ < 	2395	) ?  	514	:
							($_ < 	2405	) ?  	515	:
							($_ < 	2415	) ?  	516	:
							($_ < 	2425	) ?  	517	:
							($_ < 	2435	) ?  	519	:
							($_ < 	2445	) ?  	520	:
							($_ < 	2455	) ?  	521	:
							($_ < 	2465	) ?  	522	:
							($_ < 	2475	) ?  	524	:
							($_ < 	2485	) ?  	525	:
							($_ < 	2495	) ?  	526	:
							($_ < 	2505	) ?  	527	:
							($_ < 	2515	) ?  	529	:
							($_ < 	2525	) ?  	530	:
							($_ < 	2535	) ?  	531	:
							($_ < 	2545	) ?  	532	:
							($_ < 	2555	) ?  	534	:
							($_ < 	2565	) ?  	535	:
							($_ < 	2575	) ?  	536	:
							($_ < 	2585	) ?  	538	:
							($_ < 	2595	) ?  	539	:
							($_ < 	2605	) ?  	540	:
							($_ < 	2615	) ?  	542	:
							($_ < 	2625	) ?  	543	:
							($_ < 	2635	) ?  	544	:
							($_ < 	2645	) ?  	546	:
							($_ < 	2655	) ?  	547	:
							($_ < 	2665	) ?  	548	:
							($_ < 	2675	) ?  	550	:
							($_ < 	2685	) ?  	551	:
							($_ < 	2695	) ?  	552	:
							($_ < 	2705	) ?  	554	:
							($_ < 	2715	) ?  	555	:
							($_ < 	2725	) ?  	557	:
							($_ < 	2735	) ?  	558	:
							($_ < 	2745	) ?  	559	:
							($_ < 	2755	) ?  	561	:
							($_ < 	2765	) ?  	562	:
							($_ < 	2775	) ?  	564	:
							($_ < 	2785	) ?  	565	:
							($_ < 	2795	) ?  	567	:
							($_ < 	2805	) ?  	568	:
							($_ < 	2815	) ?  	570	:
							($_ < 	2825	) ?  	571	:
							($_ < 	2835	) ?  	573	:
							($_ < 	2845	) ?  	574	:
							($_ < 	2855	) ?  	576	:
							($_ < 	2865	) ?  	577	:
							($_ < 	2875	) ?  	579	:
							($_ < 	2885	) ?  	580	:
							($_ < 	2895	) ?  	582	:
							($_ < 	2905	) ?  	584	:
							($_ < 	2915	) ?  	585	:
							($_ < 	2925	) ?  	587	:
							($_ < 	2935	) ?  	588	:
							($_ < 	2945	) ?  	590	:
							($_ < 	2955	) ?  	592	:
							($_ < 	2965	) ?  	593	:
							($_ < 	2975	) ?  	595	:
							($_ < 	2985	) ?  	597	:
							($_ < 	2995	) ?  	598	:
							($_ < 	3005	) ?  	600	:
							($_ < 	3015	) ?  	602	:
							($_ < 	3025	) ?  	604	:
							($_ < 	3035	) ?  	605	:
							($_ < 	3045	) ?  	607	:
							($_ < 	3055	) ?  	609	:
							($_ < 	3065	) ?  	611	:
							($_ < 	3075	) ?  	612	:
							($_ < 	3085	) ?  	614	:
							($_ < 	3095	) ?  	616	:
							($_ < 	3105	) ?  	618	:
							($_ < 	3115	) ?  	620	:
							($_ < 	3125	) ?  	622	:
							($_ < 	3135	) ?  	623	:
							($_ < 	3145	) ?  	625	:
							($_ < 	3155	) ?  	627	:
							($_ < 	3165	) ?  	629	:
							($_ < 	3175	) ?  	631	:
							($_ < 	3185	) ?  	633	:
							($_ < 	3195	) ?  	635	:
							($_ < 	3205	) ?  	637	:
							($_ < 	3215	) ?  	639	:
							($_ < 	3225	) ?  	641	:
							($_ < 	3235	) ?  	643	:
							($_ < 	3245	) ?  	645	:
							($_ < 	3255	) ?  	647	:
							($_ < 	3265	) ?  	649	:
							($_ < 	3275	) ?  	651	:
							($_ < 	3285	) ?  	654	:
							($_ < 	3295	) ?  	656	:
							($_ < 	3305	) ?  	658	:
							($_ < 	3315	) ?  	660	:
							($_ < 	3325	) ?  	662	:
							($_ < 	3335	) ?  	664	:
							($_ < 	3345	) ?  	667	:
							($_ < 	3355	) ?  	669	:
							($_ < 	3365	) ?  	671	:
							($_ < 	3375	) ?  	674	:
							($_ < 	3385	) ?  	676	:
							($_ < 	3395	) ?  	678	:
							($_ < 	3405	) ?  	680	:
							($_ < 	3415	) ?  	683	:
							($_ < 	3425	) ?  	685	:
							($_ < 	3435	) ?  	688	:
							($_ < 	3445	) ?  	690	:
							($_ < 	3455	) ?  	692	:
							($_ < 	3465	) ?  	695	:
							($_ < 	3475	) ?  	697	:
							($_ < 	3485	) ?  	700	:
							($_ < 	3495	) ?  	702	:
							($_ < 	3505	) ?  	705	:
							($_ < 	3515	) ?  	707	:
							($_ < 	3525	) ?  	710	:
							($_ < 	3535	) ?  	713	:
							($_ < 	3545	) ?  	715	:
							($_ < 	3555	) ?  	718	:
							($_ < 	3565	) ?  	720	:
							($_ < 	3575	) ?  	723	:
							($_ < 	3585	) ?  	726	:
							($_ < 	3595	) ?  	729	:
							($_ < 	3605	) ?  	731	:
								731
					}				
				} elsif ($cs_child_number == 4) {					
					for ($combined_adj_income_w) {				
						$cs_obligation_com_w = 			
							($_ < 	185	) ?  	75	:
							($_ < 	195	) ?  	80	:
							($_ < 	205	) ?  	84	:
							($_ < 	215	) ?  	88	:
							($_ < 	225	) ?  	93	:
							($_ < 	235	) ?  	97	:
							($_ < 	245	) ?  	102	:
							($_ < 	255	) ?  	106	:
							($_ < 	265	) ?  	110	:
							($_ < 	275	) ?  	114	:
							($_ < 	285	) ?  	119	:
							($_ < 	295	) ?  	123	:
							($_ < 	305	) ?  	127	:
							($_ < 	315	) ?  	131	:
							($_ < 	325	) ?  	135	:
							($_ < 	335	) ?  	139	:
							($_ < 	345	) ?  	143	:
							($_ < 	355	) ?  	147	:
							($_ < 	365	) ?  	151	:
							($_ < 	375	) ?  	155	:
							($_ < 	385	) ?  	159	:
							($_ < 	395	) ?  	163	:
							($_ < 	405	) ?  	167	:
							($_ < 	415	) ?  	170	:
							($_ < 	425	) ?  	174	:
							($_ < 	435	) ?  	178	:
							($_ < 	445	) ?  	182	:
							($_ < 	455	) ?  	185	:
							($_ < 	465	) ?  	189	:
							($_ < 	475	) ?  	193	:
							($_ < 	485	) ?  	196	:
							($_ < 	495	) ?  	200	:
							($_ < 	505	) ?  	203	:
							($_ < 	515	) ?  	207	:
							($_ < 	525	) ?  	210	:
							($_ < 	535	) ?  	214	:
							($_ < 	545	) ?  	217	:
							($_ < 	555	) ?  	221	:
							($_ < 	565	) ?  	224	:
							($_ < 	575	) ?  	228	:
							($_ < 	585	) ?  	231	:
							($_ < 	595	) ?  	234	:
							($_ < 	605	) ?  	238	:
							($_ < 	615	) ?  	241	:
							($_ < 	625	) ?  	244	:
							($_ < 	635	) ?  	247	:
							($_ < 	645	) ?  	250	:
							($_ < 	655	) ?  	254	:
							($_ < 	665	) ?  	257	:
							($_ < 	675	) ?  	260	:
							($_ < 	685	) ?  	263	:
							($_ < 	695	) ?  	266	:
							($_ < 	705	) ?  	269	:
							($_ < 	715	) ?  	272	:
							($_ < 	725	) ?  	275	:
							($_ < 	735	) ?  	278	:
							($_ < 	745	) ?  	281	:
							($_ < 	755	) ?  	284	:
							($_ < 	765	) ?  	287	:
							($_ < 	775	) ?  	290	:
							($_ < 	785	) ?  	293	:
							($_ < 	795	) ?  	295	:
							($_ < 	805	) ?  	298	:
							($_ < 	815	) ?  	301	:
							($_ < 	825	) ?  	304	:
							($_ < 	835	) ?  	307	:
							($_ < 	845	) ?  	309	:
							($_ < 	855	) ?  	312	:
							($_ < 	865	) ?  	315	:
							($_ < 	875	) ?  	317	:
							($_ < 	885	) ?  	320	:
							($_ < 	895	) ?  	323	:
							($_ < 	905	) ?  	325	:
							($_ < 	915	) ?  	328	:
							($_ < 	925	) ?  	330	:
							($_ < 	935	) ?  	333	:
							($_ < 	945	) ?  	335	:
							($_ < 	955	) ?  	338	:
							($_ < 	965	) ?  	340	:
							($_ < 	975	) ?  	343	:
							($_ < 	985	) ?  	345	:
							($_ < 	995	) ?  	348	:
							($_ < 	1005	) ?  	350	:
							($_ < 	1015	) ?  	352	:
							($_ < 	1025	) ?  	355	:
							($_ < 	1035	) ?  	357	:
							($_ < 	1045	) ?  	359	:
							($_ < 	1055	) ?  	362	:
							($_ < 	1065	) ?  	364	:
							($_ < 	1075	) ?  	366	:
							($_ < 	1085	) ?  	368	:
							($_ < 	1095	) ?  	371	:
							($_ < 	1105	) ?  	373	:
							($_ < 	1115	) ?  	375	:
							($_ < 	1125	) ?  	377	:
							($_ < 	1135	) ?  	379	:
							($_ < 	1145	) ?  	382	:
							($_ < 	1155	) ?  	384	:
							($_ < 	1165	) ?  	386	:
							($_ < 	1175	) ?  	388	:
							($_ < 	1185	) ?  	390	:
							($_ < 	1195	) ?  	392	:
							($_ < 	1205	) ?  	394	:
							($_ < 	1215	) ?  	396	:
							($_ < 	1225	) ?  	398	:
							($_ < 	1235	) ?  	400	:
							($_ < 	1245	) ?  	402	:
							($_ < 	1255	) ?  	404	:
							($_ < 	1265	) ?  	406	:
							($_ < 	1275	) ?  	408	:
							($_ < 	1285	) ?  	410	:
							($_ < 	1295	) ?  	412	:
							($_ < 	1305	) ?  	414	:
							($_ < 	1315	) ?  	415	:
							($_ < 	1325	) ?  	417	:
							($_ < 	1335	) ?  	419	:
							($_ < 	1345	) ?  	421	:
							($_ < 	1355	) ?  	423	:
							($_ < 	1365	) ?  	425	:
							($_ < 	1375	) ?  	426	:
							($_ < 	1385	) ?  	428	:
							($_ < 	1395	) ?  	430	:
							($_ < 	1405	) ?  	432	:
							($_ < 	1415	) ?  	433	:
							($_ < 	1425	) ?  	435	:
							($_ < 	1435	) ?  	437	:
							($_ < 	1445	) ?  	439	:
							($_ < 	1455	) ?  	440	:
							($_ < 	1465	) ?  	442	:
							($_ < 	1475	) ?  	444	:
							($_ < 	1485	) ?  	445	:
							($_ < 	1495	) ?  	447	:
							($_ < 	1505	) ?  	449	:
							($_ < 	1515	) ?  	450	:
							($_ < 	1525	) ?  	452	:
							($_ < 	1535	) ?  	453	:
							($_ < 	1545	) ?  	455	:
							($_ < 	1555	) ?  	457	:
							($_ < 	1565	) ?  	458	:
							($_ < 	1575	) ?  	460	:
							($_ < 	1585	) ?  	461	:
							($_ < 	1595	) ?  	463	:
							($_ < 	1605	) ?  	464	:
							($_ < 	1615	) ?  	466	:
							($_ < 	1625	) ?  	467	:
							($_ < 	1635	) ?  	469	:
							($_ < 	1645	) ?  	470	:
							($_ < 	1655	) ?  	472	:
							($_ < 	1665	) ?  	473	:
							($_ < 	1675	) ?  	475	:
							($_ < 	1685	) ?  	476	:
							($_ < 	1695	) ?  	478	:
							($_ < 	1705	) ?  	479	:
							($_ < 	1715	) ?  	481	:
							($_ < 	1725	) ?  	482	:
							($_ < 	1735	) ?  	484	:
							($_ < 	1745	) ?  	485	:
							($_ < 	1755	) ?  	486	:
							($_ < 	1765	) ?  	488	:
							($_ < 	1775	) ?  	489	:
							($_ < 	1785	) ?  	491	:
							($_ < 	1795	) ?  	492	:
							($_ < 	1805	) ?  	493	:
							($_ < 	1815	) ?  	495	:
							($_ < 	1825	) ?  	496	:
							($_ < 	1835	) ?  	498	:
							($_ < 	1845	) ?  	499	:
							($_ < 	1855	) ?  	500	:
							($_ < 	1865	) ?  	502	:
							($_ < 	1875	) ?  	503	:
							($_ < 	1885	) ?  	504	:
							($_ < 	1895	) ?  	506	:
							($_ < 	1905	) ?  	507	:
							($_ < 	1915	) ?  	508	:
							($_ < 	1925	) ?  	510	:
							($_ < 	1935	) ?  	511	:
							($_ < 	1945	) ?  	512	:
							($_ < 	1955	) ?  	513	:
							($_ < 	1965	) ?  	515	:
							($_ < 	1975	) ?  	516	:
							($_ < 	1985	) ?  	517	:
							($_ < 	1995	) ?  	519	:
							($_ < 	2005	) ?  	520	:
							($_ < 	2015	) ?  	521	:
							($_ < 	2025	) ?  	523	:
							($_ < 	2035	) ?  	524	:
							($_ < 	2045	) ?  	525	:
							($_ < 	2055	) ?  	526	:
							($_ < 	2065	) ?  	528	:
							($_ < 	2075	) ?  	529	:
							($_ < 	2085	) ?  	530	:
							($_ < 	2095	) ?  	531	:
							($_ < 	2105	) ?  	533	:
							($_ < 	2115	) ?  	534	:
							($_ < 	2125	) ?  	535	:
							($_ < 	2135	) ?  	537	:
							($_ < 	2145	) ?  	538	:
							($_ < 	2155	) ?  	539	:
							($_ < 	2165	) ?  	540	:
							($_ < 	2175	) ?  	542	:
							($_ < 	2185	) ?  	543	:
							($_ < 	2195	) ?  	544	:
							($_ < 	2205	) ?  	545	:
							($_ < 	2215	) ?  	547	:
							($_ < 	2225	) ?  	548	:
							($_ < 	2235	) ?  	549	:
							($_ < 	2245	) ?  	551	:
							($_ < 	2255	) ?  	552	:
							($_ < 	2265	) ?  	553	:
							($_ < 	2275	) ?  	554	:
							($_ < 	2285	) ?  	556	:
							($_ < 	2295	) ?  	557	:
							($_ < 	2305	) ?  	558	:
							($_ < 	2315	) ?  	559	:
							($_ < 	2325	) ?  	561	:
							($_ < 	2335	) ?  	562	:
							($_ < 	2345	) ?  	563	:
							($_ < 	2355	) ?  	565	:
							($_ < 	2365	) ?  	566	:
							($_ < 	2375	) ?  	567	:
							($_ < 	2385	) ?  	569	:
							($_ < 	2395	) ?  	570	:
							($_ < 	2405	) ?  	571	:
							($_ < 	2415	) ?  	572	:
							($_ < 	2425	) ?  	574	:
							($_ < 	2435	) ?  	575	:
							($_ < 	2445	) ?  	576	:
							($_ < 	2455	) ?  	578	:
							($_ < 	2465	) ?  	579	:
							($_ < 	2475	) ?  	580	:
							($_ < 	2485	) ?  	582	:
							($_ < 	2495	) ?  	583	:
							($_ < 	2505	) ?  	584	:
							($_ < 	2515	) ?  	586	:
							($_ < 	2525	) ?  	587	:
							($_ < 	2535	) ?  	589	:
							($_ < 	2545	) ?  	590	:
							($_ < 	2555	) ?  	591	:
							($_ < 	2565	) ?  	593	:
							($_ < 	2575	) ?  	594	:
							($_ < 	2585	) ?  	596	:
							($_ < 	2595	) ?  	597	:
							($_ < 	2605	) ?  	598	:
							($_ < 	2615	) ?  	600	:
							($_ < 	2625	) ?  	601	:
							($_ < 	2635	) ?  	603	:
							($_ < 	2645	) ?  	604	:
							($_ < 	2655	) ?  	606	:
							($_ < 	2665	) ?  	607	:
							($_ < 	2675	) ?  	608	:
							($_ < 	2685	) ?  	610	:
							($_ < 	2695	) ?  	611	:
							($_ < 	2705	) ?  	613	:
							($_ < 	2715	) ?  	614	:
							($_ < 	2725	) ?  	616	:
							($_ < 	2735	) ?  	617	:
							($_ < 	2745	) ?  	619	:
							($_ < 	2755	) ?  	621	:
							($_ < 	2765	) ?  	622	:
							($_ < 	2775	) ?  	624	:
							($_ < 	2785	) ?  	625	:
							($_ < 	2795	) ?  	627	:
							($_ < 	2805	) ?  	628	:
							($_ < 	2815	) ?  	630	:
							($_ < 	2825	) ?  	632	:
							($_ < 	2835	) ?  	633	:
							($_ < 	2845	) ?  	635	:
							($_ < 	2855	) ?  	637	:
							($_ < 	2865	) ?  	638	:
							($_ < 	2875	) ?  	640	:
							($_ < 	2885	) ?  	642	:
							($_ < 	2895	) ?  	643	:
							($_ < 	2905	) ?  	645	:
							($_ < 	2915	) ?  	647	:
							($_ < 	2925	) ?  	648	:
							($_ < 	2935	) ?  	650	:
							($_ < 	2945	) ?  	652	:
							($_ < 	2955	) ?  	654	:
							($_ < 	2965	) ?  	655	:
							($_ < 	2975	) ?  	657	:
							($_ < 	2985	) ?  	659	:
							($_ < 	2995	) ?  	661	:
							($_ < 	3005	) ?  	663	:
							($_ < 	3015	) ?  	664	:
							($_ < 	3025	) ?  	666	:
							($_ < 	3035	) ?  	668	:
							($_ < 	3045	) ?  	670	:
							($_ < 	3055	) ?  	672	:
							($_ < 	3065	) ?  	674	:
							($_ < 	3075	) ?  	676	:
							($_ < 	3085	) ?  	678	:
							($_ < 	3095	) ?  	680	:
							($_ < 	3105	) ?  	682	:
							($_ < 	3115	) ?  	684	:
							($_ < 	3125	) ?  	686	:
							($_ < 	3135	) ?  	688	:
							($_ < 	3145	) ?  	690	:
							($_ < 	3155	) ?  	692	:
							($_ < 	3165	) ?  	694	:
							($_ < 	3175	) ?  	696	:
							($_ < 	3185	) ?  	698	:
							($_ < 	3195	) ?  	700	:
							($_ < 	3205	) ?  	702	:
							($_ < 	3215	) ?  	704	:
							($_ < 	3225	) ?  	707	:
							($_ < 	3235	) ?  	709	:
							($_ < 	3245	) ?  	711	:
							($_ < 	3255	) ?  	713	:
							($_ < 	3265	) ?  	715	:
							($_ < 	3275	) ?  	718	:
							($_ < 	3285	) ?  	720	:
							($_ < 	3295	) ?  	722	:
							($_ < 	3305	) ?  	725	:
							($_ < 	3315	) ?  	727	:
							($_ < 	3325	) ?  	729	:
							($_ < 	3335	) ?  	732	:
							($_ < 	3345	) ?  	734	:
							($_ < 	3355	) ?  	736	:
							($_ < 	3365	) ?  	739	:
							($_ < 	3375	) ?  	741	:
							($_ < 	3385	) ?  	744	:
							($_ < 	3395	) ?  	746	:
							($_ < 	3405	) ?  	749	:
							($_ < 	3415	) ?  	751	:
							($_ < 	3425	) ?  	754	:
							($_ < 	3435	) ?  	756	:
							($_ < 	3445	) ?  	759	:
							($_ < 	3455	) ?  	762	:
							($_ < 	3465	) ?  	764	:
							($_ < 	3475	) ?  	767	:
							($_ < 	3485	) ?  	770	:
							($_ < 	3495	) ?  	772	:
							($_ < 	3505	) ?  	775	:
							($_ < 	3515	) ?  	778	:
							($_ < 	3525	) ?  	780	:
							($_ < 	3535	) ?  	783	:
							($_ < 	3545	) ?  	786	:
							($_ < 	3555	) ?  	789	:
							($_ < 	3565	) ?  	792	:
							($_ < 	3575	) ?  	795	:
							($_ < 	3585	) ?  	797	:
							($_ < 	3595	) ?  	800	:
							($_ < 	3605	) ?  	803	:
									803
					}				
				} elsif ($cs_child_number == 5) {					
					for ($combined_adj_income_w) {				
						$cs_obligation_com_w = 			
						 ($_ < 	185	) ?  	83	:
						($_ < 	195	) ?  	88	:
						($_ < 	205	) ?  	93	:
						($_ < 	215	) ?  	98	:
						($_ < 	225	) ?  	103	:
						($_ < 	235	) ?  	107	:
						($_ < 	245	) ?  	112	:
						($_ < 	255	) ?  	117	:
						($_ < 	265	) ?  	122	:
						($_ < 	275	) ?  	127	:
						($_ < 	285	) ?  	131	:
						($_ < 	295	) ?  	136	:
						($_ < 	305	) ?  	140	:
						($_ < 	315	) ?  	145	:
						($_ < 	325	) ?  	150	:
						($_ < 	335	) ?  	154	:
						($_ < 	345	) ?  	159	:
						($_ < 	355	) ?  	163	:
						($_ < 	365	) ?  	167	:
						($_ < 	375	) ?  	172	:
						($_ < 	385	) ?  	176	:
						($_ < 	395	) ?  	181	:
						($_ < 	405	) ?  	185	:
						($_ < 	415	) ?  	189	:
						($_ < 	425	) ?  	193	:
						($_ < 	435	) ?  	197	:
						($_ < 	445	) ?  	202	:
						($_ < 	455	) ?  	206	:
						($_ < 	465	) ?  	210	:
						($_ < 	475	) ?  	214	:
						($_ < 	485	) ?  	218	:
						($_ < 	495	) ?  	222	:
						($_ < 	505	) ?  	226	:
						($_ < 	515	) ?  	230	:
						($_ < 	525	) ?  	234	:
						($_ < 	535	) ?  	238	:
						($_ < 	545	) ?  	242	:
						($_ < 	555	) ?  	245	:
						($_ < 	565	) ?  	249	:
						($_ < 	575	) ?  	253	:
						($_ < 	585	) ?  	257	:
						($_ < 	595	) ?  	260	:
						($_ < 	605	) ?  	264	:
						($_ < 	615	) ?  	268	:
						($_ < 	625	) ?  	271	:
						($_ < 	635	) ?  	275	:
						($_ < 	645	) ?  	278	:
						($_ < 	655	) ?  	282	:
						($_ < 	665	) ?  	285	:
						($_ < 	675	) ?  	289	:
						($_ < 	685	) ?  	292	:
						($_ < 	695	) ?  	296	:
						($_ < 	705	) ?  	299	:
						($_ < 	715	) ?  	303	:
						($_ < 	725	) ?  	306	:
						($_ < 	735	) ?  	309	:
						($_ < 	745	) ?  	313	:
						($_ < 	755	) ?  	316	:
						($_ < 	765	) ?  	319	:
						($_ < 	775	) ?  	322	:
						($_ < 	785	) ?  	325	:
						($_ < 	795	) ?  	329	:
						($_ < 	805	) ?  	332	:
						($_ < 	815	) ?  	335	:
						($_ < 	825	) ?  	338	:
						($_ < 	835	) ?  	341	:
						($_ < 	845	) ?  	344	:
						($_ < 	855	) ?  	347	:
						($_ < 	865	) ?  	350	:
						($_ < 	875	) ?  	353	:
						($_ < 	885	) ?  	356	:
						($_ < 	895	) ?  	359	:
						($_ < 	905	) ?  	362	:
						($_ < 	915	) ?  	365	:
						($_ < 	925	) ?  	367	:
						($_ < 	935	) ?  	370	:
						($_ < 	945	) ?  	373	:
						($_ < 	955	) ?  	376	:
						($_ < 	965	) ?  	379	:
						($_ < 	975	) ?  	381	:
						($_ < 	985	) ?  	384	:
						($_ < 	995	) ?  	387	:
						($_ < 	1005	) ?  	389	:
						($_ < 	1015	) ?  	392	:
						($_ < 	1025	) ?  	395	:
						($_ < 	1035	) ?  	397	:
						($_ < 	1045	) ?  	400	:
						($_ < 	1055	) ?  	402	:
						($_ < 	1065	) ?  	405	:
						($_ < 	1075	) ?  	408	:
						($_ < 	1085	) ?  	410	:
						($_ < 	1095	) ?  	412	:
						($_ < 	1105	) ?  	415	:
						($_ < 	1115	) ?  	417	:
						($_ < 	1125	) ?  	420	:
						($_ < 	1135	) ?  	422	:
						($_ < 	1145	) ?  	425	:
						($_ < 	1155	) ?  	427	:
						($_ < 	1165	) ?  	429	:
						($_ < 	1175	) ?  	432	:
						($_ < 	1185	) ?  	434	:
						($_ < 	1195	) ?  	436	:
						($_ < 	1205	) ?  	439	:
						($_ < 	1215	) ?  	441	:
						($_ < 	1225	) ?  	443	:
						($_ < 	1235	) ?  	445	:
						($_ < 	1245	) ?  	447	:
						($_ < 	1255	) ?  	450	:
						($_ < 	1265	) ?  	452	:
						($_ < 	1275	) ?  	454	:
						($_ < 	1285	) ?  	456	:
						($_ < 	1295	) ?  	458	:
						($_ < 	1305	) ?  	460	:
						($_ < 	1315	) ?  	462	:
						($_ < 	1325	) ?  	464	:
						($_ < 	1335	) ?  	467	:
						($_ < 	1345	) ?  	469	:
						($_ < 	1355	) ?  	471	:
						($_ < 	1365	) ?  	473	:
						($_ < 	1375	) ?  	475	:
						($_ < 	1385	) ?  	477	:
						($_ < 	1395	) ?  	479	:
						($_ < 	1405	) ?  	481	:
						($_ < 	1415	) ?  	482	:
						($_ < 	1425	) ?  	484	:
						($_ < 	1435	) ?  	486	:
						($_ < 	1445	) ?  	488	:
						($_ < 	1455	) ?  	490	:
						($_ < 	1465	) ?  	492	:
						($_ < 	1475	) ?  	494	:
						($_ < 	1485	) ?  	496	:
						($_ < 	1495	) ?  	497	:
						($_ < 	1505	) ?  	499	:
						($_ < 	1515	) ?  	501	:
						($_ < 	1525	) ?  	503	:
						($_ < 	1535	) ?  	505	:
						($_ < 	1545	) ?  	506	:
						($_ < 	1555	) ?  	508	:
						($_ < 	1565	) ?  	510	:
						($_ < 	1575	) ?  	512	:
						($_ < 	1585	) ?  	513	:
						($_ < 	1595	) ?  	515	:
						($_ < 	1605	) ?  	517	:
						($_ < 	1615	) ?  	518	:
						($_ < 	1625	) ?  	520	:
						($_ < 	1635	) ?  	522	:
						($_ < 	1645	) ?  	523	:
						($_ < 	1655	) ?  	525	:
						($_ < 	1665	) ?  	527	:
						($_ < 	1675	) ?  	528	:
						($_ < 	1685	) ?  	530	:
						($_ < 	1695	) ?  	532	:
						($_ < 	1705	) ?  	533	:
						($_ < 	1715	) ?  	535	:
						($_ < 	1725	) ?  	536	:
						($_ < 	1735	) ?  	538	:
						($_ < 	1745	) ?  	540	:
						($_ < 	1755	) ?  	541	:
						($_ < 	1765	) ?  	543	:
						($_ < 	1775	) ?  	544	:
						($_ < 	1785	) ?  	546	:
						($_ < 	1795	) ?  	547	:
						($_ < 	1805	) ?  	549	:
						($_ < 	1815	) ?  	550	:
						($_ < 	1825	) ?  	552	:
						($_ < 	1835	) ?  	553	:
						($_ < 	1845	) ?  	555	:
						($_ < 	1855	) ?  	556	:
						($_ < 	1865	) ?  	558	:
						($_ < 	1875	) ?  	559	:
						($_ < 	1885	) ?  	561	:
						($_ < 	1895	) ?  	562	:
						($_ < 	1905	) ?  	564	:
						($_ < 	1915	) ?  	565	:
						($_ < 	1925	) ?  	567	:
						($_ < 	1935	) ?  	568	:
						($_ < 	1945	) ?  	569	:
						($_ < 	1955	) ?  	571	:
						($_ < 	1965	) ?  	572	:
						($_ < 	1975	) ?  	574	:
						($_ < 	1985	) ?  	575	:
						($_ < 	1995	) ?  	577	:
						($_ < 	2005	) ?  	578	:
						($_ < 	2015	) ?  	579	:
						($_ < 	2025	) ?  	581	:
						($_ < 	2035	) ?  	582	:
						($_ < 	2045	) ?  	584	:
						($_ < 	2055	) ?  	585	:
						($_ < 	2065	) ?  	586	:
						($_ < 	2075	) ?  	588	:
						($_ < 	2085	) ?  	589	:
						($_ < 	2095	) ?  	591	:
						($_ < 	2105	) ?  	592	:
						($_ < 	2115	) ?  	593	:
						($_ < 	2125	) ?  	595	:
						($_ < 	2135	) ?  	596	:
						($_ < 	2145	) ?  	598	:
						($_ < 	2155	) ?  	599	:
						($_ < 	2165	) ?  	600	:
						($_ < 	2175	) ?  	602	:
						($_ < 	2185	) ?  	603	:
						($_ < 	2195	) ?  	604	:
						($_ < 	2205	) ?  	606	:
						($_ < 	2215	) ?  	607	:
						($_ < 	2225	) ?  	609	:
						($_ < 	2235	) ?  	610	:
						($_ < 	2245	) ?  	611	:
						($_ < 	2255	) ?  	613	:
						($_ < 	2265	) ?  	614	:
						($_ < 	2275	) ?  	616	:
						($_ < 	2285	) ?  	617	:
						($_ < 	2295	) ?  	618	:
						($_ < 	2305	) ?  	620	:
						($_ < 	2315	) ?  	621	:
						($_ < 	2325	) ?  	623	:
						($_ < 	2335	) ?  	624	:
						($_ < 	2345	) ?  	625	:
						($_ < 	2355	) ?  	627	:
						($_ < 	2365	) ?  	628	:
						($_ < 	2375	) ?  	630	:
						($_ < 	2385	) ?  	631	:
						($_ < 	2395	) ?  	632	:
						($_ < 	2405	) ?  	634	:
						($_ < 	2415	) ?  	635	:
						($_ < 	2425	) ?  	637	:
						($_ < 	2435	) ?  	638	:
						($_ < 	2445	) ?  	640	:
						($_ < 	2455	) ?  	641	:
						($_ < 	2465	) ?  	642	:
						($_ < 	2475	) ?  	644	:
						($_ < 	2485	) ?  	645	:
						($_ < 	2495	) ?  	647	:
						($_ < 	2505	) ?  	648	:
						($_ < 	2515	) ?  	650	:
						($_ < 	2525	) ?  	651	:
						($_ < 	2535	) ?  	653	:
						($_ < 	2545	) ?  	654	:
						($_ < 	2555	) ?  	656	:
						($_ < 	2565	) ?  	657	:
						($_ < 	2575	) ?  	659	:
						($_ < 	2585	) ?  	660	:
						($_ < 	2595	) ?  	662	:
						($_ < 	2605	) ?  	663	:
						($_ < 	2615	) ?  	665	:
						($_ < 	2625	) ?  	666	:
						($_ < 	2635	) ?  	668	:
						($_ < 	2645	) ?  	669	:
						($_ < 	2655	) ?  	671	:
						($_ < 	2665	) ?  	673	:
						($_ < 	2675	) ?  	674	:
						($_ < 	2685	) ?  	676	:
						($_ < 	2695	) ?  	677	:
						($_ < 	2705	) ?  	679	:
						($_ < 	2715	) ?  	681	:
						($_ < 	2725	) ?  	682	:
						($_ < 	2735	) ?  	684	:
						($_ < 	2745	) ?  	685	:
						($_ < 	2755	) ?  	687	:
						($_ < 	2765	) ?  	689	:
						($_ < 	2775	) ?  	691	:
						($_ < 	2785	) ?  	692	:
						($_ < 	2795	) ?  	694	:
						($_ < 	2805	) ?  	696	:
						($_ < 	2815	) ?  	697	:
						($_ < 	2825	) ?  	699	:
						($_ < 	2835	) ?  	701	:
						($_ < 	2845	) ?  	703	:
						($_ < 	2855	) ?  	704	:
						($_ < 	2865	) ?  	706	:
						($_ < 	2875	) ?  	708	:
						($_ < 	2885	) ?  	710	:
						($_ < 	2895	) ?  	712	:
						($_ < 	2905	) ?  	713	:
						($_ < 	2915	) ?  	715	:
						($_ < 	2925	) ?  	717	:
						($_ < 	2935	) ?  	719	:
						($_ < 	2945	) ?  	721	:
						($_ < 	2955	) ?  	723	:
						($_ < 	2965	) ?  	725	:
						($_ < 	2975	) ?  	727	:
						($_ < 	2985	) ?  	728	:
						($_ < 	2995	) ?  	730	:
						($_ < 	3005	) ?  	732	:
						($_ < 	3015	) ?  	734	:
						($_ < 	3025	) ?  	736	:
						($_ < 	3035	) ?  	738	:
						($_ < 	3045	) ?  	740	:
						($_ < 	3055	) ?  	742	:
						($_ < 	3065	) ?  	744	:
						($_ < 	3075	) ?  	747	:
						($_ < 	3085	) ?  	749	:
						($_ < 	3095	) ?  	751	:
						($_ < 	3105	) ?  	753	:
						($_ < 	3115	) ?  	755	:
						($_ < 	3125	) ?  	757	:
						($_ < 	3135	) ?  	759	:
						($_ < 	3145	) ?  	762	:
						($_ < 	3155	) ?  	764	:
						($_ < 	3165	) ?  	766	:
						($_ < 	3175	) ?  	768	:
						($_ < 	3185	) ?  	770	:
						($_ < 	3195	) ?  	773	:
						($_ < 	3205	) ?  	775	:
						($_ < 	3215	) ?  	777	:
						($_ < 	3225	) ?  	780	:
						($_ < 	3235	) ?  	782	:
						($_ < 	3245	) ?  	784	:
						($_ < 	3255	) ?  	787	:
						($_ < 	3265	) ?  	789	:
						($_ < 	3275	) ?  	792	:
						($_ < 	3285	) ?  	794	:
						($_ < 	3295	) ?  	796	:
						($_ < 	3305	) ?  	799	:
						($_ < 	3315	) ?  	801	:
						($_ < 	3325	) ?  	804	:
						($_ < 	3335	) ?  	807	:
						($_ < 	3345	) ?  	809	:
						($_ < 	3355	) ?  	812	:
						($_ < 	3365	) ?  	814	:
						($_ < 	3375	) ?  	817	:
						($_ < 	3385	) ?  	820	:
						($_ < 	3395	) ?  	822	:
						($_ < 	3405	) ?  	825	:
						($_ < 	3415	) ?  	828	:
						($_ < 	3425	) ?  	830	:
						($_ < 	3435	) ?  	833	:
						($_ < 	3445	) ?  	836	:
						($_ < 	3455	) ?  	839	:
						($_ < 	3465	) ?  	842	:
						($_ < 	3475	) ?  	844	:
						($_ < 	3485	) ?  	847	:
						($_ < 	3495	) ?  	850	:
						($_ < 	3505	) ?  	853	:
						($_ < 	3515	) ?  	856	:
						($_ < 	3525	) ?  	859	:
						($_ < 	3535	) ?  	862	:
						($_ < 	3545	) ?  	865	:
						($_ < 	3555	) ?  	868	:
						($_ < 	3565	) ?  	871	:
						($_ < 	3575	) ?  	874	:
						($_ < 	3585	) ?  	877	:
						($_ < 	3595	) ?  	880	:
						($_ < 	3605	) ?  	884	:
							884
					}				
				} 
				# did not include 6 children cs obligation because only including up to 5 children in NJ 2021. 
				#calculate total amt of child support obligation = base monthly support + monthly child care costs + children's health insurance premium or cash medical support. 
				$cs_obligation_com = $cs_obligation_com_w * 4.3; #calculate monthly cs obligation.
				$total_child_support_oblig_m = $cs_obligation_com + $cs_cc_expenses_total_m  + $ext_med_expenses_m + $total_cs_premiumcost_m; 
				#not including "court-approved extraordinary expenses" for now for NJ 2021. this appears to be at the court's discretion.

				$ncp_cs_obligation = greatest($ncp_income_ratio * $total_child_support_oblig_m, $child_support_min); #This initial  calculation of child support owed seemed missing before.

				$cp_cs_obligation = $cp_income_ratio * $total_child_support_oblig_m * 12; #calculated for self-support reserve test.


				#Calculate child support obligations after testing for self support reserve
				
				#Self-support reserve test:
				if ($ncp_adj_income - $ncp_cs_obligation * 12 >= $self_support_reserve_poverty_pct * $fpl_forone){

					$child_support_paid_m = $ncp_cs_obligation; #The ncp can afford to pay their obligation and does.

				} elsif ($cp_adj_income - $cp_cs_obligation * 12 < $self_support_reserve_poverty_pct * $fpl_forone) {

					$child_support_paid_m = $ncp_cs_obligation; #The cp cannot afford to pay their obligation and so the ncp pays their own obligation, even if they can't afford it based on the self-support test.

				} elsif ($ncp_adj_income - $ncp_cs_obligation * 12 < $self_support_reserve_poverty_pct * $fpl_forone && $cp_adj_income - $cp_cs_obligation * 12 >= $self_support_reserve_poverty_pct * $fpl_forone){

					$child_support_paid_m = greatest(pos_sub($ncp_adj_income,$self_support_reserve_poverty_pct * $fpl_forone),$child_support_min); #The ncp cannot afford to pay their obligation and the cp can afford to pay for basic expenses after accounting for the basic expenses the child needs, so the remainder of the noncustodial adjusted income after accounting for their own needs go to the custodial parent.

				}
				$child_support_paid = $child_support_paid_m *12;
				#Normally, the costs incurred by the ncp for care of the child (work-related child care, health insurance, visiting time, other expenses) would be deducted from the child support obligation, but for NJ 2021, we are assuming the ncp does not incur other costs for the children under the support order 
				#for NJ 2021, we are also assuming neither parent is requesting the "other dependent deduction"

				#if ($out->{'tanflock'} == 1 && $out->{'taxes_calculated'} == 0 && $child_support_paid_m > $tanf_recd_m && ($out->{'parent_workhours_w'} > $out->{'parent1_employedhours_w'} || ($out->{'parent_workhours_w'} > $out->{'parent2_employedhours_w'})) { #See notes in tanf code for why this is needed in some states. In certain instances, we can use tanflock -- defined simply as 0 in parent_earnings and 1 at the end of tanflock if tanf<0, to defer to the previously calculated child support if child support has already been calculated once, then tanf was calculated as positive (and therby higher than child_support, per NJ rules), then that tanf receipt results in increased child care need due to work requirements, and then based on that higher child care need, the child support order formula would result in an increase of child support high enough to disable this family from tanf receipt. For NJ, this type of consideration would have to be run after state taxes have been calculated, since those are crucial for determining a more accurate estimate of child support. The idea behind this was to avoid a nonsensical situation in which a family is paying a lot for transportation and child care resulting from tanf work requirements, has not yet been calculated, and then in this second run of child support, we find that child support paid results in an amount higher than tanf and any recalculation would result in losing tanf. This would mean that a family could lose access to child care subsidies but also would be enrolling in training and paying for child care to satisfy tanf work requirements when, in the modeled output, there would be no tanf received. However, because in NJ, families can access child care subsidies for 24 months after tanf exit, this possibility in NJ would not result in losing child care subsidies, and because other aspects of child support are also backward-looking (using last year's taxes, for example), the worst outcome of this odd loop for this family would be a parent attending training needlessly, leading to very slightly higher child care costs (because CCDF is based on mostly income and secondarily how many kids attend full time part time care). Given the encouragement of TANF recipients to stay in training regardless of TANF receipt, it seems like a reasonable tradeoff But we recalculate it in case a family gains tanf eligibility due to lower child support payments. We could run this code at the very beginning or skip the outputs in deference to earlier defined variables, but this should work since for the above condition, 
				#	$child_support_paid = $child_support_paid_pretanf;
				#	$child_support_paid_m = $child_support_paid_m_pretanf;			
				#} 			
			}
		}	
		#} else {
		#Commenting this out for now; it seems specific to the microsimulation.
		
		#$child_support_paid_m = $in->{'child_support_paid_m'}; #This is equivalent in other child support codes from administrative data as in->{'child_support_recd_m'}; + $in->{'child_support_retained_initial'}.
		#$child_support_paid = 12* $child_support_paid_m;
		#$child_support_recd = $child_support_paid; #These will be recalculated in the tanf module, but we need to know them for Head Start calculations in the child care module.
		#$child_support_recd_m = $child_support_paid_m; #These will be recalculated in the tanf module, but we need to know them for Head Start calculations in the child care module.
	}
		
	# outputs 
	#
	foreach my $name (qw(child_support_paid child_support_paid_m cs_child_number)) {
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;