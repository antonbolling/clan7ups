use CGI;
use DBI;

use strict;
use warnings;

require "cook.pl";

my $one_day = 86400;
my $three_days = 259200;

sub bid_pickable {
  my ($dbh, $q, $view_time, $item) = @_;

  # An item in bid_eq is pickable if:
  # - it's been bid on
  # - current bid is 3 days old or older
  # - current bid was made at least 3 days after the first bid and is at least a day old.
  # FIRST (always) first_bid_time must be non null, THEN
  # EITHER now() - cur_bid_time is 3 days or more, OR
  # cur_bid_time - first_bid_time is 3 days or more, AND now() - cur_bid_time is 1 day or more
  my $sth = $dbh->prepare("select first_bid_time is not null and ( (unix_timestamp(now()) - unix_timestamp(cur_bid_time) >= $three_days) or ( (unix_timestamp(cur_bid_time) - unix_timestamp(first_bid_time) >= $three_days) and (unix_timestamp(now()) - unix_timestamp(cur_bid_time) >= $one_day))) as pickable from bid_eq where id=$item");
  $sth->execute;

  my ($pickable) = $sth->fetchrow_array;
#  print "<p> Bid Pickable on item $item is $pickable </p>";
  return $pickable;
}

sub store_pickable {
  my ($dbh, $q, $view_time, $item) = @_;

  # An item in store_eq is pickable if:
  # - it's been claimed, and
  # - current time is more than a day after original claim.
  my $sth = $dbh->prepare("select first_claim_time is not null and (unix_timestamp(now()) - unix_timestamp(first_claim_time) >= $one_day) from store_eq where id=$item");
  $sth->execute;

  my ($pickable) = $sth->fetchrow_array;
#  print "<p> Store Pickable on item $item is $pickable </p>";
  return $pickable;
}

# Can only claim a store item if:
# You have at least store_eq.price points available from this zone,
# and you have more points from this zone than current claimer.
# claimable means: "this user can place a claim on this item"
sub claimable {
  my ($dbh, $q, $view_time, $item) = @_;

  # Get username.
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($username) = $sth->fetchrow_array;

  $sth = $dbh->prepare("select zone,buyer,price from store_eq where id=$item");
  $sth->execute;
  my ($zone,$holdername,$price) = $sth->fetchrow_array;

  my $curuid_avail = zone_highest_price($dbh, $q, $view_time, $zone);

  # Get the zone for this item, check if the item exists.
  $sth = $dbh->prepare("select * from store_eq where id=$item");
  $sth->execute;
  # If the item doesn't exist it's not claimable (could happen: claim timer expires,
  # claimer picks while our viewer is looking for the left mouse button)
  if (!$sth->rows) {
#    print "<p> item_doesn't_exist: claimable returning 0 for item $item. </p>\n";
    return 0;
  }

  # If the item is pickable noone can place a claim.
  if (store_pickable($dbh, $q, $view_time, $item)) {
#    print "<p> item_is_pickable: claimable returning 0 for item $item. </p>\n";
    return 0;
  }

  # Does this user have enough points?
  $sth = $dbh->prepare("select price from store_eq where id = $item");
  $sth->execute;
  my ($item_price) = $sth->fetchrow_array;

  # Not enough points.
  if ($item_price > $curuid_avail) {
#    print "<p> not_enough_points: claimable returning 0 for item $item. </p>\n";
    return 0;
  }
  else {
    # Check who the current claim is held by:
    $sth = $dbh->prepare("select buyer from store_eq where id=$item");
    $sth->execute;
    my ($buyer) = $sth->fetchrow_array;

    # If there is no current claim, it's claimable:
    if (!$buyer) {
#      print "<p> no_current_claim: claimable returning 1 for item $item. username $username, buyer $buyer. </p>\n";
      return 1;
    }

    # Check that this user has more AVAILABLE points for this zone than the buyer.
    my $thisuid = $uid;
    $sth = $dbh->prepare("select id from users where name='$holdername'");
    $sth->execute;
    my ($holderuid) = $sth->fetchrow_array;

    if ($uid == $holderuid) {
      # No reason to reclaim if you hold current claim!
      return 0;
    }

    my $vars = $q->Vars;

    # Get current uid's avail points for this zone,
    # Current buyer uid's avail points,
    $vars->{'uid'} = $holderuid;
    my $holder_avail = zone_highest_price($dbh, $q, $view_time, $zone);
    $vars->{'uid'} = $thisuid;

    # Compare what avail points would be IF NEITHER HAD A BID ON THIS ITEM.
    $holder_avail += $price;

    my $more_points = $curuid_avail > $holder_avail ? 1 : 0;

#    print "<p> compare_result: claimable returning $more_points for item $item. username $username, buyer $buyer. </p>\n";
    return $more_points;
  }
}
