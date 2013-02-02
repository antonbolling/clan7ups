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

sub get_user_id_by_name {
		my ($dbh, $user_name) = @_;
		my $user_id_sql = $dbh->prepare("select id from users where name = ?");
		$user_id_sql->execute($user_name);
		my ($user_id) = $user_id_sql->fetchrow_array;
		return $user_id;
}

sub get_user_name_by_id {
		my ($dbh, $user_id) = @_;
		my $user_name_sql = $dbh->prepare("select name from users where id= ?");
		$user_name_sql->execute($user_id);
		my ($user_name) = $user_name_sql->fetchrow_array;
		return $user_name;
}

1;
