use CGI;
use DBI;

use warnings;
use strict;

require "session.pl";

sub create_run_gui {
  my ($dbh, $q, $view_time) = @_;
  my $uid = $q->param('uid');

  my $sth = $dbh->prepare("select name from users where id=$uid");
  $sth->execute;
  my ($username) = $sth->fetchrow_array;

  my $session_info = get_session_info($dbh, $q, $view_time);

  print <<EOT;
  <h3>Submit a new run</h3>
    <form method="post" name="submitrun" action="/cgi-bin/ups.pl">
    $session_info
    <input type="hidden" name="action" value="create_run">
    <input type="hidden" name="leader" value="$uid">
    <table>
    <tr><td>Run Leader</td><td>$username</td></tr>

    <tr><td>Zone</td>
    <td>
    <select name="zone">
EOT

  $sth = $dbh->prepare("select name from zones order by name");
  $sth->execute;

  my $arrayref = $sth->fetchall_arrayref;
  foreach (@$arrayref) {
    my $item = $_;
    my $name = $item->[0];

    print <<EOT;
    <option>$name
EOT
  }

  print <<EOT;
    </select></td></tr>

    <tr><td valign=top>Run Type</td>
        <td><p><input type="radio" name="runtype" value="clan" checked>
            Clan run (clan keys, clan treasure. extra points to leader)</p>
            <p><input type="radio" name="runtype" value="self">
            Self owned (own keys, keep treasure. no extra points)</p></td>
    </tr>

    <tr><td valign=top>Runners</td>
        <td><textarea name="runners" rows=3 cols=120></textarea></td></tr>

    <tr><td valign=top>Equipment</td>
        <td><textarea name="eqlist" rows=10 cols=120></textarea></td></tr>

    <tr><td valign=top>Comments</td>
        <td><textarea name="comments" rows=3 cols=120></textarea></td></tr>

    </table>

    <input type="submit" value="Submit this run">
  </form>

  <hr>
  <h3> How to use this dialog </h3>

  <table>
  <tr><td>Field</td><td>Description</td></tr>

  <tr><td>Zone</td><td>Select which zone you ran.</td></tr>

  <tr><td valign=top>Run type</td>
      <td><p>When you run a zone you can choose whether or not to use the clan keychar. Either way
             the leader gets some form of extra compensation for leading the zone.</p>
          <p><b>Clan run</b> - You use the clan's keychar for this run, and get a 25% point bonus
             over the default award for this zone. However, you must trans cash from zone treasure
             to your clan account. Gatekeepers will check that you do this.</p>
          <p><b>Self owned run</b> - You use your own keys, and keep day keys after completing the
             run. You also keep any cash from zone treasure. However, you opt not to receive the 25%
             point bonus. </p>
          <p>If you grabbed keys off your clan's keychar for the run, you can't submit as a self-owned run.
             If you used your own keys for a run, you can't submit as a clan run.
             These options are meant to compensate clan and runner fairly, and allowing people to switch
             midrun would open the door to all kinds of abuse. Don't even ask. </p>
      </td></tr>

  <tr><td valign=top>Runners</td>
      <td></p> List the zone's runners here. You can input basically anything - a space separated
          list, comma separated list, etc. You can even paste your formlock and add extras at the
          bottom. The parser will catch just about any input. </p>

  <tr><td valign=top>Equipment</td>
      <td><p>This field should contain a list of all the equipment you popped on your run. List one
          item on each line. It's not mandatory but to keep things <b>consistent</b> please for the
          sake of all of us use appraise output here. It's simpler anyway: when you're done running,
          place all of the eq from the run into one container (say a boh) and type
          "appraise all holding". You may simply cut and paste the output from that command into
          this field.</p></td></tr>

  <tr><td valign=top>Comments</td>
      <td><p>Here you should just scribble in any significant occurrances, specifically justifications
          for modifying default point awards. You must justify any modification you make to point
          values here, or the gatekeepers will not approve your run. <b>However</b>, you'll have more
          opportunities to add to this field, so don't worry about getting it perfect now.</p></td></tr>

  </table>
EOT
}

1;
