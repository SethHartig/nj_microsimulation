#=============================================================================#
#  LIHEAP Module –  NJ 2021 adapted from KY 2020
#=============================================================================#
#
#	INPUTS NEEDED
#
#	INPUTS FROM BASE
#		liheap
#		disability_personal_expenses_m
#		disability_parent1
#		disability_parent2
#		parent1_age
#		parent2_age
#		savings
#		fuel_source
#		parent#_immigration_status 
#		spousal_sup_ncp
#
#	INPUTS FROM FRS.PM
#		fpl
#
#	OUTPUTS FROM FRS.PL
#		earnings
#
#	OUTPUTS FROM SECTION 8
#		housing_subsidized
#		rent_paid
#		rent_paid_m
#
#	OUTPUTS FROM SSI
#		ssi_recd
#
#	OUTPUTS FROM TANF
#		tanf_recd
#		child_support_recd
#
#	OUTPUTS FROM INTEREST
#		interest
#
#	OUTPUTS FROM FSP ASSETS
#		average_electric_cost
#		average_naturalgas_cost
#
#	OUTPUTS FROM FLI/TDI
#		fli_plus_tdi_recd
#
#	FOSTER CARE
#		foster_care_payment
#=============================================================================#
#SS 7.15.21 -  The amount of the LIHEAP heating benefit is determined by income, household size, fuel type, and heating region. 


sub liheap
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};

	# interim variables created in macro
	our $liheap_income = 0;			#Total of income sources used for LIHEAP eligibilty determination
	# outputs created
	our $liheap_income_m = 0;
	our $liheap_income_pov_pct = 0; 	#SS 7.15.21 - must be at or below 200% of FPL.
	our $liheap_recd = 0;			# annual value of LIHEAP received
	#	our $applicable_liheap_asset_limit = 0; # SS 7.15.21 -NJ's LIHEAP program does not have an asset test. 
	#	our $liheap_asset_limit = 2000;		# SS 7.15.21 -NJ's LIHEAP program does not have an asset test. 
	#	our $liheap_asset_limit_eldordis = 3000; #SS 7.15.21 - NJ's LIHEAP program does not have an asset test.
	#	our $liheap_asset_limit_medneeds = 4000; #SS 7.15.21 - NJ's LIHEAP program does not have an asset test.
	our $liheap_exempt_income = 0; #Let's keep this general in case there's other income to exempt.
	our $unqual_earnings_exempt = 3600;
	our $unit_size = 0;
	our $liheap_60pctsmi = 0;
	our $usf_eligible = 0; 	#flag for whether a household is eligible for the Universal Service Fund. 
	our $unit_fpl = 0; #fpl according to unit size to calculate eligibility for USF
	our $rent_paid = $out->{'rent_paid'};
	our $rent_paid_m = $out->{'rent_paid_m'};
	our $liheap_potential = 0;
	our $remaining_energy_costs = 0;
	our $usf_benefit = 0;
	our $maximum_usf_benefit = 2160;
	our $usf_limit = 4.0; #USF benefit limit as a percentage of poverty.
	#https://www.nj.gov/dca/divisions/dhcr/faq/usf.html#q5 
	# liheap detailed model plan effective 10/1/2021 - 9/30/2022: https://www.nj.gov/dca/divisions/dhcr/offices/docs/LIHEAP/LIHEAP%20DETAILED%20MODEL%20PLAN%202020.pdf 
	
	#Calculate sum of eligible people in the household. 
	
	#NOTE ON IMMIGRANTS: Only qualified aliens are allows to receive liheap benefits. "In cases where a non-qualified alien resides within an applicant household, the non qualified alien must be excluded from the HEA household size. If the non-qualified alien has monthly income in excess of $300.00, the amount in excess of $300.00 shall be counted as income to the household and must be added to all other household income in determining the household's gross monthly income."  LIHEAP Handbook, page 25. https://nj.gov/dca/divisions/dhcr/offices/docs/liheap_handbook.pdf . Undocumented folks are not permitted to receive LIHEAP benefits. 
	# Since Only qualified aliens are eligible for LIHEAP benefits, we must count how many people have undocumented status in the household. See list of programs at this notice: https://www.govinfo.gov/content/pkg/FR-1998-08-04/pdf/98-20491.pdf . There are some exceptions - the notice gives an example of weatherization of multi-unit buildings as part of LIHEAP program. Refugees and asylees are considering qualified aliens. See page 5 of NJ LIHEAP handbook https://www.nj.gov/dca/divisions/dhcr/offices/docs/LIHEAP/LIHEAP%20handbook%20v2.pdf 

	#NOTES ON DACA RECIPIENTS: It appears that DACA recipients are treated similar to undocumented immigrants or non-qualified immigrants. DACA authorizes recipients to be lawfully present in the U.S., but does not confer "lawful status". It does provide employment authorization: https://www.uscis.gov/humanitarian/consideration-of-deferred-action-for-childhood-arrivals-daca/frequently-asked-questions. 

	for (my $i = 1; $i <= $in->{'family_structure'}; $i++)	{
		if ($in->{'parent'.$i.'age'} > 17) { #This is a check to see if this adult exists in the family unit.
			if ($in->{'parent'.$i.'_unqualified'} == 1) { #this input was added to frs.pm starting in 2021
				$liheap_exempt_income =+ &least($unqual_earnings_exempt,$in->{'parent'.$i.'_earnings'});
				#this formula calculates the amount of income earned by undocumented parents that is counted in gross income. In cases where a non-qualified alien resides within an applicant household, the non qualified alien must be excluded from the HEA household size. "If the non-qualified alien has monthly income in excess of $300.00, the amount in excess of $300.00 shall be counted as income to the household and must be added to all other household income in determining the household's gross monthly income." https://www.nj.gov/dca/divisions/dhcr/offices/docs/LIHEAP/LIHEAP%20handbook%20v2.pdf  
			}
		}
	}
	# Determine if LIHEAP flag is used and whether the family is headed by a qualified alien 
	if ($in->{'liheap'} == 0) {
		$liheap_recd = 0;
	} elsif ($in->{'family_structure'} == $in->{'unqualified_immigrant_adult_count'}){	#Added check for whether the family is headed by a qualified alien. These inputs are created in frs.pm.
		$liheap_recd = 0;
	} else {
				
		#NJ's LIHEAP program does not have an asset test. 
		#There are four potential services that NJ's LIHEAP program provides. One is a heating subsidy, another is crisis assistance, a third is weatherization assistance, and a fourth is a cooling subsidy. Majority of funding is for heating assistance (60%), while cooling assistance only consists of 4% of funds. Weatherization supports upgrades to property and crisis assistance is short-term assistance, so are not modeling those here. We are only modeling the heating assistance component.
		
		#As of 2020, there is no categorical eligibility in NJ for LIHEAP assistance. In addition, no funds are directed toward a nominal payment for SNAP households. Continues to be true for FY 2022 plan. Neither are there funds toward a nominal payments for SNAP households. 

		# These rules are taken from the 2019-2020 LIHEAP state plan (2021 was not found), LIHEAP benefits matrix, and other docs found on NJ's website: https://www.nj.gov/dca/divisions/dhcr/offices/hea.html. and updated with 2021-2023 liheap state plan, once it was available. 

		#NATIVE POPULATIONS: There appear to be no special rules re this population, but it states that outreach for the program must involve cooperating groups, including American Indian organizations. NJ LIHEAP Handbook, page 25. 


		$unit_size = $in->{'family_size'} - $in->{'unqualified_immigrant_total_count'};
		
		$liheap_income = pos_sub($out->{'earnings'},$liheap_exempt_income) + $out->{'ssi_recd'} + $out->{'tanf_recd'} + $out->{'child_support_recd'} + $out->{'interest'} + $out->{'ui_recd'} + $in->{'selfemployed_netprofit_total'} + $out->{'fli_plus_tdi_recd'} + $out->{'foster_care_payment'} + $in->{'spousal_sup_ncp'}; #All of these income sources are countable in NJ's LIHEAP program. The handbook cites NJAC 10:90-3.9 for list of countable income, which include child support, self-employed earnings, and spousal support payments, among others. 

		#FOSTER CHILD NOTE: In addition, funds received by household for care of a foster child are counted as income for LIHEAP.“Foster children placed with a family by NJ Department of Children and Families (NJDCF) are to be included in the household size and the allowance paid by NJDCF is to be included in the household's income.” Any payments under Title II (which includes payments to foster grandparents) are excluded. https://nj.gov/dca/divisions/dhcr/offices/docs/liheap_handbook.pdf  
		#we are not including adult students for this iteration of NJ FRS, but for future reference, the earned income of a student enrolled in any school/training program full-time is not considered in the determination of gross income. See updated HEAP handbook. https://www.nj.gov/dca/divisions/dhcr/offices/docs/LIHEAP/LIHEAP%20handbook%20v2.pdf 
		
		# From NJ LIHEAP Handbook: "Parents receiving Social Security or SSI benefits on behalf of their children cannot be considered as not having any source of income" page 8. It does not appear that child and adult SSI income is treated differently. 
		@liheap_smi_array = qw(0 40176 52548 64908 77268 89640 102000 104316 106632); #added by SS 10.13.21 - An updated state plan for LIHEAP was uploaded to the state website for FY 2022. These are rules effective October 2021-Sept 2022. The most noteworthy change was that the program adopted 60% of SMI instead of FPL to assess gross eligibility. The array displays 60% of annualized SMI by household size derived from monthly gross income limits here https://www.nj.gov/dca/divisions/dhcr/offices/docs/usfhea_fact_sheet.pdf 
		$liheap_60pctsmi = $liheap_smi_array[$unit_size]; #updated by SS 10.13.21 to reflect smi based on revised unit_size 
		$liheap_income_m = $liheap_income / 12; 
		#SS 7.15.21 - we are not including social security benefits for this iteration of the FRS, but for later inclusion: "For individuals receiving Social Security benefits the net amount of the monthly check is countable. If the household presents an award letter rather than a check as evidence of income, the CBO must determine if the individual pays a Medicare Part B premium and deduct that amount from the gross amount of the benefit. The resulting balance shall be considered as income to the household." - handbook
		#$liheap_income_pov_pct = $liheap_income / $liheap_smi; #no longer need this.
			
		# The amount of a LIHEAP subsidy is a function of whether a family lives in subsidized housing, household size, the percentage of the poverty line that family income represents, the county of residence, the type of heating fuel a family uses (I think only if the family owns their home - unclear), and whether a family rents or owns their home. 
		# Let's talk abou this: SS 7.15.21 - minimum benefit = $45, max benefit = $1056 for heating assitance. Cooling assistance is a $200 benefit for medical necessity. The household must have at least one member with a medical condition which requires cooling. At this time, we are not modeling cooling assistance, only heating. 
		#the tables have been updated based on the newest liheap tables that have been released as part of the FY 2022 plan. 

		if ($liheap_income > $liheap_60pctsmi) { #An updated state plan for LIHEAP was uploaded to the state website for FY 2022. These are rules effective October 2021-Sept 2022. The program adopted 60% of SMI instead of 200% of FPL to assess gross eligibility.
			$liheap_recd = 0;
		} elsif ($out->{'housing_subsidized'} == 0 || $in->{'heat_in_rent'} == 0) {	#There is some local policy variation here: residence 19 refers to Sussex County, residence 21 refers to Warren county - these counties have slightly different liheap benefits. "To be eligible for LIHEAP benefits, the applicant household must be responsible for home heating or cooling costs, either directly or included in the rent; and have gross income at or below 200% of the federal poverty level." update by SS 10.13.21 - in the NJ handbook, it states that people in public housing or those receiving rent subsidies which include all heating costs are not eligible "regardless of income eligibility" unless they can prove that it has a direct responsibility for payment of its heating costs. 
			if ($in->{'heat_in_rent'} == 0) {
				if ($in->{'fuel_source'} eq 'electric') {
					if ($in->{'residence'} != 19 && $in->{'residence'} != 21)  {
						if ($unit_size <= 4) { #SS 7.15.21 - if fuel source is electric, family size is 4 or lower, and the person does not live in either Sussex or Warren counties, then follow this formula.
							for ($liheap_income_m)  {						
								$liheap_potential = 	($_ < 6440) ? 	529	 : 
												($_ < 8887) ? 	442	 :
												($_ < 9660) ? 	352	 :
												265;
							}
						} elsif ($unit_size <= 8) { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	710	 :
												($_ < 8887) ? 	591	 :
												($_ < 9660) ? 	473	 :
												354;					#Revised for 2022 policy: if the income level is greater than or equal to 9660 and less than liheap poverty level, then the benefit levels for these households will be $354/month.
							}
						} elsif ($unit_size <= 12) {
							for ($liheap_income_m) {	
								$liheap_potential = 	($_ < 6440) ? 	846	 :
												($_ < 8887) ? 	705	 :
												($_ < 9660) ? 	564	 :
												424;				
							}
						} else { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	931	 :
												($_ < 8887) ? 	776	 :
												($_ < 9660) ? 	620	 :
												466;				
							}
						}
					} else { #residence is either 21 or 19 (Warren or Sussex).
						if ($unit_size <= 4) { 
							for ($liheap_income_m)  {						
								$liheap_potential = ($_ < 6440) ? 	606	 :
											   ($_ < 8887) ? 	506	 :
											   ($_ < 9660) ? 	404	 :
											    304;			
							}
						} elsif ($unit_size <=8) { 
							for ($liheap_income_m) {						
								$liheap_potential = ($_ < 6440) ? 	821	 :
											   ($_ < 8887) ? 	675	 :
											   ($_ < 9660) ? 	541	 :
											    406;	
							}
						} elsif ($unit_size <= 12) {
							for ($liheap_income_m) {	
								$liheap_potential = 	($_ < 6440) ? 	970	 :
												($_ < 8887) ? 	807	 :
												($_ < 9660) ? 	646	 :
												485;				
							}	
						} else { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	1067	 :
												($_ < 8887) ? 	888	 :
												($_ < 9660) ? 	711	 :
												534;	
							}
						}
					}
				} elsif ($in->{'fuel_source'} eq 'gas') {
					if ($in->{'residence'} != 19 && $in->{'residence'} != 21)  {
						if  ($unit_size <= 4) { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	334	 :
												($_ < 8887) ? 	278	 :
												($_ < 9660) ? 	222	 :
												167;
							}
						} elsif ($unit_size <=8) { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	448	 :
												($_ < 8887) ? 	373	 :
												($_ < 9660) ? 	298	 :
												224;
							}
						} elsif ($unit_size <= 12) {
							for ($liheap_income_m) {	
								$liheap_potential = 	($_ < 6440) ? 	535	 :
												($_ < 8887) ? 	446	 :
												($_ < 9660) ? 	355	 :
												267;				
							}		
						} else { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	589	 :
												($_ < 8887) ? 	491	 :
												($_ < 9660) ? 	391	 :
												294;
							}
						}						
					} else { #$in->{'residence'} == 19 || $in->{'residence'} == 21) 
						if ($unit_size <= 4) { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	383	 :
												($_ < 8887) ? 	318	 :
												($_ < 9660) ? 	254	 :
												191;
							}
						} elsif ($unit_size <= 8) { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	512	 :
												($_ < 8887) ? 	427	 :
												($_ < 9660) ? 	341	 :
												256;
							}
						} elsif ($unit_size <= 12) {
							for ($liheap_income_m) {	
								$liheap_potential = 	($_ < 6440) ? 	612	 :
												($_ < 8887) ? 	509	 :
												($_ < 9660) ? 	408	 :
												306;				
							}					
						} else { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	673	 :
												($_ < 8887) ? 	560	 :
												($_ < 9660) ? 	445	 :
												337;
							}
						}
					}
				} else { 
					#These are the rates for "deliverables," which refer to non-gas and non-electric vehicles of fuel consumption, e.g. oil and propane. It seems safe to assume that, especially since according to the LIHEAP manual (page 11), peole who get their heat through the following non-electric and non-gas sources are eligible for LIHEAP benefits: oil, propane, kerosene, coal, wood. So these are separate fuel types that we'll be adding to the NJ fuel type dropdown. I've added this below, using "else" to capture the remaining fuel types.
					if ($in->{'residence'} != 19 && $in->{'residence'} != 21)  {
						if  ($unit_size <= 4) { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	641	 :
												($_ < 8887) ? 	535	 :
												($_ < 9660) ? 	428	 :
												321;
							}
						} elsif ($unit_size <= 8) { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	859	 :
												($_ < 8887) ? 	715	 :
												($_ < 9660) ? 	573	 :
												428;
							}
						} elsif ($unit_size <= 12) {
							for ($liheap_income_m) {	
								$liheap_potential = 	($_ < 6440) ? 	1025	 :
												($_ < 8887) ? 	855	 :
												($_ < 9660) ? 	685	 :
												513;				
							}							
						} else { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	1128	 :
												($_ < 8887) ? 	941	 :
												($_ < 9660) ? 	754	 :
												564;
							}
						}
					} else { #$in->{'residence'} == 19 || $in->{'residence'} == 21) 
						if  ($unit_size <= 4) { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	961	 :
												($_ < 8887) ? 	613	 :
												($_ < 9660) ? 	491	 :
												366;
							}
						} elsif ($unit_size <= 8) { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	983	 :
												($_ < 8887) ? 	820	 :
												($_ < 9660) ? 	657	 :
												493;
							}
						} elsif ($unit_size <= 12) {
							for ($liheap_income_m) {	
								$liheap_potential = 	($_ < 6440) ? 	1162	 :
												($_ < 8887) ? 	979	 :
												($_ < 9660) ? 	784	 :
												587;				
							}							
						} else { 
							for ($liheap_income_m) {						
								$liheap_potential = 	($_ < 6440) ? 	1278	 :
												($_ < 8887) ? 	1077	 :
												($_ < 9660) ? 	862	 :
												646;
							}
						}
					}
				}
			} else { #renter pays heat in rent but is not in subsidized housing.
				if ($in->{'residence'} != 19 && $in->{'residence'} != 21)  {
					if  ($unit_size <= 4) { 
						for ($liheap_income_m) {						
							$liheap_potential = 	($_ < 6440) ? 	234	 :
											($_ < 8887) ? 	196	 :
											($_ < 9660) ? 	156	 :
											118;
						}
					} elsif ($unit_size <= 8) { 
						for ($liheap_income_m) {						
							$liheap_potential = 	($_ < 6440) ? 	312	 :
											($_ < 8887) ? 	262	 :
											($_ < 9660) ? 	208	 :
											157;
						}
					} elsif ($unit_size <= 12) {
						for ($liheap_income_m) {	
							$liheap_potential = 	($_ < 6440) ? 	374	 :
											($_ < 8887) ? 	312	 :
											($_ < 9660) ? 	250	 :
											186;				
						}							
					} else { 
						for ($liheap_income_m) {						
							$liheap_potential = 	($_ < 6440) ? 	411	 :
											($_ < 8887) ? 	343	 :
											($_ < 9660) ? 	275	 :
											205;
						}
					}	
				} else { #$in->{'residence'} == 19 || $in->{'residence'} == 21)
					if  ($unit_size <= 4) { 
						for ($liheap_income_m) {						
							$liheap_potential = 	($_ < 6440) ? 	267	 :
											($_ < 8887) ? 	222	 :
											($_ < 9660) ? 	179	 :
											134;
						}
					} elsif ($unit_size <= 8) { 
						for ($liheap_income_m) {						
							$liheap_potential = 	($_ < 6440) ? 	360	 :
											($_ < 8887) ? 	299	 :
											($_ < 9660) ? 	240	 :
											179;
						}
					} elsif ($unit_size <= 12) {
						for ($liheap_income_m) {	
							$liheap_potential = 	($_ < 6440) ? 	428	 :
											($_ < 8887) ? 	358	 :
											($_ < 9660) ? 	286	 :
											216;				
						}							
					} else { 
						for ($liheap_income_m) {						
							$liheap_potential = 	($_ < 6440) ? 	471	 :
											($_ < 8887) ? 	394	 :
											($_ < 9660) ? 	315	 :
											238;
						}
					}
				}
			}
		}			
		#We use natural gas cost as a proxy for heating costs regardless of energy source. For USF calculations, we need to know how much the household pays for heating and electicity after LIHEAP is calcualated.
		if ($in->{'fuel_source'} eq 'electric') {
			$liheap_recd = least(($out->{'average_naturalgas_cost'} + $out->{'average_electric_cost'})*12,$liheap_potential);
			$remaining_energy_costs = pos_sub(($out->{'average_naturalgas_cost'} + $out->{'average_electric_cost'})*12,$liheap_recd);
		} else {
			$liheap_recd = least($out->{'average_naturalgas_cost'}*12,$liheap_potential);
			$remaining_energy_costs = pos_sub($out->{'average_naturalgas_cost'}*12,$liheap_recd); 
			#The liheap benefit is given to the utility company when households heat by electricity or natural gas. Households that heat with other fuel sources get an automatic payment in the form of a two party check payable to the head of household and the generic co-payee "your heating supplier." See liheap handbook page 10.
			#"All Home Energy Assistance benefits must be used to offset current costs of home energy", so there is no benefit on top of LIHEAP benefits.
		}	
		
		
		#Universal Service Fund benefits:
		#This is a heating benefit separate from but related to LIHEAP but based on shared rules, such as income rules. Universal Service Fund. Rules for thie program are found at https://www.nj.gov/dca/divisions/dhcr/faq/usf.html#q5 

		#If desired, USF benefits could constitute their own benefit flag, but because of how these programs work together (and because they seem to be based on a shared submission form), we assume that if a family checks teh LIHEAP flag, they also receive USF when eligible.
		
		#Recalculate fpl according to unit size, rather than family_size. 
		#First, determine the poverty level based on teh LIHEAP unit size.
		$sql = "SELECT fpl from FRS_General WHERE state = ? AND year = ? AND size = ?";
		my $stmt = $dbh->prepare($sql) ||
			&fatalError("Unable to prepare $sql: $DBI::errstr");
		my $result = $stmt->execute($in->{'state'}, $in->{'year'}, $unit_size) ||
			&fatalError("Unable to execute $sql: $DBI::errstr");
		$unit_fpl = $stmt->fetchrow();
		$stmt->finish();
		
		#Use the poverty level of teh family coupled with other eligibility criteria to determine program benefits.
		
		#"You must also spend more than 2% of your income for electric service or more than 2% of your income for natural gas service. If you heat your home with electricity, you must spend more than 4% of your income on electricity."

		#TODO: Once we finalize and understand the numbers in this code, assign usf_electric_budget_portion_max as .02 and  usf_heating_budget_portion_max as .02 as well, and use them below, including the addition of them to arrive at .04 for electrically-heated households.

		if ($liheap_income <= $usf_limit * $unit_fpl) {
			#First calculate the gas benefit, similar to the walk-through on the USF website.
			if ($in->{'fuel_source'} eq 'gas' && $remaining_energy_costs > .02 * $liheap_income_m) {
				$usf_benefit = least(pos_sub($remaining_energy_costs, $liheap_income *.02), $maximum_usf_benefit);
			}
			
			#Then calculate the USF electric benefit. This is different if you heat your home with electric heat, but available to all electric consumers (which is everyone in the FRS).
			# "A similar calculation would be made using a customer’s electricity costs. However, the LIHEAP credit is not counted a second time. It is applied only once to the utility providing energy for heating purposes. If you also receive a Lifeline benefit, that benefit is applied to the natural gas and/or electric utility bill based on the information you provided the state."
			if ($in->{'fuel_source'} eq 'electric') {
				if ($remaining_electric_costs > .04 * $liheap_income_m) {
					$usf_benefit = least(pos_sub($remaining_energy_costs, $liheap_income *.04), $maximum_usf_benefit); 
				}
			} else {
				#We add a potnetial additional electric portion of the USF benefit:
				#"The maximum total annual USF benefit for any given household is up to $2,160." Note that the way this is presented, it allows 
				$usf_benefit = least($usf_benefit + pos_sub($out->{'average_electric_cost'}, $liheap_income *.02), $maximum_usf_benefit); #Note that the operator += cannot be used here, and we must add the potential electric benefit within the least command, otherwise we run the risk of the maximum total USF benefit exceeding the maximum allowable benefit.
			}
		}	
	}
	# We now subtract the LIHEAP subsidy and USF benefits from rent paid, as the rent calculation includes fuel costs.
	$rent_paid = &pos_sub($rent_paid, $liheap_recd + $usf_benefit);
	$rent_paid_m = $rent_paid/12;
	
	# outputs
	foreach my $name (qw(liheap_recd rent_paid rent_paid_m usf_benefit)) {
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}
	
1;
											   