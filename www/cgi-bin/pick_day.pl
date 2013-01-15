use CGI;
use DBI;

use warnings;
use strict;

require "cook.pl";
require "modify_run_gui.pl";

# Return the total points, to be split among all players, for the passed run id
sub total_points_for_run {
  my ($dbh, $run_id) = @_;
	
  # Get zone number for this run.
  my $sth = $dbh->prepare("select zone, day from runs where id=$run_id");
  $sth->execute;
  my ($zone_name,$day_num) = $sth->fetchrow_array;

  print "<p>PICKDAY: zone_name = $zone_name.</p>\n";

  # Get the default value for this day,
  $sth = $dbh->prepare("select points from zone_points_$zone_name where id=$day_num");
  $sth->execute;
  my ($total_points_for_day) = $sth->fetchrow_array;

  print "<p>PICKDAY: day_points = $total_points_for_day</p>\n";

	return $total_points_for_day;
}

# Return the number of people on a run, for the passed run id
sub number_of_runners {
  my ($dbh, $run_id) = @_;

  my $sth = $dbh->prepare("select count(*) from run_points_$run_id");
  $sth->execute;

  my ($number_of_runners) = $sth->fetchrow_array;

  return $number_of_runners;
}

# Return the default number of points each runner should get,
# equal to the number of points for the run/day divided by number of runners
sub points_per_runner {
  my ($dbh, $run_id) = @_;

  my $total_points_for_day = total_points_for_run($dbh,$run_id);

  my $number_of_runners = number_of_runners($dbh,$run_id);

	my $points_per_runner = int($total_points_for_day / $number_of_runners); # always round down. This avoids the case where a large number of runners, rounded up, creates a large number of bonus points

	print "<p>PICKDAY: points_per_runner = $points_per_runner</p>\n";

	return $points_per_runner;
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

	my $points_per_runner = points_per_runner($dbh,$runid);

  # Modify points data. We already populated the table with users, so just set values.
  $sth = $dbh->prepare("update run_points_$runid set points=$points_per_runner");
  $sth->execute;

  # Done! Jump to modify_run_gui.
  modify_run_gui($dbh, $q, $view_time);
  return 1;
}

1;
