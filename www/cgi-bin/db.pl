
use warnings;
use strict;

use DBI;

require "deteriorate_points.pl";

# Change MYSQL_CLIENT_CONFIG to point to your MySQL Client Config file, which shouldn't be in the www directory
# Example mysql.cnf:
#
#  [client]
#  host = localhost
#  database = ups_db
#  user = ups_user
#  password = password
#

my $MYSQL_CLIENT_CONFIG = '/home/ryan/projects/ups/mysql.cnf';

sub get_db {

		my $dsn =
				"DBI:mysql:;" . 
				"mysql_read_default_file=$MYSQL_CLIENT_CONFIG";

		my $dbh = DBI->connect(
				$dsn, 
				undef, 
				undef) or  die "DBI::errstr: $DBI::errstr";

		deteriorate_points($dbh);

		return $dbh;
}

sub begin_transaction {
		my ($dbh) = @_;
		$dbh->{AutoCommit} = 0;
}

sub end_transaction {
		my ($dbh) = @_;
		$dbh->commit;
		$dbh->{AutoCommit} = 1;
}

1;
