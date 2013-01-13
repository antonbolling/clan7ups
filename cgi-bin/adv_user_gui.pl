use DBI;

use warnings;
use strict;

require "session.pl";
require "ups_util.pl";
require "cook.pl";

sub adv_user_gui {
  my ($dbh, $q, $view_time) = @_;
  my $session_info = get_session_info($dbh, $q, $view_time);
  
  my $uid = $q->param('uid');

  print <<EOT;
  <h3>Advanced User Management</h3>
  <form method="post" name="advuser" action="/fate-cgi/ups.pl">
    $session_info
    <input type="hidden" name="action" value="adv_user">
    <table>
      <tr>
        <td>User</td>
        <td><input type="text" name="user"></td>
      </tr>
    </table>
    <select name="option">
      <option value="mod_info">Modify User Information
      <option value="mod_pts">Modify User Points
      <option value="del_user">Delete User
    </select>
    <input type="submit" value="Modify">
  </form>
EOT

  return_main($dbh, $q, $view_time);


  #print <<EOT;
  #<h3>Account Browser</h3>
  #<form method="post" name="account_browser" action="/fate-cgi/ups.pl">
  #  $session_info
  #  <input type="hidden" name="action" value="account_browser">
  #  <select name="user">
#EOT

#  my $sth = $dbh->prepare("select id,name from users order by name");
#  $sth->execute;
  
#  my $entry = $sth->fetchall_arrayref;
  
#  foreach(@$entry) {
#    my ($uid, $name) = @$_;
#    print <<EOT;
#    <option>$name
#EOT
#  }
#  print <<EOT;
#    </select>
# </form>
#EOT
}

sub user_info_gui {
  my ($dbh, $q, $view_time) = @_;
  
  #Show user selection
  adv_user_gui($dbh, $q, $view_time);

  my $username = cook_word($q->param('user'));
  
  print <<EOT;
  <h3>Modifying User Information for $username</h3>
EOT

  #Get targets uid
  my $sth = $dbh->prepare("select id from users where name='$username'");
  $sth->execute;
  my $userid = $sth->fetchrow_array;

  #Auth tokens for next session.
  my $session_info = get_session_info($dbh, $q, $view_time);

  #Get targets access level
  $sth = $dbh->prepare("select access from users where id=$userid");
  $sth->execute;
  my $access = $sth->fetchrow_array;

  print <<EOT;
  <h4>Change Access Level</h4>
  Current Access Level for $username: $access 
  <form method="post" name="changeaccess" action="/fate-cgi/ups.pl">
    <input type="hidden" name="action" value="adv_change_access">
    <input type="hidden" name="user" value=$username>
    <input type="hidden" name="userid" value=$userid>
    $session_info
    <select name="accesslvl">
      <option value="user">User
      <option value="gate">GateKeeper
      <option value="admin">Administrator
    </select>
    <p><input type="submit" value="Change Access"></p>
  </form>

  <h4>Change password</h4>
  <form method="post" name="changepass" action="/fate-cgi/ups.pl">
    <input type="hidden" name="action" value="adv_change_password">
    <input type="hidden" name="user" value=$username>
    $session_info
    <table>
      <tr>
        <td>New password</td>
        <td><input type="password" name="newpass1"></td>
      </tr>
      <tr>
        <td>Repeat</td>
        <td><input type="password" name="newpass2"></td>
      </tr>
    </table>
  <input type="submit" value="Change password">
  </form>
EOT

  #print_main_end();

  return_adv_user($dbh, $q, $view_time);
#  main_menu($dbh, $q, $view_time);
}

sub mod_pts_gui {
  my ($dbh, $q, $view_time) = @_;
  
  #Show user selection
  adv_user_gui($dbh, $q, $view_time);

  my $username = cook_word($q->param('user'));
  
  require "adv_points.pl";

  #get point data for this user.
  my $sth = $dbh->prepare("select zone,points from user_points_$username order by zone");
  $sth->execute;

  if ($sth->rows) { 
    my $user_point_data = $sth->fetchall_arrayref;
    my $num_zones = scalar (@$user_point_data);
  
    my $total_points = get_total_points_foruser($dbh, $q, $view_time, $username);
    my $total_points_inuse = get_total_points_inuse_foruser($dbh, $q, $view_time, $username);
    my $total_points_avail = $total_points - $total_points_inuse;
  
    #print_main_start();
  
    # We found point data, display it
    print <<EOT;
    <hr>
    <h3> Point data for user $username </h3>

    <p>Total points: $total_points Available points: $total_points_avail</p>
    
    <table width="40%">
    <tr id="points_odd_row">
      <td width="100%"><b>Zone</b></td>
      <td id="points_total"><b>P</b></td>
      <td id="points_avail"><b>A</b></td>
      <td id="points_maxbid"><b>M</b></td>
      <td><b>Transfer To</b></td>
      <td><b>Add/Subtract</b></td>
    </tr>   
EOT

    my $entry;
    my $second;
    my $counter = 0;
    my $style;
    
    my $session_info = get_session_info($dbh, $q, $view_time);
    
    print <<EOT;
    <form method="post" name="xfer_pts" action="/fate-cgi/ups.pl">
      $session_info
      <input type="hidden" name="user" value="$username">
      <input type="hidden" name="action" value="adv_xfer_pts">
EOT
    
    while ($entry = shift @$user_point_data) {
    
      if ($counter % 2) {
        $style = 'points_odd_row';
      } else {
        $style = 'points_even_row';
      }
    
      print "<tr id='$style'>\n";
    
      my $zone_name = $entry->[0];
      my $points = $entry->[1];
    
      my $avail = zone_highest_price_foruser($dbh, $q, $view_time, $zone_name, $username);
      my $high_bid = zone_highest_bid_foruser($dbh, $q, $view_time, $zone_name, $username);
        
      print <<EOT;
      <td>$zone_name</td>
      
      <td id='points_total'>$points</td>
      <td id='points_avail'>$avail</td>
      
      <td id='points_maxbid'>$high_bid</td>
      <td id="points_xfer">       
        <input type="text" name="xfer_$zone_name">
      </td>
      <td>
        <input type="text" name="mod_$zone_name">
      </td>
      </tr>
EOT

      $counter++;
    }
    print <<EOT;
    </table>
    <input type="submit" name="Update">
    </form>
      
    <p> 
    <font id="points_total">P: Total points for this zone</font><br>
    <font id="points_avail">A: Available points for this zone</font><br>
    <font id="points_maxbid">M: Max bid you can make on eq from this zone</font>
    </p>
EOT
  }

  return_adv_user($dbh, $q, $view_time);
}

sub return_adv_user {
  my ($dbh, $q, $view_time) = @_;
  my $session_info = get_session_info($dbh, $q, $view_time);

  print <<EOT;
  <form name=return method=post action="/fate-cgi/ups.pl">
  $session_info
  <input type="hidden" name="action" value="adv_user_gui">
  <input type="submit" value="Back">
  </form>
EOT

  return 0;
}
1;
