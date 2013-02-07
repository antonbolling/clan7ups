#!/usr/bin/perl

#08/25/03 - JM - I think pick_store() is obsolete or something, so removed the call

use warnings;
use strict;

use CGI;
use DBI;

require "styles.pl";
require "session.pl";
require "db.pl";

# This script:
# - Attempts to connect to the database.
# - Retrieves the CGI buffer.
# - Validates session tokens, updates session magic.
# - Determines the loading time (via dbi)
# - Examines 'action' param, loads the appropriate file,
#   executes the appropriate function.

my $dbh = get_db();

my $q = new CGI;
print $q->header;

my $uid = $q->param('uid');
my $magic = $q->param('magic');

my $sth = $dbh->prepare("select unix_timestamp(now())");
$sth->execute;
my ($view_time) = $sth->fetchrow_array;

print <<EOT;
<head><title>Universal Point System</title>
EOT

print_styles();

print <<EOT;
</head>

<body>
EOT

#print "<p> Updating session info... PASSED uid, magic: $uid, $magic. view_time is $view_time. </p>\n";

if ($magic = get_session($dbh, $q, $view_time)) {
  # Switch on action flag.
  my $action = $q->param('action');
  #print "<p>Found action parameter: $action</p>\n";

  if ($action eq 'main_menu') {
    require "main_menu.pl";
    main_menu($dbh, $q, $view_time);
  }

  #Advanced User Management
  elsif ($action eq 'adv_user_gui') {
    require "adv_user_gui.pl";
    adv_user_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'adv_user') {
    require "adv_user.pl";
    adv_user($dbh, $q, $view_time);
  }
  elsif ($action eq 'adv_xfer_pts') {
    require "adv_user.pl";
    adv_xfer_pts($dbh, $q, $view_time);
  }
  elsif ($action eq 'adv_change_password') {
    require "adv_user.pl";
    adv_change_password($dbh, $q, $view_time);
  }
  elsif ($action eq 'adv_change_access') {
    require "adv_user.pl";
    adv_change_access($dbh, $q, $view_time);
  }

  elsif ($action eq 'mod_create_zone_gui') {
    require "mod_create_zone_gui.pl";
    mod_create_zone_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'create_zone') {
    require "create_zone.pl";
    create_zone($dbh, $q, $view_time);
  }
  elsif ($action eq 'modify_zone') {
    require "modify_zone.pl";
    modify_zone($dbh, $q, $view_time);
  }
  elsif ($action eq 'modify_zone_gui') {
    require "modify_zone_gui.pl";
    modify_zone_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'create_run_gui') {
    require "create_run_gui.pl";
    create_run_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'create_run') {
    require "create_run.pl";
    create_run($dbh, $q, $view_time);
  }
  elsif ($action eq 'modify_run' or $action eq 'deny_run' or 
         $action eq 'approve_run' or $action eq 'delete_run') {
    require "modify_run.pl";
    modify_run($dbh, $q, $view_time);
  }
  elsif ($action eq 'modify_run_gui') {
    require "modify_run_gui.pl";
    modify_run_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'browse') {
    require "browser.pl";
    browser($dbh, $q, $view_time);
  }
  elsif ($action eq 'add_items_start_gui') {
    require "add_items_start_gui.pl";
    add_items_start_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'user_info_gui') {
    require "user_info_gui.pl";
    user_info_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'change_password') {
    require "change_password.pl";
    change_password($dbh, $q, $view_time);
  }
  elsif ($action eq 'pick_day') {
    require "pick_day.pl";
    pick_day($dbh, $q, $view_time);
  }
  elsif ($action eq 'buy_items') {
    require "buy_items.pl";
    buy_items($dbh, $q, $view_time);
  }
  elsif ($action eq 'perform_picks_gui') {
    require "perform_picks_gui.pl";
    perform_picks_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'perform_picks') {
    require "perform_picks.pl";
    perform_picks($dbh, $q, $view_time);
  }
  elsif ($action eq 'bid_item_gui') {
    require "bid_item_gui.pl";
    bid_item_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'bid_item') {
    require "bid_item.pl";
    bid_item($dbh, $q, $view_time);
  }
  elsif ($action eq 'allocate_pick_gui') {
    require "allocate_pick_gui.pl";
    allocate_pick_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'allocate_pick') {
    require "allocate_pick.pl";
    allocate_pick($dbh, $q, $view_time);
  }
  elsif ($action eq 'revalue_gui') {
    require "revalue_gui.pl";
    revalue_gui($dbh, $q, $view_time);
  }
  elsif ($action eq 'revalue_grep') {
    require "revalue_grep.pl";
    revalue_grep($dbh, $q, $view_time);
  }
  elsif ($action eq 'revalue_bid') {
    require "revalue_bid.pl";
    revalue_bid($dbh, $q, $view_time);
  }
	elsif ($action eq 'clear_notifications') {
			require "user_notifications.pl";
			clear_notifications_by_user_id($dbh, $uid);
			require "main_menu.pl";
			main_menu($dbh, $q, $view_time);
	}	
	elsif ($action eq 'user_transfer_points_gui') {
			require "user_transfer_points.pl";
			user_transfer_points_gui($dbh,$q,$view_time);
	}
	elsif ($action eq 'user_transfer_points') {
			require "user_transfer_points.pl";
			user_transfer_points($dbh,$q,$view_time);
			require "main_menu.pl";
			main_menu($dbh, $q, $view_time);
	}	elsif ($action eq 'modify_approved_run_gui') {
			require "modify_approved_run.pl";
			if (modify_approved_run_gui($dbh,$q,$view_time)) {
					require "main_menu.pl";
					main_menu($dbh, $q, $view_time);
			}
	} elsif ($action eq 'modify_approved_run') {
			require "modify_approved_run.pl";
			modify_approved_run($dbh,$q,$view_time);
			require "main_menu.pl";
			main_menu($dbh, $q, $view_time);
	} elsif ($action eq 'recent_runs_gui') {
			require "recent_runs.pl";
			recent_runs_gui($dbh, $q, $view_time);
	} elsif ($action eq 'ups_stats_gui') {
			require "ups_stats.pl";
			ups_stats_gui($dbh, $q, $view_time);
	}
} else {
  session_expired();
}

print "</body>\n";
