#=============================================================================#
#  Interest Module -- 2021 (no changes from 2020)
#=============================================================================#
#
# Inputs referenced in this module:
#
#   FROM BASE
#     Inputs:
#       savings       # user-entered
#       passbook_rate
#
#=============================================================================#

sub interest
{
    my $self = shift;
    my $in = $self->{'in'};
    my $out = $self->{'out'};

  # outputs created
    our $interest = 0;   # annual interest on savings
                         # (assumes rate is compounded annually -- compounding
                         # monthly or quarterly adds only a tiny fraction to the
                         # results)
    our $interest_m = 0; # monthly interest on savings (interest / 12)

# Debug variables
    our $passbook_rate = $in->{'passbook_rate'};
    our $savings = $in->{'savings'};

#Interest is derived from the amount entered for family’s savings in the user-interface	on Step	3.	The	FRS	utilizes the U.S. Department of	Housing	and	Urban Development’s	(HUD)	method	for	calculating	interest: when a family has net assets over $5,000,	we apply the national average interest rate, also known as the passbook	savings rate. Savings equal to or less than $5,000 are	assumed	not to accrue interest. The passbook savings rate was 0.06 in 2019, unchanged from 2016, last announced at https://www.hud.gov/sites/documents/16-01HSGN.PDF. As with HUD standards, this rate is applied annually, and is not compounded monthly or quarterly. We assume the family does not have any other investments.	

    if ($in->{'savings'} <= 5000) { 
      $interest = 0; 
    } else { 
      $interest = $in->{'passbook_rate'} * $in->{'savings'}; 
    }

    $interest_m = $interest / 12;

  # outputs
    foreach my $name (qw(interest interest_m)) {
        $out->{$name} = ${$name};
        $self->saveDebugValues("interest", $name, ${$name});
    }

    foreach my $variable (qw(passbook_rate savings)) {
        $self->saveDebugValues("interest", $variable, $$variable, 1);
    }

    return(0);

}

1;