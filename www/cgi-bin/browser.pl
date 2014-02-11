# 11/15/03 - JM - Removed STORE system

use CGI;
use DBI;

use warnings;
use strict;

require "main_menu.pl";
require "browser_gui.pl";
require "ups_util.pl";
require "points.pl";
require "cook.pl";
require "time_string.pl";
require "auction_timing.pl";

sub browser {
  my ($dbh, $q, $view_time) = @_;

  my $session_info = get_session_info($dbh, $q, $view_time);
  my $keywords = cook_string($q->param('keywords'));
  my $class = cook_word($q->param('class'));
  my $align = cook_word($q->param('align'));
  my $loc = cook_word($q->param('loc'));
  my $zone = cook_word($q->param('zone'));
  my $order_eq_by = cook_word($q->param('order_eq_by'));
  my $admin = cook_int($q->param('uid'));

  my $adv = 'where';
  my $bid_query = "select id from bid_eq";

  if ($keywords) {
      my @keyword_list = split(/\s/, $keywords);
      foreach my $keyword (@keyword_list) {
          my $new_text = " $adv convert(descr USING latin1) collate latin1_swedish_ci like '%$keyword%'"; # convert/collate used to do case-insensitive string comparison on a binary string: http://dev.mysql.com/doc/refman/5.0/en/case-sensitivity.html
          $bid_query .= $new_text;

          $adv = 'and';
      }
  }
  if ($class ne 'any') {
    my $new_text = " $adv descr not like '% A$class %'";
    $bid_query .= $new_text;

    $adv = 'and';
  }
  if ($align ne 'any') {
    my $new_text = " $adv descr not like '% A$align %'";
    $bid_query .= $new_text;

    $adv = 'and';
  }
  if ($loc ne 'any') {
    my $new_text = " $adv descr like '% Loc($loc) %'";
    $bid_query .= $new_text;

    $adv = 'and';
  }
  if ($zone ne 'any') {
    my $new_text = " $adv zone='$zone'";
    $bid_query .= $new_text;

    $adv = 'and';
  }

  #Get username so we can display owned bids in yellow
  my $sth = $dbh->prepare("select name from users where id=$admin");
  $sth->execute;
  my $admin_name = $sth->fetchrow_array;
  $sth->finish;

#  print "<p> Grepping bid system... </p>";

    #print "Using SQL query: $bid_query\n";
    $sth = $dbh->prepare($bid_query);
    $sth->execute;

    my $data = $sth->fetchall_arrayref;

    # test
    my $orig_matches = scalar(@$data);
#      print "<p> orig_matches: $orig_matches </p>\n";

    # 'pickable' function says bid stamps are such that current bidder can pick this item.
    # get all UNpickable items.
    my @biddable_eq = grep { !auction_pickable($dbh, $_->[0]) } @$data;
    @biddable_eq = map { $_->[0] } @biddable_eq;
    my $num_biddable_items = scalar(@biddable_eq);

    if ($num_biddable_items) {
      # We have $entries matches to view.
      print <<EOT;

<h3>Bid system - $num_biddable_items matches:</h3>
EOT
      return_main($dbh, $q, $view_time);
		 	print <<EOT;
			TIP! Sort by "Timer" to see auctions ending soon. Sort multiple columns simultaneously by holding down the shift key and clicking a second, third or even fourth column header!<br>
<form method="post" name="bid_eq" action="/cgi-bin/ups.pl">
$session_info
<input type="hidden" name="action" value="bid_item_gui">
<table border=0 width=100% cellpadding=0 cellspacing=1 bgcolor=cccccc>
  <tr><td>
	<input type="submit" value="Bid on selected item">
  </td><tr>
  <tr><td>
  <table id=eqBrowser border=0 cellpadding=3 cellspacing=1 width='100%'>

	
	<thead>
  <tr id="bid_header">
    <th>Bid</th><th>Id</th><th>Zone</th><th>Desc</th>
    <th id="browser_minbid">M</th>
    <th id="browser_curbid">A</th>
    <th id="browser_minupb">U</th>
    <th id="browser_maxupb">X</th>
    <th>Timer</th>
    <th>Age</th>
  </tr>
	</thead>
EOT

      my $in_list = join ',', @biddable_eq;

			my $eq_query = "select id,bidder,zone,TRIM(descr),min_bid,bid,ceiling(bid*1.1) as min_upbid, UNIX_TIMESTAMP(first_bid_time), UNIX_TIMESTAMP(cur_bid_time), UNIX_TIMESTAMP(add_time) from bid_eq where id in ($in_list) ";
			
			if ( $order_eq_by eq "high_bids_first" ) {
					$eq_query .= " order by bid DESC, descr, add_time";
			} elsif ( $order_eq_by eq "new_items_first" ) {
					$eq_query .= " order by add_time DESC, descr";
			} else { # default to "similar_items_together"
					$eq_query .= " order by descr, bid, add_time";
			}

      $sth = $dbh->prepare($eq_query);
      $sth->execute;

    # For display purposes we need info for: maximum allowable bid by zone,
    # accounting for all of this user's points that are currently tied up in bids and claims.
      my $zone_highest_bid = all_zone_highest_bid($dbh, $admin_name);

      my $count = 0;
      my $style;
      my $have_bid = 0;
      while (my $data = $sth->fetchrow_arrayref) {
        my $eqid = $data->[0];
        my $bidder = $data->[1];
        my $zone_name = $data->[2];
        my $eq_descr = $data->[3];
        my $min_bid = $data->[4];
        my $bid = $data->[5];
        my $min_upbid = $data->[6];
        my $first_bid_time = $data->[7];
        my $cur_bid_time = $data->[8];
        my $add_time = $data->[9];

        if (defined($bidder) && $bidder eq $admin_name) {
          $have_bid = 1;
        } else {
          $have_bid = 0;
        }

        my $add_timer = $view_time - $add_time;
        $add_timer = time_string($add_timer);

        if ($have_bid) {
          $style = "bid_own";
        } else {
          if ($count % 2) {
            $style = "bid_even";
          } else {
            $style = "bid_odd";
          }
        }

        # Construct "timer" variable.
        my $bid_timer;
        if ((!$cur_bid_time) or (!$first_bid_time)) {
          $bid_timer = "N/A";
        } else {
						$bid_timer = time_string(auction_seconds_remaining($view_time,$add_time,$cur_bid_time));
        }

        my $points_avail = $zone_highest_bid->{$zone_name};

        $min_upbid = $min_upbid ? $min_upbid : $min_bid;
        $bid = $bid ? $bid : "N/A";

        print <<EOT;

      <tr id="$style">
        <td>
EOT
        if (!$have_bid) {
          print "<input type='radio' name='bid_item' value='$eqid'>";
        }
        print <<EOT;
        </td>
        <td><span class="smfont">$eqid</span></td>
        <td><span class="smfont">$zone_name</span></td>
        <td><span class="smfont">$eq_descr</span></td>
        <td id="browser_minbid"><span class="smfont">$min_bid</span></td>
        <td id="browser_curbid"><span class="smfont">$bid</span></td>
        <td id="browser_minupb"><span class="smfont">$min_upbid</span></td>
        <td id="browser_maxupb"><span class="smfont">$points_avail</span></td>
        <td><span class="smfont">$bid_timer</span></td>
        <td><span class="smfont">$add_timer</span></td>
      </tr>
EOT

        $count++;
      }

      print <<EOT;
      </table></td></tr>
			<tr><td><input type="submit" value="Bid on selected item"></td></tr>
      </table>
			</form>
			<script type='text/javascript'>
				\$(function() {
						\$('#eqBrowser').tablesorter({ headers:{ 8: { sorter:'upstimer'}, 9: { sorter:'upstimer'}}});
					 });
		</script>

      <h4>Column key</h4>
      <ul>
      <li id="browser_minbid"><font id="browser_minbid">M:</font> Minimum bid.
      <li id="browser_curbid"><font id="browser_curbid">A:</font> Current bid.
      <li id="browser_minupb"><font id="browser_minupb">U:</font> Minimum upbid. This is 10% higher than
          the current bid.
      <li id="browser_maxupb"><font id="browser_maxupb">X:</font> Maximum upbid. This is the same as the
          'M' column in point breakdown at the bottom of the page.
      <li> Timer: How much longer until this item is pickable. When this timer runs to 0, whoever holds the
           current bid wins the item.
      <li> Age: How long ago this item was added to the system.
      </ul>
EOT

    }

  browser_gui($dbh, $q, $view_time);
  return_main($dbh, $q, $view_time);

  display_points($dbh, $admin_name);
}

1;
