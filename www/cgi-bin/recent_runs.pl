use warnings;
use strict;

use CGI;
use DBI;

# Return a string containing recent runs
# in html, suitable for printing into the page.
#  - render the runs from the point-of-view of the passed user_name,
#     showing whether the user was in each run, or not
my $SHOW_RUNS_NEWER_THAN = 60 * 60 * 24 * 2; # two days in seconds
sub recent_runs {
		my ($dbh, $user_name) = @_;
		
		my $recent_runs_sql = $dbh->prepare("select runs.id, zone, day, name as leader, status from runs, users where (status = 'pending' or status = 'approved') and UNIX_TIMESTAMP(add_stamp) > UNIX_TIMESTAMP(now()) - $SHOW_RUNS_NEWER_THAN and leader = users.id");
		$recent_runs_sql->execute;
		my $at_least_one_run = $recent_runs_sql->rows;

		my $html = <<EOT;
		  <hr>
		  <h3>All Recent Runs</h3>
      <i>Pending</i> runs aren't on UPS yet - you won't see points or eq from a pending run.<br><br>
EOT

    if ($at_least_one_run ) {
				$html .= <<EOT
		  <table>
			<tr><td>Zone</td><td>Day</td><td>Leader</td><td>Status</td><td>On Run?</td></tr>
EOT
    } else {
				$html .= "(No recent runs)";
    }

		my $row_style_id = "points_even_row";
		my $row_style_id_swap = "points_odd_row";

		while (my ($run_id, $zone_name, $day_id, $leader, $run_status) = $recent_runs_sql->fetchrow_array) {
				my $day_name = get_day_name($dbh, $zone_name, $day_id);
				
				my $was_user_on_run_sql = $dbh->prepare("select * from run_points_$run_id where runner = '$user_name'");
				$was_user_on_run_sql->execute;
				my $was_user_on_run = $was_user_on_run_sql->rows;

				my $was_user_on_run_html;
				if ($was_user_on_run) {
						$was_user_on_run_html = "<font color=green>you were on this run</font>";
				} else {
						$was_user_on_run_html = "<font color=red>you were not on this run</font>";
				}

        my $swap = $row_style_id_swap;
				$row_style_id_swap = $row_style_id;
				$row_style_id = $swap;

				$html .= <<EOT
						<tr id="$row_style_id">
						  <td>$zone_name</td>
						  <td>$day_name</td>
						  <td>$leader</td>
						  <td>$run_status</td>
						  <td>$was_user_on_run_html</td>
						</tr>
EOT
		}

		if ($at_least_one_run) {
				$html .= "</table>";
		}

		return $html;
}


sub get_day_name {
		my ($dbh, $zone_name, $day_id) = @_;

		my $tempsth = $dbh->prepare("select num_days from zones where name='$zone_name'");
		$tempsth->execute;
		my ($num_days) = $tempsth->fetchrow_array;
		
		$tempsth = $dbh->prepare("select day_name from zone_points_$zone_name where id=$day_id");
		$tempsth->execute;
		my ($day_name) = $tempsth->fetchrow_array;
		
		if ($num_days == 1) {
				$day_name = "--";
		}

		return $day_name;
}
