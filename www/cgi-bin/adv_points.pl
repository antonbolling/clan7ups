use DBI;

use strict;
use warnings;

# Takes: standard, zone name, username
# Return: this user's points for passed zone name.
sub get_zone_points_foruser {
  my ($dbh, $q, $view_time, $zone, $name) = @_;
    
  my $sth = $dbh->prepare("select points from user_points_$name where zone='$zone'");
  $sth->execute;
  my ($zone_points) = $sth->fetchrow_array;

  return $zone_points ? $zone_points : 0
}

# Take: standard, username
# Return: total points this user has.
sub get_total_points_foruser {
  my ($dbh, $q, $view_time, $username) = @_;
  
  my $sth = $dbh->prepare("select sum(points) from user_points_$username");
  $sth->execute;
  my ($total_points) = $sth->fetchrow_array;

  return $total_points;
}

# Take: standard, username
# Return: total points this user has tied up in unallocated picks, or in current bids.
sub get_total_points_inuse_foruser {
  my ($dbh, $q, $view_time, $username) = @_;
  
  # Start with bid eq table.
  my $sth = $dbh->prepare("select sum(bid) from bid_eq where bidder='$username' and status='bidding'");
  $sth->execute; 
  my ($bid_points) = $sth->fetchrow_array;
  
  if (!$bid_points) {
    $bid_points = 0;
  }
  
  return $bid_points;
}

# takes: standard, zone name, username
# Returns: highest priced value this user can buy from this zone.
sub zone_highest_price_foruser {
  my ($dbh, $q, $view_time, $zone, $username) = @_;
      
  my $total_points = get_total_points_foruser($dbh, $q, $view_time, $username);
  my $total_points_in_use = get_total_points_inuse_foruser($dbh, $q, $view_time, $username);
  my $total_points_avail = $total_points - $total_points_in_use;
        
  my $zone_points = get_zone_points_foruser($dbh, $q, $view_time, $zone, $username);
  my $zone_points_in_use = get_zone_points_inuse_foruser($dbh, $q, $view_time, $zone, $username);
  my $zone_points_avail = $zone_points - $zone_points_in_use;
   
  # $zone_points_avail is the most available if the user allocates only the minimum for each
  # item. $total_points_avail is how many actual unused points the user will have after paying
  # off all items.
  
  my $highest_price_this_zone =
    ($zone_points_avail <= $total_points_avail ? $zone_points_avail : $total_points_avail);
  
  return $highest_price_this_zone;
} 

# takes: standard, zone name, username
# Returns: highest number the user can bid on an item from this zone.
sub zone_highest_bid_foruser {
  my ($dbh, $q, $view_time, $zone, $username) = @_;
      
  my $total_points = get_total_points_foruser($dbh, $q, $view_time, $username);
  my $total_points_in_use = get_total_points_inuse_foruser($dbh, $q, $view_time, $username);
  my $total_points_avail = $total_points - $total_points_in_use;
      
  my $zone_points = get_zone_points_foruser($dbh, $q, $view_time, $zone, $username);
  my $zone_points_in_use = get_zone_points_inuse_foruser($dbh, $q, $view_time, $zone, $username);
  my $zone_points_avail = $zone_points - $zone_points_in_use;

  # $zone_points_avail is the most available if the user allocates only the minimum for each
  # item. $total_points_avail is how many actual unused points the user will have after paying
  # off all items.
  
  # To find the maximum bid for an item we must adjust $zone_points_avail for this zone's perc$
  # then compare that and $total_points_avail. Whichever is smallest is the most our user can $
  
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

# Take: standard, zone name, username
# Return: minimum points for passed zone (by zone percent) of this user's that are tied
# up in unallocated picks, or current bids.
sub get_zone_points_inuse_foruser {
  my ($dbh, $q, $view_time, $zone, $username) = @_;
      
  my $sth = $dbh->prepare("select percent from zones where name='$zone'");
  $sth->execute;
  my ($percent) = $sth->fetchrow_array;
      
  # Zone doesn't exist, oops?
  if (!$percent) {
    return 0;
  }   
  
  # in bid, a PERCENTAGE of the bid's points get tied.
  $sth = $dbh->prepare("select ceiling(sum(bid) * $percent / 100) from bid_eq where 
bidder='$username' and zone='$zone'");
  $sth->execute;
  my ($zone_points_bid) = $sth->fetchrow_array;
  
  if (!$zone_points_bid) {
    $zone_points_bid = 0;
  }
  
  return $zone_points_bid;
}
1;
