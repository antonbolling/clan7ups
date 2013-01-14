use strict;
use warnings;

sub print_styles {
  print <<EOT;
<STYLE TYPE="text/css">
BODY {background-color: white}
#points_even_row {background-color: EEEEFF}
#points_odd_row {background-color: CCCCFF}
#bid_header {background-color: CBDDED}
#bid_even {background-color: EEF8FF}
#bid_odd {background-color: FFFFFF}
#bid_own {background-color: FFFF99}
#acct_exists {color: green}
#acct_dne {color: red}
#points_total {color: blue}
#points_avail {color: green}
#points_maxbid {color: red}
#browser_minbid {color: blue}
#browser_curbid {color: green}
#browser_minupb {color: navy}
#browser_maxupb {color: red}
#browser_price {color: blue}
#browser_avail {color: navy}
#browser_claimable {color: green}
#browser_yes_claim {color: green}
#browser_no_claim {color: red}
#run_pending {color: green}
#run_denied {color: red}
.smfont {font-size: 10px; font-family: Geneva, Verdana, Helvetica, Arial;}
</STYLE>
EOT
}

1;

