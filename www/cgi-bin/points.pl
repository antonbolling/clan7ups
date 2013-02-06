use CGI;
use DBI;
use strict;
use warnings;

require "cook.pl";

sub display_points {
  my ($dbh, $q, $view_time) = @_;

  # get this uid's username
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($username) = $sth->fetchrow_array;

  # get point data for this user.
  $sth = $dbh->prepare("select zone,points from user_points_$username order by zone");
  $sth->execute;

  if ($sth->rows) {
    my $user_point_data = $sth->fetchall_arrayref;
    my $num_zones = scalar (@$user_point_data);

    my $total_points = get_total_points($dbh, $q, $view_time);
    my $total_points_inuse = get_total_points_inuse($dbh, $q, $view_time);
    my $total_points_avail = $total_points - $total_points_inuse;

    # We found point data, display it
    print <<EOT;

    <hr>
    <h3> Point data for user $username </h3>

    <h4> Totals </h4>
    <ul>
    <li>Total points: $total_points
    <li>Available points: $total_points_avail
    </ul>

    <p><i>Available points</i> is your total points minus the sum of all bids you hold.</p>

    <h4> Breakdown by zone </h4>
    <table width="40%">
    <tr id="points_odd_row">
    <td width="100%">Zone</td><td id="points_total">P</td><td id="points_avail">A</td>
    <td id="points_maxbid">M</td>
    </tr>

EOT

    my $entry;
    my $second;
    my $counter = 0;
    my $style;

    while ($entry = shift @$user_point_data) {

      if ($counter % 2) {
	$style = 'points_odd_row';
      }
      else {
	$style = 'points_even_row';
      }

      print "<tr id='$style'>\n";

      my $zone_name = $entry->[0];
      my $points = $entry->[1];

      my $avail = zone_highest_price($dbh, $q, $view_time, $zone_name);
      my $high_bid = zone_highest_bid($dbh, $q, $view_time, $zone_name);
	
      print <<EOT;
      <td>$zone_name</td><td id='points_total'>$points</td>
      <td id='points_avail'>$avail</td><td id='points_maxbid'>$high_bid</td>
EOT

      $counter++;

      print "</tr>\n";
    }
    print <<EOT;
    </table>

    <p>
    <font id="points_total">P: Total points for this zone</font><br>
    <font id="points_avail">A: Available points for this zone (highest priced item you can buy)</font><br>
    <font id="points_maxbid">M: Max bid you can make on eq from this zone</font>
    </p>

    <h4>Description of point breakdown</h4>
    <ul>
    <li>Available points: How many points aren't tied up in bids. We calculate this
      as your total zone points minus the following -
      <ol>
      <li> the sum of all minimum allocations you can make for current bids in this zone.
      </ol>
    <li>Maximum bid: The highest amount you can bid on an item from this zone. This will be whichever of
      the following is smallest -
      <ol>
      <li> Your total available points, or
      <li> Whatever bid would use all your points for this zone in the minimum allocation.
      </ol>
    </ul>
EOT

# (percent / 100) * bid = this_zone_min_alloc
# bid = 100 * this_zone_min_alloc / percent
# bid maxes when this_zone_min_alloc is all currently available points for the zone.
  }
}

# Takes: zone name. Returns this user's points for that zone.
# Return: this user's points for passed zone name.
sub get_zone_points {
  my ($dbh, $q, $view_time, $zone) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;

  my ($username) = $sth->fetchrow_array;

  $sth = $dbh->prepare("select points from user_points_$username where zone='$zone'");
  $sth->execute;
  my ($zone_points) = $sth->fetchrow_array;

  return $zone_points ? $zone_points : 0
}

# Return the number of points the passed username has in the passed zone.
sub get_zone_points_from_username {
		my ($dbh, $username, $zone) = @_;
		my $sth = $dbh->prepare("select points from user_points_$username where zone = ?");
		$sth->execute($zone);
		my ($points) = $sth->fetchrow_array;
		return $points ? $points : 0;
}

# Add points_delta to the passed user_name's points to the passed zone
# Return the new points value
sub modify_zone_points_for_user {
  my ($dbh, $user_name, $zone, $points_delta) = @_;

  my $sth = $dbh->prepare("select points from user_points_$user_name where zone = ?");
  $sth->execute($zone);

  # Entry doesn't exist. create, initialize to 0.
  if(! $sth->rows) {
    $sth = $dbh->prepare("insert into user_points_$user_name values(?, ?)");
    $sth->execute($zone,0);
  }

  $sth = $dbh->prepare("update user_points_$user_name set points = points + ? where zone = ?");
  $sth->execute($points_delta, $zone);
}

# Take: standard.
# Return: total points this user has.
sub get_total_points {
  my ($dbh, $q, $view_time) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;

  my ($username) = $sth->fetchrow_array;

  $sth = $dbh->prepare ("select sum(points) from user_points_$username");
  $sth->execute;
  my ($total_points) = $sth->fetchrow_array;

  return $total_points;
}

# Take: standard.
# Return: total points this user has tied up in unallocated picks, or in current bids.
sub get_total_points_inuse {
  my ($dbh, $q, $view_time) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;

  my ($username) = $sth->fetchrow_array;

  # Start with bid eq table.
  $sth = $dbh->prepare("select sum(bid) from bid_eq where bidder='$username' and status='bidding'");
  $sth->execute;
  my ($bid_points) = $sth->fetchrow_array;

  if (!$bid_points) {
    $bid_points = 0;
  }

  return $bid_points;
}

# Take: standard, + zone name.
# Return: minimum points for passed zone (by zone percent) of this user's that are tied
# up in unallocated picks, or current bids.
sub get_zone_points_inuse {
  my ($dbh, $q, $view_time, $zone) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($username) = $sth->fetchrow_array;

  $sth = $dbh->prepare("select percent from zones where name='$zone'");
  $sth->execute;
  my ($percent) = $sth->fetchrow_array;

  # Zone doesn't exist, oops?
  if (!$percent) {
    return 0;
  }

  # in bid, a PERCENTAGE of the bid's points get tied.
  $sth = $dbh->prepare("select ceiling(sum(bid) * $percent / 100) from bid_eq where bidder='$username' and zone='$zone' and status='bidding'");
  $sth->execute;
  my ($zone_points_bid) = $sth->fetchrow_array;


  if (!$zone_points_bid) {
    $zone_points_bid = 0;
  }

  return $zone_points_bid;
}

# takes: standard, $zone name.
# Returns: highest number the user can bid on an item from this zone.
sub zone_highest_bid {
  my ($dbh, $q, $view_time, $zone) = @_;

  my $total_points = get_total_points($dbh, $q, $view_time);
  my $total_points_in_use = get_total_points_inuse($dbh, $q, $view_time);
  my $total_points_avail = $total_points - $total_points_in_use;

  my $zone_points = get_zone_points($dbh, $q, $view_time, $zone);
  my $zone_points_in_use = get_zone_points_inuse($dbh, $q, $view_time, $zone);
  my $zone_points_avail = $zone_points - $zone_points_in_use;

  # $zone_points_avail is the most available if the user allocates only the minimum for each
  # item. $total_points_avail is how many actual unused points the user will have after paying
  # off all items.

  # To find the maximum bid for an item we must adjust $zone_points_avail for this zone's percent,
  # then compare that and $total_points_avail. Whichever is smallest is the most our user can bid.

  my $sth = $dbh->prepare("select percent from zones where name='$zone'");
  $sth->execute;
  my ($zone_exists) = $sth->rows;
  my ($percent) = $sth->fetchrow_array;

  if (!$zone_exists) {
    # Not a runnable zone. No eq from this zone. Nobody will ever bid on eq from this zone.
    # Points can only be used in allocate.
    return "--";
  }
  elsif (!$percent) {
    # 0%, max bid is total points.
    return $total_points_avail;
  }
  else {
    # ($percent / 100) * $highest_bid_this_zone = $zone_points_avail;
    my $highest_bid_this_zone = int((100 * $zone_points_avail)/$percent);

    if ($highest_bid_this_zone < $total_points_avail) {
      return $highest_bid_this_zone;
    }
    else {
      return $total_points_avail;
    }
  }
}

# takes: standard, $zone name.
# Returns: highest priced value this user can buy from this zone.
sub zone_highest_price {
  my ($dbh, $q, $view_time, $zone) = @_;

  my $total_points = get_total_points($dbh, $q, $view_time);
  my $total_points_in_use = get_total_points_inuse($dbh, $q, $view_time);
  my $total_points_avail = $total_points - $total_points_in_use;

  my $zone_points = get_zone_points($dbh, $q, $view_time, $zone);
  my $zone_points_in_use = get_zone_points_inuse($dbh, $q, $view_time, $zone);
  my $zone_points_avail = $zone_points - $zone_points_in_use;

  # $zone_points_avail is the most available if the user allocates only the minimum for each
  # item. $total_points_avail is how many actual unused points the user will have after paying
  # off all items.

  my $highest_price_this_zone = 
    ($zone_points_avail <= $total_points_avail ? $zone_points_avail : $total_points_avail);

  return $highest_price_this_zone;
}

# takes: standard, $zone name.
# Returns: highest priced value this user can buy from this zone.
sub zone_highest_alloc {
  my ($dbh, $q, $view_time, $zone) = @_;

  my $zone_points = get_zone_points($dbh, $q, $view_time, $zone);
  my $zone_points_in_use = get_zone_points_inuse($dbh, $q, $view_time, $zone);
  my $zone_highest_alloc = $zone_points - $zone_points_in_use;

  return $zone_highest_alloc;
}

# Takes: typical.
# Returns: mapping ref, zone -> avail_points
sub all_zone_highest_bid {
  my ($dbh, $q, $view_time) = @_;

  # Zone list,
  my $sth = $dbh->prepare("select name from zones order by name");
  $sth->execute;
  my $data = $sth->fetchall_arrayref;
  my @zone_list = map { $_->[0] } @$data;

  # Total figures,
  my $total_points = get_total_points($dbh, $q, $view_time);
  my $total_points_in_use = get_total_points_inuse($dbh, $q, $view_time);
  my $total_points_avail = $total_points - $total_points_in_use;

  # Loop through zonelist, get max bid considering current avail points and percent
  # for every zone. Ignore total points.
  my $cur_zone;
  my %zone_highest_bid = ();
  foreach $cur_zone (@zone_list) {
    # Get percent for cur_zone
    my $sth = $dbh->prepare("select percent from zones where name='$cur_zone'");
    $sth->execute;
    my ($percent) = $sth->fetchrow_array;

    my $zone_points = get_zone_points($dbh, $q, $view_time, $cur_zone);
    my $zone_points_in_use = get_zone_points_inuse($dbh, $q, $view_time, $cur_zone);
    my $zone_points_avail = $zone_points - $zone_points_in_use;

    # ($percent / 100) * $highest_bid_this_zone = $zone_points_avail; algebra says:
    my $highest_bid_this_zone = int((100 * $zone_points_avail)/$percent);

    # To find the maximum bid for an item we must adjust $zone_points_avail for this zone's percent,
    # then compare that and $total_points_avail. Whichever is smallest is the most our user can bid.
    $zone_highest_bid{$cur_zone} = $highest_bid_this_zone < $total_points_avail ?
      $highest_bid_this_zone : $total_points_avail;
  }

  return \%zone_highest_bid;
}

# Takes: typical.
# Returns: mapping ref, zone -> avail_points
sub all_zone_highest_price {
  my ($dbh, $q, $view_time) = @_;

  # Zone list,
  my $sth = $dbh->prepare("select name from zones order by name");
  $sth->execute;
  my $data = $sth->fetchall_arrayref;
  my @zone_list = map { $_->[0] } @$data;

  # Total figures,
  my $total_points = get_total_points($dbh, $q, $view_time);
  my $total_points_in_use = get_total_points_inuse($dbh, $q, $view_time);
  my $total_points_avail = $total_points - $total_points_in_use;

  # Loop through zonelist, get max bid considering current avail points and percent
  # for every zone. Ignore total points.
  my $cur_zone;
  my %zone_highest_price = ();
  foreach $cur_zone (@zone_list) {
    my $zone_points = get_zone_points($dbh, $q, $view_time, $cur_zone);
    my $zone_points_in_use = get_zone_points_inuse($dbh, $q, $view_time, $cur_zone);
    my $zone_points_avail = $zone_points - $zone_points_in_use;

    my $highest_price_this_zone = $zone_points_avail;

    # To find the maximum bid for an item we must adjust $zone_points_avail for this zone's percent,
    # then compare that and $total_points_avail. Whichever is smallest is the most our user can bid.
    $zone_highest_price{$cur_zone} = $highest_price_this_zone < $total_points_avail ?
      $highest_price_this_zone : $total_points_avail;
  }

  return \%zone_highest_price;
}

# Takes: typical.
# Returns: mapping ref, zone -> avail_points
sub all_zone_highest_alloc {
  my ($dbh, $q, $view_time) = @_;

  # Zone list,
  my $sth = $dbh->prepare("select name from zones order by name");
  $sth->execute;
  my $data = $sth->fetchall_arrayref;
  my @zone_list = map { $_->[0] } @$data;

  # Don't care about totals in alloc.
  # my $total_points = get_total_points($dbh, $q, $view_time);
  # my $total_points_in_use = get_total_points_inuse($dbh, $q, $view_time);
  # my $total_points_avail = $total_points - $total_points_in_use;

  # Loop through zonelist, get max bid considering current avail points and percent
  # for every zone. Ignore total points.
  my $cur_zone;
  my %zone_highest_alloc = ();
  foreach $cur_zone (@zone_list) {
    my $zone_points = get_zone_points($dbh, $q, $view_time, $cur_zone);
    my $zone_points_in_use = get_zone_points_inuse($dbh, $q, $view_time, $cur_zone);
    my $zone_points_avail = $zone_points - $zone_points_in_use;

    my $highest_alloc_this_zone = $zone_points_avail;

    # To find the maximum bid for an item we must adjust $zone_points_avail for this zone's percent,
    # then compare that and $total_points_avail. Whichever is smallest is the most our user can bid.
    $zone_highest_alloc{$cur_zone} = $highest_alloc_this_zone;
  }

  return \%zone_highest_alloc;
}

# Takes: typical.
# Return: zone -> points mapping ref reflecting user's current points.
sub get_all_zone_points {
  my ($dbh, $q, $view_time) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;

  my ($username) = $sth->fetchrow_array;

  $sth = $dbh->prepare("select zone,points from user_points_$username");
  $sth->execute;
  my $data = $sth->fetchall_arrayref;

  my $cur_zone;
  my %zone_points = ();
  foreach $cur_zone (@$data) {
    my $zone_name = $cur_zone->[0];
    my $zone_points = $cur_zone->[1];

    $zone_points{$zone_name} = $zone_points;
  }

  # Zone list,
  $sth = $dbh->prepare("select name from zones order by name");
  $sth->execute;
  $data = $sth->fetchall_arrayref;
  my @zone_list = map { $_->[0] } @$data;

  # Fill in missing zones with zeros.
  foreach $cur_zone (@zone_list) {
    if (!$zone_points{$cur_zone}) {
      $zone_points{$cur_zone} = 0;
    }
  }

  return \%zone_points;
}

1;
