use CGI;
use DBI;

use warnings;
use strict;

require "session.pl";
require "modify_zone_gui.pl";
require "cook.pl";

sub create_zone {
  my ($dbh, $q, $view_time) = @_;

  my $zone = cook_word($q->param('zone'));
  my $days = cook_int($q->param('days'));
  my $percent = cook_int($q->param('percent'));

  # Passed zone/days/percent. Create this zone in the db.

  my $sth = $dbh->prepare("insert into zones (name,percent,num_days) values ('$zone',$percent,$days)");
  $sth->execute;

  # Get new zone id.
  $sth = $dbh->prepare("select id from zones where name='$zone'");
  $sth->execute;
  my $rows = $sth->rows;
  my ($zoneid) = $sth->fetchrow_array;
  print "<p>Found $rows rows matching $zone after insert. Zoneid is $zoneid.</p>\n";

  # Create this zone's points table.
  $sth = $dbh->prepare("create table zone_points_$zone (id int primary key, day_name char(20), points int)");
  $sth->execute;

  my $CGI_params = $q->Vars;
  $CGI_params->{'zoneid'} = $zoneid;

  modify_zone_gui($dbh, $q, $view_time);
}

1;
