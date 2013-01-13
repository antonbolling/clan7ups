use warnings;
use strict;

require "session.pl";

sub return_main {
  my ($dbh, $q, $view_time) = @_;
  my $session_info = get_session_info($dbh, $q, $view_time);

  print <<EOT;
  <form name=return method=post action="/fate-cgi/ups.pl">
  $session_info
  <input type="hidden" name="action" value="main_menu">
  <input type="submit" value="Return to main">
  </form>
EOT

  return 0;
}

1;

