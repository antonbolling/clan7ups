use DBI;

use warnings;
use strict;

require "db.pl";
require "adv_points.pl";
require "points.pl";
require "user.pl";
require "cook.pl";
require "ups_util.pl";
require "user_notifications.pl";

# Execute a user points transfer based on the submitted user_transfer_points_gui
sub user_transfer_points {
  my ($dbh, $q, $view_time) = @_;
  my $user_id = $q->param('uid');
	my $user_name = get_user_name_by_id($dbh,$user_id);

  my $receiving_user_name = lc(cook_word($q->param('receiving_user_name')));
	my $receiving_user_id = get_user_id_by_name($dbh,$receiving_user_name);

	if (! defined $receiving_user_id ) {
			print "Points transfer failed. Receiving user $receiving_user_name doesn't exist.<br>";
			return 1;
	}

	if ($receiving_user_id == $user_id) {
			print "Points transfer failed. You may not transfer points to yourself.<br>";
			return 1;
	}

	my $all_zones_sql = $dbh->prepare("select name from zones order by name");
	$all_zones_sql->execute;

	# Transfer points for only one zone during this subroutine.
	# Because, users may transfer up to their 'Available' points for
	# a zone; the 'A' column in the zone chart.
	# However, the 'A' column is computed assuming the user has points
	# available from other zones to cover bids.
	# I.e., if you allow the user to transfer points for more than one zone at a time,
	# the user can transfer too many points and not be able to cover his existing bids.
	my $already_transferred_points = 0; 

	while (my $zone_name_row = $all_zones_sql->fetchrow_arrayref) {
			my $zone_name = $zone_name_row->[0];
			my $points_to_send = cook_int($q->param("points_to_send_$zone_name"));

			if (!$points_to_send) {
					next;
			}

			if ($points_to_send < 1) {
					print "Skipping points transfer for $zone_name, you must send at least 1 point<br>";
					next;
			}

			if ($already_transferred_points) {
					print "Skipping points transfer for $zone_name, you may only transfer points for one zone at a time...<br>";
					next;
			}

      my $user_points_available = zone_highest_price($dbh, $user_name, $zone_name);
			if ($points_to_send > $user_points_available) {
					print "Skipping points transfer for $zone_name, you tried to send $points_to_send points (only $user_points_available available)<br>";
					next;
			}

			$already_transferred_points = 1;

      print STDERR "transferring $points_to_send $zone_name points from $user_name to $receiving_user_name\n";
			
			# If receiving_user doesn't yet have points in this zone, initialize points to zero so we can complete the transfer
			my $create_zone_points_for_receiving_user_sql = "";

			my $receiving_user_has_points_in_zone_sql = $dbh->prepare("select points from user_points_$receiving_user_name where zone='$zone_name'");
			$receiving_user_has_points_in_zone_sql->execute;
			my $receiving_user_has_points_in_zone = $receiving_user_has_points_in_zone_sql->rows;
			if (!$receiving_user_has_points_in_zone) {
					print STDERR "$receiving_user_name doesn't yet have $zone_name points and will have points initialized to zero\n";
					$create_zone_points_for_receiving_user_sql = "insert into user_points_$receiving_user_name values ('$zone_name',0); "
			} else {
					print STDERR "$receiving_user_name already had $zone_name points, don't need to create an $zone_name record\n";
	    }

			begin_transaction($dbh);
			$dbh->do("update user_points_$user_name set points = points - $points_to_send where zone = '$zone_name'");
			$dbh->do($create_zone_points_for_receiving_user_sql);
			$dbh->do("update user_points_$receiving_user_name set points = points + $points_to_send where zone = '$zone_name'");
      $dbh->do("insert into log (user,action,bigdata) values($user_id,'transfer','transferred $points_to_send $zone_name points from $user_name to $receiving_user_name')");
			$dbh->commit;
			end_transaction($dbh);

			create_notification_by_user_id($dbh, $user_id, "<form> You sent $points_to_send $zone_name points to $receiving_user_name.");
			create_notification_by_user_id($dbh, $receiving_user_id, "<form> $user_name sent you $points_to_send $zone_name points.");

			print STDERR "finished points transfer from $user_name to $receiving_user_name\n";

			print "<h2>Transferred $points_to_send $zone_name points from $user_name to $receiving_user_name</h2>";
	}
}

# Display the gui, allowing a user to execute a points transfer
sub user_transfer_points_gui {
  my ($dbh, $q, $view_time) = @_;
  my $session_info = get_session_info($dbh, $q, $view_time);
  my $user_id = $q->param('uid');
	my $user_name = get_user_name_by_id($dbh,$user_id);

  my $user_point_data_sql = $dbh->prepare("select zone,points from user_points_$user_name order by zone");
  $user_point_data_sql->execute;

	my $total_points = get_total_points_foruser($dbh, $q, $view_time, $user_name);
	my $total_points_inuse = get_total_points_inuse_foruser($dbh, $q, $view_time, $user_name);
	my $total_points_avail = $total_points - $total_points_inuse;
  
	print <<EOT;
	<h3> Transfer Points to Another User</h3>
	<p>Total points: $total_points Available points: $total_points_avail</p>

	<form method="post" action="/cgi-bin/ups.pl">			
  	$session_info
  	<input type="hidden" name="action" value="user_transfer_points">
    
	  User to send points to: <input type="text" name="receiving_user_name"><br><br>
		One zone at a time. Fill in points for only one zone below. You may send up to your Available points, the "A" column.<br><br>
	  <table width="40%">
		  <tr id="points_odd_row">
			  <td width="100%"><b>Zone</b></td>
				<td id="points_total"><b>P</b></td>
				<td id="points_avail"><b>A</b></td>
				<td id="points_maxbid"><b>M</b></td>
				<td><b>Amount to Send</b></td>
			  <td><b>Zone</b></td>
			</tr>
EOT

  if ($user_point_data_sql->rows) { 
    my $user_point_data = $user_point_data_sql->fetchall_arrayref;
    
    my $entry;
    my $counter = 0;
    my $style;
    
    while ($entry = shift @$user_point_data) {
    
      if ($counter % 2) {
        $style = 'points_odd_row';
      } else {
        $style = 'points_even_row';
      }
    
      print "<tr id='$style'>\n";
    
      my $zone_name = $entry->[0];
      my $points = $entry->[1];
    
      my $avail = zone_highest_price($dbh, $user_name, $zone_name);
      my $high_bid = zone_highest_bid($dbh, $user_name, $zone_name);
        
      print <<EOT;
        <td>$zone_name</td>
        <td id='points_total'>$points</td>
        <td id='points_avail'>$avail</td>
        <td id='points_maxbid'>$high_bid</td>
        <td id="points_to_send">       
          <input type="text" name="points_to_send_$zone_name">
        </td>
        <td>$zone_name</td>
      </tr>
EOT
      $counter++;
    }
    print <<EOT;
    </table>
		<h4>Double check the ZONE and AMOUNT!</h4>
    <input type="submit" value="Transfer Points Now">
    </form>
      
    <p> 
    <font id="points_total">P: Total points for this zone</font><br>
    <font id="points_avail">A: Available points for this zone</font> (the most you can transfer)<br>
    <font id="points_maxbid">M: Max bid you can make on eq from this zone</font>
    </p>
EOT
  }
	return_main($dbh,$q,$view_time);
}
