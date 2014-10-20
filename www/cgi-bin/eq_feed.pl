#!/usr/bin/perl

# Ubuntu - requires apt package libjson-perl

# This is the only UPS perl file which doesn't require authentication.
# Output is a resource with Content-Type: application/json containing a feed of all eq

# TODO: include a hardcoded "api key" to naively prevent access

use warnings;
use strict;

use CGI qw(:standard);
use JSON;
use DBI;

require "db.pl";

my $dbh = get_db();

my $EQ_NEWER_THAN_SECONDS = 60 * 60* 24 * 5;

my $eq_filter = " WHERE (UNIX_TIMESTAMP(now()) - UNIX_TIMESTAMP(add_time)) < $EQ_NEWER_THAN_SECONDS && status != 'picked' ";

my $eq_query = "select id, zone, descr, bid, status, first_bid_time, cur_bid_time, add_time from bid_eq $eq_filter ORDER BY cur_bid_time, add_time";

my $sth = $dbh->prepare($eq_query);
$sth->execute;


my %eq = ();

while (my ($id, $zone, $descr, $bid, $status, $first_bid_time, $cur_bid_time, $add_time) = $sth->fetchrow_array) {
  $eq{ $id } = {
              'zone' => $zone,
              'description' => $descr,
              'currentBid' => $bid,
              'currentBidTime' => $cur_bid_time,
            };
}

my $json_text = to_json(\%eq);

print header('application/json');

print $json_text;
