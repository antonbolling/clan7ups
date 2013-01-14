#08/11/03 - JM - Fixed typo on line 33 which prevented compilation

use CGI;
use DBI;

use warnings;
use strict;

require "modify_zone_gui.pl";
require "cook.pl";

sub modify_zone {
  my ($dbh, $q, $view_time) = @_;

  my $zoneid =   cook_int($q->param('zoneid'));
  my $percent =  cook_int($q->param('percent'));
  my $num_days =  cook_int($q->param('days'));
  my $zone_name = cook_word($q->param('zone'));

  # Clear the days table for this zone with old zone name.
  my $sth = $dbh->prepare("select name from zones where id='$zoneid'");
  $sth->execute;
  my ($old_zone_name) = $sth->fetchrow_array;

  $sth = $dbh->prepare("drop table zone_points_$old_zone_name");
  $sth->execute;

  # Create the days table for this zone with new zone name.
  $sth = $dbh->prepare("create table zone_points_$zone_name (id int primary key, day_name char(20), points int)");
  $sth->execute;

  foreach (1..$num_days) {
    my $this_day_num   = $_;
    my $this_day_name  = cook_string($q->param("name_$this_day_num"));
    my $this_day_value = cook_int($q->param("value_$this_day_num"));

    print "\n<p> Adding to zone_points_$zone_name day $this_day_num, named $this_day_name, value $this_day_value </p>\n\n";

    $sth = $dbh->prepare("insert into zone_points_$zone_name values ('$this_day_num', '$this_day_name', '$this_day_value')");
    $sth->execute;
  }

  # done putting together pointdata. update entry for $zoneid.
  $sth = $dbh->prepare("update zones set name='$zone_name' where id=$zoneid");
  $sth->execute;
  $sth = $dbh->prepare("update zones set percent='$percent' where id=$zoneid");
  $sth->execute;
  $sth = $dbh->prepare("update zones set num_days='$num_days' where id=$zoneid");
  $sth->execute;

  modify_zone_gui($dbh, $q, $view_time);
}

1;
