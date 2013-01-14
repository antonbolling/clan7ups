use CGI;
use DBI;

use warnings;
use strict;

require "ups_util.pl";

sub mod_create_zone_gui {
  my ($dbh, $q, $view_time) = @_;

  # Auth tokens for next session.
  my $session_info = get_session_info($dbh, $q, $view_time);
  # Get access level.
  my $access = get_access($dbh, $q, $view_time);

  # Only admin gets to do this.
  if ($access ne 'admin') {
    no_access($dbh, $q, $view_time);
    return 1;
  }

  print <<EOT;
  <h3>View/modify zone information</h3>
    <form method="post" name="zmod" action="/cgi-bin/ups.pl">
    $session_info
    <input type="hidden" name="action" value="modify_zone_gui">
    <select name="zoneid">
EOT

  my $sth = $dbh->prepare("select id, name from zones order by name");
  $sth->execute;

  my $zones = $sth->fetchall_arrayref;
  foreach (@$zones) {
    my ($id, $name) = @$_;

    print <<EOT;
    <option value="$id">$name
EOT
  }

  print <<EOT;
  </select>
  <input type="submit" value="Modify">
  </form>

  <hr>
  <h3>Add a zone</h3>
  <form name="addzone" action="/cgi-bin/ups.pl">
    $session_info
    <input type="hidden" name="action" value="create_zone">
    <table>
    <tr><td>Zone name</td><td><input type="text" name="zone"></td></tr>
    <tr><td>Number of days</td><td><input type="text" name="days" default="1"></td></tr>
    <tr><td>Percent</td><td><input type="text" name="percent"></td></tr>
    </table>
  <input type="submit" value="Add">
  </form>
EOT

  return_main($dbh, $q, $view_time);
}

1;

