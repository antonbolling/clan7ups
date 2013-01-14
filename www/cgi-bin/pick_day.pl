use CGI;
use DBI;

use warnings;
use strict;

require "cook.pl";
require "modify_run_gui.pl";

sub pick_day {
  my ($dbh, $q, $view_time) = @_;

  my $day_num = cook_int($q->param('day'));
  my $runid = cook_int($q->param('runid'));

  print "<p> day $day_num, runid $runid </p>\n";
  print "<p>PICKDAY: runid = $runid, day = $day_num</p>\n";

  # FIRST, update day number in db.
  my $sth = $dbh->prepare("update runs set day=$day_num where id=$runid");
  $sth->execute;

  # Get zone number for this run.
  $sth = $dbh->prepare("select zone from runs where id=$runid");
  $sth->execute;
  my ($zone_name) = $sth->fetchrow_array;

  print "<p>PICKDAY: zone_name = $zone_name.</p>\n";

  # Get the default value for this day,
  $sth = $dbh->prepare("select points from zone_points_$zone_name where id=$day_num");
  $sth->execute;
  my ($day_points) = $sth->fetchrow_array;

  print "<p>PICKDAY: day_points = $day_points</p>\n";

  # Modify points data. We already populated the table with users, so just set values.
  $sth = $dbh->prepare("update run_points_$runid set points=$day_points");
  $sth->execute;

  # Done! Jump to modify_run_gui.
  modify_run_gui($dbh, $q, $view_time);
  return 1;
}

1;

