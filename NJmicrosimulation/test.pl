#!/usr/bin/perl

#E.g. csvlookup_ops ($in->{'dir'}.'\FRS_Food.csv', 'cost', 'age_min', '<=', $in->{'child1_age'}, 'age_max', '>=', $in->{'child1_age'}). Should be similar to the above but with conditions to account for 'eq', '<', '>', '<=', and '>='. 

use warnings;
print "okay \n";

my @table_fields = ();
my @table_data = ();

open(CSVLOOKUPTABLE, '<', 'C:\Users\Bank Street\Dropbox\FRS\Perl\NJmicrosimulation\FRS_spr.csv') or die "Couldn't open csv lookup file $!";
#The zeroeth argument is the csv file. 

while (my $table_line = <CSVLOOKUPTABLE>) {
	my @table_fields = split "," , $table_line;

	#Tihs part is using the names in the first row to create a set of input names, and then using the order of those input names to assign the input values of the subsequent rows.
	if ($. == 1) {
		my $table_listorder = 0;
		foreach my $nameofinput (@table_fields) { 
			$table_data[$table_listorder] = $nameofinput;
			#@nameofinput = ();
			$table_listorder += 1;
			#@{$table_data[$table_listorder]} = (0,0);
			#@{$table_data[$table_listorder]} = (0,0);
		}
		
	} else {
		#print @table_data;
		our $table_valueorder = 0;
		foreach my $table_cell (@table_fields) {
			@{$table_data[$table_valueorder]}[$.] = $table_cell;
			#if ($. == 2) {
			#	if ($table_valueorder == 1) {
			#		print @table_data;
			#		print $table_data[$table_valueorder]."\n";
			#		print "line of csv = ".$.."\n";
			#		print "table_cell = ".$table_cell."\n";
			#		print "table_valueorder = ".$table_valueorder."\n";
			#		print $table_data[$table_valueorder]." = ".@{$table_data[$table_valueorder]}[$.]." \n"
			#	}
			#}
			#our $table_data[$table_valueorder]}[$.] = $table_cell; 
			#our ${$table_data[$table_valueorder]}[$.] = $table_cell; 
			$table_valueorder += 1;	
		}
	}
	$rows = $.;
}
close CSVLOOKUPTABLE;
#print "ccdf_time = ".$table->{$ccdf_time}[2]."\n";
#print "spr[33] = ". $spr[33]. "\n";
#print "year[2] = ".$year[2]."\n";
#print "ccdf_time = ".$ccdf_time[2]."\n";
#print @spr;
@inputs = (0, 'spr', 'ccdf_region', 'eq', 10, 'ccdf_time', 'eq', 'parttime_unsub', 'age_min', 'eq', 5, 'age_max', 'eq', 13, 'ccdf_type', 'eq', 'accredited_home');

#print 'rows = '.$rows .' ';

for (my $t = 2; $t <= $rows; $t++)	{
	my $table_return = 1;
	for (my $i = 1; $i <= (scalar(@inputs) - 2)/3; $i++)	{ #repeat over the number of triplets of table column, operation (e.g. '>=', and variable feeing value of table column. This is one third of the remaining arguments after the first two (the csv file and the returning column) are subtracted. E.g. for csvlookup_ops ($in->{'dir'}.'\FRS_Food.csv', 'cost', 'age_min', '<=', $in->{'child1_age'}, 'age_max', '>=', $in->{'child1_age'}), this would repeat (8 -2) / 3 = 2 times. 
		#The operator "ne" converts any numbers to strings, still. 
		#print '$inputs[3*$i] = '.$inputs[3*$i]."\n";
		#print '${$inputs[3*$i-1]}[$t] = '. ${$inputs[3*$i-1]}[$t]."\n";
		if ($inputs[3*$i] eq 'eq' && ${$inputs[3*$i-1]}[$t] ne $inputs[3*$i + 1]) { 
			$table_return = 0; #i = 1 corresponds to arguments 2,3, and 4. i = 2 corresponds to arguments 5, 6, and 7. i =3 corresponds to 8,9, and 10. And so on. (in replicating csvlookup, I switched the order of this so that it matches the syntax of inqeualities rather than reverses them.)
		}
	}
	#print 't = '.$t .' ';
	if ($table_return == 1) {
		#my $output = ${$inputs[1][$t]};
		#print $output ;
		#print 't = '.$t." \n";
		#print 'spr[t] = '.$spr[$t]."\n";
		#print '$inputs[1] = ' .$inputs[1]."\n";
		print "spr = ".${$inputs[1]}[$t]."\n";
	}
}



