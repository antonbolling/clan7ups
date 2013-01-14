use warnings;
use strict;

use DBI;
use CGI;

sub print_header {
  my ($dbh, $q) = @_;
  
  my $uid = cook_int($q->param('uid'));
  my $sth = $dbh->prepare("select name,access,clan from users where id=$uid");
  $sth->execute;
  
  my ($name, $access, $clanid) = $sth->fetchrow_array;
  
  #Get clan name
  $sth = $dbh->prepare("select name from clans where id=$clanid");
  $sth->execute;
  my $clan = $sth->fetchrow_array;
  $sth->finish;
    
  print <<EOT;
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" 
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
        <title>
                  Universal Point System
        </title>
        <link href="/fate/css/styles.css" rel="stylesheet" type="text/css" />
        <script language="JavaScript" src="/fate/js/ypSlideOutMenusC.js" 
type="text/JavaScript"></script>
        <script language="JavaScript" src="/fate/js/mouseover.js" type="text/javascript"></script>
    </head>
    <body>
    <img class="transparentheader" src="/fate/images/transparentwhite.png" alt="">
    <img id="appicon" src="/fate/images/ups-gradiant2.png" alt="" border="0">
    <div class="header">
          <div class="div_namebox">
EOT
       $name = ucfirst $name;
       print "$name";
       if ($access eq 'admin') {
         print ": Administrator";
       } elsif ($access eq 'gate') {
         print ": Gatekeeper";
       }
  print <<EOT;
      </div>
          <div class="div_clanbox">
EOT
print "   &nbsp;&nbsp;$clan";
print <<EOT;
          </div>
        </div>
EOT
}

sub print_menu_start {
  print <<EOT;
  <div class="sidebox">
EOT
}

sub print_menu_end {
  print <<EOT;
  </div>
EOT
}

sub print_main_start() {
  print <<EOT;
  <div class="mainwindow">
EOT
}

sub print_main_end() {
  print <<EOT;
  </div>
EOT
}
1;
