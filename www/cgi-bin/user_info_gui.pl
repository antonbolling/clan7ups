use CGI;
use DBI;

use strict;
use warnings;

require "cook.pl";
require "session.pl";
require "ups_util.pl";

sub user_info_gui {
  my ($dbh, $q, $view_time) = @_;

  # Get login.
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  # Auth tokens for next session.
  my $session_info = get_session_info($dbh, $q, $view_time);

  print <<EOT;
  <h4>Change password for user $login</h4>
  <form name="changepass" action="/cgi-bin/ups.pl">
  <input type="hidden" name="action" value="change_password">
  $session_info
  <table>
  <tr><td>Current password</td><td><input type="password" name="oldpass"></td></tr>
  <tr><td>New password</td><td><input type="password" name="newpass1"></td></tr>
  <tr><td>Repeat</td><td><input type="password" name="newpass2"></td></tr>
  </table>
  <input type="submit" value="Change password">
  </form>
EOT

  return_main($dbh, $q, $view_time);
}
