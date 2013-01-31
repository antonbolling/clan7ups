#08/24/03 - JM - Changed some prepare/execute statements do $dbh->do() for speed
#                Run creation is now logged

use CGI;
use DBI;

use warnings;
use strict;

require "session.pl";
require "pick_day.pl";
require "pick_day_gui.pl";
require "modify_run_gui.pl";
require "ups_util.pl";
require "cook.pl";

sub create_run {
  my ($dbh, $q, $view_time) = @_;
  my $uid = cook_int($q->param('uid'));

  my $session_info = get_session_info($dbh, $q, $view_time);

  my $leader = cook_int($q->param('leader'));
  my $zone = cook_word($q->param('zone'));
  my $runtype = cook_word($q->param('runtype'));
  my $runners = $q->param('runners');

  my $eqlist = $q->param('eqlist');
  my $comments = cook_string($q->param('comments'));

  #Create the run.
  $dbh->do("insert into runs (zone,leader,type,status,add_stamp,mod_stamp,comments) values('$zone',$leader,'$runtype','pending',FROM_UNIXTIME($view_time),FROM_UNIXTIME($view_time),'$comments')");

  #Get the runid that we just added.
  my $sth = $dbh->prepare("select id from runs where leader=$leader order by add_stamp desc");
  $sth->execute;
  my ($runid) = $sth->fetchrow_array;
  $sth->finish;

  #Get the leader's name.
  $sth = $dbh->prepare("select name from users where id=$leader");
  $sth->execute;
  my ($leader_name) = $sth->fetchrow_array;

  $dbh->do("insert into log (user,action,idata1,bigdata) values($uid,'run',$runid,'$leader_name submitted run #$runid')");

  #Find out how many days the zone has:
  $sth = $dbh->prepare("select num_days from zones where name='$zone'");
  $sth->execute;
  my ($num_days) = $sth->fetchrow_array;

  #Create a pointdata table for this run.
  $dbh->do("create table run_points_$runid (runner char(20) primary key, points int not null default 0, percent_attendance int not null default 100)");

  #Preliminary pointdata for each runner. Create a run_points table for this run
  #populate it with runners and call pick_day.
  my @runnerlist = $runners =~ /([a-zA-Z]{2,})/g;
  @runnerlist = map { lc $_ } @runnerlist;

	my @word_blacklist = qw(press return or abort name status clan afk medlink cle war thi mag legend formation undead corpse in current class sex level lv total levels cc tl total players visible to you); # remove a list of common words, making it easier to paste who -z
	foreach my $word (@word_blacklist) {
			@runnerlist = grep { !/$word/ } @runnerlist;
	}

  foreach (@runnerlist) {
    my $runner = cook_word(lc $_);
    $dbh->do("insert into run_points_$runid (runner) values ('$runner')");
  }

  #Handle the eq list.
  my @eqlist = split(/\r\n/, $eqlist);
  my $count = 0;

  foreach (@eqlist) {
    my $item = cook_string($_);

    $count++;
#    print "<p>Item $count: $item. Adding to database.</p>\n";
    $dbh->do("insert into incoming_eq (run_id,descr) values ($runid,'$item')");
  }
#  print "<p>Found $count items. Getting ids...</p>";

  #Done with create phase. Move on to modify gui.
  #IF this zone has more than 1 day, move to pick day gui;
  #Otherwise set day to 1, move on to modify gui.
  my $CGI_params = $q->Vars;
  $CGI_params->{'runid'} = $runid;

  if ($num_days == 1) {
    # Change the day to 1 as a default.
    $CGI_params->{'day'} = 1;

    # Go.
    pick_day($dbh, $q, $view_time);
  }
  else {
    pick_day_gui($dbh, $q, $view_time);
  }
}

1;
