#08/11/03 - JM - Zone popup now dynamicly displays all zones in the zones table

use CGI;
use DBI;

require "session.pl";
require "points.pl";

sub browser_gui {
  my ($dbh, $q, $view_time) = @_;

  my $session_info = get_session_info($dbh, $q, $view_time);

  my $sth = $dbh->prepare("select id, name from zones order by name");
  $sth->execute;
  my $zones = $sth->fetchall_arrayref;

  print <<EOT;
    <hr>
    <h3>Search the equipment database</h3>
    <form name=grep method=post action=/fate-cgi/ups.pl>
    $session_info
    <input type="hidden" name="action" value="browse">

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
	      <option>fing
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

          <tr>
            <td>
              Zone
            </td>
            <td>
              <select name="zone" align="left">
                <option selected>any
EOT
                foreach(@$zones) {
                  my ($id, $name) = @$_;
                  print <<EOT;
                  <option>$name
EOT
                }
              print <<EOT;
              </select>
            </td>
          </tr>
          <tr>
            <td><input type="checkbox" name="afford_item" value="true"></td>
            <td>Only items you can afford (TESTING)</td>
          </tr>
      </table>


	<input type="submit" value="Search">
      </form>
EOT
}
