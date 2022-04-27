#!/usr/bin/perl

# IMPORTANT NOTE 1: You must close the output sheet this generates (e.g. perl_output.csv) in order to run this same code again. There may be a way to automatically close the sheet or adjust teh code to give a new output sheet a new name, but I haven't programmed for that yet. Since it's easy to simply close a file, please do that. Otherwise, you'll get a lot of the same error messages saying some version of "print() on closed filehandle TEST2 at runfrsnj.pl...". That error message means: close the file that has the same name as the csv perl is trying to write to.

# NOTE TO CHONG: There's likely a way to run this perl file, and thus the rest of the perl programs called on in this file, within your R code. I was able to program something fairly rudimentary in Sta that did this, and I doubt it would be that different in R. Basically, as long as there is a command in R to open the commmand line, you can do that and then program in the command line operation to run this file, e.g. "perl runfrsnj.pl full" or "perl runfrsnj.pl alt default_profile". However, if there are command-line errors (errors in the Perl), R may not be able to rerun those errors; I wasn't able to quickly figure out a way for Stata to return those errors. So it may be better to run this from the command line, which requires only one command from the command line (running this code), after generating a csv file of inputs from the ACS data. 

use warnings;

#First we define the global variables used to assign variables via arguments in the command line:
our $firstline = 0;
our $lastline = 0;
our $single_casekey = 0;
our $single_iteration = 0;
our $alternate_policy_profile = 'none';
our $alternate_addon = 0;

#Then we assign variables from the arguments in the command line.
our $mode = $ARGV[0] or die "Please enter a mode (either full, single, range, run, or alt) \n";

if ($mode ne 'alt' && $mode ne 'full' && $mode ne 'range' && $mode ne 'single' && $mode ne 'run') { 
	die "Please enter a mode (either full, single, range, run, or alt)\n"; 
} elsif ($mode eq 'alt') {
	#The "alt" mode will adjust default policy option values based on the selected set of policy options. It will require a subsequent argument -- either full, range, single, or run -- which will generate ouptut in the same way as if alt was not selected, but with output adjusted based on the selected policy variations.
	$alternate_policy_profile = $ARGV[1] or die "For policy modeling output, please enter a policy option profile from the policy_options_profile.csv file. This will be used to assign policy alternative variables.
	\n";
	print "alternate policy profile = ".$alternate_policy_profile."\n";
	$mode = $ARGV[2] or die "After entering the alternate scenario, please enter a mode (either full, single, or range) \n";
	$alternate_addon = 2; #This is used below to 
}

if ($mode ne 'full' && $mode ne 'range' && $mode ne 'single' && $mode ne 'run') { 
	die "Please enter a mode (either full, single, range, run, or alt)\n"; 
} elsif ($mode eq 'full') {
	#The "full" mode produces the full set of outputs, over all earnings levels, sheet for the entire population of SERIALNO observations in the frs_input file.
	print "Running the full file\n";
} elsif ($mode eq 'range') {
	#The "range" mode produces the full set of outputs, over all earnings levels, sheet for a subset of the population in the frs_input file.
	$firstline = $ARGV[1 + $alternate_addon] or die "For a range output, please enter the value of the line you want to start ouptut at (the line of the csv file) followed by an end value of the last line you want to look at (e.g. range 20 25). \n"; 
	$lastline = $ARGV[2 + $alternate_addon] or die "For a range output, please enter the value of the line you want to start ouptut at (the line of the csv file) followed by an end value of the last line you want to look at (e.g. range 20 25). \n";
	print "Outputing data from ".$firstline." to ".$lastline."\n";
} elsif ($mode eq 'single') {
	#The "single" mode produces a single set of outputs for a single earnings level for a specific family. 
	$single_casekey = $ARGV[1 + $alternate_addon] or die "For a single  output, please enter the case key you want to look at followed by the iteration of that case key you want to focus on (e.g. single 115114 40) \n"; 
	$single_iteration = $ARGV[2 + $alternate_addon] or die "For a single  output, please enter the case key you want to look at followed by the iteration of that case key you want to focus on (e.g. single 115114 40)\n";
	print "Only outputing data for ".$single_casekey." at iteration number ".$single_iteration."\n";
} elsif ($mode eq 'run') { #The condition here is not necessary since mode must equal 'run' at this point, but we include this condition in here anyway mostly as a check for completeness.
	#The "run" mode produces outputs for the full range of earnings levels for a specific family. This mode essentially replicates the output currently available on NCCP's website.
	$single_casekey = $ARGV[1 + $alternate_addon] or die "For run output, please enter the case key you want to look at (e.g. run 115114) \n"; 	
	print "Only outputing data for ".$single_casekey."\n";
}
print "mode=".$mode."\n";

#Point perl to the paths of the library perl file, the input csv, and the output csv:

#IMPORTANT: Before running this program, you'll need to adjust the following variables to match the paths of the input and output csv files:
# CHANGE THIS PATH TO WHERE THE PERL FILES ARE STORED:
use lib 'C:\Users\Bank Street\Dropbox\FRS\Perl\NJmicrosimulation';
# CHANGE THIS PATH TO WHERE THE SOURCE FILE (THE FILE WITH INPUTS) IS LOCATED:
open(TEST1, '<', 'C:\Seth\Bankstreet extra\frs_inputs_4.csv') or die "Couldn't open csv file $!";
# CHANGE THIS PATH TO WHERE THE OUTPUT FILE IS LOCATED
open(TEST2, '>', 'C:\Seth\Bankstreet extra\perl_output.csv');
# ALSO CHANGE THIS PATH TO WHERE THE PERL FILES ARE STORED:
our $dir = 'C:\Users\Bank Street\Dropbox\FRS\Perl\NJmicrosimulation';

#Set up some random variables so that you can create the %self, %in, and %out hashes:
our $testinput = 55555;
our $testoutput = 1;
our %self = ('in' => {'testinput' => $testinput},'out' => {'testoutput' => $testoutput});
our $in = $self{'in'};
our $out = $self{'out'};

#This assignment of teh alternate policy profile may be irrelevant; leaving it in partially because a line like this might be necessary to initially set up the %in hash. Try deleting it once the program works:
$self{'in'}->{'alternate_policy_profile'} = $alternate_policy_profile; 
$self{'in'}->{'dir'} = $dir;


#Assign how many times (iterations) you want the perl code to increase the earnings of each household, and the amount of each earnings increase (interval):
our $iterations = 80; # Can eventually make this into an input that can be set by ESI in the input CSV file.
our $interval = 1000; #Can eventually make this into an input that can be set by ESI in the input CSV file.


my @inputvars = qw(SERIALNO residence_nj residence rent_cost); #These are the variables from teh $in hash (set) that will appear for each SERIALNO in the final output sheet. Add additional input variables as needed to determing successful execution of modules or to debug them.

#Removing these output variables to conserve time and space in processing. Just throw them back in if needed:
# rent_cost_m fpl
 
my @outputvars = qw(parent1_employedhours_w parent2_employedhours_w parent1_earnings_m parent2_earnings_m ssi_recd hlth_cov_parent1 hlth_cov_parent2 hlth_cov_child_all health_expenses child_care_expenses child_care_recd rent_paid housing_recd fsp_recd cadc_recd eitc_recd payroll_tax tax_before_credits federal_tax_credits trans_expenses food_expenses child_foodcost_red_total other_expenses lifeline_recd salestax wic_recd liheap_recd tanf_recd child_support_recd income expenses net_resources); #These are the variables from teh $out hash (set) that will appear for each SERIALNO in the final output sheet. Add additional output variables as needed to determing successful execution of modules or to debug them.

if ($mode eq 'full' || $mode eq 'range') {

	# Printing the input variable names to the first line of the output CSV file:
	for (my $i = 0; $i <= scalar @inputvars - 1; $i++) { #This is very important to note: the "scalar" returns the number of elements in an array. So in printing all those elements using this function, you need to subtract 1 from the scalar total.
		print TEST2 $inputvars[$i].","; 
	}
	# Printing the output variable names to the first lien of the CSV file, for each income iteration:
	our $dollarjump = 0; # The variable "dollarjump" is just used to loop over the iterations.
	for (my $earnjump = 0; $earnjump <= $iterations; $earnjump++) {
		$dollarjump = $earnjump*$interval;
		
		if ($earnjump == 0) {
			print TEST2 "earnings_initial,";
		} else {
			print TEST2 "earnings_initial_plus".$dollarjump.",";
		}
		
		for (my $i = 0; $i <= scalar @outputvars - 1; $i++) { 
			print TEST2 $outputvars[$i]."_iter".$earnjump.",";
		}
		
		if  ($earnjump == $iterations) { 
			print TEST2 "\n";
		}
	}
}

if ($mode eq 'run') {
	print TEST2 "Run output for case key ".$single_casekey."\n";
	print TEST2 "earnings,";
	for (my $i = 0; $i <= scalar @outputvars - 1; $i++) { 
		print TEST2 $outputvars[$i].",";
	}
	print TEST2 "\n";	
}

while (my $line = <TEST1>) {
	# For now, during the code debugging phase, I am manually checking each variables needed and assigning its value based on the column in the input CSV code. Eventually, once the input names match, I plan to write a simple script that extracts the values based on column name instead of column number.
	my @fields = split "," , $line;

	#Tihs part is using the names in the first row to create a set of input names, and then using the order of those input names to assign the input values of the subsequent rows.
	if ($. == 1) {
		my $listorder = 0;
		foreach my $nameofinput (@fields) { 
			$inputs[$listorder] = $nameofinput;
			$listorder += 1;
		}
	} else {
		if ($mode eq 'range') {
			next if $. < $firstline;
			if ($. > $lastline) {
				die "\n";
			}
		}
		my $valueorder = 0;
		foreach my $name (@fields) {
			$self{'in'}->{$inputs[$valueorder]} = $name;
			$valueorder += 1;	
		}
		
		our $single_complete_flag = 0;
		next if (($mode eq 'single' || $mode eq 'run') && $self{'in'}->{'SERIALNO'} ne $single_casekey);
		#NOT SURE WHY, but error of undefined values at 150 seems to be resolved when adding in a column of dummy (id) numbers in front of the SERIALNO field. Come back to this.
		
		#The following chunks of commented-out perl code are examples of variable corrections that were needed for the NH 2021 microsimulation project that this perl code was initially written for. If all variables needed for Perl to run the FRS perl modules have been adjusted to match what the online FRS uses to generate FRS output, none of these adjustments will be needed. That is the ideal situation, although the below commented-out code should provide some examples of how data can be adjusted prior to to running the FRS perl modules if needed.
		
		#E.g., two inputs variables that are not in the ACS daata file (because we forgot to includ them) are state and year:
		$self{'in'}->{'state'} = 'NJ';
		$self{'in'}->{'year'} = '2021';		

		#Now we reassign the names of the input variables from New HEIGHTS that don't have the same exact names as the variables in the FRS codes. No need to do this unless variables need to be renamed, but since we are working on getting the appropriate names in the frs_input file anyway with our ACS analysis, there is no need for th is. If needed down the line, follow the same syntax as below but like follows, as commented below.:		
		# $self{'in'}->{'mother_child1_PERSON_KEY'} = $self{'in'}->{'child1_mother_PERSON_KEY'};

		#Similarly, if variables are missing and need to be defined, can define those as follows, with just the variable name in the paren's:
		#foreach my $name (qw(missingvariable1 missingvariable2)) { 
		#	$self{'in'}->{$name} = 0; 
		#}
		
		#Can also rename variables as folllows (commented out for now):
		#for(my $i=1; $i<=5; $i++) {
		#	if ($self{'in'}->{'child'.$i.'_age'} eq 'NA') {
		#		$self{'in'}->{'child'.$i.'_age'} = -1;
		#	}
		#}
		
		# We use -1 for blank values in the case above, but the following commented-out chunk applies to when blank values should be converted to 0:
		#foreach my $name (qw(ssi_ag	foster_care_pymnt_ag child_sup_ret_by_state_ag spous_sup_ret_by_state_ag lcl_welfare_pymnt_ag unearned_income_in_kind_ag adoption_sub_pymnt_ag unearn_gross_mon_inc_amt_ag NHEP_Cash_initial FAP_Cash_initial FWOC_Cash_initial IDP_Cash_initial)) {  
		#	if ($self{'in'}->{$name} eq 'NA') {
		#		$self{'in'}->{$name} = 0;
		#	}
		#}

		#Corrections for empty variables, which also throw off the Perl coding:
		#foreach my $name (qw(parent1_exemption_reason parent1_workstatus parent1_spouse_person parent1_spouse_PERSON_KEY parent2_exemption_reason parent2_workstatus parent2_spouse_person parent2_spouse_PERSON_KEY parent3_exemption_reason parent3_workstatus parent3_spouse_person parent3_spouse_PERSON_KEY parent4_exemption_reason parent4_workstatus parent4_spouse_person parent4_spouse_PERSON_KEY parent1_PERSON_KEY parent2_employedhours_initial_m parent3_employedhours_initial_m parent4_employedhours_initial_m)) { #ADD IN AFTER INTERMEDIATE CORRECTION, MAYBE: parent1_hlth_insurance_detail  parent2_hlth_insurance_detail parent3_hlth_insurance_detail parent4_hlth_insurance_detail 
		#	if ($self{'in'}->{$name} eq '') {
		#		$self{'in'}->{$name} = -1;
		#	}
		#}

		#Another example of a variable correction -- keeping this in here because geographic names can be tricky.
		#if ($self{'in'}->{'residence_nh'} eq 'Millsfieldship') { #There appears to be one location entry, this one, that does not accord to any HUD town listing in NH. There is also no Google location for Millsfieldship, NH. This is likely a misspelling of "Millsfield township", a town that does appear in the HUD listing, which we are shortening to "Millsfield." It is the only entry that does not match a HUD listed town or city.
		#	$self{'in'}->{'residence_nh'} = 'Millsfield';
		#}
		
		
		#Correcting random assignments: some codes in the initial New Heights analysis referred to parent disability without checking first whether the parent is in the house. Similar coding could apply to other corrections:
		#for(my $i=1; $i<=4; $i++) {
		#	if ($self{'in'}->{'parent'.$i.'_age'} == -1) {
		#		$self{'in'}->{'disability_parent'.$i} = 0;
		#	}
		#}
		#$self{'in'}->{'disability_count'} = $self{'in'}->{'disability_parent1'} + $self{'in'}->{'disability_parent2'} + $self{'in'}->{'disability_parent3'} + $self{'in'}->{'disability_parent4'};
		
		# Now that the inputs from New HEIGHTS are gathered, we're ready to gather some last inputs for the family that don't change based on earnings level.
		
		require "general.pl";
		general(%self);
		if ($mode eq 'full' || $mode eq 'range') {
			foreach my $name (@inputvars) { 
				print TEST2 $in->{$name}.","; 
			}
		}		
		# Now that the inputs are printed, we generate the outputs by looping the run of perl files over a loop of increasing incomes.
		for (my $earnjump = 0; $earnjump <= $iterations; $earnjump++) {
			if ($mode eq 'single') {
				next if $earnjump < $single_iteration;
			}
			$self{'out'}->{'earnings'} = $self{'in'}->{'earnings_initial'}+ $earnjump*$interval;
			$self{'out'}->{'earnings_mnth'} = $self{'out'}->{'earnings'} / 12;
			
			#RUNNING THE PERL MODULES OF EXPENSES AND BENEFITS:
			
			#We now set up the order of functions to be executed as defined in the FRS's defaults function, replicated below. The NJ defaults.pl file and upcoming associated technical documentaiton describe why this spsecific order, and adjustemnts to that order based on disabiltiy or child support are necessary for our calcualtions.
			my @order = qw(interest parent_earnings fostercare fli_tdi ssdi unemployment child_care ssp ssi fed_hlth_insurance hlth child_support tanf work child_care  ccdf hlth sec8 fsp_assets liheap fsp work afterschool schoolsummermeals wic fedtax eitc payroll ctc statetax food lifeline salestax other);
			if ($self{'in'}->{'cs_flag'} == 1 || $self{'in'}->{'disability_child1'} + $self{'in'}->{'disability_child2'} + $self{'in'}->{'disability_child3'} + $self{'in'}->{'disability_child4'} + $self{'in'}->{'disability_child5'} > 0) {
				if ($self{'in'}->{'disability_child1'} + $self{'in'}->{'disability_child2'} + $self{'in'}->{'disability_child3'} + $self{'in'}->{'disability_child4'} + $self{'in'}->{'disability_child5'} > 0)	{
					push @order, qw(ssi fed_hlth_insurance hlth);
				}

				if ($self{'in'}->{'cs_flag'} == 1) {
					push @order, qw(hlth child_support);
				}
				push @order, qw(tanf work child_care ccdf sec8 fsp_assets liheap fsp work afterschool schoolsummermeals wic fedtax eitc  payroll ctc statetax food lifeline salestax other);
			}
			
			#Now we execute ach of the above functions in the order assigned.
			foreach my $function (@order) {
				require $function.'.pl';
				#Note: if this doesn't work, try using &$function instead of $function. Not sure how perl will get rid of the quotes in since the functions are referenced as a quoted word (sting) above. Probably fine, though -- erase this note if it is.
				&$function(%self);
			}
			
			#The old way (from the NH 2021 analysis) this was done is below. This looks clunky, but it may prove helpful for debugging if there are errors that require identifying which perl function is generating the error. Commenting out for now, though:
			
			#require "parent_earnings_nh.pl";
			#parent_earnings(%self);
			#require "unemployment_nh.pl";
			#unemployment (%self);
			#require "ssp_nh.pl";
			#ssp(%self);
			#require "ssi_nh.pl";
			#ssi(%self);
			#require "fed_hlth_insurance_nh.pl";
			#fed_hlth_insurance(%self);
			#require "hlth_nh.pl";
			#hlth(%self);		
			#require "child_care_nh.pl";
			#child_care(%self);
			#require "child_support_nh.pl";
			#child_support(%self);
			#require "tanf_nh.pl";
			#tanf(%self);
			#require "ccdf_nh.pl";
			#ccdf(%self);
			#tanf(%self);		
			#ccdf(%self);
			#require "sec8_nh.pl";
			#sec8(%self);
			#require "fsp_assets_nh.pl";
			#fsp_assets(%self);
			#require "liheap_nh.pl";
			#liheap(%self);
			#require "fsp_nh.pl";
			#fsp(%self);
			#require "schoolsummermeals_nh.pl";
			#schoolsummermeals(%self);
			#require "wic_nh.pl";
			#wic(%self);
			#require "fedtax_nh.pl";
			#fedtax(%self);
			#require "eitc_nh.pl";
			#eitc(%self);#above here
			#require "payroll_nh.pl";
			#payroll(%self);
			#require "ctc_nh.pl";
			#ctc(%self);
			#require "statetax_nh.pl";
			#statetax(%self);
			#require "transportation_nh.pl";
			#transportation(%self);
			#require "food_nh.pl";
			#food(%self);
			#require "lifeline_nh.pl";
			#lifeline(%self);
			#require "other_nh.pl";
			#other(%self);
			#require "salestax_nh.pl";
			#salestax(%self);


			#set debt_payment to a yearly value, instead of monthly. Placing this here instead of the modules is a legacy of the frs codes. It's fairly superflous that it's here. Should probably be in the interest module but keeping it in here to keep the interest.pl code matching to the online version.
			$out->{'debt_payment'} = 12 * $in->{'debt_payment'};

			#Once the above modules are run, we calculate total expenses, total resources, and net resources, per family, per income level.	

			$self{'out'}->{'income'} = &round($out->{'earnings'} + $out->{'child_support_recd'} + $out->{'interest'} + $out->{'tanf_recd'} + $out->{'ssi_recd'} + $out->{'fsp_recd'} + $out->{'federal_tax_credits'} + $out->{'state_tax_credits'} + $out->{'local_tax_credits'}  + $out->{'fli_plus_tdi_recd'} + $out->{'foster_child_payment'});
			
			$self{'out'}->{'expenses'} = &round($out->{'tax_before_credits'} + $out->{'payroll_tax'} + $out->{'salestax'} + $out->{'rent_paid'} + $out->{'child_care_expenses'} + $out->{'food_expenses'} + $out->{'trans_expenses'}  + $out->{'other_expenses'} + $out->{'health_expenses'} + $out->{'disability_expenses'} + $out->{'afterschool_expenses'} + $out->{'debt_payment'});

			$self{'out'}->{'net_resources'} = $out->{'income'} - $out->{'expenses'};
			#Now we print the above list of inputs to the CSV file. Whether this is desired or not in terms of the final product depends on whether we want to append the existing csv file with the output file, or to simply reproduce the input file based on what inputs are needed to return the outputs, and the variable names the FRS files use. 
			#Printing the above lists of outputs to the CSV file or the command line:
			
			if ($mode eq 'full' || $mode eq 'range') {
				print TEST2 $out->{'earnings'}.",";
				foreach my $name (@outputvars) { 
					print TEST2 $out->{$name}.","; 
				}			
				if ($earnjump == $iterations) {
					print TEST2 "\n" 
				}
			} elsif ($mode eq 'single') {
				print "Single at ".$self{'in'}->{'SERIALNO'}." at iteration".$single_iteration.":\n";
				foreach my $single_line (keys %self) {
					foreach my $elem (keys %{$self{$single_line}}) {
						print "  $elem: " . $self{$single_line}->{$elem} . "\n";
					}
				}
				die "\n";
			} elsif ($mode eq 'run') {
				print TEST2 $out->{'earnings'}.",";
				foreach my $name (@outputvars) { 
					print TEST2 $out->{$name}.","; 
				}			
				print TEST2 "\n";
				if ($earnjump == $iterations) {
					die "\n";
				}
			}
		}
	}
}

# The resulting csv file at ths step can then be analyzed itsself, based on the spacing of columns, to indicate where benefit cliffs lie (when net resources in a subsequent column is lower than in a previous column), the severity of those cliffs (the value of the difference in these cases), and which variables show differences between these incomes. For what it's worth, the ampersand that precedes these functions in at least some of the perl modules is what allows Perl to look for later definitions of these subroutines below before generating an error.

#NOTE TO SETH/SELF: If this doesn't run right due to errors around lack of ampersands before these utility functions, move them all to the general perl file, which is set up through the require function above, rather than below.

#####################################################################
# UTILITY FUNCTIONS
#####################################################################

# returns the smallest value of a list of values
sub least
{
    my @numbers = @_;
    my $min = $numbers[0];
    foreach my $i (@numbers) {
        if($i < $min) { $min = $i; }
    }
    return $min;
}

#returns the greatest value of a list of numbers
sub greatest
{
    my @numbers = @_;    
    my $max = $numbers[0];
    foreach my $i (@numbers)
    {
        if($i > $max) { $max = $i; }
    }
    return $max;
}

# subtracts $var2 from $var1 and returns the result, 
# returning 0 if the result is negative
sub pos_sub
{
    my ($var1, $var2) = @_;    
    my $result = $var1 - $var2;
    if($result < 0) { return 0; }
    else { return $result; }
}

sub round {
    my($number) = shift;
    return int($number + .5 * ($number <=> 0));
}

# rounds input to the nearest 50
sub round_to_nearest_50 {
    my($number) = shift;
    $number = $number/50.0;
    return 50 * (($number == int($number)) ? $number : int($number + 1));
}

#IMPORTANT NOTE: FOR ANY LOOKUP WITH THESE VARIABLES, NEED TO ADD A COMMA AT THE END OF EVERY LINE. It cannot be a blank space before the next line.
#OTHER IMPORTANT NOTE: There must also be a line filled in at the bottom of every csv, otherwise the search stops at the second-to-last line. I have no idea why that is, but adding in a dummy last line to all the csv files seem like it is the solutoin here, weirdly. Worth investigating further.

sub csvlookup {
	#look at https://alvinalexander.com/blog/post/perl/how-access-arguments-perl-subroutine-function/
	#E.g. csvlookup (FRS_Locations_(NJ_2021)_complete_021122.csv, id, name, $in->{'residence_nj'})

	open(CSVLOOKUPTABLE, '<', $_[0]) or die "Couldn't open csv lookup file $!";
	#The zeroeth argument is the csv file. 

	while (my $table_line = <CSVLOOKUPTABLE>) {
		my @table_fields = split "," , $table_line;

		#Tihs part is using the names in the first row to create a set of input names, and then using the order of those input names to assign the input values of the subsequent rows.
		if ($. == 1) {
			my $table_listorder = 0;
			foreach my $nameofinput (@table_fields) { 
				$table_data[$table_listorder] = $nameofinput; 
				$table_listorder += 1;
			}
		} else {

			my $table_return = 1;
			my $table_valueorder = 0;
			foreach my $table_cell (@table_fields) {
				$table->{$table_data[$table_valueorder]} = $table_cell; 
				
				for (my $i = 1; $i <= (scalar(@_) - 2)/2; $i++)	{ #repeat over the number of pairs of table column and variable feeing value of table column. This is half the remaining arguments after teh first two (the csv file and the returning column) are subtracted. E.g. for csvlookup (FRS_Locations_(NJ_2021)_complete_021122.csv, id, name, $in->{'residence_nj'}), this woudl repeat (4 -2) / 2 = 1 time. For csvlookup(FRS_Locations_(NJ_2021)_complete_021122.csv, id, name, $in->{'residence_nj'}, number_children, $in->{'child_number'}), there are 6 areguments, so this would repeat (6 - 2 ) / 2 = 2 times. 
					#The operator "ne" converts any numbers to strings, so it should work here. But possibly not if I"m not understanding this right.
					
					if (!$table->{$_[2*$i]} || !$table->{$_[1]}) { #This checks wehther the variables referred to below are defined.
						$table_return = 0;
					} elsif ($_[2*$i + 1] ne $table->{$_[2*$i]}) { #i = 1 corresponds to arguments 3 and 2. i = 2 corresponds to arguments 5 and 4. i =3 corresponds to 7 and 6. And so on.
					# seeme like the eq and ne 
						$table_return = 0;
					}
				}
				if ($table_return == 0) {
					$table_valueorder += 1;	
				} else {
					my $output = $table->{$_[1]};
					@table_fields = ();
					@table_data = ();
					close CSVLOOKUPTABLE;
					return $output ;
				}
			}			
		}
	}
}

sub csvlookup_ops {
	#E.g. csvlookup_ops ($in->{'dir'}.'\FRS_Food.csv', 'cost', 'age_min', '<=', $in->{'child1_age'}, 'age_max', '>=', $in->{'child1_age'}). Should be similar to the above but with conditions to account for 'eq', '<', '>', '<=', and '>='. 

	open(CSVLOOKUPTABLE, '<', $_[0]) or die "Couldn't open csv lookup file $!";
	#The zeroeth argument is the csv file. 

	while (my $table_line = <CSVLOOKUPTABLE>) {
		my @table_fields = split "," , $table_line;

		#Tihs part is using the names in the first row to create a set of input names, and then using the order of those input names to assign the input values of the subsequent rows.
		if ($. == 1) {
			my $table_listorder = 0;
			foreach my $nameofinput (@table_fields) { 
				$table_data[$table_listorder] = $nameofinput; 
				$table_listorder += 1;
			}
		} else {

			my $table_return = 1;
			my $table_valueorder = 0;
			foreach my $table_cell (@table_fields) {
				$table->{$table_data[$table_valueorder]} = $table_cell; 
				
				for (my $i = 1; $i <= (scalar(@_) - 2)/3; $i++)	{ #repeat over the number of triplets of table column, operation (e.g. '>=', and variable feeing value of table column. This is one third of the remaining arguments after the first two (the csv file and the returning column) are subtracted. E.g. for csvlookup_ops ($in->{'dir'}.'\FRS_Food.csv', 'cost', 'age_min', '<=', $in->{'child1_age'}, 'age_max', '>=', $in->{'child1_age'}), this would repeat (8 -2) / 3 = 2 times. 
					#The operator "ne" converts any numbers to strings, still. 
					
					if (!$table->{$_[3*$i-1]} || !$table->{$_[1]}) { #This checks wehther the variables referred to below are defined. $_[1] is the variable in the column we want to return. $_[3*$i-1]] refers to teh argument we are testing, which will be placed in the argument order as 2, 5, 8, 11, etc.
						$table_return = 0;
					} elsif ($_[3*$i] eq 'eq') {						 
						if ($table->{$_[3*$i-1]} ne $_[3*$i + 1]) { #i = 1 corresponds to arguments 2,3, and 4. i = 2 corresponds to arguments 5, 6, and 7. i =3 corresponds to 8,9, and 10. And so on. (in replicating csvlookup, I switched the order of this so that it matches the syntax of inqeualities rather than reverses them.)
						# seeme like the eq and ne 
							$table_return = 0;
						}
					} elsif ($_[3*$i] eq '<') {						 
						if ($table->{$_[3*$i-1]} >= $_[3*$i + 1]) { 
							$table_return = 0;
						}
					} elsif ($_[3*$i] eq '<=') {						 
						if ($table->{$_[3*$i-1]} > $_[3*$i + 1]) { 
							$table_return = 0;
						}
					} elsif ($_[3*$i] eq '>') {						 
						if ($table->{$_[3*$i-1]} <= $_[3*$i + 1]) { 
							$table_return = 0;
						}
					} elsif ($_[3*$i] eq '>=') {						 
						if ($table->{$_[3*$i-1]} < $_[3*$i + 1]) { 
							$table_return = 0;
						}
					}
				}
				if ($table_return == 0) {
					$table_valueorder += 1;	
				} else {
					my $output = $table->{$_[1]};
					@table_fields = ();
					@table_data = ();
					close CSVLOOKUPTABLE;
					return $output ;
				}
			}
			if ($table_return == 0) { #If it gets here without returning a value, the lookup has not worked.
				#print "csvlookup_ops failed for ".$_[1];
			}
		}
	}
}

