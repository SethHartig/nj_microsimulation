#==============================
# NJ 2021 
#==============================
#Acuity = medical needs
#Levels = time needed to care for foster child
# INPUTS
#	fosterchild_flag
#	child#_foster_status #1-8
#	parent#_time_off_foster
#
#	SOURCES:
#		SEE RESOURCES FOLDER IN DROPBOX 
#			foster care and subsidized adoption - monthly board rates
#			
#==========================================================
sub fostercare
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};
	
	#	Variables needed in this module
	our $base_rate_0_5 = 763;
	our $base_rate_6_9 = 845;
	our $base_rate_10_12 = 872;
	our $base_rate_over13 = 907;
	our $base_rate_acuity5_0_5 = 1013;
	our $base_rate_acuity5_6_9 = 1095;
	our $base_rate_acuity5_10_12 = 1122;
	our $base_rate_acuity5_over13 = 1157;
	our $level_B_increase =  50;
	our $level_C_increase = 100;
	our $level_D_increase = 150;
	our	$initial_clothing_allowance_under13 = 175;
	our $initial_clothing_allowance_13over = 200;
	our $daily_clothing_rate_under13 = 2.99;
	our $daily_clothing_rate_13over = 3.25;
	
	#	Outputs calculated in this module
	our $child1_foster_care_payment_m = 0;
	our $child2_foster_care_payment_m = 0;
	our $child3_foster_care_payment_m = 0;
	our $child4_foster_care_payment_m = 0;
	our $child5_foster_care_payment_m = 0;
	our $child1_clothing_allowance = 0;
	our $child2_clothing_allowance = 0;
	our $child3_clothing_allowance = 0;
	our $child4_clothing_allowance = 0;
	our $child5_clothing_allowance = 0;
	our $foster_children_count = 0;
	our $foster_child_payment_m  = 0; #total of all foster care payments.
	our $foster_child_payment = 0;
	#value of input child#_foster_status corresponds to acuity and levels:
	#if 'child'.$i.'_foster_status' == 0), child is not a foster child
	#1 == Acuity 1-4, Level A
	#2 == Acuity 1-4, Level B
	#3 == Acuity 1-4, Level C
	#4 == Acuity 1-4, Level D
	#5 == Acuity 5, Level A
	#6 == Acuity 5, Level B
	#7 == Acuity 5, Level C 
	#8 == Acuity 5, Level D

	if ($in->{'fosterchild_flag'} == 1) {
		for(my $i=1; $i<=5; $i++) {
			if ($in->{'child'.$i.'_foster_status'} > 0) {
				$foster_children_count += 1;	#total number of foster children in the family.
				if ($in->{'child'.$i.'_foster_status'} == 1) {
					if ($in->{'child'.$i.'_age'} <= 5) {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_0_5;
					} elsif ($in->{'child'.$i.'_age'} <= 9)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_6_9;
					} elsif ($in->{'child'.$i.'_age'} <= 12) {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_10_12;
					} else {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_over13;
					} 
				} elsif ($in->{'child'.$i.'_foster_status'} == 2) {	
					if ($in->{'child'.$i.'_age'} <= 5) {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_0_5 + $level_B_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 9)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_6_9 + $level_B_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 12)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_10_12 + $level_B_increase;
					} else {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_over13 + $level_B_increase;
					}
				} elsif ($in->{'child'.$i.'_foster_status'} == 3) {	
					if ($in->{'child'.$i.'_age'} <= 5) {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_0_5 + $level_C_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 9)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_6_9 + $level_C_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 12)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_10_12 + $level_C_increase;
					} else {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_over13 + $level_C_increase;
					}	
				} elsif ($in->{'child'.$i.'_foster_status'} == 4){	
					if ($in->{'child'.$i.'_age'} <= 5) {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_0_5 + $level_D_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 9)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_6_9 + $level_D_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 12)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_10_12 + $level_D_increase;
					} else {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_over13 + $level_D_increase;
					}
				} elsif ($in->{'child'.$i.'_foster_status'} == 5) { #else if acuity == 5
					if ($in->{'child'.$i.'_age'} <= 5) {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_0_5;
					} elsif ($in->{'child'.$i.'_age'} <= 9)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_6_9;
					} elsif ($in->{'child'.$i.'_age'} <= 12)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_10_12;
					} else {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_over13;
					}
				} elsif ($in->{'child'.$i.'_foster_status'} == 6) {
					if ($in->{'child'.$i.'_age'} <= 5) {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_0_5 + $level_B_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 9)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_6_9 + $level_B_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 12)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_10_12 + $level_B_increase;
					} else {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_over13 + $level_B_increase;
					}
				} elsif ($in->{'child'.$i.'_foster_status'} == 7){
					if ($in->{'child'.$i.'_age'} <= 5) {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_0_5 + $level_C_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 9)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_6_9 + $level_C_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 12)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_10_12 + $level_C_increase;
					} else {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_over13 + $level_C_increase;
					}
				} else { #foster status is 8, or Acuity level 5, level D.
					if ($in->{'child'.$i.'_age'} <= 5) {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_0_5 + $level_D_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 9)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_6_9 + $level_D_increase;
					} elsif ($in->{'child'.$i.'_age'} <= 12)	{
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_10_12 + $level_D_increase;
					} else {
						${'child'.$i.'_foster_care_payment_m'} = $base_rate_acuity5_over13 + $level_D_increase;
					}
				}
				#add clothing allowance to each payments
				if ($in->{'child'.$i.'_age'} <= 12) {
					${'child'.$i.'_foster_care_payment_m'} += 30 * $daily_clothing_rate_under13;
				} else {	
					${'child'.$i.'_foster_care_payment_m'} += 30 * $daily_clothing_rate_13over;
				}
				if ($in->{'parent1_time_off_foster'} > 0 || $in->{'parent2_time_off_foster'} > 0) {
					if ($in->{'child'.$i.'_age'} <= 12) {
						${'child'.$i.'_foster_care_payment_m'} += $initial_clothing_allowance_under13;
					} else {
						${'child'.$i.'_foster_care_payment_m'} += $initial_clothing_allowance_13over;
					}
				}
			}
		}
	
		
		$foster_child_payment_m = $child1_foster_care_payment_m + $child2_foster_care_payment_m +$child3_foster_care_payment_m + $child4_foster_care_payment_m + $child5_foster_care_payment_m;
		
		$foster_child_payment = $foster_child_payment_m * 12;
	}
	
	# outputs
    foreach my $name (qw(child1_foster_care_payment_m child2_foster_care_payment_m child3_foster_care_payment_m child4_foster_care_payment_m child5_foster_care_payment_m foster_child_payment_m foster_children_count foster_child_payment)) {
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;