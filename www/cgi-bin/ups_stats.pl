use warnings;
use strict;

use CGI;
use DBI;

require "ups_util.pl";

sub ups_stats_gui {
		my ($dbh, $q, $view_time) = @_;
		my $session_info = get_session_info($dbh, $q, $view_time);

		return_main2($session_info);
    print <<EOT;
		<h3>UPS Stats</h3>
		<table border="1" cellpadding="5">
EOT
    print ups_points_stats($dbh);
		print ups_runs_stats($dbh);
		print "</table>";
		print ups_points_leaderboard($dbh);

		return_main2($session_info);
}

sub ups_points_leaderboard {
		my ($dbh) = @_;

		my $html = "";
		my $all_user_points_query = "";
		my $first_user = 1;

		my $sth = $dbh->prepare("select name from users");
		$sth->execute;
		while (my ($user_name) = $sth->fetchrow_array) {
				next if $user_name eq "admin";
				if ($first_user == 1) {
						$first_user = 0;
				} else {
						$all_user_points_query .= " UNION ALL ";
				}
				$all_user_points_query .= "select name,zone,points from user_points_$user_name, users where name = '$user_name'";
		}

		print STDERR "ups stats, all_user_points_query: $all_user_points_query\n";

		$sth = $dbh->prepare($all_user_points_query);
		$sth->execute;

		$html .= '<h3>Player Points</h3>';
		$html .= 'TIP! Sort multiple columns simultaneously by holding down the shift key and clicking a second, third or even fourth column header!<br>';
		$html .= '<table id="allPlayerPoints" class="tablesorter"><thead><tr><th>Zone</th><th>Player</th><th>Points</th></tr></thead><tbody>';
		while (my ($user_name, $zone, $points) = $sth->fetchrow_array) { 
				$html .= "<tr><td>$zone</td><td>$user_name</td><td>$points</td></tr>";
		}
		$html .= "</tbody></table>";
		$html .= <<EOT;
		<script type='text/javascript'>
				\$(function() {
						\$('#allPlayerPoints').tablesorter({ 
								sortList: [[0,0],[2,1],[1,0]], // sort first column ascending, second column desc, third column asc
	    					widgets: ['zebra']
						 });
					 });
		</script>
EOT
		return $html;
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
