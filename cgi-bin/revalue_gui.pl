use CGI;
use DBI;

require "session.pl";
require "ups_util.pl";

sub revalue_gui {
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

  print <<EOT;
    <h3>Grep for items to change:</h3>
    <form name=grep method=post action=/cgi-bin/ups.pl>
    $session_info
    <input type="hidden" name="action" value="revalue_grep">

        <table>
	  <tr>
	    <td>Keywords</td>
	    <td><input type="text" name="keywords"></td>
	  </tr>

	  <tr>
	    <td>
	      Location
	    </td>

	    <td>
	      <select name="loc" align="left">
	      <option selected>any
	      <option>about
	      <option>arms
	      <option>body
	      <option>feet
	      <option>finger
	      <option>hands
	      <option>head
	      <option>hold
	      <option>legs
	      <option>light
	      <option>neck
	      <option>shield
	      <option>waist
	      <option>wield
	      <option>wrist
	      </select>
	    </td>
	  </tr>

	  <tr>
	    <td>
	      Usable by Class
	    </td>
	    
	    <td>
	      <select name="class" align="left">
		<option selected>any
		<option value="C">cleric
		<option value="M">mage
		<option value="T">thief
		<option value="W">warrior
	      </select>
	    </td>
	  </tr>
	  
	  <tr>
	    <td>
	      Usable by Align
	    </td>
	    
	    <td>	
	      <select name="align" align="left">
		<option selected>any
		<option value="G">good
		<option value="N">neutral
		<option value="E">evil
	      </select>
	    </td>
	  </tr>
	</table>
	  
	<input type="submit" value="Search">
      </form>
EOT

  return_main($dbh, $q, $view_time);
}
