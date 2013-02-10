use warnings;
use strict;

use CGI;
use DBI;

require "user.pl";
require "cook.pl";
require "session.pl";
require "ups_util.pl";

# Config keys in database
my $ENABLE_BIDDING_KEY = 'enable_bidding';

sub config_enable_bidding {
		my ($dbh) = @_;
		return get_config_value($dbh,$ENABLE_BIDDING_KEY) eq '1';
}

sub ups_config_gui {
		my ($dbh, $q, $view_time) = @_;
		my $user_id = $q->param('uid');
		my $user_name = get_user_name_by_id($dbh,$user_id);
		my $user_access_level = get_access($dbh, $q, $view_time);
		my $session_info = get_session_info($dbh, $q, $view_time);

		if (!($user_access_level eq 'admin')) {
				print STDERR "$user_name with id $user_id attempted unauthorized access of ups config gui";
				print "<h3>You're not authorized to configure ups.</h3>";
				return 1;
		}

		print "<h3>UPS Config</h3>";

		# This will be 1 if user was already on ups_config_gui and clicked 'Save Config'
		if (cook_int($q->param('saved_config'))) {
				print "<span style='color:green;'><i>Saved Changes</i></span>";
		}

		my $enable_bidding_checked_html = config_enable_bidding($dbh) ? "checked" : "";

		print <<EOT;
		<form method=post action="/cgi-bin/ups.pl">
		$session_info
		<input type="hidden" name="action" value="set_ups_config">
		<input type="hidden" name="saved_config" value="1">
		<input type="checkbox" name="enable_bidding" $enable_bidding_checked_html> Enable Bidding<br>
		<input type="submit" value="Save Changes">
    </form>
EOT
    return_main2($session_info,"Return to main without saving");
}

sub set_ups_config {
		my ($dbh, $q, $view_time) = @_;
		my $user_id = $q->param('uid');
		my $user_name = get_user_name_by_id($dbh,$user_id);
		my $user_access_level = get_access($dbh, $q, $view_time);
		my $session_info = get_session_info($dbh, $q, $view_time);

		if (!($user_access_level eq 'admin')) {
				print STDERR "$user_name with id $user_id attempted unauthorized access of set ups config";
				print "<h3>You're not authorized to configure ups.</h3>";
				return 1;
		}

		my $enable_bidding_value = $q->param('enable_bidding') eq 'on' ? 1 : 0;
		set_config_key_value_pair($dbh, $ENABLE_BIDDING_KEY, $enable_bidding_value);

		ups_config_gui($dbh,$q,$view_time);
}

# Return a config value for the passed config key
sub get_config_value {
		my ($dbh, $config_key) = @_;

		my $config_sql = $dbh->prepare("select config_value from config where config_key = ?");
		$config_sql->execute($config_key);
		
		my ($config_value) = $config_sql->fetchrow_array;

		return $config_value;
}

sub set_config_key_value_pair {
		my ($dbh, $config_key, $config_value) = @_;

		# Only one of insert/update will succeed. A concise if redundant method of create-unless-exists
		my $update_config_sql = $dbh->prepare("update config set config_value = ? where config_key = ?");
		my $insert_config_sql = $dbh->prepare("insert into config (config_value,config_key) values (?,?)");
		
		# Note swapping of key/value order to folllow update syntax
		$update_config_sql->execute($config_value,$config_key);
		$insert_config_sql->execute($config_value,$config_key);
}

1;
