#!/usr/bin/perl

use warnings;
# data analysis:
our $csv = $ARGV[0] or die "Please enter a csv to analyze \n";
#By default, the microsimulation spits out the following csv file:
# 'C:\Seth\Bankstreet extra\perl_output.csv'.
# An example of this command is "frs_analysis.pl C:\Seth\perl_output.csv". One thing we need to figure out is how a directory with white spaces can be refeerenced here. TBD.
our $numberofcliffs_across_30000_total = 0;
our $hh_faces_at_least_one_cliff_total = 0;
our $hh_faces_cliff_at_iter1_total = 0;
our $hh_netresources_iter10_less_than_iter0_total = 0;
our (@SERIALNO, @net_resources_iter10, @net_resources_iter0, @hh_netresources_iter10_less_than_iter0, @numberofcliffs_across_30000, @hh_faces_cliff_at_iter1, @hh_faces_at_least_one_cliff) = ();

print $csv. "\n";
csvtoarrays($csv);
#print join(',', @net_resources_iter1),"\n";

#counting the benefit cliffs, first per household:
for (my $i = 0; $i <= scalar(@SERIALNO) - 1; $i++) {
	$hh_faces_at_least_one_cliff[$i] = 0;
	if ($net_resources_iter10[$i] < $net_resources_iter0[$i]) {
		$hh_netresources_iter10_less_than_iter0[$i] = 1;
		$hh_netresources_iter10_less_than_iter0_total += 1;
	}
	
	for (my $j = 1; $j <= 30; $j++) {
		if (${'net_resources_iter'.$j}[$i] < ${'net_resources_iter'.($j-1)}[$i]) {
			$numberofcliffs_across_30000[$i] += 1;
			$numberofcliffs_across_30000_total +=1;
			if ($j == 1) {
				$hh_faces_cliff_at_iter1[$i] = 1;
				$hh_faces_cliff_at_iter1_total += 1;
			}
			if ($hh_faces_at_least_one_cliff[$i] == 0) {
				$hh_faces_at_least_one_cliff[$i] = 1;
				$hh_faces_at_least_one_cliff_total +=1;	
			}
		}
	}
}
foreach my $metric (qw(numberofcliffs_across_30000_total hh_faces_at_least_one_cliff_total hh_faces_cliff_at_iter1_total hh_netresources_iter10_less_than_iter0_total)) {
	print $metric.": ".${$metric}."\n";
}

sub csvtoarrays {
	#This will just convert the columns in a csv to arrays, that can be used for later lookups.
	my @table_fields = ();
	my @table_data = ();

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
			#print @table_data;
			our $table_valueorder = 0;
			foreach my $table_cell (@table_fields) {
				#@{$table_data[$table_valueorder]}[0] = 0; #Maybe integrate this into main coding.
				#@{$table_data[$table_valueorder]}[1] = 0; 
				@{$table_data[$table_valueorder]}[$. - 2] = $table_cell; #Maybe integrate this "- 2" into main coding, since it addresses the lack of zeroeth and first elements in the created arrays. 			
				$table_valueorder += 1;	
			}
		}
	}
	close CSVLOOKUPTABLE;
}

