use CGI;
use DBI;

use strict;
use warnings;

require "cook.pl";
require "user_info_gui.pl";
require "main_menu.pl";

sub change_password {
  my ($dbh, $q, $view_time) = @_;

  # Get login.
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  my $oldpass = cook_word($q->param('oldpass'));
  my $newpass1 = cook_word($q->param('newpass1'));
  my $newpass2 = cook_word($q->param('newpass2'));

  # See if this uid's password is actually oldpass:
  $sth = $dbh->prepare("select pass = PASSWORD('$oldpass') from users where id=$uid");
  $sth->execute;
  my ($correct_pass) = $sth->fetchrow_array;

  if (!$correct_pass) {
    print <<EOT;
    <p>The password you entered as 'current password' was incorrect! Try again.</p>
EOT
    user_info_gui($dbh, $q, $view_time);
    return 1;
  }
  else {
    # Correct current password
    print "<p>Correct current pass; updating..</p>\n";

    if ($newpass1 eq $newpass2) {
      print "<p>new password fields match. updating password for user $login...</p>\n";
      $sth = $dbh->prepare("update users set pass=PASSWORD('$newpass1') where id=$uid");
      $sth->execute;
      main_menu($dbh, $q, $view_time);
      return 1;
    }
    else {
      # Passwords don't match.
      print "<p>new password fields don't match! Please try again. </p>\n";
      user_info_gui($dbh, $q, $view_time);
      return 1;
    }
  }
}

1;
