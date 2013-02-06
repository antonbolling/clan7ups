use warnings;
use strict;

use CGI;
use DBI;

require "session.pl";
require "user.pl";
require "ups_util.pl";
require "time_string.pl";

# Print a gui containing recent runs
#  - render the runs from the point-of-view of the passed user_name,
#     showing whether the user was in each run, or not
sub recent_runs_gui {
		my ($dbh, $q, $view_time) = @_;
		my $session_info = get_session_info($dbh, $q, $view_time);
		my $user_id = $q->param('uid');
		my $user_name = get_user_name_by_id($dbh,$user_id);
		my $user_access_level = get_access($dbh, $q, $view_time);

		my $recent_runs_admin_mode = 0;
		if ($user_access_level eq 'gate' or $user_access_level eq 'admin') {
				$recent_runs_admin_mode = 1;
		}
		
		my $SHOW_RUNS_NEWER_THAN = 60 * 60 * 24 * 3; # three days in seconds

		my $recent_runs_sql = $dbh->prepare("select runs.id, zone, day, name as leader, status, UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(add_stamp) as age from runs, users where (status = 'pending' or status = 'approved') and UNIX_TIMESTAMP(add_stamp) > UNIX_TIMESTAMP(now()) - $SHOW_RUNS_NEWER_THAN and leader = users.id ORDER BY age ");
		$recent_runs_sql->execute;
		my $at_least_one_run = $recent_runs_sql->rows;

		my $html = <<EOT;
		  <hr>
		  <h3>All Recent Runs</h3>
      <i>Pending</i> runs aren't on UPS yet - you won't see points or eq from a pending run.<br><br>
EOT

    if ($at_least_one_run ) {
				my $modify_run_column_html = "";
				if ($recent_runs_admin_mode) {
						$modify_run_column_html = "<td>Add/Remove Runners</td>";
						$html .= <<EOT 
								<form method=post action="/cgi-bin/ups.pl">
								$session_info
								<input type="hidden" name="action" value="modify_approved_run_gui">
EOT
				}

				$html .= <<EOT;
		  <table>
			<tr>$modify_run_column_html<td>Zone</td><td>Day</td><td>Leader</td><td>Status</td><td>Age</td><td>On Run?</td></tr>
EOT
    } else {
				$html .= "(No recent runs)";
    }

		my $row_style_id = "points_even_row";
		my $row_style_id_swap = "points_odd_row";

		while (my ($run_id, $zone_name, $day_id, $leader, $run_status, $run_age) = $recent_runs_sql->fetchrow_array) {
				my $day_name = get_day_name($dbh, $zone_name, $day_id);
				$run_age = time_string($run_age);
				
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

				my $modify_run_checkbox_html = "";
				if ($recent_runs_admin_mode && $run_status eq 'approved') {
						$modify_run_checkbox_html = "<td><input type='radio' name='modify_run_id' value='$run_id>'</td>";
				} elsif ($recent_runs_admin_mode) {
						$modify_run_checkbox_html = "<td></td>";
				}

				$html .= <<EOT;
						<tr id="$row_style_id">
						  $modify_run_checkbox_html
						  <td>$zone_name</td>
						  <td>$day_name</td>
						  <td>$leader</td>
						  <td>$run_status</td>
						  <td>$run_age</td>
						  <td>$was_user_on_run_html</td>
						</tr>
EOT
		}

		if ($at_least_one_run) {
				$html .= "</table>";
				if ($recent_runs_admin_mode) {
						$html .= "<input type='submit' value='Add/Remove runners on approved run'></form>";
				}
		}

		print $html;
		return_main2($session_info);
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

return 1;
