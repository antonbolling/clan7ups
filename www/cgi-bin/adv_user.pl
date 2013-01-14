use CGI;
use DBI;

use warnings;
use strict;

require "adv_user_gui.pl";
require "cook.pl";

sub adv_user {
  my ($dbh, $q, $view_time) = @_;

  my $option = cook_word($q->param('option'));
  if ($option eq 'del_user') {
    delete_user($dbh, $q, $view_time);
  } else {
    my $username = lc cook_word($q->param('user'));
  
    #Check if the user exists
    my $sth = $dbh->prepare("select id from users where name='$username'");
    $sth->execute;

    if (!$sth->rows) {
      #user is not an account, check if it is an alias
      #printf "<p>select name from users where aliases like '%$username %'</p>";
      my $tsta = $dbh->prepare("select name from users where aliases like '%$username %'");
      $tsta->execute;
      if (!$tsta->rows) {
        #User doesn't exist, add them with null password
        require "user.pl";
        add_user($dbh, $q, 0, $username);
    
        print "$username did not exist in database, created with null password\n";
      } else {
        #username is an alias
        my $tmpName = $tsta->fetchrow_array;
        print "$username is an alias for $tmpName, cannot add or edit account\n";
        adv_user_gui($dbh, $q, $view_time);
      
        return 1;
      }

      $tsta->finish;

    }

    if ($option eq 'mod_info') {
      #Modify user information, such as password and access
      user_info_gui($dbh, $q, $view_time);
    } elsif ($option eq 'mod_pts') {
      #Transfer points
      mod_pts_gui($dbh, $q, $view_time);
    }
  }
  return 1;
}

sub delete_user {
  my ($dbh, $q, $view_time) = @_;
  
  my $username = cook_word($q->param('user'));
  #print "<p>got user $username</p>";
  
  #Check if this user exists
  my $sth = $dbh->prepare("select * from users where name='$username'");
  $sth->execute;
  if ($sth->rows) {
    #print "<p>$username exists</p>";
    
    my $uid = cook_int($q->param('uid'));
    $sth = $dbh->prepare("select name from users where id=$uid");
    $sth->execute;
    my $admin = $sth->fetchrow_array;
    
    #print "<p>Admin: $admin   UID: $uid</p>";
    
    $dbh->do("delete from users where name='$username'");
    $dbh->do("drop table user_points_$username");
    
    $dbh->do("insert into log (user,action,bigdata) values($uid,'account','$admin deleted account 
for $username')");
    
  } else {
    print "<p>User $username does not exist in the database</p>";
  }
  $sth->finish;
  adv_user_gui($dbh, $q, $view_time);
  
  return 1;
}

sub adv_change_access {
  my ($dbh, $q, $view_time) = @_;

  my $access = cook_word($q->param('accesslvl'));
  my $username = cook_word($q->param('user'));
  my $userid = cook_int($q->param('userid'));
  my $uid = cook_int($q->param('uid'));

  #Make sure that you don't end up setting yourself to gatekeeper or user
  #and screwing up the system
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;

  my $admin = $sth->fetchrow_array;
  if ($username eq $admin) {
    print "<p>You cannot change your own account type!</p>\n";
  } else {

    $dbh->do("update users set access='$access' where id=$userid");

    print "<p>Changed access level for user $username to $access</p>\n";
    $dbh->do("insert into log (user,action,bigdata) values($uid,'account','$admin changed access 
for $username to $access')");
  }
  
  $sth->finish;
  adv_user_gui($dbh, $q, $view_time);
}

sub adv_change_password {
  my ($dbh, $q, $view_time) = @_;

  my $username = cook_word($q->param('user'));
  my $newpass1 = cook_word($q->param('newpass1'));
  my $newpass2 = cook_word($q->param('newpass2'));
  my $uid = cook_int($q->param('uid'));
  
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  
  my $admin = $sth->fetchrow_array;
  
  #print "<p>UID: $uid    Admin: $admin</p>";

  $sth = $dbh->prepare("select id from users where name='$username'");
  $sth->execute;
  my $userid = $sth->fetchrow_array;

  #Dont allow passwords for administrators to be changed
  $sth = $dbh->prepare("select access from users where id=$userid");
  $sth->execute;
  
  my $access = $sth->fetchrow_array;
  if ($access ne 'admin') {

    if ($newpass1 eq $newpass2) {
      print "<p>new password fields match. updating password for user $username...</p>\n";
      $dbh->do("update users set pass=PASSWORD('$newpass1') where id=$userid");
    
      $dbh->do("insert into log (user,action,bigdata) values($uid,'account','$admin changed 
password for $username')");
    } else {
      #Passwords don't match.
      print "<p>Password fields don't match! Please try again. </p>\n";
    }
  }
  
  $sth->finish;

  adv_user_gui($dbh, $q, $view_time);
}

sub adv_xfer_pts {
  my ($dbh, $q, $view_time) = @_;
  
  #adv_user_gui($dbh, $q, $view_time);
  
  my $username = cook_word($q->param('user'));
  #print "<p>Got Username: $username</p>";
  
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($admin) = $sth->fetchrow_array;
  #print "<p>Got Admin: $admin</p>";
  
  $sth = $dbh->prepare("select zone,points from user_points_$username order by zone");
  $sth->execute;
  
  if ($sth->rows) {
    my $user_zone_data = $sth->fetchall_arrayref;
    
    my $entry;
    my $zone_name;
    my $zone_xfer;
    my $zone_mod;
    my $current_points;
    
    my @params = $q->param;
    #print "@params";
    
    #shift past uid, magic, username and action
    my $temp = shift @params;
    $temp = shift @params;
    $temp = shift @params;
    $temp = shift @params;
    
    my $action = cook_word($q->param('action'));
    
    while ($entry = shift @$user_zone_data) {
      #3 parameters per zone... xfer_zonename, add_zonename, subtract_zonename
      $zone_name = $entry->[0];
      $current_points = $entry->[1];
      
      $zone_xfer = cook_word($q->param(shift @params));
      $zone_mod = $q->param(shift @params);
      
      #First, add or subtract points to/from the current player for this zone
      if ($zone_mod != 0) {
        #Check if $current_points - $zone_mod is negative, if so, set to zero
        $current_points += $zone_mod;
        if ($current_points < 0) {
          $current_points = 0;
        }
      
        $dbh->do("update user_points_$username set points=$current_points where 
zone='$zone_name'");
      
        #Log this
        $dbh->do("insert into log (user,action,bigdata) values($uid,'admin','$admin added 
$zone_mod $zone_name points to $username')");
        #print "<p>$admin added $zone_mod $zone_name points to $username</p>";
      }
      
      #transfer $current_points to $zone_xfer
      if ($zone_xfer) {
        #print "Transferring points to $zone_xfer<br>";
      
        $sth = $dbh->prepare("select * from user_points_$zone_xfer where zone='$zone_name'");
        $sth->execute;
        if (!$sth->rows) {
          #The zone doesn't exist for this player, create it
          $dbh->do("insert into user_points_$zone_xfer values ('$zone_name',$current_points)");
        } else {
          #Zone already exists
          $dbh->do("update user_points_$zone_xfer set points=points+$current_points where 
zone='$zone_name'");
        }
      
        #Remove points from $username
        #$dbh->do("update user_points_$username set points=0 where zone='$zone_name'");
        $dbh->do("delete from user_points_$username where zone='$zone_name'");
      
        $dbh->do("insert into log (user,action,bigdata) values($uid,'admin','$admin transferred 
$current_points $zone_name points from $username to $zone_xfer')");
        #print "<p>$admin transferred $current_points $zone_name points from $username to $zone_xfer</p>";
      }
    }
    
    mod_pts_gui($dbh, $q, $view_time);
  } else {
    print "No zone data for $username!";
  }
  
  $sth->finish;
}

1;
