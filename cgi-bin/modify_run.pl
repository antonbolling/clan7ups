#08/10/03 - JM - Added missing execute where the system was supposed to remove
#                the leader from his own run.  This fixes a bug where it was possible
#                to re-add yourself to your own run and gain extra points.
#08/24/03 - JM - Changed some prepare/execute statements to $dbh->do() for speed
#                All actions in modify_run are now logged
#11/10/03 - JM - All eq now sent to bid, regardless of selection on
#                Modify Run panel

use warnings;
use strict;

use CGI;
use DBI;

require "session.pl";
require "main_menu.pl";
require "ups_util.pl";
require "cook.pl";

sub modify_run {
  my ($dbh, $q, $view_time) = @_;

  # NON gui portion of modify_run, takes cgi input from modify_run_gui, then modifies the run
  # accordingly and jumps back to modify_run_gui.
  my $uid = cook_int($q->param('uid'));
  my $runid = cook_int($q->param('runid'));
  my $cgi_view_time = cook_int($q->param('view_time'));

  my $access = get_access($dbh, $q, $view_time);

  my $action = cook_word($q->param('action'));
  print "<p> action param: $action </p>";

  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my $admin = $sth->fetchrow_array;

  #Delete run, if that was the command. Go back to main.
  if ($action eq 'delete_run') {
    print "Deleting run!\n";
    #Check owner:
    $sth = $dbh->prepare("select leader from runs where id=$runid");
    $sth->execute;
    my ($leaderuid) = $sth->fetchrow_array;

    if ($access eq 'admin' or $uid == $leaderuid) {
      #$dbh->do("delete from incoming_eq where run_id=$runid");

      #Set status to deleted
      $dbh->do("update runs set status='deleted' where id=$runid");

      #Don't remove run from runs table, or drop the run points table
      #$dbh->do("delete from runs where id=$runid");
      #$dbh->do("drop table run_points_$runid");

      #Log this action
      $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,'$admin deleted run #$runid')");
    } else {
      no_access($dbh, $q, $view_time);
    }

    main_menu($dbh, $q, $view_time);
    return 0;
  }

  $sth = $dbh->prepare("select zone,day,leader,UNIX_TIMESTAMP(mod_stamp) from runs where id=$runid");
  $sth->execute;
  my ($zone_name, $day, $leader, $mod_stamp) = $sth->fetchrow_array;

  print "<p> Viewed on $cgi_view_time, last modified on $mod_stamp.";
  if ( $cgi_view_time >= $mod_stamp ) {
    print " OK to edit.</p>";
  } else {
    print " NOT OK to edit.</p>";
    print <<EOT;
    <p> It looks like someone modified this run since you last viewed it. Cannot continue; returning
      to the main menu. </p>
EOT

    require "main_menu.pl";
    main_menu($dbh, $q, $view_time);
    return 0;
  }

  # Setting last_mod_time:
  $dbh->do("update runs set mod_stamp=FROM_UNIXTIME($view_time) where id=$runid");

  # Run has been modified. Update status to pending.
  $dbh->do("update runs set status='pending' where id=$runid");

  my $gate_access = 0;

  #By default users can't set eq values; allow gatekeeper and above to do so.
  if ($access eq 'gate' or $access eq 'admin') {
    $gate_access=1;
  }

  #Check access. Must have admin or gatekeeper access, or be submitter to modify.
  if ((!$gate_access) and ($uid != $leader)) {
    no_access($dbh, $q, $view_time);
    return 1;
  }

  #Set run type.
  my $type = cook_word($q->param('run_type'));
  $sth = $dbh->prepare("select type from runs where id=$runid");
  $sth->execute;
  my $curr_type = $sth->fetchrow_array;
  
  if ($curr_type ne $type) {
    #  print "<p> Updating run_type: $type </p>\n";
    $dbh->do("update runs set type='$type' where id=$runid");
    
    #Log this
    $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,'$admin changed run type from $curr_type to $type for run #$runid')");
  }

  # Take cgi parameters 1 at a time, proccess them and update the database appropriately.
  # 1) Modify userlist.
  # a) Delete users in 'delete_runner'.
  my @delete_runners = $q->param('delete_runner');

  if (scalar(@delete_runners)) {
    @delete_runners = map { cook_word($_) } @delete_runners;
    my @quoted_delete_runners = map { "'$_'" } @delete_runners;
    my $delete_runner_string = join ',', @quoted_delete_runners;

    print "<p>Deleting runnerlist: $delete_runner_string</p>\n";

    $dbh->do("delete from run_points_$runid where runner in ($delete_runner_string)");

    #must remove the ''s from the string so we can safely add it to the log
    my $tmpstring = cook_string2($delete_runner_string);
    
    #Log this
    $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,'$admin deleted $tmpstring from run #$runid')");

    #my $num_deleted = $sth->rows;
    #print "<p>Database reports $num_deleted runners deleted</p>\n";
  }

  # ADD RUNNERS
  # a) What is default point award for this zone?
  $sth = $dbh->prepare("select points from zone_points_$zone_name where id=$day");
  $sth->execute;
  my ($default_point_award) = $sth->fetchrow_array;

  print "<p> Default point award: $default_point_award </p>\n";
  # b) Add runners in 'runners', set to current default points.
  my $runners = cook_string($q->param('runners'));
  my @runlist = $runners =~ /(\w+)/g;
  @runlist = map { lc $_ } @runlist;

  foreach (@runlist) {
    my $runner = cook_word($_);
    print "<p>Adding runner $runner to database</p>\n";
    $dbh->do("insert into run_points_$runid values ('$runner',$default_point_award)");
    #Log this
    $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,'$admin added $runner to run $runid with $default_point_award points')");
  }

  printf "<p>Done adding runners</p>\n";

  #Any 'points_$runner' left with entry for $runner in db gets installed in
  #run_point_data.
  $sth = $dbh->prepare("select runner from run_points_$runid");
  $sth->execute;

  if ($sth->rows) {
    my $sta;
    while (my ($runner) = $sth->fetchrow_array) {
      print "Checking $runner<br>";
      my $point_control = cook_int($q->param("points_$runner"));
      if ($point_control) {
        # We have input for this user.
        #Only update point values if the new value is different from the current pts
        #that the user has on this run

        #print "select points from run_points_$runid where runner='$runner'<br";
        $sta = $dbh->prepare("select points from run_points_$runid where runner='$runner'");
        $sta->execute;
        my $current_pts = $sta->fetchrow_array;

        if ($point_control != $current_pts) {
          $dbh->do("update run_points_$runid set points=$point_control where runner='$runner'");
          print " Updating point value for $runner: $point_control<br>";
          $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,'$admin changed points for $runner to $point_control (from $current_pts) on run #$runid')");
        }
      } else {
        print " Not modifying points for $runner<br>";
      }
    }

    print "Finished checking runners<br>";
    $sta->finish;
  }

  #BUG, if anyone has zero points for this run it wont get past the above code


  print "<p>Removing leader from point list</p>";

  # Remove leader from pointdata. He has special code.
  $sth = $dbh->prepare("select name from users where id=$leader");
  $sth->execute;
  my ($leader_name) = $sth->fetchrow_array;

  $dbh->do("delete from run_points_$runid where runner='$leader_name'");

  printf "<p>Deleting selected items</p>";

  # Delete items in 'delete_item'
  my @delete_items = $q->param('delete_item');
  @delete_items = map { cook_int($_) } @delete_items;
  foreach (@delete_items) {
    my $item = $_;
#    print "<p>Deleting item $item</p>\n";

    $sth = $dbh->prepare("select descr from incoming_eq where run_id=$runid");
    $sth->execute;
    my $descr = $sth->fetchrow_array;

    $dbh->do("delete from incoming_eq where id=$item");
    $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,'$admin removed item #$item ($descr) from run $runid')");
  }

  # If we have gate access, update min_bid bid_type for each item with those params.
  if ($gate_access) {
    print "<p> Updating pointvalues for eq: gate_access is true. </p>";
    # Get a list of items on this run;
    $sth = $dbh->prepare("select id from incoming_eq where run_id='$runid'");
    $sth->execute;
    my $data = $sth->fetchall_arrayref;

    foreach (@$data) {
      my $record = $_;
      my $eqid = $record->[0];
#      print "<p>found eqid $eqid</p>\n";

      my $value = cook_int($q->param("value_$eqid"));
      #my $type = cook_word($q->param("type_$eqid"));
      $dbh->do("update incoming_eq set value='$value' where id=$eqid");
      $dbh->do("update incoming_eq set type='bid' where id=$eqid");

      $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,'$admin set eq #$eqid value to $value for run #$runid')");
    }
  }

  # Add items in 'eqlist'
  my $eqlist = $q->param('eqlist');
  my @eqlist = split(/\r\n/, $eqlist);

  foreach (@eqlist) {
    my $item = cook_string($_);

#    print "<p>Adding item $item</p>\n";
    $dbh->do("insert into incoming_eq (run_id,descr) values ($runid,'$item')");

    $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,'$admin added $item to run $runid')");
  }

  #Update comments.
  my $comments = cook_string($q->param('comments'));
  $sth = $dbh->prepare("select comments from runs where id=$runid");
  $sth->execute;
  my $curr_comments = $sth->fetchrow_array;
  
  #Log this if existing comments have been changed
  if ($comments ne $curr_comments) {
    if (length $comments <= 0) {
      $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,'$admin removed comments on run #$runid')");
    } else {
      $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,rt'$admin changed comments on run #$runid from $curr_comments to $comments')");
    }
  }

  $dbh->do("update runs set comments='$comments' where id=$runid");

  print "<p>Ready for jump choice</p>\n";

  # Done updating database records. jump to the next gui or action.
  # Users just get modify_run gui,
  # Admins can choose to approve and jump to mainmenu or
  # Deny and jump to mainmenu.
  if ($action eq 'modify_run') {
    require "modify_run_gui.pl";
    modify_run_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'approve_run') {
    require "approve_run.pl";
    approve_run($dbh, $q, $view_time);
  }
  elsif ($action eq 'deny_run') {
    $dbh->do("update runs set status='denied' where id=$runid");
    main_menu($dbh, $q, $view_time);
  }
}
