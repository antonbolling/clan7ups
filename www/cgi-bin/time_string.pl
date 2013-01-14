use warnings;
use strict;

use DBI;
use CGI;

sub time_string {
  my ($time_in_seconds) = @_;

  my $one_minute = 60;
  my $one_hour = 3600;
  my $one_day = 86400;

  my $time_string = "";

#  print "minute: $one_minute, hour: $one_hour, day: $one_day\n";
#  print "passed time: $time_in_seconds\n";

  my $days = int($time_in_seconds/$one_day);
  my $remainder = $time_in_seconds % $one_day;

  my $deg = 0;
  my $started = 0;

  # For each item: print IF
  # - Fewer than 2 items have been printed, AND
  # - if 0 items have been printed the current item must be defined.
  if ($days) {
    $time_string .= "${days}d";
    $deg++;
    $started = 1;
  }

#  print "$days days\n";
#  print "remainder is $remainder\n";

  my $hours = int($remainder / $one_hour);
  $remainder = $remainder % $one_hour;

  if (($started and $deg < 2) or ($deg == 0 and $hours)) {
    $time_string .= "${hours}h";
    $deg++;
    $started = 1;
  }

#  print "$hours hours\n";
#  print "remainder is $remainder\n";

  my $minutes = int($remainder/$one_minute);
  my $seconds = $remainder % $one_minute;

  if (($started and $deg < 2) or ($deg == 0 and $minutes)) {
    $time_string .= "${minutes}m";
    $deg++;
    $started = 1;
  }

  if (($started and $deg < 2) or ($deg == 0 and $seconds)) {
    $time_string .= "${seconds}s";
  }

#  print "$minutes minutes\n";
#  print "$seconds seconds\n";

  return $time_string;
}

1;
