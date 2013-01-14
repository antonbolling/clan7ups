
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
-- Table structure for table `zone_points_alps`
--

CREATE TABLE zone_points_alps (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_alps`
--

INSERT INTO zone_points_alps VALUES (1,'alps',35);

--
-- Table structure for table `zone_points_bloodstone`
--

CREATE TABLE zone_points_bloodstone (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_bloodstone`
--

INSERT INTO zone_points_bloodstone VALUES (1,'day1',15);
INSERT INTO zone_points_bloodstone VALUES (2,'day2',22);
INSERT INTO zone_points_bloodstone VALUES (3,'day3',14);
INSERT INTO zone_points_bloodstone VALUES (4,'day4',23);
INSERT INTO zone_points_bloodstone VALUES (5,'lloth',4);
INSERT INTO zone_points_bloodstone VALUES (6,'dk',10);
INSERT INTO zone_points_bloodstone VALUES (7,'glab',10);
INSERT INTO zone_points_bloodstone VALUES (8,'drolem',7);

--
-- Table structure for table `zone_points_coliseum`
--

CREATE TABLE zone_points_coliseum (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_coliseum`
--

INSERT INTO zone_points_coliseum VALUES (1,'coli',17);

--
-- Table structure for table `zone_points_condemned`
--

CREATE TABLE zone_points_condemned (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_condemned`
--

INSERT INTO zone_points_condemned VALUES (1,'condemned',13);

--
-- Table structure for table `zone_points_demonforge`
--

CREATE TABLE zone_points_demonforge (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_demonforge`
--

INSERT INTO zone_points_demonforge VALUES (1,' Kanch',13);
INSERT INTO zone_points_demonforge VALUES (2,' Kanch + Extras',22);
INSERT INTO zone_points_demonforge VALUES (3,' day1 (Dhaul)',31);
INSERT INTO zone_points_demonforge VALUES (4,' day2 - THG',45);

--
-- Table structure for table `zone_points_den`
--

CREATE TABLE zone_points_den (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_den`
--

INSERT INTO zone_points_den VALUES (1,'Killed Thanos',12);
INSERT INTO zone_points_den VALUES (2,'Skipped Thanos',6);

--
-- Table structure for table `zone_points_eldricks`
--

CREATE TABLE zone_points_eldricks (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_eldricks`
--

INSERT INTO zone_points_eldricks VALUES (1,'eldricks',17);

--
-- Table structure for table `zone_points_elysium`
--

CREATE TABLE zone_points_elysium (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_elysium`
--

INSERT INTO zone_points_elysium VALUES (1,'day1',25);
INSERT INTO zone_points_elysium VALUES (2,'day2',26);

--
-- Table structure for table `zone_points_estate`
--

CREATE TABLE zone_points_estate (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_estate`
--

INSERT INTO zone_points_estate VALUES (1,'Count',19);
INSERT INTO zone_points_estate VALUES (2,'All but count',13);

--
-- Table structure for table `zone_points_kalata`
--

CREATE TABLE zone_points_kalata (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_kalata`
--

INSERT INTO zone_points_kalata VALUES (1,'kalata',19);

--
-- Table structure for table `zone_points_kukdheuda`
--

CREATE TABLE zone_points_kukdheuda (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_kukdheuda`
--

INSERT INTO zone_points_kukdheuda VALUES (1,'kukdheuda',12);

--
-- Table structure for table `zone_points_lyryanoth`
--

CREATE TABLE zone_points_lyryanoth (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_lyryanoth`
--

INSERT INTO zone_points_lyryanoth VALUES (1,'Lyr',15);

--
-- Table structure for table `zone_points_reclasta`
--

CREATE TABLE zone_points_reclasta (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_reclasta`
--

INSERT INTO zone_points_reclasta VALUES (1,'reclasta',19);

--
-- Table structure for table `zone_points_scales`
--

CREATE TABLE zone_points_scales (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_scales`
--

INSERT INTO zone_points_scales VALUES (1,'Loaded',10);
INSERT INTO zone_points_scales VALUES (2,'NoLoad',3);

--
-- Table structure for table `zone_points_sevoseth`
--

CREATE TABLE zone_points_sevoseth (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_sevoseth`
--

INSERT INTO zone_points_sevoseth VALUES (1,'sevoseth',22);

--
-- Table structure for table `zone_points_tomb`
--

CREATE TABLE zone_points_tomb (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_tomb`
--

INSERT INTO zone_points_tomb VALUES (1,'day1',16);
INSERT INTO zone_points_tomb VALUES (2,'bronze',13);
INSERT INTO zone_points_tomb VALUES (3,'silver',20);
INSERT INTO zone_points_tomb VALUES (4,'gold',22);

--
-- Table structure for table `zone_points_verigaard`
--

CREATE TABLE zone_points_verigaard (
  id int(11) NOT NULL default '0',
  day_name char(20) default NULL,
  points int(11) default NULL,
  PRIMARY KEY  (id)
);

--
-- Dumping data for table `zone_points_verigaard`
--

INSERT INTO zone_points_verigaard VALUES (1,'verigaard',12);

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

--
-- Dumping data for table `zones`
--

INSERT INTO zones VALUES (2,'bloodstone',75,8);
INSERT INTO zones VALUES (3,'elysium',50,2);
INSERT INTO zones VALUES (4,'tomb',15,4);
INSERT INTO zones VALUES (5,'kalata',25,1);
INSERT INTO zones VALUES (6,'lyryanoth',10,1);
INSERT INTO zones VALUES (7,'demonforge',50,4);
INSERT INTO zones VALUES (8,'coliseum',25,1);
INSERT INTO zones VALUES (9,'alps',50,1);
INSERT INTO zones VALUES (10,'condemned',10,1);
INSERT INTO zones VALUES (11,'eldricks',15,1);
INSERT INTO zones VALUES (12,'verigaard',10,1);
INSERT INTO zones VALUES (13,'estate',10,2);
INSERT INTO zones VALUES (14,'scales',100,2);
INSERT INTO zones VALUES (15,'den',15,2);
INSERT INTO zones VALUES (19,'kukdheuda',25,1);
INSERT INTO zones VALUES (18,'reclasta',25,1);
INSERT INTO zones VALUES (20,'sevoseth',25,1);

