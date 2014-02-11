/*
 * plugin for TableSorter.js to sort "Timer" column properly in UPS
 * tablesorter.com/docs/example-parsers.html
 * 
 * Problem:
 *
 * Timer
 *  23h45m
 *  24m7s
 *  1d17h
 *
 *  Timer column sorts alphabetically and not by time
 */

var timerRegex = /^((\d+)d)?((\d+)h)?((\d+)m)?((\d)+s)?$/;

$.tablesorter.addParser({
		id: 'upstimer',
		is: function(s) {
				var timerMatch = timerRegex.exec(s);
				var atLeastOneTimer = /\d+s|\d+m|\d+h|\d+d/;
				var atLeastOneTimerMatch = atLeastOneTimer.exec(s);
				return timerMatch != null && atLeastOneTimerMatch != null;
		},
		format: function(s) {
				if (s === "N/A") {
						return 24*60*60*365*3; // Define "N/A" as a very large timer
				}

				// convert timer string into seconds-until-auction-done
				var match = timerRegex.exec(s);
				// match[0] = entire match, [2] = days integer, [4] = hours integer, [6] = minutes integer, [8] = seconds integer
				var secondsRemaining = 0;
				if (match[2] != null) { secondsRemaining += parseInt(match[2]) * 24 * 60 * 60; }
				if (match[4] != null) { secondsRemaining += parseInt(match[4]) * 60 * 60; }
				if (match[6] != null) { secondsRemaining += parseInt(match[6]) * 60; }
				if (match[8] != null) { secondsRemaining += parseInt(match[8]); }
				return secondsRemaining;
		},
		type: 'numeric'
});
