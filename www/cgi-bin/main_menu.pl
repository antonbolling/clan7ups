#08/24/03 - JM - Fixed list_picks() so the table draws properly
#                Modified list_runs_user/gate so approved and denied runs aren't listed

use warnings;
use strict;

use CGI;
use DBI;

require "browser_gui.pl";
require "session.pl";
require "points.pl";
require "cook.pl";
require "time_string.pl";
require "auction_timing.pl";

# Display:
# -- All equipment this user can pick with links to the allocate script.
# -- Equipment browser like index.html,
# -- Links to all other functions this user has access to.
# . For user this is: add a run, user management.
# . For gatekeeper:   approve runs, perform picks.
# . For admin:        user management with advanced features (change passwords, modify points)
#                     Modify equipment entries directly.
sub main_menu {
  my ($dbh, $q, $view_time) = @_;

  # Get login.
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  # Auth tokens for next session.
  my $session_info = get_session_info($dbh, $q, $view_time);
  # Get access level.
  my $access = get_access($dbh, $q, $view_time);

  # 1: Print other options besides the main screen. Main screen browses eq, allows users to bid,
  # Provides links to the allocation page (inside the browser), shows users' points.
  # User options: add a run. go to user management page where user/gate can change their own password/email.
  # Gate options: run approval page. picks page. Outdated equipment page.
  # Admin options: User management; user ABSORBTION, creation, deletion. Modify a users' points directly.
  #                Delete an entry from the main equipment database.
  # 2: If 'gate' access: list all pending runs with submit to modify_run_gui.
  # 3: If the user has runs in the run table with 'reject' status, display info for each, radio buttons
  # for each, submit to modify_run_gui.
  # 4: Check to see if user has pending picks. Show the user's outgoing picks, and picks waiting for
  # allocation.
  # 5: Show the browser.
  # 6: Display user's current points.

  print <<EOT;
<h3>Welcome, $login! You have access level $access.</h3>

EOT

  # All levels: Select a non-main-menu action.
  select_action($dbh, $q, $view_time);

  # Gatekeeper? Check for 'pending' status runs.
  if ($access eq 'gate' or $access eq 'admin') {
    list_runs_gate($dbh, $q, $view_time);
  }

  # User: Allow to modify any runs belonging to the user..
  list_runs_user($dbh, $q, $view_time);

  display_notifications($dbh, $session_info, $uid);

  # User: Display pickable and waiting eq from store.
  list_bids($dbh, $q, $view_time);

  # User: List picks.
  list_picks($dbh, $q, $view_time);

  # THREE: Display the browser.
  browser_gui($dbh, $q, $view_time);

  display_points($dbh, $q, $view_time);

  print <<EOT;
  <form name=return method=post action="/cgi-bin/ups.pl">
  $session_info
  <input type="hidden" name="action" value="main_menu">
  <input type="submit" value="Refresh this page">
  </form>
EOT

}

sub list_runs_user {
  my ($dbh, $q, $view_time) = @_;

  my $session_info = get_session_info($dbh, $q, $view_time);
  my $uid = cook_int($q->param('uid'));

  my $sth = $dbh->prepare("select id,zone,day,status,UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(add_stamp) from runs where leader=$uid and (status='pending' or status='denied') order by add_stamp");
  $sth->execute;

  if (my $records = $sth->rows) {
      print <<EOT;
<hr>
<h3>User: you have $records unapproved or flagged runs.</h3>
<form name="viewrun" method="post" action="/cgi-bin/ups.pl">
<input type="hidden" name="action" value="modify_run_gui">
$session_info
<table>
<tr><td>View</td><td>Zone</td><td>Day</td><td>Name</td><td>Status</td><td>Age</td></tr>
EOT


    while (my ($runid, $zone_name, $day, $status, $add_stamp) = $sth->fetchrow_array) {
      if (($status eq 'pending') or ($status eq 'denied')) {

        $add_stamp = time_string($add_stamp);

        my $tempsth = $dbh->prepare("select num_days from zones where name='$zone_name'");
        $tempsth->execute;
        my ($num_days) = $tempsth->fetchrow_array;

        $tempsth = $dbh->prepare("select day_name from zone_points_$zone_name where id=$day");
        $tempsth->execute;
        my ($day_name) = $tempsth->fetchrow_array;

        if ($num_days == 1) {
	  $day = "--";
          $day_name = "--";
        }

        if ($status eq 'pending') {
          $status = "<td id='run_pending'>pending</td>";
        }
        else {
          $status = "<td id='run_denied'>denied</td>";
        }

        print <<EOT;
        <tr>
        <td><input type="radio" name="runid" value="$runid"></td>
        <td>$zone_name</td><td>$day</td><td>$day_name</td>$status
        <td>$add_stamp</td>
        </tr>
EOT
      }
    }

    print <<EOT;
  </table>
  <input type="submit" value="View run">
  </form>
EOT
  }
}

sub list_runs_gate {
  my ($dbh, $q, $view_time) = @_;

  my $sth = $dbh->prepare("select id,zone,day,leader,status,UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(add_stamp) from runs where status='pending' or status='denied' order by status, add_stamp");
  $sth->execute;

  my $session_info = get_session_info($dbh, $q, $view_time);

  if (my $records = $sth->rows) {
    print <<EOT;
<hr>
<h3>Gatekeeper: $records runs waiting to be approved</h3>
<form name="approverun" method="post" action="/cgi-bin/ups.pl">
<input type="hidden" name="action" value="modify_run_gui">
$session_info
<table>
<tr><td>View</td><td>Zone</td><td>Day</td><td>Name</td><td>Leader</td><td>Status</td><td>Age</td></tr>
EOT

    while (my ($runid,$zone_name,$day,$leader,$status,$add_stamp) = $sth->fetchrow_array) {
#    print "<p>Testing: runid $runid zone $zone_name day $day leader $leader add_stamp $add_stamp</p>\n";

      if (($status eq 'pending') or ($status eq 'denied')) {

        $add_stamp = time_string($add_stamp);

        my $tempsth = $dbh->prepare("select name from users where id=$leader");
        $tempsth->execute;
        my ($leader_name) = $tempsth->fetchrow_array;

        $tempsth = $dbh->prepare("select num_days from zones where name='$zone_name'");
        $tempsth->execute;
        my ($num_days) = $tempsth->fetchrow_array;

        $tempsth = $dbh->prepare("select day_name from zone_points_$zone_name where id=$day");
        $tempsth->execute;
        my ($day_name) = $tempsth->fetchrow_array;

        if ($status eq 'pending') {
          $status = "<td id='run_pending'>pending</td>";
        }
        else {
          $status = "<td id='run_denied'>denied</td>";
        }

        if ($num_days == 1) {
	  $day = "--";
          $day_name = "--";
        }

        print <<EOT;
        <tr>
        <td><input type="radio" name="runid" value="$runid"></td>
        <td>$zone_name</td><td>$day</td><td>$day_name</td>
        <td>$leader_name</td>
        $status
        <td>$add_stamp</td>
        </tr>
EOT
      }
    }

    print <<EOT;
    </table>
    <input type="submit" value="View run">
    </form>
EOT
  }
}

sub select_action {
  my ($dbh, $q, $view_time) = @_;
  my $session_info = get_session_info($dbh, $q, $view_time);

  print <<EOT;
<form name=action method="post" action="/cgi-bin/ups.pl">
$session_info
<select name="action">
<option value="create_run_gui">Submit a run
<option value="user_info_gui">Modify your user info
<option value="recent_runs_gui">View recent runs
<option value="user_transfer_points_gui">Transfer points to another user
<option value="ups_stats_gui">View ups stats
EOT

  # What access level are we?
  my $access = get_access($dbh,$q,$view_time);

  if ($access eq 'admin' or $access eq 'gate') {
    print <<EOT;
<option value="perform_picks_gui">Perform picks
<option value="obs_eq_gui">Remove old equipment - BROKEN
<option value="revalue_gui">Revalue equipment entries - BROKEN
EOT
  }

  if ($access eq 'admin') {
    print <<EOT;
<option value="ups_config_gui">Ups config
<option value="mod_create_zone_gui">Modify zone info
<option value="adv_user_gui">Advanced user management
<option value="add_items_start_gui">Transfer new equipment to the system - BROKEN
EOT
  }

  print <<EOT;
</select>
<input type="submit" value="Go!">
</form>

EOT
}

sub display_notifications {
  my ($dbh, $session_info, $uid) = @_;

	my $notifications_sql = $dbh->prepare("select id, notification from user_notifications where user_id = ?");
  $notifications_sql->execute($uid);

  my $at_least_one_notification = 0;

	my $rendered_notifications = "";

	my $notification_ids = "";

  # BY CONVENTION, ALL NOTIFICATIONS MUST be a string containing a html form omitting a trailing </form> tag. main_menu.pl will append the </form> tag with the proper session_info
  while (my $notification_row = $notifications_sql->fetchrow_arrayref) {
			$at_least_one_notification = 1;

			my $notification_id = $notification_row->[0];
			$notification_ids .= $notification_id . " ";

			my $notification = $notification_row->[1];
      $rendered_notifications .= <<EOT;
			<div class="user-notification">
					$notification
					$session_info
					</form>
			</div><br>
EOT
	}

	if ($at_least_one_notification) {
			print <<EOT;
			<hr>
			<h3>Notifications</h3>
			$rendered_notifications
			<form method="post" name="clear_notifications" action="/cgi-bin/ups.pl">
					<input type="hidden" name="action" value="clear_notifications">
					<input type="hidden" name="notification_ids" value="$notification_ids">
					$session_info
					<input type="submit" value="Clear Notifications">
					</form>
EOT
	}
}

sub list_bids {
  my ($dbh, $q, $view_time) = @_;

  my $session_info = get_session_info($dbh, $q, $view_time);
  my $uid = cook_int($q->param('uid'));

  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  $sth = $dbh->prepare("select id from bid_eq where bidder='$login' and status='bidding'");
  $sth->execute;
  my $num_items = $sth->rows;

  my $data = $sth->fetchall_arrayref;
  my $item;

  my @pickable_bids;
  my @waiting_bids;

  foreach $item (@$data) {
    my $eqid = $item->[0];

    if (auction_pickable($dbh, $eqid)) {
      push @pickable_bids, $eqid;
    }
    else {
      push @waiting_bids, $eqid;
    }
  }

  my $num_waiting = scalar(@waiting_bids);
  my $num_pickable = scalar(@pickable_bids);

  if ($num_items) {
    print <<EOT;
    <hr>
    <h3>Bid system: $num_items total bids</h3>
EOT

    if ($num_waiting) {
      print <<EOT;
      <h4> Bids waiting on a timer: $num_waiting </h4>
      <table>
      <tr><td>ID</td><td>Bid</td><td>Description</td><td>Timer</td></tr>
EOT

      my $in_list = join ',', @waiting_bids;

      $sth = $dbh->prepare("select id,bid,descr,UNIX_TIMESTAMP(add_time),UNIX_TIMESTAMP(cur_bid_time) from bid_eq where id in ($in_list) order by cur_bid_time");
      $sth->execute;
      $data = $sth->fetchall_arrayref;

      foreach $item (@$data) {
        my ($eqid, $bid, $descr, $add_time, $cur_bid_time) = @$item;

				my $timer = time_string(auction_seconds_remaining($view_time,$add_time,$cur_bid_time));

        print <<EOT
        <tr>
        <td>$eqid</td><td>$bid</td>
        <td>$descr</td>
        <td>$timer</td>
        </tr>

EOT
      }

    print "</table>\n";

    }


    if ($num_pickable) {
      print <<EOT;
      <h4> $num_pickable items ready to pick </h4>

      <form name="pick_bid" method="post" action="/cgi-bin/ups.pl">
      <input type="hidden" name="action" value="allocate_pick_gui">
      $session_info

      <table>
      <tr><td>Pick</td><td>ID</td><td>Bid</td><td>Description</td></tr>
EOT

      my $in_list = join ',', @pickable_bids;

      $sth = $dbh->prepare("select id,bid,descr from bid_eq where id in ($in_list)");
      $sth->execute;
      $data = $sth->fetchall_arrayref;

      foreach $item (@$data) {
        my ($eqid, $price, $descr) = @$item;

        print <<EOT
        <tr>
        <td><input type="radio" name="eqid" value="$eqid"></td>
        <td>$eqid</td>
        <td>$price</td>
        <td>$descr</td>
        </tr>

EOT
      }

    print <<EOT;
    </table>
    <input type="submit" value="Allocate points / pick selected">
    </form>

EOT

    }

  }
}

sub list_picks {
  my ($dbh, $q, $view_time) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  $sth = $dbh->prepare("select UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(add_stamp),descr from outgoing_eq where bidder='$login'");
  $sth->execute;
  my $num_picks = $sth->rows;
  my $data = $sth->fetchall_arrayref;

  print <<EOT;
  <hr>
  <h3>$num_picks picks waiting to be sent out</h3>

  <table>
  <tr><td>Age</td><td>Description</td></tr>
EOT

  my $item;
  foreach $item (@$data) {
    my $age = $item->[0];
    my $descr = $item->[1];
    my $time_str = time_string($age);

    print <<EOT;
    <tr>
      <td>$time_str</td>
      <td>$descr</td>
    </tr>
EOT
  }

  print <<EOT;
  </table>
EOT

}


1;
