#!/usr/bin/perl

# IMPORTANT NOTE 1: You must close the output sheet this generates (sample2.csv) in order to run this same code again. There may be a way to automatically close the sheet or adjust teh code to give a new output sheet a new name, but I haven't programmed for that yet. Since it's easy to simply close a file, please do that. Otherwise, you'll get a lot of the same error messages saying some version of "print() on closed filehandle TEST2 at runfrsnh.pl...". That error message means: close the file that has the same name as the csv perl is trying to write to.

# ESI, please note: If doing this in Stata, the Stata do-file StataToPerlToStata automatically opens the command line by the ! function. Once we debug all the Perl files, you will not need to open the terminal or command line yourself; Stata does this for you and terminal or command will operate in the background while Stata is running this code through Perl. However, if there are command-line errors (errors in the Perl), Stata will not return those errors. So it may be better to run this from the command line, which requires only one command from the command line (running this code), after generating and exporting a csv file of inputs from Stata. The Perl code will return a csv file containing the initial inputs as well as the outputs from the code, which can then be imported back into Stata for analysis. These are essentially teh steps that the Stata do file does, with the added benefit of being able to indicate when errors occur before importing back into Stata.

use warnings;

our $mode = $ARGV[0] or die "Please enter a mode (either full, single, range, run, or alt) \n";
our $firstline = 0;
our $lastline = 0;
our $single_casekey = 0;
our $single_iteration = 0;
our $alternate = 'none';
our $alternateaddon = 0;
our $alternate_value = 0;
if ($mode eq 'full') {
	print "Running the full file\n";
} elsif ($mode eq 'range') {
	$firstline = $ARGV[1] or die "For a range output, please enter the value of the line you want to start ouptut at (the line of the csv file) followed by an end value of the last line you want to look at (e.g. range 20 25). \n"; 
	$lastline = $ARGV[2] or die "For a range output, please enter the value of the line you want to start ouptut at (the line of the csv file) followed by an end value of the last line you want to look at (e.g. range 20 25). \n";
	print "Outputing data from ".$firstline." to ".$lastline."\n";
} elsif ($mode eq 'single') {
	$single_casekey = $ARGV[1] or die "For a single  output, please enter the case key you want to look at followed by the iteration of that case key you want to focus on (e.g. single 115114 40) \n"; 
	$single_iteration = $ARGV[2] or die "For a single  output, please enter the case key you want to look at followed by the iteration of that case key you want to focus on (e.g. single 115114 40)\n";
	print "Only outputing data for ".$single_casekey." at iteration number ".$single_iteration."\n";
} elsif ($mode eq 'run') {
	$single_casekey = $ARGV[1] or die "For run output, please enter the case key you want to look at (e.g. run 115114) \n"; 	
	print "Only outputing data for ".$single_casekey."\n";
} elsif ($mode eq 'alt') {
	#The following are the policy modeling examples we did for NJ.
#LOOK AT ME: Need to figure out a way to code in bundles of policy changes.
	$alternate = $ARGV[1] or die "For policy modeling output, please enter a policy variation you want to model.
	- Enter 'bbce' if you want to model the impact of raising the SNAP income limit to 200% of the poverty level. 
	- Enter 'heatandeat' if you want to model the impact of providing a LIHEAP nominal payment to people in subsidized housing who do not pay a heating bill, raising eligibility for SNAP. 
	- Enter 'prek' if you want to see the impact of universally available free pre-K for 4-year-olds. 
	- Enter 'tanf_eid' followed by a value to change the value of the TANF earned income disregard, which is currently .5, or 50%. (Please enter the decimal equivalent of the new percentage if you want to model this change). 
	- Enter 'tanf_ptdef' to allow part-time workers to access the higher maximum TANF child care deduction afforded to full-time workers. 
	- Enter 'tanf_ccalt' followed by four numbers separated by dahses (e.g. tanf_ccalt 300-50-150-25 to model more exact changes to the child care deductions. The sequence 175-25-87.5-12.5 will reflect the current policy of a 175 dollars per child for full-time workers, with an additional 25 dollars for care to infant children of full-time workers, and 87.50 dollars per child for part-time workers, with an additional 25 dollars for care to infant children of part-time workers. 
	- Enter 'sprat75th' to model increasing state payment rates (SPRs) in the CCDF program to the 75th percentile market rate based on designations and values in the latest child care market rate study. 
	- Enter 'sprat75over60' to model increasing state payment rates (SPRs) in the CCDF program to approximate 75th percentile market rate based on multiplying current SPR's by 1.25 (which equals 75/60). This is not a percentile change but more an increase by 25% of the applicable SPRs. 
	- Enter 'licensedspr' to model applying SPRs for licensed child care homes instead of license-exempt child care homes. This assumes that all families receiving CCDF have their children enrolled in licensed child care homes, which carry higher SPRs. 
	- Enter 'ccdfsteps' to adjust the stepped income percentage changes to add more steps/increments in order to potentially smooth out significant increases to child care costs as families earn more. 
	- Enter 'onsitechildcare' to model the impact of onsite, free child care provided by employers. This will eliminate all child care needs for adjust the stepped income percentage changes to add more steps/increments in order to potentially smooth out significant increases to child care costs as families earn more. 
	- Enter 'universal_ehs' to model the provision of free Early Head Start programming available to all children ages 0-3, including care for all children ages 0-3 for 8 hours a day, five days per week, throughout both the school year adn the summer.  
	- Enter 'universal_cep' to model the expansion and universal adoption of the Community Eligibility Provision, allowing all children in school (ages 5-17) to receive free school breakfast and lunch.  
	- Enter 'employer_transit' to model the provision of free, universal transportation to work, for example free commuter transportation provided by employers.
	- Enter 'liheapsteps' followed by a value to adjust the stepped decreases to LIEHAP payments, to add more steps/increments in order to potentially smooth out significant increases to child care costs as families earn more. The value that you indicate will be the reduction each successive increase of 10% FPL will have on the baseline LIHEAP amount for families with the lowest heating costs. (A value of 35 results in minimum liheap benefits that matches the current policy. Higher amounts will lead to potentially higher effective marginal taxes.)
	- Enter 'bbceheatandeat' to model the impact of both an increase of the SNAP gross income limit to 200% and the adoption of a Heat and Eat program.
	- Enter 'flatrent' to model the impact of flat rents for subsidized housing recipients.
	- Enter 'startingwage' followed by a value to model the impact of adjusting the assumption of a starting wage for unemployed individuals at 13.13 dollars/hour. Enter the alternate starting wage as the additional value.
	- Enter 'minwage' followed by a value to model the impact of adjusting the minimum wage. Enter the alternate minimum wage as the additional value. This will assign a starting wage of this value to unemployed individuals, and also raise the value of the wage to this value for anyone whose New HEIGHTS data indicate make wages below this amount. 
	- Enter 'halfdayk' to model the impact of half-day Kindergarten as opposed to full-day Kindergarten. This changes the school day length for 5-year-olds to 2.5 hours instead of 6 hours, which is the default school day length in this model for all school-age children.
	- Enter 'cdc_fsa' followed by a value  to model the impact of the employer provision of a child and dependent care FSA, which reduces gross income counted for Mediciad and ACA subsidies, as well as federal taxes. The value you enter represents the monetary amount that tax filing unit 1 in this household (the only tax filing unit with dependents) is withholding from their paycheck(s) to pay for child care. Please note that this simulation does not check whether the full amount of the FSA is used, but money in a child care FSA could have been carried over from 2020 into 2021 and from 2021 into 2022. Normally, there is a cap but not during COVID years. The American Rescue Plan increased the maximum for CDC FSAs to 10,500 dollars. Because there is no penalty for carrying over funds, we are not reducing earnings based on any unused FSA contributions.
	\n";
	print "alternate=".$alternate."\n";
	if ($alternate eq 'tanf_eid' || $alternate eq 'tanf_ccalt' || $alternate eq 'liheapsteps' || $alternate eq 'startingwage' || $alternate eq 'minwage' || $alternate eq 'cdc_fsa') {
		$alternateaddon = 1;
		$alternate_value = $ARGV[2] or die "For policy modeling output with alternative values, please the value of the policy variable you want to model. For example, after 'tanf_eid', enter the new value of the TANF earned income disregard. The current value of New Hampshire's earned income disregard is 0.5 (equivalent to 50%). In that case, enter the decimal value, not the percentage, for the change you want to model. \n";
	}
	print "alternateaddon=".$alternateaddon."\n";
	print "alternate_value=".$alternate_value."\n";
	$mode = $ARGV[2 + $alternateaddon] or die "After entering the alternate scenario, please enter a mode (either full, single, or range) \n";
	print "mode=".$mode."\n";
	if ($mode eq 'full') {
		print "Running the full file\n";
	} elsif ($mode eq 'range') {
		$firstline = $ARGV[3 + $alternateaddon] or die "For a range output, please enter the value of the line you want to start ouptut at (the line of the csv file) followed by an end value of the last line you want to look at (e.g. range 20 25). \n"; 
		$lastline = $ARGV[4 + $alternateaddon] or die "For a range output, please enter the value of the line you want to start ouptut at (the line of the csv file) followed by an end value of the last line you want to look at (e.g. range 20 25). \n";
		print "Outputing data from ".$firstline." to ".$lastline."\n";
	} elsif ($mode eq 'single') {
		$single_casekey = $ARGV[3 + $alternateaddon] or die "For a single  output, please enter the case key you want to look at followed by the iteration of that case key you want to focus on (e.g. single 115114 40) \n"; 
		$single_iteration = $ARGV[4 + $alternateaddon] or die "For a single  output, please enter the case key you want to look at followed by the iteration of that case key you want to focus on (e.g. single 115114 40)\n";
		print "Only outputing data for ".$single_casekey." at iteration number ".$single_iteration."\n";
	} elsif ($mode eq 'run') {
		$single_casekey = $ARGV[3 + $alternateaddon] or die "For run output, please enter the case key you want to look at (e.g. run 115114) \n"; 	
		print "Only outputing data for ".$single_casekey."\n";
	} else {
		die "Please enter a mode (either full, single, range, or run). If modeling an alternative policy that carries an additional value (e.g. tanf_eid), please enter the value of the policy variable you want to model. For example, after 'tanf_eid', enter the new value of the TANF earned income disregard. The current value of New Hampshire's earned income disregard is 0.5 (equivalent to 50%). In that case, enter the decimal value, not the percentage, for the change you want to model. So if you want to model a change in the earned income disregard to 60% of income, for the first 100 families in the New HEIGHTS data, type 'perl runfrsnh.pl alt tanf_eid .6 range 1 100. \n"; 
	}
} else {
	die "Please enter a mode (either full, single, range, run, or alt)\n"; 
}

# CHANGE THIS PATH TO WHERE THE PERL FILES ARE STORED:
use lib 'C:\Users\Bank Street\Dropbox\FRS\Perl\StataPerl'; #If anybody is running this package, this line needs to include the directory where the active perl files are being stored.
# CHANGE THIS PATH TO WHERE THE SOURCE FILE (THE FILE WITH INPUTS) IS LOCATED
open(TEST1, '<','C:\Users\Bank Street\Dropbox\FRS\Perl\StataPerl\frs_010621.csv') or die "Couldn't open sample csv file $!"; #Was "frs_102020(no_id)_w_exclusions.csv" before last change.
#open(TEST1, '<','C:\Users\NCCP\Dropbox\FRS\Perl\StataPerl\newheights_frs(with_id_no_hlth_detail).csv') or die "Couldn't open sample csv file $!";
# CHANGE THIS PATH TO WHERE THE OUTPUT FILE IS LOCATED
open(TEST2, '>','C:\Seth\Bankstreet extra\perl_output.csv');

our $testinput = 55555;
our $testoutput = 1;
our %self = ('in' => {'testinput' => $testinput},'out' => {'testoutput' => $testoutput});

our $in = $self{'in'};
our $out = $self{'out'};

$self{'in'}->{'alternate'} = $alternate; 
$self{'in'}->{'alternateaddon'} = $alternateaddon;
$self{'in'}->{'alternate_value'} = $alternate_value;

our $iterations = 80; # Can eventually make this into an input that can be set by ESI in the input CSV file.
our $interval = 1000; #Can eventually make this into an input that can be set by ESI in the input CSV file.

my @inputvars = qw(CASE_KEY residence_nj residence rent_cost); #Add as needed to determing successful execution of modules or to debug them.

#Removing these output variables to conserve time and space in processing. Just throw them back in if needed:
# rent_cost_m fpl
 
my @outputvars = qw(parent1_employedhours_w parent2_employedhours_w parent1_earnings_m parent2_earnings_m ssi_recd hlth_cov_parent1 hlth_cov_parent2 hlth_cov_child_all health_expenses child_care_expenses child_care_recd rent_paid housing_recd fsp_recd cadc_recd eitc_recd payroll_tax tax_before_credits federal_tax_credits trans_expenses food_expenses child_foodcost_red_total other_expenses lifeline_recd salestax wic_recd liheap_recd tanf_recd child_support_recd income expenses net_resources); #Add as needed to determing successful execution of modules or to debug them.

#Removing these output variables to conserve time and space in processing. Just throw them back in if needed:
# fmr interest_m hlth_gross_income_m spr_all_children unsub_all_children parent_workhours_w  pha_ua fsp_recd_m federal_tax_gross  

if ($mode eq 'full' || $mode eq 'range') {

	# Printing the input variable names to the CSV file:
	for (my $i = 0; $i <= scalar @inputvars - 1; $i++) { #This is very important to note: the "scalar" returns the number of elements in an array. So in printing all those elements using this function, you need to subtract 1 from the scalar total.
		print TEST2 $inputvars[$i].","; 
	}
	# Printing the output variable names to the CSV file, for each income iteration:
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
	#ALT OUT next if $. == 1;
	#The alternate part here I am trying out is using the names in the first row to create a set of input names, and then using the order of those input names to assign the input values of the subsequent rows.
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
		next if (($mode eq 'single' || $mode eq 'run') && $self{'in'}->{'CASE_KEY'} != $single_casekey);
		
		# Some retained test code to make sure the variables are being added to %self correctly:
		# print $self{'in'}->{'checking'}.","; #Just a check that this is working. It should print out the hh_shelter_cost outputs for each observation.
		
		#Now we reassign the names of the input variables from New HEIGHTS that don't have the same exact names as the variables in the FRS codes. No need to do this unless variables need to be renamed, but since we are working on getting the appropriate names in the frs_input file anyway with our ACS analysis, there is no need for th is. If needed down the line, follow the same syntax as below but like follows, as commented below.:		
		# $self{'in'}->{'mother_child1_PERSON_KEY'} = $self{'in'}->{'child1_mother_PERSON_KEY'};

		#Similarly, if variables are missing and need to be defined, can define those as follows, with just the variable name in the paren's:
		foreach my $name (qw(missingvariable1 missingvariable2)) { 
			$self{'in'}->{$name} = 0; 
		}
		
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
		
		require "general_nh.pl";
#LOOK AT ME: Need to include residence_nj to residence id using lookup in Perl of FRS_Locations.
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
			
			#At one point, we will need to assess the order that these modules are run. These work for DC and so far in the code, although there are some loops we need to resolve at some point.
			# Also, to make it easier to move files around, once all perl scripts are drafted, we can bunch all the "require" commands together, as a loop, and move around the program execution commands as we see fit (like the online FRS does). But doing them individually has helped in terms of ensuring all the codes are written correctly at original upload.
			require "interest_nh.pl";
			interest(%self);
			require "parent_earnings_nh.pl";
			parent_earnings(%self);
			require "unemployment_nh.pl";
			unemployment (%self);
			require "ssp_nh.pl";
			ssp(%self);
			require "ssi_nh.pl";
			ssi(%self);
			require "fed_hlth_insurance_nh.pl";
			fed_hlth_insurance(%self);
			require "hlth_nh.pl";
			hlth(%self);		
			require "child_care_nh.pl";
			child_care(%self);
			require "child_support_nh.pl";
			child_support(%self);
			require "tanf_nh.pl";
			tanf(%self);
			require "ccdf_nh.pl";
			ccdf(%self);
			tanf(%self);		
			ccdf(%self);
			require "sec8_nh.pl";
			sec8(%self);
			require "fsp_assets_nh.pl";
			fsp_assets(%self);
			require "liheap_nh.pl";
			liheap(%self);
			require "fsp_nh.pl";
			fsp(%self);
			require "schoolsummermeals_nh.pl";
			schoolsummermeals(%self);
			require "wic_nh.pl";
			wic(%self);
			require "fedtax_nh.pl";
			fedtax(%self);
			require "eitc_nh.pl";
			eitc(%self);#above here
			require "payroll_nh.pl";
			payroll(%self);
			require "ctc_nh.pl";
			ctc(%self);
			require "statetax_nh.pl";
			statetax(%self);
			require "transportation_nh.pl";
			transportation(%self);
			require "food_nh.pl";
			food(%self);
			require "lifeline_nh.pl";
			lifeline(%self);
			require "other_nh.pl";
			other(%self);
			require "salestax_nh.pl";
			salestax(%self);
			
			#Once the above modules are run, we calculate total expenses, total resources, and net resources, per family, per income level.	
			
			$self{'out'}->{'income'} = &round($out->{'earnings'} + $out->{'interest'} + $out->{'ssi_recd'} + $out->{'child_support_recd'} + $out->{'fsp_recd'} + $out->{'federal_tax_credits'} + $in->{'selfemployed_netprofit_total'} + $out->{'tanf_recd'});
						
			$self{'out'}->{'expenses'} = &round($out->{'debt_payment'} + $out->{'health_expenses'} + $out->{'child_care_expenses'} + $out->{'rent_paid'} + $out->{'payroll_tax'} + $out->{'tax_before_credits'} + $out->{'trans_expenses'} + $out->{'food_expenses'} + $out->{'other_expenses'} + $out->{'disability_expenses'} + $out->{'salestax'});
			$self{'out'}->{'net_resources'} = $out->{'income'} - $out->{'expenses'};
			#Now we print the above list of inputs to the CSV file. Whether this is desired or not in terms of the final product depends on whether we want to append the existing csv file with the output file, or to simply reproduce the input file based on what inputs are needed to return the outputs, and the variable names the FRS files use. 
			#Printing the above lists of outputs to the CSV file or the command line:
			# start test 2
			if ($mode eq 'full' || $mode eq 'range') {
				print TEST2 $out->{'earnings'}.",";
				foreach my $name (@outputvars) { 
					print TEST2 $out->{$name}.","; 
				}			
				if ($earnjump == $iterations) {
					print TEST2 "\n" 
				}
			} elsif ($mode eq 'single') {
				print "Single at ".$self{'in'}->{'CASE_KEY'}." at iteration".$single_iteration.":\n";
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

# The resulting csv file at ths step can then be analyzed itsself, based on the spacing of columns, to indicate where benefit cliffs lie (when net resources in a subsequent column is lower than in a previous column), the severity of those cliffs (the value of the difference in these cases), and which variables show differences between these incomes. This is a simple transforatmion that could be done in either Perl or Stata.

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

