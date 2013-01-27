
-- Medievia UPS MySQL database Schema.
-- Tested on MySQL Server 5.5

-- A default administrator account is created, username "admin", password "pw".
-- This admin account should have the password changed asap.

--
-- Table structure for table `bid_eq`
--

CREATE TABLE bid_eq (
  id int(11) NOT NULL auto_increment,
  zone varchar(20) default NULL,
  run_id int(8) default NULL,
  descr blob,
  min_bid int(11) default NULL,
  bidder varchar(20) default NULL,
  bid int(11) default NULL,
  status enum('added','bidding','picked','sent') default NULL,
  cur_bid_time datetime default NULL,
  prev_bid_time datetime default NULL,
  first_bid_time datetime default NULL,
  add_time datetime default NULL,
  PRIMARY KEY  (id)
);

CREATE TABLE incoming_eq (
  id int(11) NOT NULL auto_increment,
  run_id int(11) default NULL,
  descr blob,
  value int(11) default '0',
  type enum('bid','store') default 'store',
  PRIMARY KEY  (id)
);

CREATE TABLE log (
  id int(11) NOT NULL auto_increment,
  time timestamp NOT NULL,
  user int(11) default NULL,
  action varchar(20) default NULL,
  cdata1 varchar(20) default NULL,
  cdata2 varchar(20) default NULL,
  idata1 int(11) default NULL,
  idata2 int(11) default NULL,
  bigdata blob,
  PRIMARY KEY  (id)
);

CREATE TABLE outgoing_eq (
  id int(11) NOT NULL auto_increment,
  descr blob,
  bidder varchar(20) default NULL,
  add_stamp timestamp NOT NULL,
  PRIMARY KEY  (id)
);

CREATE TABLE picked_eq (
  id int(11) default NULL,
  bidder varchar(20) default NULL,
  descr blob
);

CREATE TABLE runs (
  id int(11) NOT NULL auto_increment,
  zone varchar(20) default NULL,
  day int(11) default NULL,
  leader int(11) default NULL,
  type enum('clan','self') default NULL,
  status enum('pending','denied','approved','deleted') default NULL,
  add_stamp datetime default NULL,
  mod_stamp datetime default NULL,
  comments blob,
  PRIMARY KEY  (id)
);

CREATE TABLE user_points_ (
  zone char(20) default NULL,
  points int(11) default NULL
);

CREATE TABLE users (
  id int(11) NOT NULL auto_increment,
  name varchar(20) default NULL,
  aliases text,
  pass varchar(128) default NULL,
  access enum('user','gate','admin') NOT NULL default 'user',
  magic int(11) default NULL,
  session_stamp datetime default NULL,
  PRIMARY KEY  (id)
);

--
-- Create a default admin account
--

INSERT INTO users (name,pass,access) VALUES ('admin',PASSWORD('pw'),'admin');

--
-- Table structure for table `zones`
--

CREATE TABLE zones (
  id int(11) NOT NULL auto_increment,
  name varchar(20) default NULL,
  percent int(11) default NULL,
  num_days int(11) default NULL,
  PRIMARY KEY  (id)
);

CREATE TABLE user_notifications (
  id int NOT NULL auto_increment,
  user_id int NOT NULL,
  notification text NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
	  ON DELETE CASCADE
    ON UPDATE CASCADE,
  PRIMARY KEY  (id)
);