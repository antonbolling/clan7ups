#!/usr/bin/perl

use warnings;
use strict;

use CGI;
use DBI;

require "session.pl";
require "cook.pl";
require "styles.pl";
require "db.pl";

my $dbh = get_db();

my $q = new CGI;

my $login = lc cook_word($q->param('login'));
my $pass = cook_word($q->param('pass'));

my $login_sql = $dbh->prepare("select id from users where name=? and pass=PASSWORD(?)");
$login_sql->execute($login,$pass);

my $valid_login = $login_sql->rows;
my ($uid) = $login_sql->fetchrow_array;

if ($valid_login) {
	redirect_to_main_menu($dbh, $q, $uid);
} else {
  invalid_login($q, $login);
}

sub redirect_to_main_menu {
	my ($dbh, $q, $uid) = @_;

  my $time_sql = $dbh->prepare("select unix_timestamp(now())");
  $time_sql->execute;
  my ($time) = $time_sql->fetchrow_array;

  my $magic = new_session($dbh, $uid);
  my $CGI_params = $q->Vars;
  $CGI_params->{'magic'} = $magic;
  $CGI_params->{'uid'} = $uid;
  my $session_info = get_session_info($dbh, $q, $time);

	print $q->header;
	print <<EOT;
	<head>
	<title>Redirecting to UPS main menu...</title>
	<script src="//code.jquery.com/jquery-1.10.2.min.js"></script>
	<script type="text/javascript">
	\$(function() {
			document.body.innerHTML += "<form id='redirectToMainMenu' action='/cgi-bin/ups.pl' method='post'><input type='hidden' name='action' value='main_menu'>$session_info</form>";
			document.getElementById('redirectToMainMenu').submit();
		 });
	</script>
	</head>
  <body>
	SUCCESS.. redirecting to main menu...
  </body>
EOT
  print $q->end_html;
}

sub invalid_login {
  my ($q, $login) = @_;

	print $q->header;

	print <<EOT;
<head><title>Universal Point System</title>
EOT
  print_styles();
  print <<EOT;
</head>
<body>
  <p>Trying to log in using login $login</p>
  <p>You entered an invalid username/password pair.</p>
  <p>If you haven't had your account password set, or if this problem continues,
     speak to an administrator. </p>
  <p><A HREF="/">Back to the top</a></p>
EOT

  print $q->end_html;
}
