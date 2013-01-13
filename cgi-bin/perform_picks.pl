#08/25/03 - JM - Sent picks are now logged

use CGI;
use DBI;

require "perform_picks_gui.pl";
require "session.pl";
require "cook.pl";

sub perform_picks {
  my ($dbh, $q, $view_time) = @_;

  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($login) = $sth->fetchrow_array;

  # Check perms
  my $access = get_access($dbh, $q, $view_time);
  if ($access ne 'admin' and $access ne 'gate') {
    no_access($dbh, $q, $view_time);
    return 1;
  }

  my @item_list = $q->param('picked_list');
  if (!scalar(@item_list)) {
    # No items. error out. return to gui.
    print <<EOT;
    <p id="error">ERROR: Select some items, doofus!</p>
EOT

    perform_picks_gui($dbh, $q, $view_time);
    return 1;
  }

  #Otherwise we are fine. Cook items in @item_list remove them from
  #outgoing_eq.

  @item_list = map { print "item $_ "; cook_int($_) } @item_list;
  my $in_list = join ',', @item_list;
  my $deletions = scalar(@item_list);

  my $item;
  foreach $item (@item_list) {
    $sth = $dbh->prepare("select bidder,descr from outgoing_eq where id=$item");
    $sth->execute;
    my ($bidder,$descr) = $sth->fetchrow_array;
    
    $descr = cook_string2($descr);
      
    $dbh->do("insert into picked_eq (id,bidder,descr) values($item,'$bidder','$descr')");

    $dbh->do("insert into log (user,action,cdata1,cdata2,idata1,bigdata) values($uid,'sent_pick','$login','$bidder',$item,'$login sent item #$item ($descr) to $bidder')");
  }
  $sth->finish;

  #$dbh->do("update bid_eq set status='sent' where id=$eqid");
  $dbh->do("delete from outgoing_eq where id in ($in_list)");

  print <<EOT;
  <h4> $deletions deletions, items $in_list. Returning to picklist... </h4>
EOT

  perform_picks_gui($dbh, $q, $view_time);
}

1;
