use CGI;
use DBI;

use strict;
use warnings;

my $one_day = 86400;
my $three_days = 259200;

sub bid_pickable {
  my ($dbh, $q, $view_time, $item) = @_;

  # An item in bid_eq is pickable if:
  # - it's been bid on
  # - current bid is 3 days old or older
  # - current bid was made at least 3 days after the first bid and is at least a day old.
  # FIRST (always) first_bid_time must be non null, THEN
  # EITHER now() - cur_bid_time is 3 days or more, OR
  # cur_bid_time - first_bid_time is 3 days or more, AND now() - cur_bid_time is 1 day or more
  my $sth = $dbh->prepare("select first_bid_time is not null and ( (unix_timestamp(now()) - unix_timestamp(cur_bid_time) >= $three_days) or ( (unix_timestamp(cur_bid_time) - unix_timestamp(first_bid_time) >= $three_days) and (unix_timestamp(now()) - unix_timestamp(cur_bid_time) >= $one_day))) as pickable from bid_eq where id=$item");
  $sth->execute;

  my ($pickable) = $sth->fetchrow_array;
  return $pickable;
}

sub store_pickable {
  my ($dbh, $q, $view_time, $item) = @_;

  # An item in store_eq is pickable if:
  # - it's been claimed.
  # - current claim is at least a day old.
  my $sth = $dbh->prepare("select cur_claim_time is not null and (unix_timestamp(now()) - unix_timestamp(cur_claim_time) >= $one_day)");
  $sth->execute;

  my ($pickable) = $sth->fetchrow_array;
  return $pickable;
}
