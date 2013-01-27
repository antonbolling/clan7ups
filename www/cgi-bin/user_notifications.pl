use CGI;
use DBI;

use warnings;
use strict;

require "user.pl";

sub create_notification_by_user_name {
		my ($dbh, $user_name, $notification) = @_;
		my $user_id = get_user_id_by_name($dbh, $user_name);
		create_notification_by_user_id($dbh,$user_id,$notification);
}

# BY CONVENTION, ALL $notifications MUST be a string containing a html form omitting a trailing </form> tag. main_menu.pl will append the </form> tag with the proper session_info
sub create_notification_by_user_id {
		my ($dbh, $user_id, $notification) = @_;
		my $create_notification_sql = $dbh->prepare("insert into user_notifications (user_id,notification) values (?,?)");
		$create_notification_sql->execute($user_id,$notification);
}

sub clear_notifications_by_user_id {
		my ($dbh, $user_id) = @_;
		my $clear_notifications_sql = $dbh->prepare("delete from user_notifications where user_id = ?");
		$clear_notifications_sql->execute($user_id);
}
