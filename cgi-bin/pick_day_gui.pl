use CGI;
use DBI;

use strict;
use warnings;

require "cook.pl";
require "session.pl";

sub pick_day_gui {
  my ($dbh, $q, $view_time) = @_;
  my $uid = cook_int($q->param('uid'));

  my $runid = cook_int($q->param('runid'));
  my $day = cook_int($q->param('day'));

  my $sth = $dbh->prepare("select zone from runs where id=$runid");
  $sth->execute;
  my ($zone_name) = $sth->fetchrow_array;

  my $session_info = get_session_info($dbh, $q, $view_time);

  $sth = $dbh->prepare("select num_days from zones where name='$zone_name'");
  $sth->execute;
  my ($num_days) = $sth->fetchrow_array;
#  print "<p>Zone $zone_name has $num_days days.</p>";

  $sth = $dbh->prepare("select day_name from zone_points_$zone_name order by id");
  $sth->execute;

#  print "<p> day $day, runid $runid</p>\n";

  # Now we have day information for this zone, print it.
  print <<EOT;
  <form name="pickday" method="post" action="/cgi-bin/ups.pl">
  <input type="hidden" name="action" value="pick_day">
  <input type="hidden" name="runid" value="$runid">
  $session_info
  <p>You ran day <select name="day">
EOT

  foreach (1..$num_days) {
    my $tempday = $_;

    my ($day_name) = $sth->fetchrow_array;

    print <<EOT;
    <option value="$tempday">$tempday: $day_name
EOT
  }

  print <<EOT;
  </select></p>

  <input type="submit" value="Choose this day">
  </form>
EOT

}
