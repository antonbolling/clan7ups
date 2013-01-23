use CGI;
use DBI;

use warnings;
use strict;

require "cook.pl";
require "modify_run_gui.pl";

# Set run points for all runners in the passed run_id,
# based on each runner's % attendance and total points for the run
sub set_run_points_for_all_runners_based_on_attendance {
  my ($dbh, $run_id) = @_;

	my $total_points_for_run = total_points_for_run($dbh,$run_id);

	my $sth = $dbh->prepare("select runner, percent_attendance, FLOOR($total_points_for_run * percent_attendance / total_percent_attendance) as new_points from run_points_$run_id, (select sum(percent_attendance) as total_percent_attendance from run_points_$run_id) as tmp");
	$sth->execute;
	if ($sth->rows) {
			my $update_points_dbh = $dbh->prepare("update run_points_$run_id set points = ? where runner = ?");
			while (my ($runner,$percent_attendance, $new_points) = $sth->fetchrow_array) {
					print STDERR "run $run_id $runner with attendance $percent_attendance updating points to $new_points\n";
					$update_points_dbh->execute($new_points,$runner);
			}
			$update_points_dbh->finish
	}
	$sth->finish;
}

# Return the total points for the passed run id
sub total_points_for_run {
  my ($dbh, $run_id) = @_;
	
  # Get zone number for this run.
  my $sth = $dbh->prepare("select zone, day from runs where id=$run_id");
  $sth->execute;
  my ($zone_name,$day_num) = $sth->fetchrow_array;

  # Get the default value for this day,
  $sth = $dbh->prepare("select points from zone_points_$zone_name where id=$day_num");
  $sth->execute;
  my ($total_points_for_day) = $sth->fetchrow_array;

	print STDERR "run $run_id has zone $zone_name day $day_num with total points $total_points_for_day\n";

	return $total_points_for_day;
}

sub pick_day {
  my ($dbh, $q, $view_time) = @_;

  my $day_num = cook_int($q->param('day'));
  my $runid = cook_int($q->param('runid'));

  print "<p> day $day_num, runid $runid </p>\n";
  print "<p>PICKDAY: runid = $runid, day = $day_num</p>\n";

  # FIRST, update day number in db.
  my $sth = $dbh->prepare("update runs set day=$day_num where id=$runid");
  $sth->execute;

	set_run_points_for_all_runners_based_on_attendance($dbh,$runid);

  # Done! Jump to modify_run_gui.
  modify_run_gui($dbh, $q, $view_time);
  return 1;
}

1;
