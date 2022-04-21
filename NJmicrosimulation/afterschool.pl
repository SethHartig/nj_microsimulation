#=============================================================================#
#  Afterschool Module – 2021 – NJ
#=============================================================================#
#
# Inputs referenced in this module:
#
#  FROM BASE
#  ostp 	#This is a flag representing whether users select “Afterschool?” as a potential benefit to receive.
# prek
# child#_age
# afterschool_charge_d	#A user input for the weekly rate of child care payment is. Necessary if ostp=1.
# FROM TANF
# tanf_recd
# 
#   FROM HEALTH
#  hlth_cov_child#
#
#=============================================================================#

sub afterschool
{
    my $self = shift;
    my $in = $self->{'in'};
    my $out = $self->{'out'};


    # outputs created
	our $summerweeks = 0; 
    our $afterschool_child1 = 0;		#  indication as to whether child1 is enrolled in afterschool
    our $afterschool_child2 = 0;		#  indication as to whether child2 is enrolled in afterschool
    our $afterschool_child3 = 0;		#  indication as to whether child3 is enrolled in afterschool
    our $afterschool_child4 = 0;		#  indication as to whether child4 is enrolled in afterschool
    our $afterschool_child5 = 0;		#  indication as to whether child5 is enrolled in afterschool
    our $afterschool_child1_copay = 0;	# child1 afterschool copay
    our $afterschool_child2_copay = 0;	# child2 afterschool copay
    our $afterschool_child3_copay = 0;	# child3 afterschool copay
    our $afterschool_child4_copay = 0;	# child4 afterschool copay
    our $afterschool_child5_copay = 0;	# child5 afterschool copay
    our $afterschool_expenses = 0; 	#  The total afterschool fees for the family

	our $afterschool_charge_d = 0; #Setting this to 0 for now, but may make this an input depending on further research in NJ. 
	
	#Molly found no large-scale afterschool or OSTP program in NJ, just 21st CCLCs, which do not serve a large portion of schoolchildren. So unless further research reveals more afterschool availability separate from other child care, the ostp will be disabled for NJ.
	#
	# 1: Check for afterschool flag
	#


	if ($in->{'ostp'} == 1) {
	# 2 Check for afterschool eligibility (and enrollment) by age. 
	#


		my $sql = "SELECT DISTINCT summerweeks FROM FRS_Locations WHERE state = ? && year = ? && id = ?";
		my $stmt = $dbh->prepare($sql) ||
			&fatalError("Unable to prepare $sql: $DBI::errstr");
		$stmt->execute($in->{'state'}, $in->{'year'}, $in->{'residence'}) ||
			&fatalError("Unable to execute $sql: $DBI::errstr");
		$summerweeks = $stmt->fetchrow();


		for(my $i=1; $i<=5; $i++) {
			if(($in->{'prek'} == 1 && ($in->{'child' . $i . '_age'} == 3 || $in->{'child' . $i . '_age'} ==4)) || ($in->{'child' . $i . '_age'} >= 5 && $in->{'child' . $i . '_age'} <=13)) {
				${'afterschool_child' . $i} = 1;
				# Determine co-pays or charges, if there are any in afterschool programs that are funded separately from child care.
				#We assume afterschool happens every school day, 5 days a week, for 43 non-summer weeks.
				${'afterschool_child' . $i . '_copay'} = $afterschool_charge_d * 5 * (52-$summerweeks); 
			}
		}

		
		$afterschool_expenses = $afterschool_child1_copay + $afterschool_child2_copay + $afterschool_child3_copay+  $afterschool_child4_copay + $afterschool_child5_copay ;

		# Note: At this point, for states that have separate OSTP programs, we are defining the afterschool_expenses here, and will be including it as a potential part of the CDCTC deduction in fedtax. Conceivably it could also be added to the child care expenses in the child care module. However, it may or may not be cheaper to enroll children in afterschool, depending on the user inputs  – certainly it will be more expensive if a family is choosing not to enroll in Medicaid or TANF when eligible, but enrolling their children in afterschool even when not working. So for now, we're modeling afterschool expenses as a separate expense. 
		
	} 

  # outputs
    foreach my $name (qw(afterschool_expenses afterschool_child1 afterschool_child2 afterschool_child3 afterschool_child4 afterschool_child5 afterschool_child1_copay afterschool_child2_copay afterschool_child3_copay afterschool_child4_copay afterschool_child5_copay)) {
        $out->{$name} = ${$name};
        $self->saveDebugValues("afterschool", $name, ${$name});
    }
    foreach my $variable (qw(afterschool_expenses afterschool_child1 afterschool_child2 afterschool_child3 afterschool_child4 afterschool_child5 afterschool_child1_copay afterschool_child2_copay afterschool_child3_copay afterschool_child4_copay afterschool_child5_copay)) {
        $self->saveDebugValues("afterschool", $variable, $$variable, 1);
    }

	
    
    
    return(0);
}

1;
