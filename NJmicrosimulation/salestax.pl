#=============================================================================#
#  Sales Tax – 2021 - NJ adapted from KY
#=============================================================================#
#
# Inputs referenced in this module:
#
#   FROM OTHER
#   other_expenses
#
#=============================================================================#

sub salestax
{
    my $self = shift;
    my $in = $self->{'in'};
    my $out = $self->{'out'};
 
    # Additional inputs
    our $statesalestax_rate_other = 0.06625;	# The state sales tax is 6.625% in NJ for sales made on and after January 1, 2018 https://www.state.nj.us/treasury/taxation/ratechange/su-overview.shtml. Sales Tax is levied on: Tangible personal property; Specified digital products; and Enumerated services.
    our $localsalestax_rate_other = 0;	# There are no local sales taxes in NJ https://www.state.nj.us/treasury/taxation/salestax.shtml .
	#Outputs created
    our $salestax_rate_other = 0;		# The applicable sales tax on tangible personal property, calculated below. This includes local sales taxes where they are applicable. 
    # outputs calculated in macro
    our $salestax = 0;

    # In most places, the only applicable sales tax rate for the purposes of the FRS is a tax rate on tangible personal property, and these expenditures are captured completely in the “other” expenses calculation. It is important to consider what expenses are additionally included in state or local sales tax systems beyond the expenses captured in sales taxes, but in the case of NH, where there are no sales taxes whatsoever, this is irrelevant. Because later outcome mesaures include the salestax variable, though, we need to assign 0 values to these variables. 
	#
	# Combining state and local taxes:
	$salestax_rate_other = $statesalestax_rate_other + $localsalestax_rate_other;
    # Because our calculation of “other expenses” is based on the EPI calculation of other expenses, and because that in turn is based on national consumer expenditure statistics (which cannot be easily broken down by state), the below calculation carves out sales taxes from the “other expenses” calculation. This calculation is different than the one we did in 2017, when we introduced sales tax, because the "other expenses" calculation is now reduced by the national sales tax average. This allows for better state-to-state comparisons.

    #$salestax = $salestax_rate_other * $out->{'other_expenses'}; #Calculating this now in other.pl.

    # outputs
    foreach my $name (qw(salestax_rate_other)) {
        $out->{$name} = ${$name} || '';
        $self->saveDebugValues("salestax", $name, ${$name});
    }

    foreach my $variable (qw(salestax salestax_rate_other statesalestax_rate_other localsalestax_rate_other)) { 
        $self->saveDebugValues("salestax", $variable, $$variable, 1);
    }

    return(0);

}

1

