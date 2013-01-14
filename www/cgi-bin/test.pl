#!/usr/bin/perl
#script to check free drive space
#cron me to run once per hour
#my estimate of drive space pct available might be different than df's
#this is because I a) don't round weirdly and b) use blocks free
#       rather than blocks used for my calculation
#       df seems a touch messed up in that regard.

#settings
#       set mailwarn to the mailing address of your sysadmins
#       set mailcrit to their mail-to-pager address
$mailwarn = "sholes\@athertonia.org";
$mailcrit = "sholes\@athertonia.org";

#get the hostname minus the trailing domains
$hostname = `hostname -s`;
chomp $hostname;
#grep / makes sure headers aren't included
#grep -v shm removes mounted under shm (swap).
#df -ml returns only local drives, size in megabytes
open (DFOUTPUT, "df -ml | grep / | grep -v shm | grep -v /boot | grep -v /tmp | grep -v cdrom |") or die "Can't fork: $!";

$i = 0;
$j = 0;
while ($DFout = <DFOUTPUT>) {
        @readtemp = split (/ +/,$DFout);
        chomp $readtemp[5];
        $mount[$i] = $readtemp[5];
        $total[$i] = $readtemp[1];
        $free[$i] = $readtemp[3];
        $freeGB[$i] = int $readtemp[3]/1024;
        $pct[$i] = $free[$i]/$total[$i]*100;
        $i++;
        $j++;
} #end while loop

#testing drive space left
for ($i = 0; $i < $j; $i++) {
        #uncomment next line to print debug information to console
        #print "Name:$mount[$i] Total:$total[$i]  Free:$freeGB[$i]GB  FreePct:$pct[$i]%\n";
        if ($pct[$i] < 5) {
                if ($pct[$i] < 2.5) {
                        $mailCommand = "mail -s \"$hostname major space crunch\" $mailcrit, $mailwarn";
                        open MAIL, "|$mailCommand";
                        print MAIL "$hostname has fallen below $freeGB[$i]GB on $mount[$i].";
                        close MAIL;
                } else {
                        $mailCommand = "mail -s \"$hostname minor space crunch\" $mailwarn";
                        open MAIL, "|$mailCommand";
                        print MAIL "$hostname has fallen below 5% free space on $mount[$i].\n";
                        print MAIL "Please fix this.  This script will mail every hour until it is fixed.\n";
                        close MAIL;
                }
        }
} #end for

