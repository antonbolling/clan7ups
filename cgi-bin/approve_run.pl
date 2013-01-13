#08/22/03 - JM - Leaders can no longer approve their own runs, for security reasons
#08/24/03 - JM - Changed some prepare/execute statements to $dbh->do() for speed
#                Approved runs are now set as 'approved' and approval is logged
#11/11/03 - JM - Removed reference to deprecated store system
#11/22/03 - JM - Leader no longer gets bonus for a scales run

use warnings;
use strict;

use CGI;
use DBI;

require "user.pl";
require "main_menu.pl";
require "ups_util.pl";
require "cook.pl";

sub approve_run {
#  print "APPROVE_RUN.PL\n";

  my ($dbh, $q, $view_time) = @_;

  my $runid = cook_int($q->param('runid'));
  my $adminid = cook_int($q->param('uid'));
  
  # We have a runid.
  # 1) Move equipment entries into the main eq database.
  # 2) Create any users that don't exist in the main database.
  # 3) Award points to all users in points field of this run.
  # 4) Handle leader award based on run_type value.

  # 1) Move equipment entries into the main eq database.
  my $sth = $dbh->prepare("select zone,leader,type,day from runs where id=$runid");
  $sth->execute;
  my ($zone_name, $leader, $run_type, $run_day) = $sth->fetchrow_array;

  #First make sure the run leader isnt approving his own run
  #$sth = $dbh->prepare("select id from users where name=$leader");
  #$sth->execute;
  #my $leaderid = $sth->fetchrow_array;

  print "<p>Leader ID: $leader, Admin ID: $adminid</p>";

  if ($leader eq $adminid) {
    print "<p> You cannot approve your own run!</p>\n";
    return 1;
  }

  print "<p> Setting zone_name to $zone_name for this run. </p>\n";

  # Move incoming_eq_id records for this runid to bid_eq.
  # Get an eqlist for this runid.
  $sth = $dbh->prepare("select id,descr,value,type from incoming_eq where run_id=$runid");
  $sth->execute;

  # Move the records 1 at a time.
  while (my $record = $sth->fetchrow_arrayref) {

    #$incoming_eq_id is only used to delete this entry from the incoming_eq table
    my ($incoming_eq_id, $descr, $value, $type) = @$record;

    $descr = cook_string($descr);

    print <<EOT;
    <p>DEBUG: Moving item $incoming_eq_id from incoming_eq to eq.</p>
    <p>descr -> $descr, value -> $value, type -> $type, zone -> $zone_name</p>
EOT

##########################################################

    #A new id number is assigned to this eq when it is moved
    #so now i just store the run_id along with each eq entry as well
    $dbh->do("insert into bid_eq (zone,run_id,descr,status,min_bid,add_time) values ('$zone_name',$runid,'$descr','added',$value,now())");

    #Remove from incoming_id table
    $dbh->do("delete from incoming_eq where id=$incoming_eq_id");

##########################################################

  }

  #Get a list of runners for this run.
  $sth = $dbh->prepare("select runner from run_points_$runid");
  $sth->execute;

  while (my ($runner) = $sth->fetchrow_array) {
    print "<p>Checking user table for runner $runner</p>";
    my $tempsth = $dbh->prepare("select id from users where name='$runner'");
    $tempsth->execute;

    my $found_runner = $tempsth->rows;
    $tempsth->finish;
    if (!$found_runner) {
      #check if it is an alias
      my $tmpsth = $dbh->prepare("select name from users where aliases like '%$runner %'");
      $tmpsth->execute;
      if ($tmpsth->rows) {
        my $real_name = $tmpsth->fetchrow_array;
        print "<p>$runner is an alias for $real_name, replacing... ";
        $dbh->do("update run_points_$runid set runner='$real_name' where runner='$runner'");
        $runner = $real_name;
        print "Done<p>";
      } else {
        print "<p>$runner doesn't exist, creating.</p>";
        add_user($dbh, $q, $view_time, $runner);
      }
      $tmpsth->finish;
    }

    #Check this user's point data for an entry for this zone.
    $tempsth = $dbh->prepare("select points from user_points_$runner where zone='$zone_name'");
    $tempsth->execute;
    my $entry_exists = $tempsth->rows;

    #If it doesn't exist, create.
    if (!$entry_exists) {
      printf "<p>Creating $zone_name entry for $runner</p>";
      $dbh->do("insert into user_points_$runner values ('$zone_name',0)");
    }

    #Add this user's point award.
    $tempsth = $dbh->prepare("select points from run_points_$runid where runner='$runner'");
    $tempsth->execute;
    my ($award) = $tempsth->fetchrow_array;

    $dbh->do("update user_points_$runner set points=points + $award where zone='$zone_name'");
  }

  #Done with runners; Decide what to do with the leader.
  $sth = $dbh->prepare("select name from users where id=$leader");
  $sth->execute;
  my ($leader_name) = $sth->fetchrow_array;

  # Figure default point award for the day we ran.
  $sth = $dbh->prepare("select points from zone_points_$zone_name where id=$run_day");
  $sth->execute;
  my ($default_leader_award) = $sth->fetchrow_array;

  my $leader_award;

  #Don't assign extra leader award if this was a scales run
  if ($zone_name ne 'scales') {
    if ($run_type eq 'self') {
      $leader_award = $default_leader_award;
    } elsif ($run_type eq 'clan') {
      $leader_award = int ($default_leader_award * 5 / 4);
    }
  } else {
    print "<p>Scales run, not awarding leader bonus</p>";
    $leader_award = $default_leader_award;
  }

print <<EOT;
  <p> Default point award for day $run_day of zone $zone_name is $default_leader_award.
      Run type is $run_type so actual leader award is $leader_award. Leader name is
      $leader_name</p>
EOT
  # Update the leader's point data.
  $sth = $dbh->prepare("select points from user_points_$leader_name where zone='$zone_name'");
  $sth->execute;
  my $entry_exists = $sth->rows;

  # If it doesn't exist, create.
  if (!$entry_exists) {
    $dbh->do("insert into user_points_$leader_name values ('$zone_name',0)");
  }

  # Add leader's point award.
  $dbh->do("update user_points_$leader_name set points = points + $leader_award where zone='$zone_name'");

  #Remove the run from runs table;
  #$dbh->do("delete from runs where id='$runid'");
  #$dbh->do("drop table run_points_$runid");

  #Set run status to approved
  $dbh->do("update runs set status='approved' where id=$runid");
  
  my $uid = cook_int($q->param('uid'));
  $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my $admin = $sth->fetchrow_array;
  
  #Log
  $dbh->do("insert into log (user,action,idata1,cdata1,bigdata) values($uid,'run',$runid,'approved','$admin APPROVED run #$runid')");

  main_menu($dbh, $q, $view_time);
}
