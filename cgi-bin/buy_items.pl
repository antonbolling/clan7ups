#08/25/03 - JM - Changed some prepare/execute statements to just $dbh->do()
#                Purchased items are now logged

use warnings;
use strict;

use CGI;
use DBI;

require "session.pl";
require "points.pl";
require "cook.pl";
require "main_menu.pl";
require "pickable.pl";

my $one_day = 86400;
my $three_days = 259200;

sub buy_items {
  my ($dbh, $q, $view_time) = @_;

  # Get login.
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  # Auth tokens for next session.
  my $session_info = get_session_info($dbh, $q, $view_time);

  # Cook item list:
  my @item_list = $q->param('buy_items');
  if (!scalar(@item_list)) {
    # There were no items. error out, return to main.
    print <<EOT;
    <p id="error">ERROR: No items selected! Returning you to the main menu.
EOT
  }
  else {
    # Cook the itemlist. Loop through the itemlist. Reclaim each that's claimable, print
    # a speol for each.
    my @cooked_list = map { cook_int($_) } @item_list;
    my $in_list = join ',', @cooked_list;

    print "<p>trying to buy items: $in_list</p>\n";

    my $sth = $dbh->prepare("select id,zone,descr,price from store_eq where id in ($in_list)");
    $sth->execute;
    my $data = $sth->fetchall_arrayref;
    my $num_items = $sth->rows;

#    print "<p> $num_items items </p>\n";

    print <<EOT;
    <ul>
EOT

    my $item;
    foreach $item (@$data) {
      my ($eqid, $zone, $descr, $price) = @$item;

      # Find out if this user has enough points to even afford the item:
      my $can_afford;
      my $points_avail = zone_highest_price($dbh, $q, $view_time, $zone);

      if ($price <= $points_avail) {
        print <<EOT;
        <li><font id="success">SUCCEEDED</font> placing claim to item id $eqid: $descr
EOT

        # Recook the descr field.
        $descr = cook_string($descr);

        # First: Put the item in ougoing_eq
        $dbh->do("insert into outgoing_eq (bidder,descr) values ('$login','$descr')");

        # Next: Delete the item from store_eq
        $dbh->do("delete from store_eq where id=$eqid");

        # Last: update user's points.
        $dbh->do("update user_points_$login set points = points - $price where zone = '$zone'");

        $dbh->do("insert into log (user,action,cdata1,cdata2,idata1,bigdata) values($uid,'buy','$login','$zone',$eqid,'$login bought item #$eqid ($descr) for $price $zone points')");
      }
      else {
        print <<EOT;
        <li><font id="failed">FAILED</font> to place a claim on item id $eqid: $descr.
            You don\'t have enough points to buy this item; $price required, $points_avail avail.
EOT
      }
    }
    print <<EOT;
    </ul>

    <p>Done buying items. If an item you selected isn\'t listed above, someone else beat you to it.
       Please don\'t ask. Returning to the main menu.</p>
EOT
  }

  main_menu($dbh, $q, $view_time);
}
1;
