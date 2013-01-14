#09/03/03 - JM - Picks are now listed oldest first, and number of picks is displayed

use CGI;
use DBI;

use warnings;
use strict;

require "cook.pl";
require "session.pl";
require "ups_util.pl";
require "main_menu.pl";
require "time_string.pl";

sub perform_picks_gui {
  my ($dbh, $q, $view_time) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  my $session_info = get_session_info($dbh, $q, $view_time);

  $sth = $dbh->prepare("select id,UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(add_stamp) as age,bidder,descr from outgoing_eq order by add_stamp");
  $sth->execute;

  my $matches = $sth->rows;
  if (!$matches) {
    print "<h3>No picks waiting to be sent. Returning to main menu..</h3>";
    main_menu($dbh, $q, $view_time);
    return 1;
  }

  # Otherwise we have picks to send. Check access.
  my $access = get_access($dbh, $q, $view_time);
  if ($access ne 'admin' and $access ne 'gate') {
    no_access($dbh, $q, $view_time);
    return 1;
  }

  # If you get here, there are picks and you have access.
  my $data = $sth->fetchall_arrayref;

  print <<EOT;
  <h3>Perform picks</h3>
  <h4>$matches picks remaining to be sent out</h4>

  <form name="picks" method="post" action="/cgi-bin/ups.pl">
  <input type="hidden" name="action" value="perform_picks">
  $session_info
  <table>
  
<tr><td><b>Sent</b></td><td><b>Winner</b></td><td><b>Age</b></td><td><b>Description</b></td></tr>
EOT

  my $item;
  foreach $item (@$data) {
    my ($eqid, $age, $winner, $descr) = @$item;
    my $time_str = time_string($age);

    print <<EOT;
    <tr>
    <td><input type="checkbox" name="picked_list" value="$eqid"></td>
    <td>$winner</td>
    <td>$time_str</td>
    <td>$descr</td>
    </tr>
EOT
  }

  print <<EOT;
  </table>
  <input type="submit" value="Remove these items from the picklist">
  </form>
EOT

  return_main($dbh, $q, $view_time);
}

1;
