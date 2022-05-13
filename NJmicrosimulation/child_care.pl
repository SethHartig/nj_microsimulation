#=============================================================================#
#  Child Care Module -- 2021 NJ  
#=============================================================================#
# Inputs referenced in this module:
#
#   FROM BASE
#     Inputs:
#		residence
# 		state
# 		year
# 		ccdf_type
# 		ccdf_region
# 		child#_age
# 		child#_withbenefit_setting
#		child_care_continue_estimate_source 
# 		child#_continue_setting
# 		child#_continue_amt_m
# 		child_care_nobenefit_estimate_source
# 		child#_nobenefit_setting
# 		child#_nobenefit_amt_m
# 		children_under13
# 		preK
# 		afterschool
# 		ccdf
#		fli       	
#		tdi  
#		mother_timeoff_for_newborn (IN WEEKS)
#		other_parent_timeoff_for_newborn (IN WEEKS)
#		fullday_preK	#policy modeling option
#		fullday_K		#policy modeling option
#		parent#_time_off_foster 	#in weeks
#
#	INPUTS THAT MAY ALSO BE ADJUSTED IN PARENT EARNINGS IF USER SELECTS TRADITIONAL WORK SCHEDULES
#  		weekenddaysworked
#  		maxweekendshifts 
#  		breadwinner_wkday_hometime
#  		breadwinner_wkend_hometime
#  		workdaystart
#	EARNINGS
#	    firstrunchildcare
#   FROM WORK
#       parent_workhours_w
# 		parent1_transhours_w
# 		parent2_transhours_w
# 		parent1_employedhours_w 
# 		parent2_employedhours_w
# 		caregiver_maxworkweek 
# 		caregiver_workshifts_w
# 		caregiver_backtobackshifts
# 		caregiver_maxshiftlength
#=============================================================================#

sub child_care
{
    my $self = shift;
    my $in = $self{'in'};
    my $out = $self{'out'};
	

	#Pre-K: There seem to be at least a few NJ pre-k programs that are widely available. This demands additional research, and includes, at least:
	# 1. The Abbott (or former Abbott) Preschool Progam mandated in specific school districts (across all counties). For now, we are modeling preschool based on requirements for "state-funded" preschool, which seems to encompass the provision of presschool in the original Abbott school districts and expanded districts, as listed in the NJ DOE website at https://www.nj.gov/education/ece/psguide/ under "State Funded District Preschool Programs." From references that these are "free" programs and that there is seemingly no specific income requirement, it appears that where adequately funded and as space allows, these programs are simply part of the school continuum for pupils; there is no income requirement or co-pays.
	# 2. Non-Abbott Early Childhood Program Aid (ECPA) program is required only in districts where 20 to 40% of children meet the criteria for free or reduced-price lunch services.
	# 3. The third program, formerly known as the Early Launch to Learning Initiative (ELLI), was established in 2004, as part of New Jersey’s efforts to offer access to high-quality prekindergarten education to all of the state’s low-income 4-year-olds. Initially, all Non-Abbott districts were eligible to apply for funds; however, new districts have been unable to apply in recent years due to limited funds.
#LOOK AT ME: More research needs to go into whether there's more than just the need to model pre-k  funded through Abbott and subsequent legislation here.
	# 4. Local preschool programs, which may or may not represent expansions of these three options, are offered in:
	#	a. Newark
	#	b. elsewhere?
	#
	# We need to figure out what the rules are for these programs so that they can integrated into the UI/TI and Perl codes, in this code and/or potentially elsewhere. 
	# additional values used and outputs
	# Variables that are outputs are indicated accordingly
	our $prek_age_min = 3; #The youngest age for which we're modeling preK in the state. In NJ, the state-funded free pre-K program is only available to 4-year-olds
	our $prek_age_max = 4; #The oldest age for which we're modeling preK in the state. In NJ, the state-funded free pre-K program is only available to 4-year-olds
	our $schoolstart = 8; #This is the average school start time in NJ, according to a state survey published at https://www.nj.gov/education/students/safety/health/StartTimes.pdf.
	our $ft_child_care_min = 6; #the minimum number of hours at or above which a state (in this case NJ) defines as full-time
	our $schoolend_halfday = 12; 	#make sure this is a half day - this is a policy modeling option for both preK and Kindergarten.
	our $schoolend_fullday = 15; 	#make sure this is a full day	- this is the default for both preK and Kindergarten for NJ 2021.
	our $schoolend_ostp_prek = 18;	#No ostp in NJ 2021
	our $child_care_days = 0;   #? days per week child spends in child care (same for all children, though school-aged children have half days while preschool need full)
	our $day1_cc_end1_child1 = 0;
	our $day1_cc_end1_child2 = 0;
	our $day1_cc_end1_child3 = 0;
	our $day1_cc_end1_child4 = 0;
	our $day1_cc_end1_child5 = 0;
	our $day1_cc_end2_child1 = 0;
	our $day1_cc_end2_child2 = 0;
	our $day1_cc_end2_child3 = 0;
	our $day1_cc_end2_child4 = 0;
	our $day1_cc_end2_child5 = 0;
	our $day1_cc_end3_child1 = 0;
	our $day1_cc_end3_child2 = 0;
	our $day1_cc_end3_child3 = 0;
	our $day1_cc_end3_child4 = 0;
	our $day1_cc_end3_child5 = 0;
	our $day1_cc_hours_child1 = 0;
	our $day1_cc_hours_child2 = 0;
	our $day1_cc_hours_child3 = 0;
	our $day1_cc_hours_child4 = 0;
	our $day1_cc_hours_child5 = 0;
	our $day1_cc_hours1_child1 = 0;
	our $day1_cc_hours1_child2 = 0;
	our $day1_cc_hours1_child3 = 0;
	our $day1_cc_hours1_child4 = 0;
	our $day1_cc_hours1_child5 = 0;
	our $day1_cc_hours2_child1 = 0;
	our $day1_cc_hours2_child2 = 0;
	our $day1_cc_hours2_child3 = 0;
	our $day1_cc_hours2_child4 = 0;
	our $day1_cc_hours2_child5 = 0;
	our $day1_cc_hours3_child1 = 0;
	our $day1_cc_hours3_child2 = 0;
	our $day1_cc_hours3_child3 = 0;
	our $day1_cc_hours3_child4 = 0;
	our $day1_cc_hours3_child5 = 0;
	our $day1_cc_start1_child1 = 0;
	our $day1_cc_start1_child2 = 0;
	our $day1_cc_start1_child3 = 0;
	our $day1_cc_start1_child4 = 0;
	our $day1_cc_start1_child5 = 0;
	our $day1_cc_start2_child1 = 0;
	our $day1_cc_start2_child2 = 0;
	our $day1_cc_start2_child3 = 0;
	our $day1_cc_start2_child4 = 0;
	our $day1_cc_start2_child5 = 0;
	our $day1_cc_start3_child1 = 0;
	our $day1_cc_start3_child2 = 0;
	our $day1_cc_start3_child3 = 0;
	our $day1_cc_start3_child4 = 0;
	our $day1_cc_start3_child5 = 0;
	our $day1care_child1 = 0;
	our $day1care_child2 = 0;
	our $day1care_child3 = 0;
	our $day1care_child4 = 0;
	our $day1care_child5 = 0;
	our $day1cost_child1 = 0;
	our $day1cost_child2 = 0;
	our $day1cost_child3 = 0;
	our $day1cost_child4 = 0;
	our $day1cost_child5 = 0;
	our $day1hours = 0;
	our $day2_cc_end1_child1 = 0;
	our $day2_cc_end1_child2 = 0;
	our $day2_cc_end1_child3 = 0;
	our $day2_cc_end1_child4 = 0;
	our $day2_cc_end1_child5 = 0;
	our $day2_cc_end2_child1 = 0;
	our $day2_cc_end2_child2 = 0;
	our $day2_cc_end2_child3 = 0;
	our $day2_cc_end2_child4 = 0;
	our $day2_cc_end2_child5 = 0;
	our $day2_cc_end3_child1 = 0;
	our $day2_cc_end3_child2 = 0;
	our $day2_cc_end3_child3 = 0;
	our $day2_cc_end3_child4 = 0;
	our $day2_cc_end3_child5 = 0;
	our $day2_cc_hours_child1 = 0;
	our $day2_cc_hours_child2 = 0;
	our $day2_cc_hours_child3 = 0;
	our $day2_cc_hours_child4 = 0;
	our $day2_cc_hours_child5 = 0;
	our $day2_cc_hours1_child1 = 0;
	our $day2_cc_hours1_child2 = 0;
	our $day2_cc_hours1_child3 = 0;
	our $day2_cc_hours1_child4 = 0;
	our $day2_cc_hours1_child5 = 0;
	our $day2_cc_hours2_child1 = 0;
	our $day2_cc_hours2_child2 = 0;
	our $day2_cc_hours2_child3 = 0;
	our $day2_cc_hours2_child4 = 0;
	our $day2_cc_hours2_child5 = 0;
	our $day2_cc_hours3_child1 = 0;
	our $day2_cc_hours3_child2 = 0;
	our $day2_cc_hours3_child3 = 0;
	our $day2_cc_hours3_child4 = 0;
	our $day2_cc_hours3_child5 = 0;
	our $day2_cc_start1_child1 = 0;
	our $day2_cc_start1_child2 = 0;
	our $day2_cc_start1_child3 = 0;
	our $day2_cc_start1_child4 = 0;
	our $day2_cc_start1_child5 = 0;
	our $day2_cc_start2_child1 = 0;
	our $day2_cc_start2_child2 = 0;
	our $day2_cc_start2_child3 = 0;
	our $day2_cc_start2_child4 = 0;
	our $day2_cc_start2_child5 = 0;
	our $day2_cc_start3_child1 = 0;
	our $day2_cc_start3_child2 = 0;
	our $day2_cc_start3_child3 = 0;
	our $day2_cc_start3_child4 = 0;
	our $day2_cc_start3_child5 = 0;
	our $day2care_child1 = 0;
	our $day2care_child2 = 0;
	our $day2care_child3 = 0;
	our $day2care_child4 = 0;
	our $day2care_child5 = 0;
	our $day2cost_child1 = 0;
	our $day2cost_child2 = 0;
	our $day2cost_child3 = 0;
	our $day2cost_child4 = 0;
	our $day2cost_child5 = 0;
	our $day2hours = 0; 
	our $day3_cc_end1_child1 = 0;
	our $day3_cc_end1_child2 = 0;
	our $day3_cc_end1_child3 = 0;
	our $day3_cc_end1_child4 = 0;
	our $day3_cc_end1_child5 = 0;
	our $day3_cc_end2_child1 = 0;
	our $day3_cc_end2_child2 = 0;
	our $day3_cc_end2_child3 = 0;
	our $day3_cc_end2_child4 = 0;
	our $day3_cc_end2_child5 = 0;
	our $day3_cc_end3_child1 = 0;
	our $day3_cc_end3_child2 = 0;
	our $day3_cc_end3_child3 = 0;
	our $day3_cc_end3_child4 = 0;
	our $day3_cc_end3_child5 = 0;
	our $day3_cc_hours_child1 = 0;
	our $day3_cc_hours_child2 = 0;
	our $day3_cc_hours_child3 = 0;
	our $day3_cc_hours_child4 = 0;
	our $day3_cc_hours_child5 = 0;
	our $day3_cc_hours1_child1 = 0;
	our $day3_cc_hours1_child2 = 0;
	our $day3_cc_hours1_child3 = 0;
	our $day3_cc_hours1_child4 = 0;
	our $day3_cc_hours1_child5 = 0;
	our $day3_cc_hours2_child1 = 0;
	our $day3_cc_hours2_child2 = 0;
	our $day3_cc_hours2_child3 = 0;
	our $day3_cc_hours2_child4 = 0;
	our $day3_cc_hours2_child5 = 0;
	our $day3_cc_hours3_child1 = 0;
	our $day3_cc_hours3_child2 = 0;
	our $day3_cc_hours3_child3 = 0;
	our $day3_cc_hours3_child4 = 0;
	our $day3_cc_hours3_child5 = 0;
	our $day3_cc_start1_child1 = 0;
	our $day3_cc_start1_child2 = 0;
	our $day3_cc_start1_child3 = 0;
	our $day3_cc_start1_child4 = 0;
	our $day3_cc_start1_child5 = 0;
	our $day3_cc_start2_child1 = 0;
	our $day3_cc_start2_child2 = 0;
	our $day3_cc_start2_child3 = 0;
	our $day3_cc_start2_child4 = 0;
	our $day3_cc_start2_child5 = 0;
	our $day3_cc_start3_child1 = 0;
	our $day3_cc_start3_child2 = 0;
	our $day3_cc_start3_child3 = 0;
	our $day3_cc_start3_child4 = 0;
	our $day3_cc_start3_child5 = 0;
	our $day3care_child1 = 0;
	our $day3care_child2 = 0;
	our $day3care_child3 = 0;
	our $day3care_child4 = 0;
	our $day3care_child5 = 0;
	our $day3cost_child1 = 0;
	our $day3cost_child2 = 0;
	our $day3cost_child3 = 0;
	our $day3cost_child4 = 0;
	our $day3cost_child5 = 0;
	our $day3hours = 0;
	our $day4_cc_end1_child1 = 0;
	our $day4_cc_end1_child2 = 0;
	our $day4_cc_end1_child3 = 0;
	our $day4_cc_end1_child4 = 0;
	our $day4_cc_end1_child5 = 0;
	our $day4_cc_end2_child1 = 0;
	our $day4_cc_end2_child2 = 0;
	our $day4_cc_end2_child3 = 0;
	our $day4_cc_end2_child4 = 0;
	our $day4_cc_end2_child5 = 0;
	our $day4_cc_end3_child1 = 0;
	our $day4_cc_end3_child2 = 0;
	our $day4_cc_end3_child3 = 0;
	our $day4_cc_end3_child4 = 0;
	our $day4_cc_end3_child5 = 0;
	our $day4_cc_hours_child1 = 0;
	our $day4_cc_hours_child2 = 0;
	our $day4_cc_hours_child3 = 0;
	our $day4_cc_hours_child4 = 0;
	our $day4_cc_hours_child5 = 0;
	our $day4_cc_hours1_child1 = 0;
	our $day4_cc_hours1_child2 = 0;
	our $day4_cc_hours1_child3 = 0;
	our $day4_cc_hours1_child4 = 0;
	our $day4_cc_hours1_child5 = 0;
	our $day4_cc_hours2_child1 = 0;
	our $day4_cc_hours2_child2 = 0;
	our $day4_cc_hours2_child3 = 0;
	our $day4_cc_hours2_child4 = 0;
	our $day4_cc_hours2_child5 = 0;
	our $day4_cc_hours3_child1 = 0;
	our $day4_cc_hours3_child2 = 0;
	our $day4_cc_hours3_child3 = 0;
	our $day4_cc_hours3_child4 = 0;
	our $day4_cc_hours3_child5 = 0;
	our $day4_cc_start1_child1 = 0;
	our $day4_cc_start1_child2 = 0;
	our $day4_cc_start1_child3 = 0;
	our $day4_cc_start1_child4 = 0;
	our $day4_cc_start1_child5 = 0;
	our $day4_cc_start2_child1 = 0;
	our $day4_cc_start2_child2 = 0;
	our $day4_cc_start2_child3 = 0;
	our $day4_cc_start2_child4 = 0;
	our $day4_cc_start2_child5 = 0;
	our $day4_cc_start3_child1 = 0;
	our $day4_cc_start3_child2 = 0;
	our $day4_cc_start3_child3 = 0;
	our $day4_cc_start3_child4 = 0;
	our $day4_cc_start3_child5 = 0;
	our $day4care_child1 = 0;
	our $day4care_child2 = 0;
	our $day4care_child3 = 0;
	our $day4care_child4 = 0;
	our $day4care_child5 = 0;
	our $day4cost_child1 = 0;
	our $day4cost_child2 = 0;
	our $day4cost_child3 = 0;
	our $day4cost_child4 = 0;
	our $day4cost_child5 = 0;
	our $day4hours = 0;	
	our $day5_cc_end1_child1 = 0;
	our $day5_cc_end1_child2 = 0;
	our $day5_cc_end1_child3 = 0;
	our $day5_cc_end1_child4 = 0;
	our $day5_cc_end1_child5 = 0;
	our $day5_cc_end2_child1 = 0;
	our $day5_cc_end2_child2 = 0;
	our $day5_cc_end2_child3 = 0;
	our $day5_cc_end2_child4 = 0;
	our $day5_cc_end2_child5 = 0;
	our $day5_cc_end3_child1 = 0;
	our $day5_cc_end3_child2 = 0;
	our $day5_cc_end3_child3 = 0;
	our $day5_cc_end3_child4 = 0;
	our $day5_cc_end3_child5 = 0;
	our $day5_cc_hours_child1 = 0;
	our $day5_cc_hours_child2 = 0;
	our $day5_cc_hours_child3 = 0;
	our $day5_cc_hours_child4 = 0;
	our $day5_cc_hours_child5 = 0;
	our $day5_cc_hours1_child1 = 0;
	our $day5_cc_hours1_child2 = 0;
	our $day5_cc_hours1_child3 = 0;
	our $day5_cc_hours1_child4 = 0;
	our $day5_cc_hours1_child5 = 0;
	our $day5_cc_hours2_child1 = 0;
	our $day5_cc_hours2_child2 = 0;
	our $day5_cc_hours2_child3 = 0;
	our $day5_cc_hours2_child4 = 0;
	our $day5_cc_hours2_child5 = 0;
	our $day5_cc_hours3_child1 = 0;
	our $day5_cc_hours3_child2 = 0;
	our $day5_cc_hours3_child3 = 0;
	our $day5_cc_hours3_child4 = 0;
	our $day5_cc_hours3_child5 = 0;
	our $day5_cc_start1_child1 = 0;
	our $day5_cc_start1_child2 = 0;
	our $day5_cc_start1_child3 = 0;
	our $day5_cc_start1_child4 = 0;
	our $day5_cc_start1_child5 = 0;
	our $day5_cc_start2_child1 = 0;
	our $day5_cc_start2_child2 = 0;
	our $day5_cc_start2_child3 = 0;
	our $day5_cc_start2_child4 = 0;
	our $day5_cc_start2_child5 = 0;
	our $day5_cc_start3_child1 = 0;
	our $day5_cc_start3_child2 = 0;
	our $day5_cc_start3_child3 = 0;
	our $day5_cc_start3_child4 = 0;
	our $day5_cc_start3_child5 = 0;
	our $day5care_child1 = 0;
	our $day5care_child2 = 0;
	our $day5care_child3 = 0;
	our $day5care_child4 = 0;
	our $day5care_child5 = 0;
	our $day5cost_child1 = 0;
	our $day5cost_child2 = 0;
	our $day5cost_child3 = 0;
	our $day5cost_child4 = 0;
	our $day5cost_child5 = 0;
	our $day5hours = 0;
	our $day6_cc_end1_child1 = 0;
	our $day6_cc_end1_child2 = 0;
	our $day6_cc_end1_child3 = 0;
	our $day6_cc_end1_child4 = 0;
	our $day6_cc_end1_child5 = 0;
	our $day6_cc_end2_child1 = 0;
	our $day6_cc_end2_child2 = 0;
	our $day6_cc_end2_child3 = 0;
	our $day6_cc_end2_child4 = 0;
	our $day6_cc_end2_child5 = 0;
	our $day6_cc_hours = 0;
	our $day6_cc_hours_child1 = 0;
	our $day6_cc_hours_child2 = 0;
	our $day6_cc_hours_child3 = 0;
	our $day6_cc_hours_child4 = 0;
	our $day6_cc_hours_child5 = 0;
	our $day6_cc_hours1_child1 = 0;
	our $day6_cc_hours1_child2 = 0;
	our $day6_cc_hours1_child3 = 0;
	our $day6_cc_hours1_child4 = 0;
	our $day6_cc_hours1_child5 = 0;
	our $day6_cc_hours2_child1 = 0;
	our $day6_cc_hours2_child2 = 0;
	our $day6_cc_hours2_child3 = 0;
	our $day6_cc_hours2_child4 = 0;
	our $day6_cc_hours2_child5 = 0;
	our $day6_cc_hours3_child1 = 0;
	our $day6_cc_hours3_child2 = 0;
	our $day6_cc_hours3_child3 = 0;
	our $day6_cc_hours3_child4 = 0;
	our $day6_cc_hours3_child5 = 0;
	our $day6_cc_start1_child1 = 0;
	our $day6_cc_start1_child2 = 0;
	our $day6_cc_start1_child3 = 0;
	our $day6_cc_start1_child4 = 0;
	our $day6_cc_start1_child5 = 0;
	our $day6_cc_start2_child1 = 0;
	our $day6_cc_start2_child2 = 0;
	our $day6_cc_start2_child3 = 0;
	our $day6_cc_start2_child4 = 0;
	our $day6_cc_start2_child5 = 0;
	our $day6care_child1 = 0;
	our $day6care_child2 = 0;
	our $day6care_child3 = 0;
	our $day6care_child4 = 0;
	our $day6care_child5 = 0;
	our $day6cost_child1 = 0;
	our $day6cost_child2 = 0;
	our $day6cost_child3 = 0;
	our $day6cost_child4 = 0;
	our $day6cost_child5 = 0;
	our $day7_cc_end1_child1 = 0;
	our $day7_cc_end1_child2 = 0;
	our $day7_cc_end1_child3 = 0;
	our $day7_cc_end1_child4 = 0;
	our $day7_cc_end1_child5 = 0;
	our $day7_cc_end2_child1 = 0;
	our $day7_cc_end2_child2 = 0;
	our $day7_cc_end2_child3 = 0;
	our $day7_cc_end2_child4 = 0;
	our $day7_cc_end2_child5 = 0;
	our $day7_cc_hours = 0;
	our $day7_cc_hours_child1 = 0;
	our $day7_cc_hours_child2 = 0;
	our $day7_cc_hours_child3 = 0;
	our $day7_cc_hours_child4 = 0;
	our $day7_cc_hours_child5 = 0;
	our $day7_cc_hours1_child1 = 0;
	our $day7_cc_hours1_child2 = 0;
	our $day7_cc_hours1_child3 = 0;
	our $day7_cc_hours1_child4 = 0;
	our $day7_cc_hours1_child5 = 0;
	our $day7_cc_hours2_child1 = 0;
	our $day7_cc_hours2_child2 = 0;
	our $day7_cc_hours2_child3 = 0;
	our $day7_cc_hours2_child4 = 0;
	our $day7_cc_hours2_child5 = 0;
	our $day7_cc_hours3_child1 = 0;
	our $day7_cc_hours3_child2 = 0;
	our $day7_cc_hours3_child3 = 0;
	our $day7_cc_hours3_child4 = 0;
	our $day7_cc_hours3_child5 = 0;
	our $day7_cc_start1_child1 = 0;
	our $day7_cc_start1_child2 = 0;
	our $day7_cc_start1_child3 = 0;
	our $day7_cc_start1_child4 = 0;
	our $day7_cc_start1_child5 = 0;
	our $day7_cc_start2_child1 = 0;
	our $day7_cc_start2_child2 = 0;
	our $day7_cc_start2_child3 = 0;
	our $day7_cc_start2_child4 = 0;
	our $day7_cc_start2_child5 = 0;
	our $day7care_child1 = 0;
	our $day7care_child2 = 0;
	our $day7care_child3 = 0;
	our $day7care_child4 = 0;
	our $day7care_child5 = 0;
	our $day7cost_child1 = 0;
	our $day7cost_child2 = 0;
	our $day7cost_child3 = 0;
	our $day7cost_child4 = 0;
	our $day7cost_child5 = 0;
	our $fridayshifts = 0;
	our $mondayshifts = 0;
	our $remainder = 0;
	our $remaining_wkdy_hometime = 0;
	our $remaining_wknd_hometime = 0;
	our $roundtriptraveltime = 1;	# The number of hours we assume it takes to get from the child care facility or school to work and back again. This adds to the amount of child care needed. This is an assumption built into previous versions of the FRS, but it makes sense to make this assumption explicit in the form of this variable. It may be worth assessing whether we want to add more than a half-hour here, and how this affects our travel assumptions in the parent work effort and transportation module.
	our $saturdayhours = 0;
	our $saturdayshifts = 0;
	our $schoolend_child1 = 0;				
	our $schoolend_child2 = 0;				
	our $schoolend_child3 = 0;				
	our $schoolend_child4 = 0;				
	our $schoolend_child5 = 0;
	our $spr_all_children = 0;    # total annual state reimbursement rate to all children's providers (output)
	our $spr_child1 = 0;   
	our $spr_child2 = 0;   
	our $spr_child3 = 0;   
	our $spr_child4 = 0;   
	our $spr_child5 = 0;   
	our $summerday1_cc_end1_child1 = 0;
	our $summerday1_cc_end1_child2 = 0;
	our $summerday1_cc_end1_child3 = 0;
	our $summerday1_cc_end1_child4 = 0;
	our $summerday1_cc_end1_child5 = 0;
	our $summerday1_cc_hours_child1 = 0;	
	our $summerday1_cc_hours_child2 = 0;	
	our $summerday1_cc_hours_child3 = 0;	
	our $summerday1_cc_hours_child4 = 0;	
	our $summerday1_cc_hours_child5 = 0;	
	our $summerday1_cc_hours1_child1 = 0;
	our $summerday1_cc_hours1_child2 = 0;
	our $summerday1_cc_hours1_child3 = 0;
	our $summerday1_cc_hours1_child4 = 0;
	our $summerday1_cc_hours1_child5 = 0;
	our $summerday1_cc_start1_child1 = 0;
	our $summerday1_cc_start1_child2 = 0;
	our $summerday1_cc_start1_child3 = 0;
	our $summerday1_cc_start1_child4 = 0;
	our $summerday1_cc_start1_child5 = 0;
	our $summerday1care_child1 = 0;
	our $summerday1care_child2 = 0;
	our $summerday1care_child3 = 0;
	our $summerday1care_child4 = 0;
	our $summerday1care_child5 = 0;
	our $summerday1cost_child1 = 0;
	our $summerday1cost_child2 = 0;
	our $summerday1cost_child3 = 0;
	our $summerday1cost_child4 = 0;
	our $summerday1cost_child5 = 0;
	our $summerday2_cc_end1_child1 = 0;
	our $summerday2_cc_end1_child2 = 0;
	our $summerday2_cc_end1_child3 = 0;
	our $summerday2_cc_end1_child4 = 0;
	our $summerday2_cc_end1_child5 = 0;
	our $summerday2_cc_hours_child1 = 0;	
	our $summerday2_cc_hours_child2 = 0;	
	our $summerday2_cc_hours_child3 = 0;	
	our $summerday2_cc_hours_child4 = 0;	
	our $summerday2_cc_hours_child5 = 0;	
	our $summerday2_cc_hours1_child1 = 0;
	our $summerday2_cc_hours1_child2 = 0;
	our $summerday2_cc_hours1_child3 = 0;
	our $summerday2_cc_hours1_child4 = 0;
	our $summerday2_cc_hours1_child5 = 0;
	our $summerday2_cc_start1_child1 = 0;
	our $summerday2_cc_start1_child2 = 0;
	our $summerday2_cc_start1_child3 = 0;
	our $summerday2_cc_start1_child4 = 0;
	our $summerday2_cc_start1_child5 = 0;
	our $summerday2care_child1 = 0;
	our $summerday2care_child2 = 0;
	our $summerday2care_child3 = 0;
	our $summerday2care_child4 = 0;
	our $summerday2care_child5 = 0;
	our $summerday2cost_child1 = 0;
	our $summerday2cost_child2 = 0;
	our $summerday2cost_child3 = 0;
	our $summerday2cost_child4 = 0;
	our $summerday2cost_child5 = 0;
	our $summerday3_cc_end1_child1 = 0;
	our $summerday3_cc_end1_child2 = 0;
	our $summerday3_cc_end1_child3 = 0;
	our $summerday3_cc_end1_child4 = 0;
	our $summerday3_cc_end1_child5 = 0;
	our $summerday3_cc_hours_child1 = 0;	
	our $summerday3_cc_hours_child2 = 0;	
	our $summerday3_cc_hours_child3 = 0;	
	our $summerday3_cc_hours_child4 = 0;	
	our $summerday3_cc_hours_child5 = 0;		
	our $summerday3_cc_hours1_child1 = 0;
	our $summerday3_cc_hours1_child2 = 0;
	our $summerday3_cc_hours1_child3 = 0;
	our $summerday3_cc_hours1_child4 = 0;
	our $summerday3_cc_hours1_child5 = 0;
	our $summerday3_cc_start1_child1 = 0;
	our $summerday3_cc_start1_child2 = 0;
	our $summerday3_cc_start1_child3 = 0;
	our $summerday3_cc_start1_child4 = 0;
	our $summerday3_cc_start1_child5 = 0;
	our $summerday3care_child1 = 0;
	our $summerday3care_child2 = 0;
	our $summerday3care_child3 = 0;
	our $summerday3care_child4 = 0;
	our $summerday3care_child5 = 0;
	our $summerday3cost_child1 = 0;
	our $summerday3cost_child2 = 0;
	our $summerday3cost_child3 = 0;
	our $summerday3cost_child4 = 0;
	our $summerday3cost_child5 = 0;
	our $summerday4_cc_end1_child1 = 0;
	our $summerday4_cc_end1_child2 = 0;
	our $summerday4_cc_end1_child3 = 0;
	our $summerday4_cc_end1_child4 = 0;
	our $summerday4_cc_end1_child5 = 0;
	our $summerday4_cc_hours_child1 = 0;	
	our $summerday4_cc_hours_child2 = 0;	
	our $summerday4_cc_hours_child3 = 0;	
	our $summerday4_cc_hours_child4 = 0;	
	our $summerday4_cc_hours_child5 = 0;	
	our $summerday4_cc_hours1_child1 = 0;
	our $summerday4_cc_hours1_child2 = 0;
	our $summerday4_cc_hours1_child3 = 0;
	our $summerday4_cc_hours1_child4 = 0;
	our $summerday4_cc_hours1_child5 = 0;
	our $summerday4_cc_start1_child1 = 0;
	our $summerday4_cc_start1_child2 = 0;
	our $summerday4_cc_start1_child3 = 0;
	our $summerday4_cc_start1_child4 = 0;
	our $summerday4_cc_start1_child5 = 0;
	our $summerday4care_child1 = 0;
	our $summerday4care_child2 = 0;
	our $summerday4care_child3 = 0;
	our $summerday4care_child4 = 0;
	our $summerday4care_child5 = 0;
	our $summerday4cost_child1 = 0;
	our $summerday4cost_child2 = 0;
	our $summerday4cost_child3 = 0;
	our $summerday4cost_child4 = 0;
	our $summerday4cost_child5 = 0;
	our $summerday5_cc_end1_child1 = 0;
	our $summerday5_cc_end1_child2 = 0;
	our $summerday5_cc_end1_child3 = 0;
	our $summerday5_cc_end1_child4 = 0;
	our $summerday5_cc_end1_child5 = 0;
	our $summerday5_cc_hours_child1 = 0;	
	our $summerday5_cc_hours_child2 = 0;	
	our $summerday5_cc_hours_child3 = 0;	
	our $summerday5_cc_hours_child4 = 0;	
	our $summerday5_cc_hours_child5 = 0;	
	our $summerday5_cc_hours1_child1 = 0;
	our $summerday5_cc_hours1_child2 = 0;
	our $summerday5_cc_hours1_child3 = 0;
	our $summerday5_cc_hours1_child4 = 0;
	our $summerday5_cc_hours1_child5 = 0;
	our $summerday5_cc_start1_child1 = 0;
	our $summerday5_cc_start1_child2 = 0;
	our $summerday5_cc_start1_child3 = 0;
	our $summerday5_cc_start1_child4 = 0;
	our $summerday5_cc_start1_child5 = 0;
	our $summerday5care_child1 = 0;
	our $summerday5care_child2 = 0;
	our $summerday5care_child3 = 0;
	our $summerday5care_child4 = 0;
	our $summerday5care_child5 = 0;
	our $summerday5cost_child1 = 0;
	our $summerday5cost_child2 = 0;
	our $summerday5cost_child3 = 0;
	our $summerday5cost_child4 = 0;
	our $summerday5cost_child5 = 0;
	our $summerday6_cc_end1_child1 = 0;
	our $summerday6_cc_end1_child2 = 0;
	our $summerday6_cc_end1_child3 = 0;
	our $summerday6_cc_end1_child4 = 0;
	our $summerday6_cc_end1_child5 = 0;
	our $summerday6_cc_hours_child1 = 0;	
	our $summerday6_cc_hours_child2 = 0;	
	our $summerday6_cc_hours_child3 = 0;	
	our $summerday6_cc_hours_child4 = 0;	
	our $summerday6_cc_hours_child5 = 0;	
	our $summerday6_cc_hours1_child1 = 0;
	our $summerday6_cc_hours1_child2 = 0;
	our $summerday6_cc_hours1_child3 = 0;
	our $summerday6_cc_hours1_child4 = 0;
	our $summerday6_cc_hours1_child5 = 0;
	our $summerday6_cc_start1_child1 = 0;
	our $summerday6_cc_start1_child2 = 0;
	our $summerday6_cc_start1_child3 = 0;
	our $summerday6_cc_start1_child4 = 0;
	our $summerday6_cc_start1_child5 = 0;
	our $summerday6care_child1 = 0;
	our $summerday6care_child2 = 0;
	our $summerday6care_child3 = 0;
	our $summerday6care_child4 = 0;
	our $summerday6care_child5 = 0;
	our $summerday6cost_child1 = 0;
	our $summerday6cost_child2 = 0;
	our $summerday6cost_child3 = 0;
	our $summerday6cost_child4 = 0;
	our $summerday6cost_child5 = 0;
	our $summerday7_cc_end1_child1 = 0;
	our $summerday7_cc_end1_child2 = 0;
	our $summerday7_cc_end1_child3 = 0;
	our $summerday7_cc_end1_child4 = 0;
	our $summerday7_cc_end1_child5 = 0;
	our $summerday7_cc_hours_child1 = 0;	
	our $summerday7_cc_hours_child2 = 0;	
	our $summerday7_cc_hours_child3 = 0;	
	our $summerday7_cc_hours_child4 = 0;	
	our $summerday7_cc_hours_child5 = 0;	
	our $summerday7_cc_hours1_child1 = 0;
	our $summerday7_cc_hours1_child2 = 0;
	our $summerday7_cc_hours1_child3 = 0;
	our $summerday7_cc_hours1_child4 = 0;
	our $summerday7_cc_hours1_child5 = 0;
	our $summerday7_cc_start1_child1 = 0;
	our $summerday7_cc_start1_child2 = 0;
	our $summerday7_cc_start1_child3 = 0;
	our $summerday7_cc_start1_child4 = 0;
	our $summerday7_cc_start1_child5 = 0;
	our $summerday7care_child1 = 0;
	our $summerday7care_child2 = 0;
	our $summerday7care_child3 = 0;
	our $summerday7care_child4 = 0;
	our $summerday7care_child5 = 0;
	our $summerday7cost_child1 = 0;
	our $summerday7cost_child2 = 0;
	our $summerday7cost_child3 = 0;
	our $summerday7cost_child4 = 0;
	our $summerday7cost_child5 = 0;
	our $sundayhours = 0;
	our $sundayshifts = 0;
	our $thursdayshifts = 0;
	our $tuesdayshifts = 0;
	our $unsub_all_children = 0; 	# unsubsidized cost of child care for all children (output)
	our $unsub_child1 = 0; 
	our $unsub_child2 = 0; 
	our $unsub_child3 = 0; 
	our $unsub_child4 = 0; 
	our $unsub_child5 = 0; 
	our $unsub_type1 = 0;  
	our $unsub_type2 = 0; 
	our $unsub_type3 = 0;  
	our $unsub_type4 = 0;  
	our $unsub_type5 = 0;  
	our $userenteredvalues = 0;
	our $wednesdayshifts = 0;
	our $weekdayhours = 0;
	our $weekdaymaxworkweek = 0;
	our $weekdayshifts = 0;
	our $weekdaysworked = 0;
	our $wkndremainder = 0;
	our $cc_expenses_child1 = 0; # We need these variables for the child support code to run twice correctly.
	our $cc_expenses_child2 = 0; 
	our $cc_expenses_child3 = 0;
	our $cc_expenses_child4 = 0;
	our $cc_expenses_child5 = 0;
	#Variables incorporating nontraditional hours:
	our $fullcost_child1 = 0;
	our $fullcost_child2 = 0;
	our $fullcost_child3 = 0;
	our $fullcost_child4 = 0;
	our $fullcost_child5 = 0;
	our $fullcost_child5 = 0;
	our $fullcost_all_children = 0;
	our $spr_nontrad_bonus = 1; #The additional amount KY is providing per day for CCDF coverage during nontraditional hours.
	our $nontraditional_days_child1 = 0;
	our $nontraditional_days_child2 = 0;
	our $nontraditional_days_child3 = 0;
	our $nontraditional_days_child4 = 0;
	our $nontraditional_days_child5 = 0;
	our $nontraditional_summerdays_child1 = 0;
	our $nontraditional_summerdays_child2 = 0;
	our $nontraditional_summerdays_child3 = 0;
	our $nontraditional_summerdays_child4 = 0;
	our $nontraditional_summerdays_child5 = 0;
	our $child1_weekly_cc_hours = 0;
	our $child2_weekly_cc_hours = 0;
	our $child3_weekly_cc_hours = 0;
	our $child4_weekly_cc_hours = 0;
	our $child5_weekly_cc_hours = 0;
	our $child1_weekly_cc_hours_summer = 0;
	our $child2_weekly_cc_hours_summer = 0;
	our $child3_weekly_cc_hours_summer = 0;
	our $child4_weekly_cc_hours_summer = 0;
	our $child5_weekly_cc_hours_summer = 0;
	our $weeks_off  = 0;				#calculating the number of weeks a bonding parent does not need for child care. 
	our $summerweeks = 0;
	
	our $childcare_threshold_age_child1 = 0;
	our $childcare_threshold_age_child2 = 0;
	our $childcare_threshold_age_child3 = 0;
	our $childcare_threshold_age_child4 = 0;
	our $childcare_threshold_age_child5 = 0;
	
	use POSIX;
	# 1. DETERMINE NEED FOR CARE AND CHECK CCDF FLAG
	#
	if ($out->{'parent_workhours_w'} == 0 || $in->{'children_under13'} + $in->{'disabled_older_children'} == 0) { 
		#  $child_care_debug .= "- Ineligible at step 1 ";
		$unsub_all_children = 0;
		$spr_all_children = 0;
	} else  {
		#Maybe just create the arrays from csv's here?
		csvtoarrays($in->{'dir'}.'\FRS_spr.csv'); #Possibly move this to runfrsnj perl file to just run it once, but will then need to redefine function so that it names the arrays something specific to the excel sheet, maybe as an arguemnt. E.g. spr_age_min, and refer to those in the csv_arraylookup functions below.
		#print @spr;

		# We first have to check that the hometime variables, combined with the second parent’s work schedule, do not mathematically conflict. 
		if ( (&greatest($out->{'parent1_transhours_w'}, $out->{'parent2_transhours_w'})) + $in->{'breadwinner_wkend_hometime'} + $in->{'breadwinner_wkday_hometime'}  > 168) {
			# First chip away at the weekends at home if the second parent works, then weekdays. Vice versa if the caregiving parent doesn’t work on weekends. Conceivably, we could try to maximize this based on whether the first (caregiving) parent works on weekends, but that would just take too much code and be too reliant on additional assumptions.
			$remaining_wknd_hometime = &pos_sub(168 - &greatest($out->{'parent1_transhours_w'}, $out->{'parent2_transhours_w'}), $out->{'breadwinner_wkday_hometime'});
		
			if (&greatest($out->{'parent1_transhours_w'}, $out->{'parent2_transhours_w'}) + $remaining_wknd_hometime + $in->{'breadwinner_wkday_hometime'} > 168) {
				$remaining_wkdy_hometime = &pos_sub(168 - &greatest($out->{'parent1_transhours_w'}, $out->{'parent2_transhours_w'}), $remaining_wknd_hometime);
			
			} else {
				$remaining_wkdy_hometime = $in->{'breadwinner_wkday_hometime'};

			}

		
		} else {
		$remaining_wknd_hometime = $in->{'breadwinner_wkend_hometime'};
		$remaining_wkdy_hometime = $in->{'breadwinner_wkday_hometime'};
		}
		# Now calculate how many days and the number of hours worked by one parent on Saturday or Sunday, and adjust the weekend hometime amount by the maximum allowable time. Let’s assume this is the second parent in a two-parent family, or the only parent in a one-parent family, who works on the weekend.

		# WEEKENDS:
		# It doesn’t matter in terms of expenses whether a parent works on a Saturday or Sunday, so to lessen confusion we can arbitrarily assign the first weekend day worked to be Saturday, if the user opts to model weekend work.
		# Need to make sure to define all these created variables as 0’s at beginning of this subroutine.
		if (($in->{'weekenddaysworked'} == 1 && $out->{'caregiver_maxworkweek'} >= 1) || (($in->{'weekenddaysworked'} == 2) && ($out->{'caregiver_maxworkweek'} == 1)))  {  
			$saturdayshifts = &least($out->{'caregiver_workshifts_w'}, $in->{'maxweekendshifts'});
			$saturdayhours = $saturdayshifts * $out->{'caregiver_maxshiftlength'};
			$day6_cc_hours = &pos_sub($saturdayhours + $roundtriptraveltime + (ceil($saturdayshifts) - 1) * $out->{'caregiver_backtobackshifts'}, $remaining_wknd_hometime); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
			# It is important to note here that the above can result as either 0, a whole number, or a number with decimals. The decimals are important in defining the number of hours needed when hours do not fit neatly into shifts. To calculate the number of hours of child care needed each Saturday, we use the maxshiftlength variable to convert this time from shifts to hours.
			# We then add travel time based on at least round trip to and from work, as well as the time it takes to travel between shifts or to make a round trip, involving pickup from child care, using the backtobackshifts variable (which is either 0, 1, or 2). We can also utilize the variables that, for two-parent families, allow one parent to be at home while the other parent works or travels to work. For single-parent families, breadwinner_wkend_hometime = 0, so this formula applies to both. 
		} elsif (($in->{'weekenddaysworked'} == 2) && ($out->{'caregiver_maxworkweek'} >= 2)) { 
			$wkndremainder = (&least($out->{'caregiver_workshifts_w'}, $in->{'maxweekendshifts'}) - (floor(&least($out->{'caregiver_workshifts_w'}, $in->{'maxweekendshifts'}))));
			$saturdayshifts = floor(&least($out->{'caregiver_workshifts_w'}/2, $in->{'maxweekendshifts'}/2)) + $wkndremainder;
			$saturdayhours = $saturdayshifts * $out->{'caregiver_maxshiftlength'};
			$sundayshifts = &pos_sub(&least($out->{'caregiver_workshifts_w'}, $in->{'maxweekendshifts'}), $saturdayshifts);
			$sundayhours = $sundayshifts * $out->{'caregiver_maxshiftlength'};
			$day6_cc_hours = &pos_sub($saturdayhours + $roundtriptraveltime + (ceil($saturdayshifts) - 1) * $out->{'caregiver_backtobackshifts'}, $remaining_wknd_hometime); 
			# For two-parent families, we can calculate the remaining breadwinner hometime. WE can do this by invoking the inverse of the &pos_sub operation above.
			$remaining_wknd_hometime = &pos_sub($remaining_wknd_hometime, $saturdayhours + $roundtriptraveltime + (ceil($saturdayshifts) - 1) * $out->{'caregiver_backtobackshifts'}); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
			$day7_cc_hours = &pos_sub($sundayhours + $roundtriptraveltime + (ceil($sundayshifts) - 1) * $out->{'caregiver_backtobackshifts'}, $remaining_wknd_hometime); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
		}

		# WEEKDAYS
		$weekdayshifts = &pos_sub($out->{'caregiver_workshifts_w'}, $saturdayshifts + $sundayshifts);
		$weekdayhours = &pos_sub($out->{'parent_workhours_w'}, $saturdayhours + $sundayhours);
		if ($saturdayshifts > 0 && $sundayshifts > 0) {
			$weekdaymaxworkweek = ($out->{'caregiver_maxworkweek'} - 2);
		} elsif ($saturdayshifts > 0) {
			$weekdaymaxworkweek = ($out->{'caregiver_maxworkweek'} - 1);
		} else {
			$weekdaymaxworkweek = $out->{'caregiver_maxworkweek'};
		}

		# It is important to remember here that at this point, weekdaymaxworkweek might equal 0, meaning that child care is only needed on Saturdays and/or Sundays.

		# Now we calculate the number of days the caregiver works:

		if ($weekdayshifts >= $weekdaymaxworkweek) {
			$weekdaysworked = $weekdaymaxworkweek;
		} else {
			$weekdaysworked = ceil($weekdayshifts);
		}
		# There are three types of possible weekdays in terms of the share of shifts. N shifts, N - 1 shifts, and one day that has a number of shifts in between these two numbers. Each permutation will have a different number of hours needed for possible child care. We can begin by first identifying the pesky partial-shift day. We will do this throughout the various weekdaysworked scenarios, with always Monday being the day a possible decimal can appear in its shifts.  Because we round up for the days after Monday but before the last day, 

		if ($weekdaysworked > 0) {
			$remainder = ($weekdayshifts - (floor($weekdayshifts/$weekdaysworked)*$weekdaysworked));
		}

		#to delete before migration to prod. JSB this was changed, please confirm with Seth. it's throwing an odd error regardless of how i rewrite this. 
		#	$mondayshifts = floor($weekdayshifts/$weekdaysworked);
		#	$tuesdayshifts = floor ($weekdayshifts/$weekdaysworked);
		#	$wednesdayshifts = floor($weekdayshifts/$weekdaysworked);
		#	$thursdayshifts = floor($weekdayshifts/$weekdaysworked);
		#	$fridayshifts = floor($weekdayshifts/$weekdaysworked);

		if ($weekdaysworked == 1) {
			$mondayshifts = floor($weekdayshifts/$weekdaysworked); 
		} elsif ($weekdaysworked == 2) {
			$mondayshifts = floor($weekdayshifts/$weekdaysworked);
			$tuesdayshifts = floor($weekdayshifts/$weekdaysworked);
		} elsif ($weekdaysworked== 3) {
			$mondayshifts = floor($weekdayshifts/$weekdaysworked);
			$tuesdayshifts = floor($weekdayshifts/$weekdaysworked);
			$wednesdayshifts = floor($weekdayshifts/$weekdaysworked);
		} elsif ($weekdaysworked == 4) {
			$mondayshifts = floor($weekdayshifts/$weekdaysworked);
			$tuesdayshifts = floor($weekdayshifts/$weekdaysworked);
			$wednesdayshifts = floor($weekdayshifts/$weekdaysworked);
			$thursdayshifts = floor($weekdayshifts/$weekdaysworked);
		} elsif ($weekdaysworked== 5) {
			$mondayshifts = floor($weekdayshifts/$weekdaysworked);
			$tuesdayshifts = floor ($weekdayshifts/$weekdaysworked);
			$wednesdayshifts = floor($weekdayshifts/$weekdaysworked);
			$thursdayshifts = floor($weekdayshifts/$weekdaysworked);
			$fridayshifts = floor($weekdayshifts/$weekdaysworked);
		}

	
		if ($remainder > 0 && $remainder <=1) {
			$mondayshifts = $mondayshifts + $remainder;
		} elsif ($remainder > 1 && $remainder <=2) {
			$mondayshifts = $mondayshifts + 1;
			$tuesdayshifts = $tuesdayshifts + $remainder - 1;
		} elsif ($remainder > 2 && $remainder <=3) {
			$mondayshifts = $mondayshifts + 1;
			$tuesdayshifts = $tuesdayshifts + 1;
			$wednesdayshifts = $wednesdayshifts + $remainder - 2;
		} elsif ($remainder > 3 && $remainder <=4) {
			$mondayshifts = $mondayshifts + 1;
			$tuesdayshifts = $tuesdayshifts + 1;
			$wednesdayshifts = $wednesdayshifts + 1;
			$thursdayshifts = $thursdayshifts + $remainder - 3;
		} elsif ($remainder > 4 && $remainder <=5) {
			$mondayshifts = $mondayshifts + 1;
			$tuesdayshifts = $tuesdayshifts + 1;
			$wednesdayshifts = $wednesdayshifts + 1;
			$thursdayshifts = $thursdayshifts + 1;
			$fridayshifts = $fridayshifts + $remainder - 4;
		}

		# Through this manipulation, fridayshifts < thursdayshifts < wednesdayshifts < tuesdayshifts < mondayshifts. We can use these inequalities to optimize the reduction in child care caused by one parent staying home when another parent is working. 
		#JSB CHECK THIS PLEASE 
		$day5hours = &pos_sub(($fridayshifts * $out->{'caregiver_maxshiftlength'}) + ($roundtriptraveltime*ceil(&least(1, $fridayshifts)) + (ceil($fridayshifts) - 1) * $out->{'caregiver_backtobackshifts'}), $remaining_wkdy_hometime); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
		$remaining_wkdy_hometime = &pos_sub($remaining_wkdy_hometime, $fridayshifts * $out->{'caregiver_maxshiftlength'} + $roundtriptraveltime*ceil(&least(1, $fridayshifts))  + (ceil($fridayshifts) - 1) * $out->{'caregiver_backtobackshifts'}); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
		$day4hours = &pos_sub($thursdayshifts * $out->{'caregiver_maxshiftlength'} + $roundtriptraveltime* ceil(&least(1, $thursdayshifts))  + (ceil($thursdayshifts) - 1) * $out->{'caregiver_backtobackshifts'}, $remaining_wkdy_hometime); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
		$remaining_wkdy_hometime = &pos_sub($remaining_wkdy_hometime, $thursdayshifts * $out->{'caregiver_maxshiftlength'} + $roundtriptraveltime *ceil(&least(1, $thursdayshifts)) + (ceil($thursdayshifts) - 1) * $out->{'caregiver_backtobackshifts'}); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
		$day3hours = &pos_sub($wednesdayshifts * $out->{'caregiver_maxshiftlength'} + $roundtriptraveltime *ceil(&least(1, $wednesdayshifts)) + (ceil($wednesdayshifts) - 1) * $out->{'caregiver_backtobackshifts'}, $remaining_wkdy_hometime); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
		$remaining_wkdy_hometime = &pos_sub($remaining_wkdy_hometime, $wednesdayshifts * $out->{'caregiver_maxshiftlength'} + $roundtriptraveltime *ceil(&least(1, $wednesdayshifts)) + (ceil($wednesdayshifts) - 1) * $out->{'caregiver_backtobackshifts'}); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
		$day2hours = &pos_sub($tuesdayshifts * $out->{'caregiver_maxshiftlength'} + $roundtriptraveltime *ceil(&least(1, $tuesdayshifts)) + (ceil($tuesdayshifts) - 1) * $out->{'caregiver_backtobackshifts'}, $remaining_wkdy_hometime); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
		$remaining_wkdy_hometime = &pos_sub($remaining_wkdy_hometime, $tuesdayshifts * $out->{'caregiver_maxshiftlength'} + $roundtriptraveltime *ceil(&least(1, $tuesdayshifts)) + (ceil($tuesdayshifts) - 1) * $out->{'caregiver_backtobackshifts'}); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
		$day1hours = &pos_sub($mondayshifts * $out->{'caregiver_maxshiftlength'} + $roundtriptraveltime *ceil(&least(1, $mondayshifts)) + (ceil($mondayshifts) - 1) * $out->{'caregiver_backtobackshifts'}, $remaining_wkdy_hometime); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.
		$remaining_wkdy_hometime = &pos_sub($remaining_wkdy_hometime, $mondayshifts * $out->{'caregiver_maxshiftlength'} + $roundtriptraveltime *ceil(&least(1, $mondayshifts)) + (ceil($mondayshifts) - 1) * $out->{'caregiver_backtobackshifts'}); #10/20 edit: removed the text ".5 * $roundtriptraveltime *" from this equation.

		# How much child care does a child need?

		# From the school schedule at 
		# We need to use how many weeks of summer there is.
		$summerweeks = &csvlookup($in->{'dir'}.'\FRS_Locations.csv', 'summerweeks', 'id', $in->{'residence'});

		if (1 == 0) { #EquivalentSQL
			my $sql = "SELECT DISTINCT summerweeks FROM FRS_Locations WHERE state = ? && year = ? && id = ?";
			my $stmt = $dbh->prepare($sql) ||
				&fatalError("Unable to prepare $sql: $DBI::errstr");
			$stmt->execute($in->{'state'}, $in->{'year'}, $in->{'residence'}) ||
				&fatalError("Unable to execute $sql: $DBI::errstr");
			$summerweeks = $stmt->fetchrow();
			# School days last from 8:45am to 3:15pm for children of all grades, or 6.5 hours. See the indication at https://dcps.dc.gov/ece that pre-school children have the same calendar as traditionally-aged schoolchildren. 
		}
		
		#For children 1-5 
		for(my $i=1; $i<=5; $i++) {
			
			#Setting the threshold for child care. Probably an easier way to do this, but setting these up here makes the code below less complicated.
			if ($in->{'disability_child'.$i} == 0) {
				${'childcare_threshold_age_child'.$i} = 13;
			} else {
				${'childcare_threshold_age_child'.$i} = 19;
			}
				
			#IMPORTANT NOTE RE PRE-K: Assessing eligibiltiy for free pre-K: All 4-year-olds are potentially eligible for free pre-K, as space allows, but all school districts must allow children whose family income is below 160% or who satisfy National School Lunch Program or School Breakfst Program eligibility requirements, whose parents opt in to the program, to access free Pre-K. Notably, once a child is enrolled in free pre-K, they cannot be un-enrolled; there is no recertification period since the program only lasts one year. This means that in essence, similar to Head Start, there is no exit eligibiltiy income limit. We could, conceivably, build in an applicant income test to determine whether a child satisfied the age requirements (which we do below) AND using the minimum earnings level or the initial earnigns to see if that falls below the income threshold of 160% FPG, but we generally do not model applicant eligibility. If we were doing that, or perhaps used the earnings min or the initial earnings level as the starting inocme point, we would also have to allow some version or approximation of the SNAP codes (fsp.pl) to run either inside this code or before it, since SNAP eligibiltiy confers categorical eligibiltiy for free school lunches, which provides categorical eligibility for free pre-K. This would get complicated -- since SNAP eligibility is partially dependent on child care costs (and other benefit programs like child support which can also be impacted by child care costs), and access to preschool influences child care costs. Some workaround is likely possible, though, but may involve at least one more large loop after fsp.pl is run. 
			# For future reference, all 3- or 4-year-olds who have disabilities whose parents seek free pre-K must also be able to access it. But we are not modeling children with disabiltiies in the KY FRS (yet).

			if (($in->{'prek'} == 1 && $in->{'child'.$i.'_age'} >= $prek_age_min && $in->{'child'.$i.'_age'}<=$prek_age_max)|| ($in->{'child'.$i.'_age'} >= 5 && $in->{'child'.$i.'_age'} < ${'childcare_threshold_age_child'.$i})) {
				if ($in->{'ostp'} == 1) { #We are not modeling OSTP for KY or NJ, so that variable is always 0 and this condition is never satisfied.
					#The child is in afterschool, so the total time they are away from home (and without need for child care) is from 8:45pm-6pm. That’s 9.25 hours for now. That leaves 15 potential hours of child care.
					#Technically, 
					${'schoolend_child'.$i} = $schoolend_ostp_prek;
				} elsif (($in->{'prek'} == 1 && $in->{'child'.$i.'_age'} >= $prek_age_min && $in->{'child'.$i.'_age'}<=$prek_age_max && $in->{'fullday_prek'} == 0) || ($in->{'fullday_k'} == 0 && $in->{'child'.$i.'_age'} == 5)) {
					#Half-day pre-K is only 2.5 hours per day, not including time to provide breakfast and lunch. Different schools have different options for how to arrange the hours, including a potential arrangement of 4 days of school (with a single or double session) and a 5th day reserved "for services to children and their families, such as home visits, special experiences for children, parent training, or coordination of medical or social services." 5-day instruction is rare for KY preschool (https://legislature.ky.gov/LRC/Publications/Research%20Reports/RR450.pdf), but that option is specific to instruction, and clearly indicates some serves should be provided in lieu of instruction. For simplicity's sake -- and in the absence of school district data at leat for the time being, we are modeling 2.5 hours plus a half hour for breakfst or lunch in time that the parent does not need to pay for child care. 
					${'schoolend_child'.$i} = $schoolend_halfday;			
				} else {
					${'schoolend_child'.$i} = $schoolend_fullday;
				}
			}
			# We need to keep in mind that this family can include children who need child care and children who do not need child care. 
												 
			if ($in->{'child'.$i.'_age'} >= ${'childcare_threshold_age_child'.$i} || $in->{'child'.$i.'_age'} == -1) {
				# for days 1-7:
				${'spr_child'.$i} = 0;
				${'unsub_child'.$i} = 0;
				for(my $j=1; $j<=7; $j++) {
					${'day' . $j . '_cc_hours_child' . $i} = 0; 
					${'summerday' . $j . '_cc_hours_child' . $i} = 0; 
					${'day' . $j . 'care_child' . $i} = 'none';
					${'summerday' . $j . 'care_child' . $i} = 'none';
				}
			} 
			else {
							   
				${'day6_cc_hours_child' . $i} = $day6_cc_hours; 
				${'day7_cc_hours_child' . $i} = $day7_cc_hours;
				if ($in->{'child'.$i.'_age'} <= 2 || ($in->{'prek'} == 0 && $in->{'child'.$i.'_age'} >= $prek_age_min && $in->{'child'.$i.'_age'} <= $prek_age_max)) {
					#The child is not in school, therefore cannot have their child care hours reduced by the length of the school day.
					# For days 1-5 
					for(my $j=1; $j<=5; $j++) {
							${'day' . $j . '_cc_hours_child' . $i} = ${'day'.$j.'hours'}; 
							${'day' . $j . '_cc_start1_child' . $i} = $in->{'workdaystart'};
							${'day' . $j . '_cc_end1_child' . $i} =  $in->{'workdaystart'} + ${'day'.$j.'hours'};
							${'summerday' . $j . '_cc_hours_child' . $i} = ${'day' . $j . 'hours'}; 
							${'summerday' . $j . '_cc_start1_child' . $i} = $in->{'workdaystart'}; 
							${'summerday'.$j.'_cc_end1_child' .$i} = $in->{'workdaystart'} + ${'day'.$j.'hours'}; 
					}
				} else { 	# Child is school age.
					#for days 1-5:
					for(my $j=1; $j<=5; $j++) {
						if (${'day'.$j.'hours'} > 0 ) {
							#During the school year : 
							# Children can take the schoolbus  (check), so we subtract an hour in the morning and add an hour at the end of the day. We have to figure out how this would work for KY. For DC, DCPS transports only special needs students in the District. While kids enrolled in DCPS schools ride free on DC’s metro, which we accounted for in transportation costs, parents may have safety concerns about children under age 13 riding the metro on their own. That means that a parent would have to spend time to accompany the child to school or make arrangements for children to get to school and back. For example, they could pay for a carpool service or be accompanied by trusted neighborhood adults or older siblings. If the user wants to model additional costs for these alternative arrangements (e.g., contributing to carpooling expenses), then the user can add expenses in the other expenses field on step 7).

							${'day'.$j.'_cc_hours1_child' .$i} = (&pos_sub(($schoolstart - 1), $in->{'workdaystart'}) - &pos_sub($schoolstart - 1, $in->{'workdaystart'} + ${'day'.$j.'hours'})); #*problem line
							
							${'day'.$j.'_cc_hours2_child' .$i} = (&pos_sub(($in->{'workdaystart'} + ${'day'.$j.'hours'}), ${'schoolend_child'.$i} + 1) - &pos_sub($in->{'workdaystart'}, ${'schoolend_child'.$i} + 1)); 
							# We need to account for the fact that some night shifts may bleed into the school day, and then, for really long shifts, whether night shifts bleed into the next evening. 
							if ($in->{'workdaystart'} + ${'day'.$j.'hours'} > 24 + ($schoolstart - 1)) {
								${'day'.$j.'_cc_hours2_child' .$i} = ${'day'.$j.'_cc_hours2_child' .$i} - ($in->{'workdaystart'} +${'day'.$j.'hours'} - (24 + ($schoolstart - 1))); 
								if ($in->{'workdaystart'} + ${'day'.$j.'hours'} > 24 + (${'schoolend_child'.$i} + 1)) {
									${'day'.$j.'_cc_start3_child' .$i} = ${'schoolend_child'.$i} + 1;
									${'day'.$j.'_cc_end3_child' .$i} = $in->{'workdaystart'} + ${'day'.$j.'hours'} - 24;
									${'day'.$j.'_cc_hours3_child' .$i} = ${'day'.$j.'_cc_end3_child' .$i} - ${'day'.$j.'_cc_start3_child' .$i};
								} 
							} 
							${'day' . $j . '_cc_hours_child' . $i}  = ${'day'.$j.'_cc_hours1_child' .$i} + ${'day'.$j.'_cc_hours2_child' .$i} + ${'day'.$j.'_cc_hours3_child' .$i}; 
							#We now also define the starts and ends of the two traditional bouts of non-summer childcare:
							if (${'day'.$j.'_cc_hours1_child' .$i}  > 0) {
								${'day' . $j . '_cc_start1_child' . $i}  = $in->{'workdaystart'};  
								${'day' . $j . '_cc_end1_child' . $i}  = &least($in->{'workdaystart'} + ${'day'.$j.'hours'}, $schoolstart - 1); 
							}
							if (${'day'.$j.'_cc_hours2_child' .$i} > 0) {
								${'day'.$j.'_cc_start2_child'.$i} = &greatest($in->{'workdaystart'}, ${'schoolend_child'.$i} + 1);  
								${'day'.$j.'cc_end2_child'.$i} = &least($in->{'workdaystart'} + ${'day'.$j.'hours'}, 24 + ($schoolstart - 1)); 
							}
							# During summer:
							${'summerday'.$j.'_cc_hours_child'.$i}  = ${'day'.$j.'hours'};   
							${'summerday'.$j.'_cc_start1_child'.$i} = $in->{'workdaystart'};  
							${'summerday'.$j.'_cc_end1_child' .$i}  =  $in->{'workdaystart'} + ${'day'.$j.'hours'}; 
						}
					}
	 
				}	

				# We are now ready to see what category child care hours fall under. Yay.
				#We also now account for some states' s policies of increasing SPR's above by fixed amounts for days delivering nontraditional care. This can important partially because the SPRs are needed to allow for the calculation of child care costs about co-pays for families (overage payments). But, tentatively, it appears that NJ does not include any distinctions based on nontraditional vs. traditional care.
#LOOK AT ME - need to do comprehensive review of NJ child care policies to see if CCDF policies really are irrespective of nontraditional hours.				

				#The next operation breaks down whether a unit of care is full-time, part-time, or nonexistent.
				# WEEKENDS:
				#For days 6-7:	
			
				for(my $j=6; $j<=7; $j++) { 
					if (${'day' . $j . '_cc_hours_child' . $i}  == 0){
						${'day'.$j.'care_child'.$i} = 'none'; 
						${'summerday'.$j.'care_child'.$i} = 'none'; 
					} elsif (${'day' . $j . '_cc_hours_child' . $i}  > 0 && ${'day' . $j . '_cc_hours_child' . $i}  < 6) {
						${'day'.$j.'care_child'.$i} = 'parttime'; 
						${'summerday'.$j.'care_child'.$i}  = 'parttime';
						#${'nontraditional_days_child'.$i} +=1;
						#${'nontraditional_summerdays_child'.$i} +=1;
					} else { # more than 9 hours
						# Full time care is  9 hours or more. 
						${'day'.$j.'care_child'.$i}  = 'fulltime'; 
						${'summerday'.$j.'care_child'.$i}  = 'fulltime'; 
						#${'nontraditional_days_child'.$i} +=1;
						#${'nontraditional_summerdays_child'.$i} +=1;
					}
	 
				} 	
				# WEEKDAYS during the school year:
				# For days 1-5:  non-school-age children, during the school year (same as summer days)
				for(my $j=1; $j<=5; $j++) {
					if ($in->{'child'.$i.'_age'} <= 2 || ($in->{'prek'} == 0 && ($in->{'child'.$i.'_age'}>= $prek_age_min && $in->{'child'.$i.'_age'} <= $prek_age_max))) {
						if (${'day'.$j.'_cc_hours_child' . $i}  == 0) {
							${'day'.$j.'care_child'.$i}  = 'none'; 
						} elsif (${'day' . $j . '_cc_hours_child' . $i}  > 0 && ${'day'.$j.'_cc_hours_child' . $i}  < $ft_child_care_min) {
							${'day'.$j.'care_child'.$i}  = 'parttime'; 
						} else { # over 9 hours of care
							${'day'.$j.'care_child'.$i}  = 'fulltime';  
						}
						if ((${'day'.$j.'care_child'.$i} eq 'parttime' || ${'day'.$j.'care_child'.$i} eq 'fulltime') &&  (${'day'.$j.'_cc_start1_child'.$i} < 5 || ${'day'.$j.'_cc_end1_child'.$i} > 19)) {
							#${'nontraditional_days_child'.$i} +=1;
						}
						
	 
					} else { #School-age children:	
						if (${'day' . $j . '_cc_hours_child' . $i}  == 0) {
							${'day'.$j.'care_child'.$i}  = 'none'; 
						} elsif (${'day' . $j . '_cc_hours_child' . $i}  < $ft_child_care_min) {
							${'day'.$j.'care_child'.$i}  = 'parttime'; 
						} else { 
							${'day'.$j.'care_child'.$i}  = 'fulltime';  
						} 
						if ((${'day'.$j.'care_child'.$i} eq 'parttime' || ${'day'.$j.'care_child'.$i} eq 'fulltime') && (${'day'.$j.'_cc_start1_child'.$i} < 5 || ${'day'.$j.'_cc_end1_child'.$i} > 19 || ${'day'.$j.'_cc_start2_child'.$i} > 19 || ${'day'.$j.'_cc_end2_child'.$i} > 19 || ${'day'.$j.'_cc_hours3_child' .$i} > 0)) {
							#${'nontraditional_days_child'.$i} +=1;
						}
					}
					
					if ($in->{'disability_child'.$i} == 1) {

						if (${'day'.$j.'_cc_hours_child'.$i} > 0) {
							#LOOK AT ME: Once "partime" to "parttime" typo is corrected, change this if block to this line:
							#${'day'.$j.'care_child'.$i} = ${'day'.$j.'care_child'.$i}.'_special';
							
							#But in the meantime, since we can't concatenate like that,
							if (${'day'.$j.'care_child'.$i}  eq 'parttime') { 
								${'day'.$j.'care_child'.$i} = 'partime_special'; 
							} elsif (${'day'.$j.'care_child'.$i} eq 'fulltime') {
								${'day'.$j.'care_child'.$i} = 'fulltime_special';
							}

						}
					}

				}
				${'child'.$i.'_weekly_cc_hours'} = ${'day1_cc_hours_child'.$i} + ${'day2_cc_hours_child'.$i} + ${'day3_cc_hours_child'.$i} + ${'day4_cc_hours_child'.$i} + ${'day5_cc_hours_child'.$i} + ${'day6_cc_hours_child'.$i} + ${'day7_cc_hours_child'.$i}; 
			
				# WEEKDAYS during summer
				#For days 1-5: 
				for(my $j=1; $j<=5; $j++) { 
					if (${'summerday'.$j.'_cc_hours_child'.$i}  == 0) {
						${'summerday'.$j.'care_child'.$i}  = 'none'; 
					} elsif (${'summerday'.$j.'_cc_hours_child'.$i}  < $ft_child_care_min) {
						${'summerday'.$j.'care_child'.$i}  = 'parttime'; 	  
					} else {
						${'summerday'.$j.'care_child'.$i}  = 'fulltime'; 
					}
					if ((${'summerday'.$j.'care_child'.$i} eq 'parttime' || ${'summerday'.$j.'care_child'.$i} eq 'fulltime') &&  (${'summerday'.$j.'_cc_start1_child'.$i} < 5 || ${'summerday'.$j.'_cc_end1_child'.$i} > 19)) {
						#${'nontraditional_summerdays_child'.$i} +=1;
					}
					
					if ($in->{'disability_child'.$i} == 1) { #Building in higher subsidized and unsubsidized child care costs for children with disabilities severe enough to receive SSI. The definition of disability for receiving SSI and of special needs for receiving higher CCDF copays is very similar.
						if (${'summerday'.$j.'_cc_hours_child'.$i} > 0) {
							#LOOK AT ME: Once "partime" to "parttime" typo is corrected, change this if block to this line:
							#${'summerday'.$j.'care_child'.$i} = ${'summerday'.$j.'care_child'.$i}.'_special';

							#But in the meantime, since we can't concatenate like that,
							if (${'summerday'.$j.'care_child'.$i}  eq 'parttime') {
								${'summerday'.$j.'care_child'.$i} = 'partime_special'; #LOOK AT ME: same note as above: when typo (from "partime_special_unsub" to "parttime_special_unsub"  in FRS_spr is corrected, correct this line here.
							} elsif (${'summerday'.$j.'care_child'.$i} eq 'fulltime') {
								${'summerday'.$j.'care_child'.$i} = 'fulltime_special';
							}	
						}
					}
				}
				
				
				${'child'.$i.'_weekly_cc_hours_summer'} = ${'summerday1_cc_hours_child'.$i} + ${'summerday2_cc_hours_child'.$i} + ${'summerday3_cc_hours_child'.$i} + ${'summerday4_cc_hours_child'.$i} + ${'summerday5_cc_hours_child'.$i} + ${'day6_cc_hours_child'.$i} + ${'day7_cc_hours_child'.$i}; 
			}	
		}

		# Note for future consideration: It’s at this point that we should be able to tell pretty well exactly when children are receiving child care. When a child is in child care, the child care provider may or may not provide them with a meal, but based on research by SS it appears that these meals are usually billable to the parent, so a reduction in food costs does not seem in order.  From the market rate report, it seems that if child care facilities participate in the Child and Adult Food Program (CACFP), that facility is reimbursed for the meal, but apparently that program is designed to provide income to child care providers rather than families whose children are in care. 

		#get SQL queries ready			
		
		
		if (1 == 0) { #EquivalentSQL
			my $sql = "SELECT DISTINCT FRS_SPR.spr FROM FRS_CareOptions LEFT JOIN FRS_SPR USING (state, year, ccdf_type) LEFT JOIN FRS_Locations USING (state, year, ccdf_region) WHERE FRS_SPR.state = ? && FRS_SPR.year = ? && FRS_SPR.ccdf_time = ? && FRS_SPR.age_min <= ? && FRS_SPR.age_max >= ? && FRS_Locations.id = ? && FRS_CareOptions.text = ?";
			my $stmt = $dbh->prepare($sql) ||
				&fatalError("Unable to prepare $sql: $DBI::errstr");  
		}

		#Helpful for debugging this code:

		#print 'day2care_child1 = '.$day2care_child1 ."\n";
		#print 'child1_age = ' .$in->{'child1_age'} . "\n";
		#print "child1_withbenefit_setting = ". $in->{"child1_withbenefit_setting"} . "\n";

		#for(my $j=1; $j<=2; $j++) {
		#	${'day'.$j.'cost_child1'} = csv_arraylookup ($in->{'dir'}.'\FRS_spr.csv', 'spr', 'ccdf_time', 'eq', 'fulltime', 'age_min', '<=', 2, 'age_max', '>=', 2, 'ccdf_region', 'eq', 19, 'ccdf_type', 'eq', 'accredited_center');
		#	print 'day'.$j.'cost_child1 = '.${'day'.$j.'cost_child1'} . "\n";
		#}
		
		
		#	for(my $i=1; $i<=1; $i++) {
		#		for(my $j=1; $j<=2; $j++) {
		#			if ($in->{'child'.$i.'_age'} != -1 && $in->{'child'.$i.'_age'}< ${'childcare_threshold_age_child'.$i}) {
		#				if (${"day".$j."care_child".$i} ne 'none') {
		#					${'day'.$j.'cost_child'.$i} = csv_arraylookup ($in->{'dir'}.'\FRS_spr.csv', 'spr', 'ccdf_time', 'eq', ${"day".$j."care_child".$i}, 'age_min', '<=', $in->{'child'.$i.'_age'}, 'age_max', '>=', $in->{'child'.$i.'_age'}, 'ccdf_region', 'eq', 19, 'ccdf_type', 'eq', $in->{"child".$i."_withbenefit_setting"});
		#				}
		#			}
		#		}
		#	}
		
		
		#	for(my $i=1; $i<=5; $i++) {
		#		for(my $j=1; $j<=7; $j++) {
		#			if ($in->{'child'.$i.'_age'} != -1 && $in->{'child'.$i.'_age'}< ${'childcare_threshold_age_child'.$i}) {
		#				if (${"summerday".$j."care_child".$i} ne 'none') {
		#					${'summerday'.$j.'cost_child'.$i} = csv_arraylookup ($in->{'dir'}.'\FRS_spr.csv', 'spr', 'ccdf_time', 'eq', ${"summerday".$j."care_child".$i}, 'age_min', '<=', $in->{'child'.$i.'_age'}, 'age_max', '>=', $in->{'child'.$i.'_age'}, 'ccdf_region', 'eq', 14, 'ccdf_type', 'eq', $in->{"child".$i."_withbenefit_setting"});
		#				}
		#			}
		#		}
		#	}
		
		# for each child from 1-5 :
		for(my $i=1; $i<=5; $i++) {
			if ($in->{'child'.$i.'_age'} != -1 && $in->{'child'.$i.'_age'}< ${'childcare_threshold_age_child'.$i}) {
				
				#calculate weeks off based on fli/tdi receipt. 
				if ($in->{'child'.$i.'_age'} == 0) {
					#We ask users how much time they take off for newborn even if they don't take fli or tdi. 
					$weeks_off = &greatest($in->{'mother_timeoff_for_newborn'},$in->{'other_parent_timeoff_for_newborn'});	#again, here we are assuming the parents are taking overlapping leave (not taking leave one after another but taking leave together). We may need to adjust this to either maximize child care savings and assume the parents don't take leave together or add a user-entered input to ask whether the parents' leave overlaps.	
				} elsif ($in->{'child'.$i.'_foster_status'} >= 1) {
					#We also ask users how much time they take off for  bonding with a foster child, even if they don't take fli or tdi. Need to separate this out from the above condition because parents with both a newborn and a new foster child can take time off separately.
					$weeks_off = &greatest($in->{'parent1_time_off_foster'}, $in->{'parent2_time_off_foster'});	#again, here we are assuming the parents are taking overlapping leave (not taking leave one after another but taking leave together). We may need to adjust this to either maximize child care savings and assume the parents don't take leave together or add a user-entered input to ask whether the parents' leave overlaps.	
				}
				#Subsidized rates:
				
				# For each day from 1-7 :
				for(my $j=1; $j<=7; $j++) {
					# Look up price of child care by type of subsidized care:

					# Look up child care cost by $ccdf_time = $day#care_child#, by child#_age (>= age_min and <=age_max) and care type (ccdf_type = child#_withbenefit_setting), and call that variable $day#cost_child#.
					
					if (${"day".$j."care_child".$i} ne 'none') {
						${'day'.$j.'cost_child'.$i} = csv_arraylookup ($in->{'dir'}.'\FRS_spr.csv', 'spr', 'ccdf_region', 'eq', $in->{'residence'}, 'ccdf_time', 'eq', ${"day".$j."care_child".$i}, 'age_min', '<=', $in->{'child'.$i.'_age'}, 'age_max', '>=', $in->{'child'.$i.'_age'}, 'ccdf_type', 'eq', $in->{"child".$i."_withbenefit_setting"});
					} 
					
					if (1 == 0) { #EquivalentSQL
						$stmt->execute($in->{'state'}, $in->{'year'}, ${"day".$j."care_child".$i}, $in->{"child".$i."_age"}, $in->{"child".$i."_age"}, $in->{'residence'}, $in->{"child".$i."_withbenefit_setting"}) ||&fatalError("Unable to execute $sql: $DBI::errstr");
						${'day'.$j.'cost_child'.$i} = $stmt->fetchrow() / 5; 
					}
					#IMPORTANT NOTE: Note that in NJ, we are dividing the weekly rates in the FRS_SPR table by 5. The justification for this derivation is that the SPR daily rates are all one-fifth of the weekly rates, and there is only weekly or daily (not monthly) in the market rate study. As we are deriving missing values for other market rates than those included in the study based on the ratios between subsidized care and market rates when both are available for certain types of care, we are similarly assuming here that the market rates are proportionately relative to the subsidized rates for the full set of daily rates, which are all misssing from the market rate study.

					# Look up child care cost by $ccdf_time = $summerday#care_child#, by child#_age (>= age_min and <=age_max) and care type (ccdf_type = child#_withbenefit_setting), and call that variable $summerday#cost_child#.
					if (${"summerday".$j."care_child".$i} ne 'none') {
						${'summerday'.$j.'cost_child'.$i} = csv_arraylookup ($in->{'dir'}.'\FRS_spr.csv', 'spr', 'ccdf_region', 'eq', $in->{'residence'}, 'ccdf_time', 'eq', ${"summerday".$j."care_child".$i}, 'age_min', '<=', $in->{'child'.$i.'_age'}, 'age_max', '>=', $in->{'child'.$i.'_age'}, 'ccdf_type', 'eq', $in->{"child".$i."_withbenefit_setting"});
					} 
					if (1 == 0) { #EquivalentSQL
						$stmt->execute($in->{'state'}, $in->{'year'}, ${"summerday".$j."care_child".$i}, $in->{"child".$i."_age"}, $in->{"child".$i."_age"}, $in->{'residence'}, $in->{"child".$i."_withbenefit_setting"}) ||&fatalError("Unable to execute $sql: $DBI::errstr");
						${'summerday'.$j.'cost_child'.$i} = $stmt->fetchrow() / 5;
					}
				}			

				${'spr_child'.$i} = (52 - $summerweeks - $weeks_off)*(${'day1cost_child'.$i} + ${'day2cost_child'.$i} +${'day3cost_child'.$i} + ${'day4cost_child'.$i} + ${'day5cost_child'.$i} +${'day6cost_child'.$i} + ${'day7cost_child'.$i} + ${'nontraditional_days_child'.$i}*$spr_nontrad_bonus) + $summerweeks * (${'summerday1cost_child'.$i} + ${'summerday2cost_child'.$i} + ${'summerday3cost_child'.$i} + ${'summerday4cost_child'.$i} + ${'summerday5cost_child'.$i} + ${'summerday6cost_child'.$i} + ${'summerday7cost_child'.$i} + ${'nontraditional_summerdays_child'.$i}*$spr_nontrad_bonus); #This is the same formula as above, but just want to make sure this is clear that this is for a non-infant whose family is not taking off to care for the infant. #child care costs are the same throughout the year for infants.  
			
				#Unsubsidized rates:
				
				if ($in->{'ccdf'} == 1) {
					if ($in->{'child_care_continue_estimate_source'} ne 'spr') {
						$userenteredvalues = 1;
					}
				} elsif ($in->{'child_care_nobenefit_estimate_source'} ne 'spr') {
					$userenteredvalues = 1;
				}	
				if ($userenteredvalues == 1) {
					# If the user enters a user-entered value for unsubsidized care, at least  one of these values will not equal “spr”, but if they keep to the defaults at least one will. 
					# We still need to figure out how to reconcile the user-entered options for these, and whether or not we want to allow the associated costs to vary  based on the amount of child care need (like the previous FRS’s have allowed). For now, though, I’m just setting that to the monthly value the user enters.
					for(my $j=1; $j<=7; $j++) { 
						if (${'day'.$j.'care_child'.$i} eq 'none') { 
							${'day'.$j.'cost_child'.$i} = 0; 
						} else { 
							if ($in->{'ccdf'} == 1) { 
								${'day'.$j.'cost_child'.$i} = $in->{'child'.$i.'_continue_amt_m'} / 5;  #We divide by 5 in NJ 2021 for the time being because SPRs are expressed as weekly amounts. 
							} else { 
								${'day'.$j.'cost_child'.$i} = $in->{'child'.$i.'_nobenefit_amt_m'} / 5; 
							} 
						} 
						if (${'summerday'.$j.'care_child'.$i} eq 'none') { 
							${'summerday'.$j.'cost_child'.$i} = 0; 
						} else { 
							if ($in->{'ccdf'} == 1) { 
								${'summerday'.$j.'cost_child'.$i} = $in->{'child'.$i.'_continue_amt_m'} / 5; 
							} else { 
								${'summerday'.$j.'cost_child'.$i} = $in->{'child'.$i.'_nobenefit_amt_m'} / 5;
							} 
						} 
					} 
 
					${'unsub_child' . $i} = (52 - $summerweeks - $weeks_off)*(${'day1cost_child'. $i}  + ${'day2cost_child'. $i}  +${'day3cost_child'. $i}  +${'day4cost_child' . $i}  +${'day5cost_child' . $i}  +${'day6cost_child' . $i}  +${'day7cost_child' . $i} ) + $summerweeks * (${'summerday1cost_child' . $i} + ${'summerday2cost_child' . $i} +${'summerday3cost_child' . $i} + ${'summerday4cost_child' . $i} + ${'summerday5cost_child' . $i} +${'summerday6cost_child' . $i} + ${'summerday7cost_child' . $i} ); 
				} else {
					if ($in->{'ccdf'} == 1) {
						${'unsub_type'.$i}  = $in->{'child'.$i.'_continue_setting'}; 
					} else {
						${'unsub_type'.$i} = $in->{'child'.$i.'_nobenefit_setting'};
					} 
					# Look up price of unsubsidized child care by type of care, by type of unsubdized care.
					# For each day from 1-7 :
					for(my $j=1; $j<=7; $j++) { #There's definitely a better way to do all this renaming, probably using concatenations. But going the brute force way for now since it's not a lot of lines to do. That fulltime transforms into Unsubsidized would make this a little less elegant anyway.
						if ($in->{'disability_child'.$i} == 1) {
							if (${'day'.$j.'care_child'.$i}  eq 'parttime_special') { 
								${'day'.$j.'care_child'.$i} = 'partime_special_unsub'; #LOOK AT ME: when typo (from "partime_special_unsub" to "parttime_special_unsub"  in FRS_spr is corrected, correct this line here.
							} elsif (${'day'.$j.'care_child'.$i} eq 'fulltime_special') {
								${'day'.$j.'care_child'.$i} = 'fulltime_special_unsub';
							}
							if (${'summerday'.$j.'care_child'.$i}  eq 'parttime_special') {
								${'summerday'.$j.'care_child'.$i} = 'partime_special_unsub'; #LOOK AT ME: same note as above: when typo (from "partime_special_unsub" to "parttime_special_unsub"  in FRS_spr is corrected, correct this line here.
							} elsif (${'summerday'.$j.'care_child'.$i} eq 'fulltime_special') {
								${'summerday'.$j.'care_child'.$i} = 'fulltime_special_unsub';
							}	
						} else {
							if (${'day'.$j.'care_child'.$i}  eq 'parttime') {
								${'day'.$j.'care_child'.$i} = 'parttime_unsub';
							} elsif (${'day'.$j.'care_child'.$i} eq 'fulltime') { 
								${'day'.$j.'care_child'.$i}  = 'Unsubsidized';
							}
							if (${'summerday'.$j.'care_child'.$i}  eq 'parttime') {
								${'summerday'.$j.'care_child'.$i} = 'parttime_unsub';
							} elsif (${'summerday'.$j.'care_child'.$i} eq 'fulltime') { 
								${'summerday'.$j.'care_child'.$i}  = 'Unsubsidized';
							}
						}
						# Look up child care cost by $ccdf_time = $day#care_child#, by child#_age (>= age_min and <=age_max) and care type (if (CCDF = 1) {ccdf_type = child#_continue_setting} else {ccdf_type = child#_nobenefit_setting}), and call that variable $day#cost_child#.
						
						if (${"day".$j."care_child".$i} ne 'none') {
							${'day'.$j.'cost_child'.$i} = csv_arraylookup ($in->{'dir'}.'\FRS_spr.csv', 'spr', 'ccdf_region', 'eq', $in->{'residence'}, 'ccdf_time', 'eq', ${"day".$j."care_child".$i}, 'age_min', '<=', $in->{'child'.$i.'_age'}, 'age_max', '>=', $in->{'child'.$i.'_age'}, 'ccdf_type', 'eq', ${'unsub_type'.$i});
						} 
						
						if (${"summerday".$j."care_child".$i} ne 'none') {
							${'summerday'.$j.'cost_child'.$i} = csv_arraylookup ($in->{'dir'}.'\FRS_spr.csv', 'spr', 'ccdf_region', 'eq', $in->{'residence'}, 'ccdf_time', 'eq', ${"summerday".$j."care_child".$i}, 'age_min', '<=', $in->{'child'.$i.'_age'}, 'age_max', '>=', $in->{'child'.$i.'_age'}, 'ccdf_type', 'eq', ${'unsub_type'.$i});
						} 
						
						if (1 == 0) { #EquivalentSQL
						
							$stmt->execute($in->{'state'}, $in->{'year'}, ${"day".$j."care_child".$i}, $in->{"child".$i."_age"}, $in->{"child".$i."_age"}, $in->{'residence'}, ${'unsub_type'.$i}) ||&fatalError("Unable to execute $sql: $DBI::errstr");
							${'day'.$j.'cost_child'.$i} = $stmt->fetchrow() / 5;

							# Look up child care cost by $ccdf_time = $summerday#care_child#, child#_age (>= age_min and <=age_max) and care type (if (CCDF = 1) {ccdf_type = child#_continue_setting} else {ccdf_type = child#_nobenefit_setting}),and call that variable $summerday#cost_child#.
							$stmt->execute($in->{'state'}, $in->{'year'}, ${"summerday".$j."care_child".$i}, $in->{"child".$i."_age"}, $in->{"child".$i."_age"}, $in->{'residence'}, ${'unsub_type'.$i}) ||&fatalError("Unable to execute $sql: $DBI::errstr");
							${'summerday'.$j.'cost_child'.$i} = $stmt->fetchrow() / 5;
						}
					}
					${'unsub_child' . $i} = (52 - $summerweeks - $weeks_off)*(${'day1cost_child'. $i} + ${'day2cost_child'. $i} + ${'day3cost_child'. $i} + ${'day4cost_child' . $i} + ${'day5cost_child' . $i} + ${'day6cost_child' . $i} + ${'day7cost_child' . $i}) + $summerweeks * (${'summerday1cost_child' . $i} + ${'summerday2cost_child' . $i} + ${'summerday3cost_child' . $i} + ${'summerday4cost_child' . $i} + ${'summerday5cost_child' . $i} + ${'summerday6cost_child' . $i} + ${'summerday7cost_child' . $i}); #This assumes, as below, that parents have their child in non-summer months. This does not affect the calculations here but does affect it in ccdf, at least for NJ. We discussed this but I'm inclined to leave this assumption intact, in that the baby is born in January. Otherwise the family has a different family size over the course of a year, which messes up nearly all the other benefit programs in our model.
					
					${'cc_expenses_child' . $i} = ${'unsub_child' . $i};

					#To accurately account for overage costs, specifically for families who choose to switch child care provider types after losing CCDF, we need to also calculate the total costs of what unsubsidized rates would be for those child care providers when the family is on CCDF subsidies. 
					for(my $j=1; $j<=7; $j++) {

						if (${"day".$j."care_child".$i} ne 'none') {
							${'day'.$j.'cost_child'.$i} = csv_arraylookup ($in->{'dir'}.'\FRS_spr.csv', 'spr', 'ccdf_region', 'eq', $in->{'residence'}, 'ccdf_time', 'eq', ${"day".$j."care_child".$i}, 'age_min', '<=', $in->{'child'.$i.'_age'}, 'age_max', '>=', $in->{'child'.$i.'_age'}, 'ccdf_type', 'eq', $in->{"child".$i."_withbenefit_setting"});
						} 
					
						if (${"summerday".$j."care_child".$i} ne 'none') {
							${'summerday'.$j.'cost_child'.$i} = csv_arraylookup ($in->{'dir'}.'\FRS_spr.csv', 'spr', 'ccdf_region', 'eq', $in->{'residence'}, 'ccdf_time', 'eq', ${"summerday".$j."care_child".$i}, 'age_min', '<=', $in->{'child'.$i.'_age'}, 'age_max', '>=', $in->{'child'.$i.'_age'}, 'ccdf_type', 'eq', $in->{"child".$i."_withbenefit_setting"});
						} 

						if (1 == 0) { #EquivalentSQL
						
							$stmt->execute($in->{'state'}, $in->{'year'}, ${"day".$j."care_child".$i}, $in->{"child".$i."_age"}, $in->{"child".$i."_age"}, $in->{'residence'}, $in->{"child".$i."_withbenefit_setting"}) ||&fatalError("Unable to execute $sql: $DBI::errstr");
							${'day'.$j.'cost_child'.$i} = $stmt->fetchrow() / 5;

							$stmt->execute($in->{'state'}, $in->{'year'}, ${"summerday".$j."care_child".$i}, $in->{"child".$i."_age"}, $in->{"child".$i."_age"}, $in->{'residence'}, $in->{"child".$i."_withbenefit_setting"}) ||&fatalError("Unable to execute $sql: $DBI::errstr");
							${'summerday'.$j.'cost_child'.$i} = $stmt->fetchrow() / 5;
						}
					}
					${'fullcost_child' . $i} = (52 - $summerweeks - $weeks_off)*(${'day1cost_child'. $i}  + ${'day2cost_child'. $i}  +${'day3cost_child'. $i}  +${'day4cost_child' . $i}  +${'day5cost_child' . $i}  +${'day6cost_child' . $i}  +${'day7cost_child' . $i} ) + $summerweeks * (${'summerday1cost_child' . $i} + ${'summerday2cost_child' . $i} +${'summerday3cost_child' . $i} + ${'summerday4cost_child' . $i} + ${'summerday5cost_child' . $i} +${'summerday6cost_child' . $i} + ${'summerday7cost_child' . $i} ); 
				}
			}
		}
		$spr_all_children = $spr_child1 + $spr_child2 + $spr_child3 + $spr_child4 + $spr_child5; 
		$unsub_all_children = $unsub_child1 + $unsub_child2 + $unsub_child3 + $unsub_child4 + $unsub_child5;
		$fullcost_all_children = $fullcost_child1 + $fullcost_child2 + $fullcost_child3 + $fullcost_child4 + $fullcost_child5;
		
	}

	# outputs
    foreach my $name (qw(prek_age_min prek_age_max firstrunchildcare spr_all_children spr_child1 spr_child2 spr_child3 spr_child4 spr_child5 unsub_child1 unsub_child2 unsub_child3 unsub_child4 unsub_child5 unsub_all_children cc_expenses_child1 cc_expenses_child2 cc_expenses_child3 cc_expenses_child4 cc_expenses_child5 fullcost_child1 fullcost_child2 fullcost_child3 fullcost_child4 fullcost_child5 fullcost_all_children day1care_child1 summerday1care_child1 
						day2care_child1 summerday2care_child1 day3care_child1 summerday3care_child1 day4care_child1 summerday4care_child1 
						day5care_child1 summerday5care_child1 day6care_child1 summerday6care_child1 day7care_child1 summerday7care_child1 day1care_child2 
						summerday1care_child2 day2care_child2 summerday2care_child2 day3care_child2 summerday3care_child2 day4care_child2 summerday4care_child2 
						day5care_child2 summerday5care_child2 day6care_child2 summerday6care_child2 day7care_child2 summerday7care_child2 day1care_child3 
						summerday1care_child3 day2care_child3 summerday2care_child3 day3care_child3 summerday3care_child3 day4care_child3 summerday4care_child3 
						day5care_child3 summerday5care_child3 day6care_child3 summerday6care_child3 day7care_child3 summerday7care_child3 day1care_child4 
						summerday1care_child4 day2care_child4 summerday2care_child4 day3care_child4 summerday3care_child4 day4care_child4 summerday4care_child4 
						day5care_child4 summerday5care_child4 day6care_child4 summerday6care_child4 day7care_child4 summerday7care_child4 day1care_child5 
						summerday1care_child5 day2care_child5 summerday2care_child5 day3care_child5 summerday3care_child5 day4care_child5 summerday4care_child5 
						day5care_child5 summerday5care_child5 day6care_child5 summerday6care_child5 day7care_child5 summerday7care_child5 child1_weekly_cc_hours child2_weekly_cc_hours child3_weekly_cc_hours child4_weekly_cc_hours child5_weekly_cc_hours child1_weekly_cc_hours_summer child2_weekly_cc_hours_summer child3_weekly_cc_hours_summer child4_weekly_cc_hours_summer child5_weekly_cc_hours_summer weeks_off
						)) { 
		$self{'out'}->{$name} = ${$name}; 
    }

    return(%self);

}

1;

