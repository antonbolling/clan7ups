use warnings;
use strict;

use Data::Dumper;
use CGI;
use DBI;

require "time_string.pl";
require "user.pl";
require "points.pl";
require "cook.pl";
require "session.pl";
require "modify_run.pl";
require "modify_run_gui.pl";
require "recent_runs.pl";
require "approve_run.pl";
require "user_notifications.pl";

# Return 0 if the GUI finished displaying, 1 if there was a parameter or permissions problem
sub modify_approved_run_gui {
  my ($dbh, $q, $view_time) = @_;
  my $user_id = $q->param('uid');
	my $user_name = get_user_name_by_id($dbh,$user_id);
  my $user_access_level = get_access($dbh, $q, $view_time);
  my $session_info = get_session_info($dbh, $q, $view_time);
	my $run_id = cook_int($q->param("modify_run_id"));
	
	if ( validate_modify_approved_run_params($dbh,$q,$view_time) != 0) {
			return 1;
	}

	my $modify_run_sql = $dbh->prepare("select zone, day, name as leader, status, UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(add_stamp) as age from runs, users where leader = users.id and runs.id = $run_id");
	$modify_run_sql->execute;

	my ($zone_name, $day_id, $leader, $run_status, $run_age) = $modify_run_sql->fetchrow_array;
	$run_age = time_string($run_age);
	my $day_name = get_day_name($dbh, $zone_name, $day_id);

	print <<EOT;
	<h3>Add/Remove runners from approved run</h3>
EOT
	return_main($dbh,$q,$view_time);
  print <<EOT;
	<form method=post action="/cgi-bin/ups.pl">
			$session_info
			<input type="hidden" name="action" value="modify_approved_run_gui">
			<input type="hidden" name="modify_run_id" value="$run_id">
			<input type="submit" value="Discard any changes made below and try again">
  </form>
	Modifying this run (double check that it is the correct run):<br><br>
	<table>
			<tr><td>Zone</td><td>Day</td><td>Leader</td><td>Status</td><td>Age</td></tr>
			<tr id="points_odd_row">
			  <td>$zone_name</td>
			  <td>$day_name</td>
			  <td>$leader</td>
			  <td>$run_status</td>
			  <td>$run_age</td>
			</tr>
	</table>

	
	<form method=post action="/cgi-bin/ups.pl">
	$session_info
	<input type="hidden" name="action" value="modify_approved_run">
  <input type="hidden" name="modify_run_id" value="$run_id">
EOT

	display_runners($dbh, $run_id);

	print <<EOT;

  <b>Reason to modify run:</b><br>
  <textarea name="modification_reason" rows=3 cols=80>(Be sure to fill in a reason)</textarea><br>

	<b><span style="width: 300px; color: red; background-color: yellow">
			<><><><><><><><><> DANGER ZONE(tm) <><><><><><><><><><><br>
			!! You will REMOVE POINTS from users !!<br>
			If unsure, click "Discard any changes" up top.<br>
			Clicking this button will immediately apply your changes to this run.<br>
			<input type="submit" value="WARNING - Immediately Modify This Run - CANNOT BE UNDONE - WARNING">
			<br><><><><><><><><><> DANGER ZONE(tm) <><><><><><><><><><>
	</span></b>
	</form>
EOT

	return 0;
}

# Return zero if the parameters for modify_approved_run are valid
sub validate_modify_approved_run_params {
	my ($dbh,$q, $view_time) = @_;
  my $user_id = $q->param('uid');
	my $user_name = get_user_name_by_id($dbh,$user_id);
  my $user_access_level = get_access($dbh, $q, $view_time);

  if (!($user_access_level eq 'gate' or $user_access_level eq 'admin')) {
			print STDERR "$user_name with id $user_id attempted unauthorized access of modify approved run gui";
			print "<h3>You're not authorized to modify approved runs.</h3>";
			return 1;
	}

	my $run_id = cook_int($q->param("modify_run_id"));

	if (! defined $run_id ) {
			print "<h3>You must select a run to modify.</h3>";
			return 1;
	}

	my $modify_run_sql = $dbh->prepare("select zone, day, name as leader, status, UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(add_stamp) as age from runs, users where leader = users.id and runs.id = $run_id");
	$modify_run_sql->execute;
	my $found_run = $modify_run_sql->rows;

	if (!$found_run) {
			print STDERR "modify_approved_run couldn't find run $run_id";
			print "<h3>Modify approved runs couldn't find a run with id $run_id.</h3>";
			return 1;
	}

	my ($zone_name, $day_id, $leader, $run_status, $run_age) = $modify_run_sql->fetchrow_array;
	$run_age = time_string($run_age);
	my $day_name = get_day_name($dbh, $zone_name, $day_id);

	if (!($run_status eq 'approved')) {
			print STDERR "modify_approved_run attempted to modify a non-approved run, $run_id, $zone_name, day $day_id, $leader, status $run_status";
			print "<h3>Run $run_id isn't currently approved and cannot be modified.</h3>";
			return 1;
	}

  return 0;
}

sub modify_approved_run {
		my ($dbh, $q, $view_time) = @_;

		if ( validate_modify_approved_run_params($dbh,$q,$view_time) != 0) {
				return 1;
		}

		my $run_id = cook_int($q->param('modify_run_id'));
		my $modification_reason = $q->param('modification_reason');
		my $user_id = $q->param('uid');
		my $user_name = get_user_name_by_id($dbh,$user_id);
		my $zone_name = get_zone_name_by_run_id($dbh, $run_id);

    # algorithm:
		# 2. begin transaction
		print STDERR "modify_approved_run: starting transaction, run_id $run_id, user $user_name, zone $zone_name\n";		
		begin_transaction($dbh);

		# 3a. store old runner details
		my $old_runner_details = get_runner_details($dbh, $run_id, $zone_name);
		print STDERR "modify_approved_run: old runner details, run id $run_id, got details: " . Dumper($old_runner_details);

		# 3. erase old run points, as they will be re-applied after the run is modified
		erase_run_points($dbh, $run_id, $zone_name);
		
		# 4. modify_runners(), updating the run with the modifications made in modify_approve_run_gui
		modify_runners($dbh, $q, $view_time, $run_id, $user_id, $user_name);

		# 5. re-approve the run, creating non-existent users and applying the run points to the user's point balance
		approve_runners($dbh,$q,$view_time,$run_id,$zone_name);

		# 5b. store new runner details
		my $new_runner_details = get_runner_details($dbh, $run_id, $zone_name);
		print STDERR "modify_approved_run: new runner details, run id $run_id, got details: " . Dumper($new_runner_details);

		# 5c. merge runner details to for notifications
		my $merged_runner_details = merge_old_new_runner_details($dbh, $old_runner_details, $new_runner_details, $zone_name);
		my $merged_runner_details_dump = Dumper($merged_runner_details);
		print STDERR "modify_approved_run: merged runner details, run id $run_id, got details: $merged_runner_details_dump";

		# 6. send notifications
		send_modify_approve_run_notifications($dbh, $merged_runner_details, $run_id, $modification_reason);

		# 7. log the run modification
		my $sth = $dbh->prepare("insert into log (user,action,bigdata) values(?,'modify-approved-run',?)");
		$sth->execute($user_id,"$user_name modified run $run_id. Modification details: $merged_runner_details_dump");

		# 8. commit transaction
		end_transaction($dbh);
		print STDERR "modify_approved_run: ended transaction, run_id $run_id, user $user_name, zone $zone_name\n";

		modify_approved_run_gui($dbh,$q,$view_time);
}

sub get_zone_name_by_run_id {
	my ($dbh, $run_id) = @_;
  my $sth = $dbh->prepare("select zone from runs where id = ? ");
  $sth->execute($run_id);
  my ($zone_name) = $sth->fetchrow_array;
	return $zone_name;
}

# Return a reference to an array, where each array element is a Hash declaring keys:
#  "user_name" -> user name of runner
#  "percent_attendance" -> percent attendance the runner received for the passed run_id
#  "run_points" -> points runner received for the passed run_id
#  "total_zone_points" -> total points runner has in the zone for passed run_id
sub get_runner_details {
  my ($dbh, $run_id, $zone_name) = @_;
  my $sth = $dbh->prepare("select runner, points, percent_attendance from run_points_$run_id");
  $sth->execute;
	
	my @runner_details = ();
	while (my $data = $sth->fetchrow_arrayref) {
      my ($user_name, $points, $percent_attendance) = @$data;
			my $total_zone_points = get_zone_points_from_username($dbh, $user_name, $zone_name);
			my %one_runner_details = (
					user_name => $user_name,
					run_points => $points,
					percent_attendance => $percent_attendance,
					total_zone_points => $total_zone_points,
					);
			push(@runner_details, \%one_runner_details );
	}
	return \@runner_details;
}

# Return a reference to a hash:
#  "user_name" -> {
#                    
#                 }
sub merge_old_new_runner_details {
  my ($dbh, $old_runner_details, $new_runner_details, $zone_name) = @_;

	my $merged_runner_details = {};

	foreach my $one_runner_details (@$old_runner_details) {
			my $new_total_zone_points = get_zone_points_from_username($dbh, $one_runner_details->{ user_name }, $zone_name);

			$merged_runner_details->{ $one_runner_details->{ user_name } } = {
					old_run_points => $one_runner_details->{ run_points },
					old_percent_attendance => $one_runner_details->{ percent_attendance },
					old_total_zone_points => $one_runner_details->{ total_zone_points },

					# notification will be overwritten below in the case that the user hasn't be removed from the run
					notification => "You were removed from the run and now have $new_total_zone_points $zone_name points. (Before being removed, you had $one_runner_details->{ percent_attendance }% attendance and $one_runner_details->{ run_points } points on this run, and had $one_runner_details->{ total_zone_points } total $zone_name points.)",
					};
	}

	foreach my $one_runner_details (@$new_runner_details) {
			if ( exists $merged_runner_details->{ $one_runner_details->{ user_name } } ) {
					#  3.  Your old attendance was X, new attendance is Y, and your points went up/down by Z
					$merged_runner_details->{ $one_runner_details->{ user_name } }->{ notification } = "You now have $one_runner_details->{ percent_attendance }% attendance and $one_runner_details->{ run_points } points on this run, and $one_runner_details->{ total_zone_points } total $zone_name points. (Before the change, you had $merged_runner_details->{ $one_runner_details->{ user_name } }->{ old_percent_attendance }% attendance and $merged_runner_details->{ $one_runner_details->{ user_name } }->{ old_run_points } points on this run, and had $merged_runner_details->{ $one_runner_details->{ user_name } }->{ old_total_zone_points } total $zone_name points.)";
			} else {
					#  2.  You were added to the run with attendance X, received points Y
					$merged_runner_details->{ $one_runner_details->{ user_name } } = {};
					$merged_runner_details->{ $one_runner_details->{ user_name } }->{ notification } = "You were added to the run with $one_runner_details->{ percent_attendance }% attendance and $one_runner_details->{ run_points } points, and now have $one_runner_details->{ total_zone_points } total $zone_name points.";
			}

			$merged_runner_details->{ $one_runner_details->{ user_name } }->{ new_run_points } = $one_runner_details->{ run_points };
			$merged_runner_details->{ $one_runner_details->{ user_name } }->{ new_percent_attendance } = $one_runner_details->{ percent_attendance };
			$merged_runner_details->{ $one_runner_details->{ user_name } }->{ new_total_zone_points } = $one_runner_details->{ total_zone_points };
	}
	return $merged_runner_details;
}

# For the passed run_id and zone, deduct the run points from the user's points balance in that zone
sub erase_run_points {
	my ($dbh, $run_id, $zone_name) = @_;
	my $sth = $dbh->prepare("select runner, points from run_points_$run_id");
	$sth->execute;

	while (my $data = $sth->fetchrow_arrayref) {
      my ($runner_user_name, $runner_points) = @$data;
			modify_zone_points_for_user($dbh, $runner_user_name, $zone_name, -1 * $runner_points);
			print STDERR "erase_run_points: subtracted $runner_points $zone_name points from $runner_user_name\n";
	}
}

sub send_modify_approve_run_notifications {
		my ($dbh, $merged_runner_details, $run_id, $modification_reason) = @_;

		my $sql = $dbh->prepare("select zone, day, name as leader, status, UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(add_stamp) as age from runs, users where leader = users.id and runs.id = $run_id");
		$sql->execute;

		my ($zone_name, $day_id, $leader, $run_status, $run_age) = $sql->fetchrow_array;
		$run_age = time_string($run_age);
		my $day_name = get_day_name($dbh, $zone_name, $day_id);
		$day_name = "" if ($day_name eq "--");

		my $base_notification_prefix = "You were involved in a <b>$zone_name $day_name run $run_age ago</b> that's changed. Reason: $modification_reason<br> ";
		my $base_notification_suffix = "<br><i>You may have negative $zone_name points now, or may need more points to pick an item. This is OK and does not affect your current bids! Thanks a lot and sorry for the change!</i>";
    for my $runner_user_name ( keys %$merged_runner_details ) {
				my $runner_notification = $base_notification_prefix . $merged_runner_details->{ $runner_user_name }->{ notification } . $base_notification_suffix;
				print STDERR "modify_approved_run: sending notification to $runner_user_name: $runner_notification\n";
				create_notification_by_user_name( $dbh, $runner_user_name, $runner_notification );
    }
}

1;
