use warnings;
use strict;

use CGI;
use DBI;

require "cook.pl";
require "session.pl";
require "main_menu.pl";
require "time_string.pl";
require "ups_util.pl";
require "auction_timing.pl";

sub bid_item_gui {
  my ($dbh, $q, $view_time) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  my $session_info = get_session_info($dbh, $q, $view_time);

  my $bid_item_num = cook_int($q->param('bid_item'));

  if (!$bid_item_num) {
    print <<EOT;
    <p>ERROR: Pick an item, genius!</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }

  $sth = $dbh->prepare("select zone, descr, min_bid, bidder, bid, UNIX_TIMESTAMP(cur_bid_time), UNIX_TIMESTAMP(first_bid_time), UNIX_TIMESTAMP(add_time) from bid_eq where id=$bid_item_num");
  $sth->execute;

  my $matches = $sth->rows;

  print "<p>$matches matches</p>";

  my ($zone, $descr, $min_bid, $bidder, $bid, $cur_bid_time, $first_bid_time, $add_time) =
     $sth->fetchrow_array;

  my $time_string;
  if (!$matches) {
    print "<p>ERROR: Oops, it looks like that item was already picked. Returning to main...</p>\n";
    main_menu($dbh, $q, $view_time);
    return 1;
  }
  elsif (defined($bidder) and $bidder eq $login) {
    print <<EOT;
    <p>You already have the standing bid on this item. Returning to main.</p>
EOT
    main_menu($dbh, $q, $view_time);
    return 1;
  }
  elsif (!$first_bid_time) {
    print "<p>Looks like you're the first to place a bid on this item. Continuing...</p>";
    $time_string = "N/A";
  }
  else {
		my $timer_seconds = auction_seconds_remaining($view_time,$add_time,$cur_bid_time);

    if ($timer_seconds < 1) {
      print "<p>ERROR: Oops, it looks like the timer for that item expired! Returning to main...";
      main_menu($dbh, $q, $view_time);
      return 1;
    }

    # If we got past that, set the time string;
    $time_string = time_string($timer_seconds);
  }

  # Got this far. The item is biddable. Get a little more information;
  # Calculate min upbid.
  my $min_upbid;
  if (!$bid) {
    $bid = 'N/A';
    $min_upbid = $min_bid;
  }
  else {
    $min_upbid = $bid * 1.1;
    my $int_upbid = int($min_upbid);

    if ($int_upbid < $min_upbid) {
      $int_upbid++;
    }

    $min_upbid = $int_upbid;
  }

  my $max_upbid = zone_highest_bid($dbh, $q, $view_time, $zone);

  print <<EOT;
  <ul>
  <li> $descr
  <li> Item ID: $bid_item_num
  <li> Zone: $zone
  <li> Minimum bid: $min_bid
  <li> Current bid: $bid
  <li> Minimum upbid: $min_upbid
  <li> Maximum upbid: $max_upbid
  <li> Timer till current bid wins: $time_string
  </ul>
EOT

  if ($min_upbid > $max_upbid) {
    print <<EOT;
    <p>ERROR: Oops, looks like you're out of luck. You don't have enough points to bid on this item!
       returning to the main menu.</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }
  else {
    print <<EOT;
    <form name="picks" method="post" action="/cgi-bin/ups.pl">
    <input type="hidden" name="action" value="bid_item">
    <input type="hidden" name="bid_item" value="$bid_item_num">
    $session_info
    <p>Your bid on this item: <input type="text" name="bid"></p>
    <input type="submit" value="Place this bid">
    </form>
EOT

    return_main($dbh, $q, $view_time);
  }
}

1;
