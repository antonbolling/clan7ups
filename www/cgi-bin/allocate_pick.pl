#08/24/03 - JM - Changed some prepare/execute statements to $dbh->do() for speed
#08/25/03 - JM - Point allocations are now logged

use CGI;
use DBI;

use strict;
use warnings;

require "cook.pl";
require "main_menu.pl";
require "session.pl";
require "auction_timing.pl";
require "ups_util.pl";
require "allocate_pick_gui.pl";
require "points.pl";

sub allocate_pick {
  my ($dbh, $q, $view_time) = @_;
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  $sth = $dbh->prepare("select zone,points from user_points_$login");
  $sth->execute;
  my $num_zones = $sth->rows;
  my $data = $sth->fetchall_arrayref;

  if (!$num_zones) {
    print <<EOT;
    <p>ERROR: You have no points. wth? This should not happen.</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }

  my $eqid = cook_int($q->param('eqid'));
  if (!$eqid) {
    print <<EOT;
    <p>ERROR: No item associated with this allocate. ??</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }

  # Check that this item is pickable and $uid has current maxbid
  my $pickable = auction_pickable($dbh, $eqid);
  $sth = $dbh->prepare("select bidder from bid_eq where id=$eqid");
  $sth->execute;
  my $item_exists = $sth->rows;
  my ($bidder) = $sth->fetchrow_array;

  if (!$item_exists) {
    print <<EOT;
    <p>ERROR: Something is wrong; the item does not exist. Contact an admin. </p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }

  if ((!$bidder) or ($bidder ne $login)) {
    print <<EOT;
    <p>ERROR: You do not hold the standing bid on this item. Something is wrong; contact an admin.</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }

  if (!$pickable) {
    print <<EOT;
    <p>ERROR: This item is not yet pickable. Something is wrong; contact an admin.</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }

  # Get information about this item.
  $sth = $dbh->prepare("select bid, descr, zone from bid_eq where id=$eqid");
  $sth->execute;
  my ($bid, $descr, $zone) = $sth->fetchrow_array;
  $sth = $dbh->prepare("select percent from zones where name='$zone'");
  $sth->execute;
  my ($percent) = $sth->fetchrow_array;

  my $min_alloc = ($percent / 100) * $bid;
  my $int_min_alloc = int ($min_alloc);
  $int_min_alloc++ if $int_min_alloc < $min_alloc;
  $min_alloc = $int_min_alloc;

  my $remaining_alloc = $bid - $min_alloc;

  my $item_zone_points = get_zone_points_from_username($dbh, $login, $zone);
	if ($item_zone_points < $min_alloc) {
			print <<EOT;
    <p>ERROR: You do not have enough $zone points to pick this item right now. You have $item_zone_points $zone points available. You need $min_alloc. Try again when you have more $zone points.</p>
EOT
    main_menu($dbh, $q, $view_time);
    return 1;
	}

  print <<EOT;
  <p>Trying to allocate for item: $descr.</p>
  <p>First we will deduct the required $min_alloc from $zone.</p>
  <p>You need another $remaining_alloc points from other zones.</p>
  <ul>
EOT

  my $item;
  my $sum = 0;
  my %total_alloc;

  foreach $item (@$data) {
    my ($zone_name, $points) = @$item;
    my $avail = zone_highest_alloc($dbh, $login, $zone_name);

    # Check if this zone is in param.
    my $this_zone_alloc = cook_int($q->param($zone_name));
    $this_zone_alloc = 0 if !$this_zone_alloc;
    $this_zone_alloc = 0 if $this_zone_alloc < 0;

    if ($this_zone_alloc) {
      print "<li>$zone_name: $this_zone_alloc";
      $total_alloc{$zone_name} = $this_zone_alloc;

      if ($this_zone_alloc > $avail) {
        print <<EOT;
        </ul>
        <p>ERROR: You only have $avail available $zone_name points, but you told us to use $this_zone_alloc.
           starting over.
EOT
        allocate_pick_gui($dbh, $q, $view_time);
        return 1;
      }

      $sum += $this_zone_alloc;
    }
  }

  print "</ul>\n";

  if ($sum != $remaining_alloc) {
    print <<EOT;
    <p>ERROR: You need to give us another $remaining_alloc points, but you gave us $sum.
       YOU MUST BE EXACT. Starting over.</p>
EOT
    allocate_pick_gui($dbh, $q, $view_time);
    return 1;
  }

  # If we get here, the allocate is valid.
  print <<EOT;
  <p> SUCCESS. Deducting points, moving this item to the picklist. Returning to main. </p>
EOT

  $dbh->do("update user_points_$login set points=points-$min_alloc where zone='$zone'");

  $dbh->do("insert into log (user,action,cdata1,idata1,bigdata) values($uid,'allocate','$login',$eqid,'$login automaticly allocated $min_alloc $zone points for item #$eqid')");

  foreach $item (sort keys %total_alloc) {
    my $this_zone_alloc = $total_alloc{$item};

    $dbh->do("update user_points_$login set points=points-$this_zone_alloc where zone='$item'");

    $dbh->do("insert into log (user,action,cdata1,idata1,bigdata) values($uid,'allocate','$login',$eqid,'$login allocated $this_zone_alloc $item points for item #$eqid')");
  }

  #Clean up user points table:
  $dbh->do("delete from user_points_$login where points=0");

  #Move the item to outgoing:
  $descr = cook_string($descr);
  $dbh->do("update bid_eq set status='picked' where id=$eqid");
  $dbh->do("insert into outgoing_eq (descr,bidder) values ('$descr','$bidder')");
  #$dbh->do("delete from bid_eq where id=$eqid");

  #Return to main.
  main_menu($dbh, $q, $view_time);
}
1;
