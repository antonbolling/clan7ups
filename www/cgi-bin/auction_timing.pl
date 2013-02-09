use warnings;
use strict;

use CGI;
use DBI;

my $MINIMUM_AUCTION_DURATION_SECONDS = 60 * 60 * 24 * 3; # 3 days in seconds, the minimum time an item may be on ups for
my $UPBID_DURATION_SECONDS = 60 * 60 * 24; # 1 day in seconds, the minimum time after an upbid that an auction ends and the item is pickable

# Return truthy if the auction is pickable for the passed bid_eq_id, falsy otherwise
sub auction_pickable {
		my ($dbh, $bid_eq_id) = @_;
		return auction_seconds_remaining(get_auction_times($dbh,$bid_eq_id)) < 1;
}

# Return the number of seconds remaining on an auction, given the current time, add time, and current bid time
# A return value <= 0 indicates the auction is over and the item may be picked
# If the auction has no current bid, the maximum auction length will be returned
sub auction_seconds_remaining {
		my ($current_time, $add_time, $current_bid_time) = @_;

		if (! defined $current_bid_time) {
				#print STDERR "auction_seconds_remaining received null current_bid_time, so returning the maximum auction legnth\n";
				return $MINIMUM_AUCTION_DURATION_SECONDS;
		}

		my $upbid_end_time = $current_bid_time + $UPBID_DURATION_SECONDS;
		my $minimum_auction_end_time = $add_time + $MINIMUM_AUCTION_DURATION_SECONDS;

		my $latest_end_time = $upbid_end_time > $minimum_auction_end_time ? $upbid_end_time : $minimum_auction_end_time;
		
		my $auction_seconds_remaining = $latest_end_time - $current_time;

		#print STDERR "bid_seconds_remaining had add_time $add_time, cur_bid_time $current_bid_time, latest_end_time $latest_end_time, and seconds remaining $auction_seconds_remaining\n";

		return $auction_seconds_remaining;
}

# Return the current time, an auction add time, and auction current bid time, given a bid_eq id
sub get_auction_times {
		my ($dbh, $bid_eq_id) = @_;

		my $bid_item_sql = $dbh->prepare("select UNIX_TIMESTAMP(now()), UNIX_TIMESTAMP(add_time), UNIX_TIMESTAMP(cur_bid_time) from bid_eq where id = ?");
		$bid_item_sql->execute($bid_eq_id);

		my ($current_time, $add_time, $current_bid_time) = $bid_item_sql->fetchrow_array;
		
		return ($current_time, $add_time, $current_bid_time);
}

1;
