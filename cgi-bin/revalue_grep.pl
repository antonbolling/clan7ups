use CGI;
use DBI;

use warnings;
use strict;

require "main_menu.pl";
require "ups_util.pl";
require "points.pl";
require "pickable.pl";
require "cook.pl";
require "time_string.pl";
require "revalue_gui.pl";
require "session.pl";

sub revalue_grep {
  my ($dbh, $q, $view_time) = @_;

  my $session_info = get_session_info($dbh, $q, $view_time);
  my $keywords = cook_string($q->param('keywords'));
  my $class = cook_word($q->param('class'));
  my $align = cook_word($q->param('align'));
  my $loc = cook_word($q->param('loc'));

  my $access = get_access($dbh, $q, $view_time);
  if ($access ne 'admin' and $access ne 'gate') {
    # No access.
    print <<EOT;
    <p>You do not have access to this dialog. Please tell an admin how you got here.
       Returning to main.</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }

  my $adv = 'where';
  my $store_query = "select id from store_eq";
  my $bid_query = "select id from bid_eq";

  if ($keywords) {
    $keywords = uc $keywords;
    my $new_text = " $adv upper(descr) like '%$keywords%'";
    $store_query .= $new_text;
    $bid_query .= $new_text;

    $adv = 'and';
  }
  if ($class ne 'any') {
    my $new_text = " $adv descr not like '% A$class %'";
    $store_query .= $new_text;
    $bid_query .= $new_text;

    $adv = 'and';
  }
  if ($align ne 'any') {
    my $new_text = " $adv descr not like '% A$align %'";
    $store_query .= $new_text;
    $bid_query .= $new_text;

    $adv = 'and';
  }
  if ($loc ne 'any') {
    my $new_text = " $adv descr like '% Loc($loc) %'";
    $store_query .= $new_text;
    $bid_query .= $new_text;

    $adv = 'and';
  }

#  print "<p> Grepping bid system... </p>";

  my $sth = $dbh->prepare($bid_query);
  $sth->execute;

  my $data = $sth->fetchall_arrayref;

  # test
  my $orig_matches = scalar(@$data);
#  print "<p> orig_matches: $orig_matches </p>\n";

  # 'pickable' function says bid stamps are such that current bidder can pick this item.
  # get all UNpickable items.
  my @biddable_eq = grep { !bid_pickable($dbh, $q, $view_time, $_->[0]) } @$data;
  @biddable_eq = map { $_->[0] } @biddable_eq;
  my $num_biddable_items = scalar(@biddable_eq);

  print <<EOT;

<h3>Bid system - $num_biddable_items matches:</h3>\n
<table width='100%'>
EOT

  if ($num_biddable_items) {
    # We have $entries matches to view.
    print <<EOT;

<form method="post" name="bid_eq" action="/fate-cgi/ups.pl">
$session_info
<input type="hidden" name="action" value="revalue_bid">

<tr id="bid_odd_row">
<td>Revalue</td><td>Zone</td><td>Desc</td>
<td id="browser_minbid">M</td><td>Age</td>
<td>New Minbid</td>
</tr>

EOT

    my $in_list = join ',', @biddable_eq;
#    print "<p>in_list: $in_list</p>\n";

    $sth = $dbh->prepare ("select id,zone,descr,min_bid,UNIX_TIMESTAMP(add_time) from bid_eq where id in ($in_list) order by descr,add_time");
    $sth->execute;

    my $count = 0;
    my $style;
    while (my $data = $sth->fetchrow_arrayref) {
      my $eqid = $data->[0];
      my $zone_name = $data->[1];
      my $eq_descr = $data->[2];
      my $min_bid = $data->[3];
      my $add_time = $data->[8];

      my $add_timer = $view_time - $add_time;
      $add_timer = time_string($add_timer);

      if ($count % 2) {
        $style = "bid_odd_row";
      }
      else {
        $style = "bid_even_row";
      }

      print <<EOT;

      <tr id="$style">
      <td><input type="checkbox" name="revalue_item" value="$eqid"></td>
      <td>$zone_name&nbsp;&nbsp;&nbsp;&nbsp;</td>
      <td>$eq_descr&nbsp;&nbsp;&nbsp;&nbsp;</td>
      <td id="browser_minbid">$min_bid</td>
      <td>$add_timer</td>
      <td><input type="text" name="revalue_item_$eqid" value="$min_bid"></td>
      </tr>
EOT

      $count++;
    }

    print <<EOT;
    </table>
    <input type="submit" value="Clear bids on and alter minbids for selected items">
    </form>

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

#  print "<p> Grepping for eq: keywords class align loc, $keywords $class $align $loc </p>\n";
#  print "<p> Store query: $store_query </p>\n";
#  print "<p> Bid query: $bid_query </p>\n";
#  print "<p> Grepping store system... </p>";

  $sth = $dbh->prepare($store_query);
  $sth->execute;

  $data = $sth->fetchall_arrayref;

  # test
  $orig_matches = scalar(@$data);
#  print "<p> orig_matches: $orig_matches </p>\n";

  my @claimable_store_eq = map { $_->[0] } @$data;
  my $num_claimable_items = scalar(@claimable_store_eq);

  print <<EOT;
<hr>
<h3>Store system - $num_claimable_items matches:</h3>\n

EOT

  if ($num_claimable_items) {
    # We have $num_claimable_items matches to view.
    print <<EOT;
<form method="post" name="buy_eq" action="/fate-cgi/ups.pl">
 $session_info
<input type="hidden" name="action" value="revalue_store">

<table>
<tr id="store_odd_row">
<td>Revalue</td><td>Zone</td><td>Descr</td>
<td id="browser_price">P</td><td>Age</td>
<td>New Price</td>2
</tr>

EOT

    my $in_list = join ',', @claimable_store_eq;
#    print "<p>in_list: $in_list</p>\n";

    $sth = $dbh->prepare("select id,zone,descr,price,UNIX_TIMESTAMP(first_claim_time) as pick_stamp,UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(add_time) from store_eq where id in ($in_list) order by descr,add_time");
    $sth->execute;

    my $count = 0;
    my $style;

    while (my $item = $sth->fetchrow_arrayref) {
      my $eqid = $item->[0];
      my $zone_name = $item->[1];
      my $eq_descr = $item->[2];
      my $eq_price = $item->[3];
      my $add_time = time_string($item->[5]);

      if ($count % 2) {
        $style = "store_odd_row";
      }
      else {
        $style = "store_even_row";
      }

      print <<EOT;

      <tr id="$style">
      <td><input type="checkbox" name="revalue_item" value="$eqid"></td>
      <td>$zone_name&nbsp;&nbsp;&nbsp;&nbsp;</td>
      <td>$eq_descr&nbsp;&nbsp;&nbsp;&nbsp;</td>
      <td id="browser_price">$eq_price</td>
      <td>$add_time</td>
      <td><input type="text" name="revalue_item_$eqid" value="$eq_price"></td>
      </tr>
EOT

      $count++;
    }

    print <<EOT;
    </table>
    <input type="submit" value="Revalue selected items">
    </form>

    <h4>Column key</h4>
    <ul>
    <li id="browser_price"><font id="browser_price">P:</font> Price of this item.
    <li id="browser_avail"><font id="browser_avail">A:</font> Available points for this zone. Same as in
        your point breakdown at the bottom of the page.
    <li id="browser_claimable"><font id="browser_claimable">C:</font> Claimable. Can you place a claim on
        this item? You can if:
        <ul>
        <li>You have enough points from this zone to buy the item, and
        <li>You have more points than whoever holds the current claim, or the item hasn\'t been claimed yet.
        </ul>
    <li> Timer: How much longer until this item is pickable, ie whoever holds the current claim wins it.
         For store system items the timer always expires one day after the first time someone places a
         claim.
    <li> Age: How long ago this item was added to the system.
    </ul>
EOT
  }


  revalue_gui($dbh, $q, $view_time);
}

1;
