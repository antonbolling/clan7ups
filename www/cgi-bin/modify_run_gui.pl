#11/10/03 - JM - Removed Store option

use CGI;
use DBI;

use warnings;
use strict;

require "session.pl";
require "ups_util.pl";
require "cook.pl";

sub modify_run_gui {
  my ($dbh, $q, $view_time) = @_;
  my $runid = cook_int($q->param('runid'));

  my $session_info = get_session_info($dbh, $q, $view_time);

  my $sth = $dbh->prepare("select users.name, zone, add_stamp, day from users, runs where runs.id=$runid and users.id = runs.leader");
  $sth->execute;
  my ($run_leader, $zone_name, $runtime, $day) = $sth->fetchrow_array;

  $sth = $dbh->prepare("select status from runs where id='$runid'");
  $sth->execute;
  my ($status) = $sth->fetchrow_array;

  print <<EOT;
  <h3>Modifying run $runid, zone $zone_name day $day. Current status is <b>$status</b></h3>
  <form name=askday method=post action="/cgi-bin/ups.pl">
  $session_info
  <input type="hidden" name="view_time" value="$view_time">
  <input type="hidden" name="runid" value="$runid">
EOT

  # runtype.
  $sth = $dbh->prepare("select type from runs where id='$runid'");
  $sth->execute;
  my ($run_type) = $sth->fetchrow_array;

  # Print runtype selector.
  print "<h4>Run type</h4>\n";

  if ($run_type eq 'clan') {
    print <<EOT;
    <table>
    <tr><td><input type="radio" name="run_type" value="clan" checked></td>
      <td><p>Clan run</p></td></tr>
    <tr><td><input type="radio" name="run_type" value="self"></td>
      <td><p>Self owned</p></td></tr>
    </table>
EOT
  } elsif ($run_type eq 'self') {
#    print "<p>Testing in SELF</p>\n";
    print <<EOT;
    <table>
    <tr><td><input type="radio" name="run_type" value="clan"></td>
      <td><p>Clan run</p></td></tr>
    <tr><td><input type="radio" name="run_type" value="self" checked></td>
      <td><p>Self owned</p></td></tr>
    </table>
EOT
  }

  #Check access level.
  my $access = get_access($dbh, $q, $view_time);

  #By default users can't set eq values; allow gatekeeper and above to do so.
  #Next: list equipment items. Buttons for deleting. Space to add new items.
  $sth = $dbh->prepare("select id,descr from incoming_eq where run_id=$runid");
  $sth->execute;

  if (!$sth->rows) {
    # there is no eq with this run
    print <<EOT;
    <h4> No eq for this run </h4>
EOT
  } else {
    # There is eq with this run
    print <<EOT;
    <h4>Modify/Delete Items</h4>
    <table>
    <tr>
      <td><b>Delete</b></td>
      <td><center><b>Item Description</b></center></td>
      <td><b>Value</b></td>
EOT

    print <<EOT;
    </tr>
EOT

    while (my($incoming_eq_id, $incoming_eq_descr) = $sth->fetchrow_array) {
      print <<EOT;
      <tr>
      <td><input type="checkbox" name="delete_item" value="$incoming_eq_id"></td>
      <td>$incoming_eq_descr</td>
EOT

      if ($access eq 'admin' or $access eq 'gate') {
        #Get min_bid and bid_type for this incoming_eq id.
        my $eqsth = $dbh->prepare("select value from incoming_eq where id='$incoming_eq_id'");
        $eqsth->execute;
        my $value = $eqsth->fetchrow_array;

        print <<EOT;
        <td><input type="text" name="value_$incoming_eq_id" value="$value"></td>
EOT
      } #end if
      print "</tr>";
    } #end while
    print <<EOT;
    </table>
EOT
  }

  print <<EOT;
  <h4>Add items</h4>
  <textarea name="eqlist" rows=3 cols=120></textarea>
  <hr>
 <h4>Run leader: $run_leader (must still appear in list below to receive points)</h4>
EOT

 

  $sth = $dbh->prepare("select runner, points from run_points_$runid");
  $sth->execute;

  if (!$sth->rows) {
    # No runners;

    print <<EOT;
    <h4>No runners found</h4>
EOT
  } else {
    #Found runners
    print <<EOT;
    <h4>Modify runner awards / Delete runners</h4>
    <table>
      <tr>
        <td><b>DELETE</b></td>
        <td><b>Point award</b></td>
        <td><b>Player</b></td>
        <td><b>Exists?</b></td>
      </tr>
EOT

    while (my $data = $sth->fetchrow_arrayref) {
      my ($runner, $award) = @$data;

      #Does runner exist?
      my $usth = $dbh->prepare("select id from users where name='$runner'");
      $usth->execute;

      my $exists;

      if ($usth->rows()) {
        #runner exists in database.
        $exists = "<td><font color=green>exists</font></td>";
      } else {
        #runner not in db, check if it is an alias
        #print "<p>select name from users where aliases like '%$runner %'</p>";        
        my $tsta = $dbh->prepare("select name from users where aliases like '%$runner %'");
        $tsta->execute;
        if (!$tsta->rows) {
          $exists = "<td><font color=red>DOESN'T EXIST</font></td>";
        } else {
          my ($tmpName) = $tsta->fetchrow_array;
          $exists = "<td><font color=blue>Alias for $tmpName</font></td>";
        }
        $tsta->finish;
      }

      print <<EOT;
      <tr>
      <td><input type="checkbox" name="delete_runner" value="$runner"></td>
      <td><input type="text" name="points_$runner" value="$award"></td>
      <td>$runner</td>
      $exists
      </tr>
EOT
    }

    print <<EOT;
    </table>
EOT
  }

  print <<EOT;
  <h4> Add runners </h4>
  <textarea name="runners" rows=5 cols=80></textarea>
  <hr>
EOT

  # Comments
  $sth = $dbh->prepare("select comments from runs where id=$runid");
  $sth->execute;
  my ($comments) = $sth->fetchrow_array;

  print <<EOT;
  <h4> Comments </h4>
  <textarea rows=5 cols=80 name="comments">$comments</textarea>
EOT

  print <<EOT;
    <h4> Next action </h4>
    <p><select name="action">
    <option value="modify_run" selected>Save changes
EOT

  if ($access eq 'gate' or $access eq 'admin') {
    print <<EOT;
    <option value="deny_run">Save changes, flag as denied
    <option value="approve_run">Save changes, approve
EOT
  }

  print <<EOT;
  <option value="delete_run">Delete this run
  </select></p>
EOT

  print <<EOT;
  <br>
  <input type="submit" value="Submit">
  </form>
EOT

  return_main($dbh, $q, $view_time);

  print <<EOT;
  <h3>Using this dialog: first time users must read</h3>
  <p> This dialog performs 2 different functions: it allows runners to modify th
e info for runs they
      submit, as well as allowing gatekeepers to review/modify run info before a
pproving point
      rewards and moving eq entries to the main database. This dialog displays m
any options, some
      of which interact in non obvious ways. </p>
  <h4>Information for users</h3>
  <p> You should find yourself at this dialog right after submitting a run from 
the 'submit a run'
      dialog off the main menu. At this point, if the zone is a multi-day zone, 
the very first thing
      you should do is choose which day you ran and hit submit. </p>
  <p> Changing which day you ran automatically resets all runners' pointvalues a
fter you submit.
      This is why you always do it first. If you change the day again all runner
 point rewards will
      reset to the new day's default, regardless of what you had input. </p>
  <p> Next, remember that clicking 'return to main' will NOT save the changes yo
u made to this run.
      ALWAYS click submit when you're done modifying your run, THEN return to ma
in IF all information
      is correct. </p>
  <h4>Information for gatekeepers and admins</h4>
  <p> If you are a gatekeeper or admin you will have access to the advanced feat
ures here; you'll see
      value and system options for each piece of eq submitted with a run. Make s
ure these are set properly
      before clicking on approve. Note that rejecting a run won't save changes; 
if you want to 
      communicate reasons to the leader change the comments field, submit with a
ction set to modify,
      then select reject and submit. </p>
  <p> For now just live with these peculiarities. We'll make it more foolproof l
ater. </p>
EOT
}
1;


