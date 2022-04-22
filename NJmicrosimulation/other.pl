#=============================================================================#
#  Other Necessities -- 2021 (modified from 2020) 
#=============================================================================#
#
# Inputs referenced in this module:
#
#   FROM BASE
#     Inputs:
#       rent_cost                       # [this reflects the unsubsidized cost of rent; could be either FMR or a user-entered override value]
#
# disability_work_expenses_m
# disability_personal_expenses_m
#
#   FROM FOOD
#       family_foodcost
#
#   FROM LIFELINE
#       lifeline_recd
#		ebb_recd
#
#	FROM SALESTAX
#		salestax_rate_other				# The applicable sales tax on tangible personal property, calculated below. This includes local sales taxes where they are applicable. 
#=============================================================================#

sub other
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};


	#Hard-coded policy variables:
	our $phone_expenses_national = 830; #Derived from Consumer Expenditure Survey data, second-to-lowest quintile. Thess are the costs that can be adjusted based on lifeline receipt.
	our $other_household_expenses_national = 855; #2nd-quintle other hosuehold expenses, which includes internet access, based on CEX 2020.
	our $other_expenses_percentage = .2822; #Derivation of other expenses as proportion of food and hosuing expenses, using second-to-lowest quintile. This includes phone and internet expenses. 
	our $sales_tax_average = .0743; # To enable state-by-state comparisons, and to better estimate the impact of sales tax policy, beginning in 2019 we are reducing the calculation of other expenses by the average combined state and local tax rate, which is calculated annually by the Tax Foundation. That annual report does not include a national average, but that can easily be determined by weighting each of the state average rates by the population in that state relative to the population of the US. This is calculated from using the latest Tax Foundation publication on average sales tax rates by state, and finding a national average using the latest Census state popuilations, to weigh the state averages against the proportion they represent of the national population. For the 2019 Tax Foundation publication, this is the average sales tax facing Americans. According to that publication (https://files.taxfoundation.org/20190130115700/State-Local-Sales-Tax-Rates-2019-FF-633.pdf), most sales tax calculations use a base that is generally consistent with our calculation for other expenses. 2020 documentation is available at https://files.taxfoundation.org/20200115132659/State-and-Local-Sales-Tax-Rates-2020.pdf. 2021 rates at https://files.taxfoundation.org/20210106094117/State-and-Local-Sales-Tax-Rates-2021.pdf and uses 2020 Census data for weighting these tax rates by state population.

    # outputs created
    our $other_expenses = 0;
	our $phone_expenses = 0;
	our $salestax = 0;
	
	#Intermediary variables
	our $phone_expenses_presalestax = 0;
	our $other_household_expenses_presalestax = 0;
	our $disability_expenses = 0;
	our $other_expenses_national = 0;
	our $other_expenses_presalestax = 0;
	our $internet_reduction = 0;
	# We formerly relied on EPI’s family budget calculator’s method of determining the cost of other necessities, which is based on Consumer Expenditure Survey data: http://www.epi.org/publication/family-budget-calculator-technical-documentation/. This estimates that the cost of items including “apparel, entertainment, personal care expenses, household supplies (including furnishings and equipment, household operations, housekeeping supplies, and telephone services), reading materials, school supplies, and other miscellaneous items of necessity” total to 48.3% of the cost of food and housing, based on 2014 Consumer Expenditure Survey data. This is a change from an earlier methodology that EPI used, that pegged this at 25.6% of food and housing. Upon closer analysis of their approach in August 2017, we decided to slightly adjust it by removing educational expenses (which includes private tuition and other costs that we already account for, elsewhere,  such as afterschool co-pays) as well as entertainment costs, which seems more a function of disposable income than costs that should be included in calculations for a basic, livable income. Based on 2015 Consumer Expenditure Survey data, the removal of these expenses brought the proportion of these costs compared to rent, utilities, and food down to 34%. Based on the 2017-2018 Consumer Expenditure Survey data, these same categories constituted 33.6% of spending.


	# Note that rent_cost is included in here, not rent_paid. This represents the unsubsidized cost of housing, so that receipt of Section 8 does not impact costs of other necessities.
		
	#LOOK AT ME: Commenting out this derivation of rent_cost_m, which seems unnecessary and redundant with the derivation of it in frs.pm. It was seemingly added here as part of some debug, but until whatever issue it was used to debug emerges again, there's no neeed for it. Unless removing it leads to some isssue down the line, delete this comment by June 2022.
	
    #my $sql = "SELECT rent FROM FRS_Locations WHERE state = ? AND year = ? AND id = ? AND number_children = ?";
    #my $stmt = $dbh->prepare($sql) ||
    #    &fatalError("Unable to prepare $sql: $DBI::errstr");
    #my $result = $stmt->execute($in->{'state'}, $in->{'year'}, $in->{'residence'}, $in->{'child_number'}) ||
    #    &fatalError("Unable to execute $sql: $DBI::errstr");

    #if($in->{'housing_override'}) {
    #    $in->{'rent_cost_m'} = $in->{'housing_override_amt'};
    #} else {
	#	$in->{'rent_cost_m'} = $stmt->fetchrow();
    #}

    # Start Debug variables
    #our $rent_cost = $in->{'rent_cost_m'} * 12;
    # End Debug
    if($in->{'other_override'}) {
        $other_expenses = $in->{'other_override_amt'} * 12;
		$salestax += ($out->{'salestax_rate_other'} / (1 + $out->{'salestax_rate_other'})) * $in->{'other_override_amt'} * 12; # This is the portion of sales tax a person would pay of the user-entered other expenses amount, which is post sales tax.
    } else {
		# New beginning in  2019, we're going to calculate this as a pre-sales tax base, meaning we're going to adjust this figure to remove the national average of sales taxes.	
		$other_expenses_national = ($other_expenses_percentage) * ($out->{'family_foodcost'} + $in->{'rent_cost_m'} * 12);
		# Now we adjust to remove the estimated sales tax portion. This allows us to have an "other expenses" base that is unchanged by state or local sales taxes, enabling comparisons of sales tax policies across states and localities.
		$other_expenses_presalestax = $other_expenses_national / (1 + $sales_tax_average);
		$other_expenses = (1 + $out->{'salestax_rate_other'}) * $other_expenses_presalestax;
		$salestax += $out->{'salestax_rate_other'} * $other_expenses_presalestax;
							
    }
	
	if ($out->{'lifeline_recd'} > 0) {
		$phone_expenses_presalestax = $out->{'lifeline_cost'};
	} else {
		$phone_expenses_presalestax = $phone_expenses_national / (1 + $sales_tax_average);
	}
	$phone_expenses = (1 + $out->{'salestax_rate_other'}) * $phone_expenses_presalestax;

	$salestax += $out->{'salestax_rate_other'} * $phone_expenses_presalestax;

	if ($out->{'ebb_recd'} == 0) {
		$internet_reduction = 0;
	} else {
		$other_household_expenses_presalestax = $other_household_expenses_national / (1 + $sales_tax_average);
		$internet_reduction = &least($out->{'ebb_recd'}, $other_household_expenses_presalestax) * (1 + $out->{'salestax_rate_other'});
	}

	$salestax -= $out->{'salestax_rate_other'} * $internet_reduction;

	#Now we subtract from other_expenses any savings generated by the Lifeline program. This approach is consisent with the FRS methodology (but not the MTRC one), in that users can override a total pre-subidized "other expenses" number, which include telephone expenses. That amount is reduced by any subsidies the family receives.
	
	$other_expenses = pos_sub($other_expenses, pos_sub($phone_expenses_national, $phone_expenses) + $internet_reduction);
	
	# Beginning in 2017, we will also be including disability-related expenses, derived from new user-entered inputs.

	$disability_expenses = 12 * ($in->{'disability_work_expenses_m'} + $in->{'disability_personal_expenses_m'});



	# outputs
    foreach my $name (qw(other_expenses disability_expenses salestax phone_expenses other_expenses_presalestax phone_expenses_presalestax other_expenses_national internet_reduction)) {
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;