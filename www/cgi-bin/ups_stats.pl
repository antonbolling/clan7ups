use warnings;
use strict;

use CGI;
use DBI;

require "ups_util.pl";

sub ups_stats_gui {
		my ($dbh, $q, $view_time) = @_;
		my $session_info = get_session_info($dbh, $q, $view_time);

		print <<EOT;
		<h3>UPS Stats</h3>
		<table border="1" cellpadding="5">
EOT
    print ups_points_stats($dbh);
		print ups_runs_stats($dbh);
		print "</table>";

		return_main2($session_info);
}

# Return a string containing html render of the UPS points stats
sub ups_points_stats {
		my ($dbh) = @_;
		my $html = "";

		my $total_points = 0;

		my $all_users_sql = $dbh->prepare("select name from users");
		$all_users_sql->execute;

		while (my ($name) = $all_users_sql->fetchrow_array) {
				my $user_points_sql = $dbh->prepare("select sum(points) from user_points_$name");
				$user_points_sql->execute;
				if (defined $user_points_sql->err) {
						print STDERR "ups stats found no points for user $name\n";
						next;
				}
				my ($user_total_points) = $user_points_sql->fetchrow_array;
				$total_points += $user_total_points;
		}

		$html .= "<tr><td>Total UPS points for all players:</td><td>$total_points</td></tr>";

		my $total_bids_sql = $dbh->prepare("select sum(bid) from bid_eq where status = 'bidding'");
		$total_bids_sql->execute;
		
		my ($total_bids) = $total_bids_sql->fetchrow_array;

		$html .= "<tr><td>Total points tied up in bids:</td><td>$total_bids</td></tr>";

		my $total_points_banked = $total_points - $total_bids;

		$html .= "<tr><td>Total points banked (total - bid):</td><td>$total_points_banked</td></tr>";

		return $html;
}

# Return a string containing html render of the UPS runs stats
sub ups_runs_stats {
		my ($dbh) = @_;
		my $html = "";

		my $number_of_runs_sql = $dbh->prepare("select count(*) from runs where status = 'approved'");
		$number_of_runs_sql->execute;
		
		my ($number_of_runs) = $number_of_runs_sql->fetchrow_array;

		$html .= "<tr><td>Number of approved runs:</td><td>$number_of_runs</td></tr>";

		return $html;
}

1;
