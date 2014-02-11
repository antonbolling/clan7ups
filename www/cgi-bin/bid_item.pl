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
require "user_notifications.pl";
require "auction_timing.pl";
require "ups_config.pl";

sub bid_item {
  my ($dbh, $q, $view_time) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  my $session_info = get_session_info($dbh, $q, $view_time);

  my $bid_item_num = cook_int($q->param('bid_item'));

  if (!config_enable_bidding($dbh)) {
			print <<EOT;
      <h3>Oh noes, bidding is currently disabled.  Sorry... have a kitten</h3>
			<img src="http://placekitten.com/300/300">
EOT
			main_menu($dbh, $q, $view_time);
			return 1;
	}

  if (!$bid_item_num) {
    print <<EOT;
    <p>ERROR: No item num. invalid input. wth? ask an admin to figure out what\'s wrong.</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }

  $sth = $dbh->prepare("select zone, descr, min_bid, bidder, bid, auto_max_upbid, UNIX_TIMESTAMP(cur_bid_time), UNIX_TIMESTAMP(first_bid_time), UNIX_TIMESTAMP(add_time) from bid_eq where id=?");
  $sth->execute($bid_item_num);

  my $matches = $sth->rows;

  print "<p>$matches matches</p>";

  my ($zone, $descr, $min_bid, $current_bidder, $current_bid, $current_auto_max_upbid, $cur_bid_time, $first_bid_time, $add_time) =
     $sth->fetchrow_array;

  if (!$matches) {
    print "<p>ERROR: Oops, it looks like that item was already picked. Returning to main...</p>\n";
    main_menu($dbh, $q, $view_time);
    return 1;
  }
  elsif (defined($current_bidder) and $current_bidder eq $login) {
    print <<EOT;
    <p>You already have the standing bid on this item. Returning to main.</p>
EOT
    main_menu($dbh, $q, $view_time);
  }
  elsif (!$first_bid_time) {
    print "<p>Looks like you're the first to place a bid on this item. Continuing...</p>";
  }
  else {
		my $timer_seconds = auction_seconds_remaining($view_time,$add_time,$cur_bid_time);

    if ($timer_seconds < 1) {
      print "<p>ERROR: Oops, it looks like the timer for that item expired! Returning to main...</p>\n";
      main_menu($dbh, $q, $view_time);
      return 1;
    }
  }

  # OK timers allow bidding. Calculate min upbid.
  # Got this far. The item is biddable. Get a little more information;
  # Calculate min upbid.
  my $min_upbid;
  if (!$current_bid) {
    $current_bid = 'N/A';
    $min_upbid = $min_bid;
  }
  else {
    $min_upbid = $current_bid * 1.1;
    my $int_upbid = int($min_upbid);

    if ($int_upbid < $min_upbid) {
      $int_upbid++;
    }

    $min_upbid = $int_upbid;
  }

  # What is this user's max upbid?
  my $max_upbid = zone_highest_bid($dbh, $login, $zone);
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
		my $auto_max_upbid = cook_int($q->param('auto_max_upbid'));

		my $original_auto_max_upbid = $auto_max_upbid; # cache the original value, as it will be saved to the database if $login is successful in winning this bid

		if ($auto_max_upbid and $auto_max_upbid > $max_upbid) {
				# Don't permit auto_max_upbid to exceed max_upbid, ensuring that auto_max_upbid is itself a valid bid
				$auto_max_upbid = $max_upbid;
		}

		my $incumbent_max_upbid = undef;

		if ($current_bidder) {
				my $incumbent_max_upbid = $current_bid + zone_highest_bid($dbh, $current_bidder, $zone); # current_bidder's current_bid points are tied up and not counted in zone_highest_bid, so add them in
				if ($current_auto_max_upbid and $current_auto_max_upbid > $incumbent_max_upbid) {
						# limit the current bidder's auto_max_upbid to their maximum bid for this zone,
						# ensuring that current_auto_max_upbid is itself a valid bid
						$current_auto_max_upbid = $incumbent_max_upbid;
				}
		}

    if (!$bid or $bid < $min_upbid) {
      print <<EOT;
      <p>ERROR: You must bid at least $min_upbid points on this item. Please try again.</p>
EOT

      bid_item_gui($dbh, $q, $view_time);
      return 1;
    } elsif ( !$auto_max_upbid or $auto_max_upbid <= $bid) {
				print <<EOT;
				<p>ERROR: Your automatic max upbid of $auto_max_upbid must be greater than your bid of $bid. Please set the automatic max upbid higher.</p>
EOT
        bid_item_gui($dbh, $q, $view_time);
				return 1;
		} elsif ($bid > $max_upbid) {
				print <<EOT;
				<p>ERROR: Your bid of $bid exceeds your max upbid of $max_upbid. Please bid lower.</p>
EOT
        bid_item_gui($dbh, $q, $view_time);
				return 1;
		} elsif ($current_bidder and $current_auto_max_upbid and !$auto_max_upbid and $bid <= $current_auto_max_upbid) {
				do_auto_max_upbid($dbh, $current_bidder, $bid_item_num, $descr, $current_bid, $bid );
				print <<EOT;
				<p>ERROR: Your bid was lower than the current bidder\'s automatic max upbid. The current bidder was forced to match your bid of $bid. Please bid higher.</p>
EOT
        bid_item_gui($dbh, $q, $view_time);
				return 1;
		} elsif ($current_bidder and $current_auto_max_upbid and $auto_max_upbid and $bid <= $current_auto_max_upbid and $auto_max_upbid <= $current_auto_max_upbid) {
				do_auto_max_upbid($dbh, $current_bidder, $bid_item_num, $descr, $current_bid, $auto_max_upbid);
				print <<EOT;
				<p>ERROR: Your automatic max upbid was lower than the current bidder\'s automatic max upbid. The current bidder was forced to match your automatic max upbid of $auto_max_upbid. Please bid higher.</p>
EOT
        bid_item_gui($dbh, $q, $view_time);
				return 1;
		} else {
				if ($current_bidder and $current_auto_max_upbid and $auto_max_upbid and $bid <= $current_auto_max_upbid && $auto_max_upbid > $current_auto_max_upbid) {
						$bid = $current_auto_max_upbid + 1;
						print <<EOT;
						<p>NOTE: Your bid was increased to $bid to exceed the old bidder\'s automatic max upbid. Your auto max upbid is still $original_auto_max_upbid.</p>
EOT
				}

      print <<EOT;
      <p> SUCCESS: Placing a bid of $bid points on item $bid_item_num, $descr.
          Returning to the main menu.</p>
EOT

      #Log this bid
      my $auto_max_upbid_string = $original_auto_max_upbid ? $original_auto_max_upbid : "";
      my $log_msg = "$login bid $bid (auto_max_upbid $auto_max_upbid_string) on item $bid_item_num";
      my $sth = $dbh->prepare("insert into log (user,action,idata1,bigdata) values(?,'bid',?,?)");
			$sth->execute($uid,$bid_item_num,$log_msg);

			$sth = $dbh->prepare("update bid_eq set bid=?, auto_max_upbid=?, bidder=?, status='bidding', cur_bid_time=now() where id=?");
			$sth->execute($bid,$original_auto_max_upbid,$login,$bid_item_num);

			if ($first_bid_time) {
					create_outbid_notification($dbh, $current_bidder, $bid_item_num, $descr, $current_bid, $bid);
			}

      if (!$first_bid_time) {
					$sth = $dbh->prepare("update bid_eq set first_bid_time=now() where id=?");
					$sth->execute($bid_item_num);
      }

      main_menu($dbh, $q, $view_time);
      return 1;
    }
  }
}

# When executing an automatic upbid, update only the current bid on an item
# No modifications to timers, current bidder, auto max upbid, etc.
sub do_auto_max_upbid {
		my ($dbh, $current_bidder, $bid_item_num, $descr, $old_bid, $new_bid) = @_;
		my $sth = $dbh->prepare("update bid_eq set bid=? where id=?");
		$sth->execute($new_bid,$bid_item_num);
		create_auto_upbid_notification($dbh, $current_bidder, $bid_item_num, $descr, $old_bid, $new_bid);
}

sub create_auto_upbid_notification {
		my ($dbh, $current_bidder, $bid_item_num, $descr, $old_bid, $new_bid) = @_;
		my $notification = "<form>auto upbid on ID $bid_item_num, your bid increased from $old_bid to $new_bid, $descr";
		create_notification_by_user_name($dbh, $current_bidder, $notification);
}

sub create_outbid_notification {
		my ($dbh, $old_bidder, $bid_item_num, $descr, $old_bid, $new_bid) = @_;

		my $upbid_notification = <<EOT;
		<form method="post" name="outbid_notification" action="/cgi-bin/ups.pl">
				<input type="hidden" name="action" value="bid_item_gui">
				<input type="hidden" name="bid_item" value='$bid_item_num'>
				outbid on ID $bid_item_num, your bid of $old_bid was replaced by $new_bid, $descr
				<input type="submit" value="Upbid">
EOT
# BY CONVENTION, ALL NOTIFICATIONS MUST be a string containing a html form omitting a trailing </form> tag. main_menu.pl will append the </form> tag with the proper session_info
    print STDERR "bid_item.pl: creating outbid notification for item $bid_item_num, previous bidder $old_bidder\n";
		create_notification_by_user_name($dbh,$old_bidder,$upbid_notification);
}

1;
