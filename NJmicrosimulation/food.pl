#=============================================================================#
#  Food Costs – 2021 (modified from 2020 ) 
#=============================================================================#
# All highlights and brown text represent changes to the existing module
#
# Inputs referenced in this module:
#
#   FROM BASE:
#	family_structure
#	child#_age
#	parent#_age
#	family_size
#	year
#	food_override
#	food_override_amt
#
# SCHOOL AND SUMMER MEALS:
# child_foodcost_red_total	# Total reduction in all children’s food costs due to meals programs
#
# WIC
# wic_recd			# Total reduction in food expenses due to WIC receipt
#=============================================================================#

sub food
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};

  # outputs created
    our $food_expenses = 0; # total annual family food expenses
    our $family_foodcost = 0;       # annual
	our  $subsidized_food = 0; 	# The total amount of food subsidies that the family is receiving.

	# variables used in this script

	# Policy data
	# Costs for low-cost food plan cited below, including food cost adjustments, are available at  https://fns-prod.azureedge.net/sites/default/files/media/file/CostofFoodJan2020.
	our $adult_foodcost = 247.55;
	our $olderparent_foodcost_m =  236.55;    #  (Mean of low-cost food costs between Female aged 51-70 years and Male aged 51-70 years. Source is the USDA Low-Cost food plan issued Nov 2021.) 
	our $yo18parent_foodcost_m =  245.30;    #   (Mean of low-cost food costs between 18-year-old female and 18-year-old male. Source is the USDA Low-Cost food plan issued Nov 2021. That this is only slightly lower than the monthly parent1 and parent2 food cost indicated above makes this a pretty marginal adjustment for this year, but as we are pulling from a federal table that specifically includes ages, it is appropriate to do so at this time. If the table indicates larger differences between adults and 18-year-olds at a later date, this code will already account for that change.
	our $familysize_adjustment = qw(0 1.2 1.1 1.05 1 0.95 0.95 0.90 .90 .90)[$in->{'family_size'}];     # Food cost adjustment

	# Variables generated in program:
	our $parent1_foodcost_m = 0;	# monthly food cost for first parent (Mean of low-cost food costs between Female aged 19-50 years and Male aged 19-50 years. Source is the USDA Low-Cost food plan issued Nov 2021.)
	our $parent2_foodcost_m = 0;	# monthly food cost for second parent. (Mean of low-cost food costs between Female aged 19-50 years and Male aged 19-50 years. Source is the USDA Low-Cost food plan issued Nov 2021.)#
	#	our $parent3_foodcost_m = 235.20;	# monthly food cost for third parent. (Mean of low-cost food costs between Female aged 19-50 years and Male aged 19-50 years. Source is the USDA Low-Cost food plan issued Nov 2021.) Hashed out for now until we are ready to program in 4 adults.
	#	our $parent4_foodcost_m = 235.20;	# monthly food cost for fourth parent. (Mean of low-cost food costs between Female aged 19-50 years and Male aged 19-50 years. Source is the USDA Low-Cost food plan issued Nov 2021.) Hashed out for now until we are ready to program in 4 adults.
	our $child1_foodcost_m  = 0;	 # Monthly food cost per child stratified by age
	our $child2_foodcost_m  = 0;	# Monthly food cost per child stratified by age
	our $child3_foodcost_m  = 0;	 # Monthly food cost per child stratified by age
	our $child4_foodcost_m  = 0;	# Monthly food cost per child stratified by age
	our $child5_foodcost_m  = 0;	# Monthly food cost per child stratified by age
	our $base_foodcost_m = 0;              	# Total monthly (unadjusted) family food cost, based on a family of 4
	our $base_foodcost = 0;                	# NIP: Total annual (unadjusted) family food cost, based on a family of 4. Commenting out for now; delete this if there's no other program that uses this. but comment out if it's not mentioned anywhere else.
	our $family_foodcost_fmred  = 0;	# NIP: the family food costs after accounting for free meals 
	#programs for children
	our $child_nutrition_flag = 0; #Catch-all flag variable important for charts.


    #   1.  Calculate base food cost for each family
    #   Use Food Cost tables to look up Child#_foodcost_m 

	# Adjust individual adult food costs as needed.

	# Adjusting this to accommodate Basic Needs Budget inputs, which allow users to select a family structure of 2 but does not requre users to add in a second parent's age.
	
	for (my $i = 1; $i <= $in->{'family_structure'}; $i++) { 
		${'parent'.$i.'_foodcost_m'} = $adult_foodcost;
		if ($in->{'parent'.$i.'_age'} == 18) {
			${'parent'.$i.'_foodcost_m'} = $yo18parent_foodcost_m;
		} elsif ($in->{'parent'.$i.'_age'} > 50) {
			${'parent'.$i.'_foodcost_m'} = $olderparent_foodcost_m;
		}
	}

	# Get individual children's food costs - alternative way to do this using the MySQL codes, but since hard-coding is easier for now (while SQL codes are separately updated and also because it helps the microsimulation to have Perl codes use hard-coded arrays), keeping off that for now.
	#	my $sql = "SELECT cost FROM FRS_Food WHERE year = ? && age_min <= ? && age_max >= ?";
	#	for (my $i = 1; $i <= 5; $i++) {
	#		if ($in->{'child'.$i.'_age'} != -1) {		
	#			my $stmt = $dbh->prepare($sql) || &fatalError("Unable to prepare $sql: $DBI::errstr");
	#			$stmt->execute($in->{"year"}, $in->{"child".$i."_age"}, $in->{"child".$i."_age"});
	#			${"child".$i."_foodcost_m"} = $stmt->fetchrow();
	#		} else {
	#			${"child".$i."_foodcost_m"} = 0;
	#		}
	#	}
	

		# Get individual children's food costs
		for (my $i = 1; $i <= 5; $i++) {
			if ($in->{'child'.$i.'_age'} == -1) {
				${"child".$i."_foodcost_m"} = 0;
			} else {
				${"child".$i."_foodcost_m"} = qw(133.30 133.30 139.80 139.80 143.20 143.20 202.00 202.00 202.00 216.10 216.10 216.10 232.40 232.40 234.60 234.60 234.60 234.60)[$in->{"child".$i."_age"}]; #Child costs for low-cost food plan as of January 2021. Ages 12-17 represent aveage between males and females.
			}
		}
		
	$base_foodcost_m = $parent1_foodcost_m + $parent2_foodcost_m + + $child1_foodcost_m + $child2_foodcost_m + $child3_foodcost_m + $child4_foodcost_m+ $child5_foodcost_m; 
	
	if($in->{'food_override'}) { #Adjusting the incorporation of food overrides to match other aspects of the FRS methology and better demonstrate the impact of WIC and school meals. What the food override should be used to adjust is a family's food budget, not what they actually spend on food. So this will include the costs of groceries, prior to any reductions that WIC or school meals might introduce. This is different from pre-2021 simulators, which apparently didn't register any impact of WIC or school meals if the food override was selected.
		$family_foodcost = 12 * $in->{'food_override_amt'}; 
	} else {
		$family_foodcost = $base_foodcost_m * 12 * $familysize_adjustment;
	}
	
	$food_expenses = &round(&pos_sub($family_foodcost, $out->{'child_foodcost_red_total'} + $out->{'wic_recd'}));

	$subsidized_food = &pos_sub($family_foodcost, $food_expenses); #Simulators prior to 2021 had this reversed, generating a negateive subsidized food value.

	if ($in->{'nsbp'}==1 || $in->{'frpl'} == 1 || $in->{'fsmp'} == 1) {
		$child_nutrition_flag = 1;
	}
	

  # outputs
    foreach my $name (qw(child_nutrition_flag food_expenses family_foodcost subsidized_food)) {
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}
# Assumptions and justifications (from when methodology was revised in 2017).
# The USDA separates out food costs according to gender of child for children older than 11, and separates food costs for parents according to gender for all ages. Previous versions calculated food costs for children older than 11 based on the average food cost between the listing for male and female children of that age range, and assumed food costs for a one-parent family based on listings for females age 19-50, and for two-parent families based on listings for one female age 19-50 and one male age 19-50.  Because we are now asking about age of parent, we need to also include lower food costs for older parents (ages 51-61). The differences in monthly food cost between adult males and adult females in the low-cost food plan is at most $43.80, or $525.60 per year. While we could also ask about parent gender in Step 2, the maximum difference from the USDA calculations and the average cost between male and female adult food costs is $272.80 per year per adult, before any food subsidies are considered. This seems fairly nominal, and is based on estimated food costs anyway (with likely considerable margins of error compared to actual food costs) so I think it’s okay to use the assumption that each household adult consumes the average of male and female food costs. We are also removing gender assumptions by using the average of male and female food costs this year.
# We are also assuming that if a user enters their own food costs, those food costs are out-of-pocket, and therefore inclusive of any savings the family may be getting from WIC or school and summer meals programs.
# We may need to be clear in the user interface that by entering user-entered food costs, the tool will not be reducing those food costs by WIC or school/summer meals. 
#Testing scenarios for this module should include the following:
# SNAP, TANF, nsbp, frpm, fsmp toggled off and on
# Test with 5 children and 4 children
# user-entered values for food costs (to test the food_override features)  
# family structure 1 and 2 


1;