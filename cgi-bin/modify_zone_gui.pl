use CGI;
use DBI;

use warnings;
use strict;

require "session.pl";
require "ups_util.pl";
require "cook.pl";

sub modify_zone_gui {
  my ($dbh, $q, $view_time) = @_;
  print "<p> TESTING: $dbh, $q, $view_time </p>";

  my $zoneid = cook_int($q->param('zoneid'));
  my $session_info = get_session_info($dbh, $q, $view_time);

  my $sth = $dbh->prepare("select name,percent,num_days from zones where id=$zoneid");
  $sth->execute();
  my ($zone_name, $zone_per, $zone_days) = $sth->fetchrow_array;

  print <<EOT;
  <h3>Modifying zone $zoneid, named $zone_name</h3>
  <form method="post" name="modify_zone" action="ups.pl">
    $session_info
    <input type="hidden" name="action" value="modify_zone">
    <input type="hidden" name="zoneid" value="$zoneid">
    <table>
    <tr><td>Zone name</td><td><input type="text" name="zone" value="$zone_name"></td></tr>
    <tr><td>Number of days</td><td><input type="text" name="days" value="$zone_days"></td></tr>
    <tr><td>Percentage</td><td><input type="text" name="percent" value="$zone_per"></td></tr>
    </table>
EOT

  # Get all the day records.
  $sth = $dbh->prepare("select day_name,points from zone_points_$zone_name order by id");
  $sth->execute;

  print <<EOT;
  <table>
  <tr><td>Day</td><td>Name</td><td>Value</td></td>
EOT

  # have our points structure, now loop among elements.
  my $day_num = 1;
  while (my $data = $sth->fetchrow_arrayref) {
    my ($day_name, $day_value) = @$data;

    print <<EOT;

    <tr><td>$day_num</td>
    <td><input type="text" name="name_$day_num" value="$day_name"></td>
    <td><input type="text" name="value_$day_num" value="$day_value"></td>
    </tr>
EOT

    $day_num++;
  }

  if ($day_num <= $zone_days) {
    foreach ($day_num..$zone_days) {
      print <<EOT;

    <tr><td>$_</td>
    <td><input type="text" name="name_$_"></td>
    <td><input type="text" name="value_$_"></td>
    </tr>
EOT
    }
  }

  # Print end formatting tags, submit button. New form for returning to main menu.
  print <<EOT;
  </table>

  <input type="submit" value="Submit">
  </form>
EOT

  return_main($dbh, $q, $view_time);
}

1;
