use CGI;
use DBI;

require "revalue_gui.pl";
require "cook.pl";

sub revalue_store {
  my ($dbh, $q, $view_time) = @_;

  my $session_info = get_session_info($dbh, $q, $view_time);
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

  # Jump through the list of items our admin selected.
  my @revalue_items = $q->param('revalue_item');
  if (!scalar(@revalue_items)) {
    print <<EOT;
    <p id="error">ERROR: No items selected! Starting over..</p>
EOT

    revalue_gui($dbh, $q, $view_time);
    return 1;
  }

  @revalue_items = map { cook_int($_) } @revalue_items;
  my $in_list = join ',', @revalue_items;

  my $sth = $dbh->prepare("select id, descr from store_eq where id in ($in_list)");
  $sth->execute;
  my $data = $sth->fetchall_arrayref;

  my $item;
  foreach $item (@$data) {
    my $eqid = $item->[0];
    my $descr = $item->[1];

    my $this_item_new_val = cook_int($q->param("revalue_item_$eqid"));

    if (!$this_item_new_val) {
      print "<p>Not doing anything with item $eqid: $descr. No new price specified.</p>"
    }
    else {
      print "<p>Revaluing item $eqid: $descr. New value $this_item_new_val<p>";
      $sth = $dbh->prepare("update store_eq set price=$this_item_new_val where id=$eqid");
      $sth->execute;
    }
  }

  # Done. Display the revalue browser again.
  revalue_gui($dbh, $q, $view_time);
}

1;
