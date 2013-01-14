use warnings;
use strict;

use CGI;
use DBI;

require "main_menu.pl";
require "cook.pl";
require "pickable.pl";

sub pick_store {
  my ($dbh, $q, $view_time) = @_;

  # Get login.
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  # Pick all items in store_eq that have current buyer $login, and are store_pickable.
  $sth = $dbh->prepare("select id from store_eq where buyer='$login'");
  $sth->execute;
  my $claimed_items = $sth->rows;

  if (!$claimed_items) {
    print <<EOT;
    <p>You have no active claims in the store system.
       If you are seeing this you have found a bug; please inform an admin.</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }

  my $data = $sth->fetchall_arrayref;
  my @all_claims = map { $_->[0] } @$data;
  my @pickable_claims = grep { store_pickable($dbh, $q, $view_time, $_) } @all_claims;
  my $in_list = join ',', @pickable_claims;
  my $num_picks = scalar(@pickable_claims);

  if ($num_picks) {
    print <<EOT;
    <p> $num_picks items to pick from the store system.. itemlist: $in_list</p>
EOT

    # Ok now actually do picks. Move items in $in_list to outgoing_eq.
    $sth = $dbh->prepare("select id, zone, descr, price, buyer from store_eq where id in ($in_list)");
    $sth->execute;
    $data = $sth->fetchall_arrayref;

    print <<EOT;
    <ul>
EOT

    my $item;
    foreach $item (@$data) {
      my $eqid = $item->[0];
      my $zone = $item->[1];
      my $descr = $item->[2];
      my $price = $item->[3];
      my $bidder = $item->[4];

      #re-escape quotes in descr.
      $descr = cook_string($descr);

      #Put this item in outgoing:
      $dbh->do("insert into outgoing_eq (descr,bidder) values ('$descr', '$bidder')");

      #Subtract points from the user:
      $dbh->do("update user_points_$bidder set points = points - $price where zone = '$zone'");

      #Print something.
      print <<EOT;
      <li> Picking item $eqid, $descr. Subtracting $price $zone points from $bidder.
EOT
    }

    print <<EOT;
    </ul>
EOT

    # drop items.
    $dbh->do("delete from store_eq where id in ($in_list)");

    main_menu($dbh, $q, $view_time);
    return 1;

  }
  else {
    print <<EOT;
    <p>You have no store system items waiting to be picked.
       If you are seeing this you have found a bug; please inform an admin.</p>
EOT

    main_menu($dbh, $q, $view_time);
    return 1;
  }
}

1;
