use CGI;
use DBI;

use strict;
use warnings;

require "cook.pl";
require "main_menu.pl";
require "session.pl";
require "pickable.pl";
require "ups_util.pl";

sub allocate_pick_gui {
  my ($dbh, $q, $view_time) = @_;
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  my $session_info = get_session_info($dbh, $q, $view_time);

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
    <p>ERROR: Select an item, doofus!</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }

  # Check that this item is pickable and $uid has current maxbid
  my $pickable = bid_pickable($dbh, $q, $view_time, $eqid);
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

  print <<EOT;

  <p> Allocating for: $descr. </p>
  <p> This item is from zone $zone, which has percent $percent%. </p>
  <p> I will automatically deduct the required <b>$min_alloc</b> points from $zone. </p>
  <p> Tell me where to get the remaining <b>$remaining_alloc</b> points. </p>

  <form name="allocate_pick" method=post action="/fate-cgi/ups.pl">
  $session_info
  <input type="hidden" name="action" value="allocate_pick">
  <input type="hidden" name="eqid" value="$eqid">

  <table>
  <tr><td>Zone</td><td>Avail</td><td>Alloc</td></tr>
EOT

  my $item;
  my $count = 0;
  foreach $item (@$data) {
    my ($zone_name, $points) = @$item;
    my $avail = zone_highest_alloc($dbh, $q, $view_time, $zone_name);

    #if ($zone_name ne 'scales') {
      $count++;

      print <<EOT;

      <tr>
      <td>$zone_name</td>
      <td>$avail</td>
      <td><input type="text" name="$zone_name"></td>
EOT
    #}
  }

  # Printed input controls for each zone in user_points_*
  # close the form, submit button, etc. Additional info to the user.

  print <<EOT;
  </table>
  <input type="submit" value="allocate points / pick">
  </form>

EOT

  return_main($dbh, $q, $view_time);
}

1;
