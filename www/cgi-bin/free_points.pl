use CGI;
use DBI;
use strict;
use warnings;

require "points.pl";

# For each existing user, give them bonus $FREE_POINTS_PER_ZONE points in each existing zone
# - db transaction performed in this function
sub free_points_in_each_zone_for_all_users {
		my ($dbh) = @_;
		my $FREE_POINTS_PER_ZONE = 2;

		begin_transaction($dbh);
		print STDERR "free points: giving each user $FREE_POINTS_PER_ZONE in each zone\n";
		$dbh->do("insert into log (action,bigdata) values('freepoints','giving all users $FREE_POINTS_PER_ZONE free points in each zone')");

		my @zones;

		my $sth = $dbh->prepare("select name from zones");
		$sth->execute;
		while (my ($zone_name) = $sth->fetchrow_array) {
				push(@zones, $zone_name);
		}

		$sth = $dbh->prepare("select name from users");
		$sth->execute;
		while (my ($user_name) = $sth->fetchrow_array) {
				print STDERR "DEBUG free points: giving $user_name $FREE_POINTS_PER_ZONE in each zone\n";
				foreach (@zones) {
						my $current_zone = $_; # so I remember what $_ means
						# print STDERR "DEBUG free points: giving $user_name $FREE_POINTS_PER_ZONE $current_zone points\n";
						modify_zone_points_for_user( $dbh, $user_name, $current_zone, $FREE_POINTS_PER_ZONE);
				}
		}
		end_transaction($dbh);
}
