use strict;
use subs;

use CGI;
use DBI;

sub add_user {
  my ($dbh, $q, $view_time, $user_name) = @_;

  my $sth = $dbh->prepare("insert into users (name) values ('$user_name')");
  $sth->execute;
  $sth = $dbh->prepare("create table user_points_$user_name (zone char(20), points int)");
  $sth->execute;
}

1;
