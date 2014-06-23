use warnings;
use strict;

use CGI;
use DBI;

require "ups_config.pl";
require "time_string.pl";
require "user_notifications.pl";
require "free_points.pl"; # not a dependency for deteriorate_points, just used here as a convenient hook for free points

# Go through the database and deteriorate points for all users, based on the
# deterioration rates in config and time of last det.
sub deteriorate_points {
		my ($dbh) = @_;

		my $sth = $dbh->prepare("select unix_timestamp(now())");
		$sth->execute;
		my ($now_timestamp) = $sth->fetchrow_array;

		my $det_halflife_days = config_points_deteriorate_halflife($dbh);
		my $det_frequency_minutes = config_points_deteriorate_frequency($dbh);
		my $last_det_timestamp = last_det_timestamp($dbh);
		my $det_rate_for_period = det_rate_for_period($det_halflife_days, $det_frequency_minutes);
		my $periods_since_last_det = periods_since_last_det($now_timestamp, $last_det_timestamp, $det_frequency_minutes);

		my $last_timestamp_string = time_string($now_timestamp - $last_det_timestamp);

		print STDERR "points det halflife_days: $det_halflife_days , freq_minutes: $det_frequency_minutes, det_rate_for_period: $det_rate_for_period , lastdet: $last_timestamp_string \n";

		if ($periods_since_last_det > 0) {
				print STDERR "periods_since_last_det > 0, executing points det...\n";
				begin_transaction($dbh);
				execute_points_det($dbh, $periods_since_last_det, $det_rate_for_period);
				$dbh->do("insert into log (action,bigdata) values('pointsdet','points det halflife_days: $det_halflife_days , det_frequency_minutes: $det_frequency_minutes, det_rate_for_period: $det_rate_for_period, periods_since_last_det: $periods_since_last_det , lastdet: $last_timestamp_string')");
				$sth = $dbh->prepare("insert into points_deteriorate_log (points_deteriorate_timestamp,deteriorate_halflife_days,deteriorate_frequency_minutes,det_rate_for_period,periods_since_last_det) values (now(),?,?,?,?)");
				$sth->execute($det_halflife_days,$det_frequency_minutes,$det_rate_for_period,$periods_since_last_det);
				end_transaction($dbh);

				# NOTE - free_points_in_each_zone_for_all_users has nothing to do with deteriorate_points
				# this is a convenient hook to give free points before det'ing points
				free_points_in_each_zone_for_all_users($dbh);
		}
}

sub periods_since_last_det {
		my ($now_timestamp, $last_det_timestamp, $det_frequency_minutes) = @_;

		my $seconds_since_last_det = $now_timestamp - $last_det_timestamp;
		my $minutes_since_last_det = $seconds_since_last_det / 60;
		my $periods_since_last_det = int($minutes_since_last_det / $det_frequency_minutes);

		print STDERR "points det, det_frequency_minutes: $det_frequency_minutes, seconds since last det: $seconds_since_last_det , minutes since last det: $minutes_since_last_det , periods since last det: $periods_since_last_det \n";

		return $periods_since_last_det;
}

sub execute_points_det {
		my ($dbh, $periods_since_last_det, $det_rate_for_period) = @_;

		my $final_det_multiplier = (1.0 - $det_rate_for_period) ** $periods_since_last_det;

		print STDERR "execute point det, periods_since_last_det: $periods_since_last_det , det_rate_for_period $det_rate_for_period, final det multiplier: $final_det_multiplier \n";

		my $sth = $dbh->prepare("select name from users");
		$sth->execute;
		while (my ($user_name) = $sth->fetchrow_array) {
				points_det_for_one_user($dbh, $user_name, $final_det_multiplier);
		}
}

sub points_det_for_one_user {
		my ($dbh, $user_name, $final_det_multiplier) = @_;

		my $sth = $dbh->prepare("update user_points_$user_name set points = round(points * $final_det_multiplier)");
		$sth->execute;

		my $final_det_percent_rounded = (int (100000 * (1.0 - $final_det_multiplier))) / 1000.0;
		my $notification = "<form>Everyone's points deteriorated by $final_det_percent_rounded%. (sorry for spammy notification)";
		create_notification_by_user_name($dbh, $user_name, $notification);

		print STDERR "det'd points for $user_name\n"
}

sub det_rate_for_period {
		my ($halflife_days, $frequency_minutes) = @_;

		# Ie, detted_points = points * ( 1.0 - $det_rate_per_period )
		# And using this formula detted_points will have a halflife of $halflife_days
		my $det_rate_per_period = ((2.0 - 0.5**(1.0/$halflife_days))**($frequency_minutes/1440.0) - 1.0);

		return $det_rate_per_period;
}

# Return the timestamp of the last time points were det'd
sub last_det_timestamp {
		my ($dbh) = @_;

		create_last_det_timestamp_if_none_exists($dbh);

		my $sth = $dbh->prepare("select UNIX_TIMESTAMP(max(points_deteriorate_timestamp)) from points_deteriorate_log");
		$sth->execute;
		my ($last_det_timestamp) = $sth->fetchrow_array;

		return $last_det_timestamp;
}

# Ensure that points_det_log table has at least one entry,
# Otherwise we have no history upon which to base our next det
sub create_last_det_timestamp_if_none_exists {
		my ($dbh) = @_;

		my $create_unless_exists_query = <<EOT;
		INSERT INTO points_deteriorate_log
    SELECT now(),0,0,0,0
    FROM DUAL
    WHERE NOT EXISTS (SELECT * FROM points_deteriorate_log);
EOT

		my $sth = $dbh->prepare($create_unless_exists_query);
		$sth->execute;
}
