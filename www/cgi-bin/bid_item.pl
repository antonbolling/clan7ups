#08/24/03 - JM - Changed some prepare/execute statements to $dbh->do() for speed
#                Bids are now logged

use warnings;
use strict;

use CGI;
use DBI;

require "cook.pl";
require "session.pl";
require "main_menu.pl";
require "time_string.pl";
require "ups_util.pl";
require "bid_item_gui.pl";

my $one_day = 86400;
my $three_days = 259200;

sub bid_item {
  my ($dbh, $q, $view_time) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  my $session_info = get_session_info($dbh, $q, $view_time);

  my $bid_item_num = cook_int($q->param('bid_item'));

  if (!$bid_item_num) {
    print <<EOT;
    <p>ERROR: No item num. invalid input. wth? ask an admin to figure out what\'s wrong.</p>
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
  }
  elsif (!$first_bid_time) {
    print "<p>Looks like you're the first to place a bid on this item. Continuing...</p>";
  }
  else {
    my $time_first_to_cur = $cur_bid_time - $first_bid_time;
    my $three_days_after_cur = $cur_bid_time + $three_days;
    my $one_day_after_cur = $cur_bid_time + $one_day;

    my $timer_expires = $time_first_to_cur > $three_days ? $one_day_after_cur : $three_days_after_cur;
    my $timer_seconds = $timer_expires - $view_time;

    if ($timer_seconds <= 0) {
      print "<p>ERROR: Oops, it looks like the timer for that item expired! Returning to main...</p>\n";
      main_menu($dbh, $q, $view_time);
      return 1;
    }
  }

  # OK timers allow bidding. Calculate min upbid.
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

  # What is this user's max upbid?
  my $max_upbid = zone_highest_bid($dbh, $q, $view_time, $zone);
  if ($min_upbid > $max_upbid) {
    print <<EOT;
    <p>ERROR: Oops, looks like you're out of luck. You don't have enough points to bid on this item!
       returning to the main menu.</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }
  else {
    # This user has enough points.
    # If they bid more than min_upbid update the entry,
    # otherwise loop back into bid_item_gui with an error about bid must be at least blah.
    my $bid = cook_int($q->param('bid'));

    if (!$bid or $bid < $min_upbid) {
      print <<EOT;
      <p>ERROR: You must bid at least $min_upbid points on this item. Please try again.</p>
EOT

      bid_item_gui($dbh, $q, $view_time);
      return 1;
    } elsif ($bid > $max_upbid) {
				print <<EOT;
				<p>ERROR: Your bid of $bid exceeds your max upbid of $max_upbid. Please bid lower.</p>
EOT
        bid_item_gui($dbh, $q, $view_time);
				return 1;
		} else {
      print <<EOT;
      <p> SUCCESS: Placing a bid of $bid points on item $bid_item_num, $descr.
          Returning to the main menu.</p>
EOT

      #Log this bid
      $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'bid',$bid_item_num,'$login bid $bid on item $bid_item_num')");

      $dbh->do("update bid_eq set bid=$bid, bidder='$login', status='bidding', cur_bid_time=now() where id=$bid_item_num");

      if (!$first_bid_time) {
        $dbh->do("update bid_eq set first_bid_time=now() where id=$bid_item_num");
      }

      main_menu($dbh, $q, $view_time);
      return 1;
    }
  }
}

1;
