use warnings;
use strict;

require "session.pl";

# I hate to name this 'return_main2', should really just rip out old return_main
sub return_main2 {
  my ($session_info, $return_main_button_label) = @_;

	if (! defined $return_main_button_label) {
			$return_main_button_label = "Return to main";
	}

  print <<EOT;
  <form name=return method=post action="/cgi-bin/ups.pl">
  $session_info
  <input type="hidden" name="action" value="main_menu">
  <input type="submit" value="$return_main_button_label">
  </form>
EOT

  return 0;
}

sub return_main {
  my ($dbh, $q, $view_time) = @_;
  my $session_info = get_session_info($dbh, $q, $view_time);

  print <<EOT;
  <form name=return method=post action="/cgi-bin/ups.pl">
  $session_info
  <input type="hidden" name="action" value="main_menu">
  <input type="submit" value="Return to main">
  </form>
EOT

  return 0;
}

1;
