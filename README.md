# UPS

Fork of old Fate Universal Points System.  This is an old perl website that's probably the best UPS system ever used on Medievia.  Any Medievia clan should be able to use the instructions below to setup their own UPS.

## Setup
1. install MySQL Server 5
2. in MySQL, create a database, username, and password for the UPS, e.g. ups_db, ups_user, ups_password123
3. create your own mysql_config.cnf based on the provided example_mysql_config.cnf
4. in www/cgi-bin/db.pl, update `MYSQL_CLIENT_CONFIG` to point to your mysql_config.cnf
5. setup the database schema using the provided ups-database-schema.sql: `mysql -u ups_user -p ups_db < ups-database-schema.sql`
6. You're ready to go! Serve the www/ directory with a perl cgi handler
7. See the provided lighttpd.conf for an easy way to have the site up in five minutes

## Administrator Notes
* The only safe way to create a new account is to add them to a run; the non-existent account will be created when the run is approved
* The only safe way to create a new administrator account is to promote an existing account to administrator
* ups-database-schema.sql creates a default administrator account, username "admin", password "pw" - change this password ASAP

## Missing Features from Fate UPS
* 'Remove old equipment' is a BROKEN admin feature - there's no way to remove eq from system without having it picked
* 'Revalue equipment entries' is a BROKEN admin feature - there's no way to adjust eq min bids after run is approved
* 'Transfer new equipment to this system' is a BROKEN admin feature - there's no way to bulk import eq without submitting it as a run
* 'EQ Store' feature is missing / broken, which allowed certain items to be outright purchasable instead of taking bids
* Fate UPS bestowed 25% bonus points to the run leader. This has been removed (zero bonus points to run leader)

## Upcoming
* UPS comes with a list of top eq zones circa 2004. Needs updating. E.g. there's no Vondarkla
* Fix some of the BROKENs above
* Remove debug spam at top of each page once it's running smoothly
* Configurable auction length - the auction length of three days is hardcoded in many places
* Make UPS website pretty

## Credits
Thanks to Fate for this awesome UPS!  Original author unknown, possibly Evangelion.

## LICENSE
Copyright is held by unknown original author. Released under BSD 3-Clause license to the extent permitted by original author.
