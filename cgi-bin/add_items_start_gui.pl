use CGI;
use DBI;

use warnings;
use strict;

require 'ups_util.pl';
require 'cook.pl';

sub add_items_start_gui {
  my ($dbh, $q, $view_time) = @_;
  my $uid = cook_int($q->param('uid'));

  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($username) = $sth->fetchrow_array;

  my $session_info = get_session_info($dbh, $q, $view_time);

  print <<EOT;
  <h3>Add eq to the database</h3>
    <form method="post" name="add_eq" action="/fate-cgi/ups.pl">
    $session_info
    <input type="hidden" name="action" value="add_items_start">

    <p>Equipment list:<br>
    <textarea name="eqlist" rows=10 cols=80></textarea>

    <input type="submit" value="Submit this equipment">
EOT

  return_main();
}

1;
