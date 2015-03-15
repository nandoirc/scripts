# serveruptime.tcl
#
#	This script will hand out runts to people in specified channels.
#
# Copyright (c) 2015(s), Nando <nando at rizon.net>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
# v1.0 by Nando <nando at rizon.net>, Mar 15, 2015
##############################################################################################
# This script shows the uptime and version of each server of the network
# its based on /stats u, so the network must answer that command
#
#  02/2015:	@Nando | #RizonCafe #DALnetCafe #EFnetCafe
#
#	Usage:	!uptime
##############################################################################################
##  ##                             Start Setup.                                         ##  ##
##############################################################################################
# Set your channel
set uptime_channelname "#YOUR_CHANNEL"
# Set the time in minuets to refresh users information.
set uptime_updateinterval "1440"
# Set the command
set uptime_command "!uptime"
# End of configuration

bind evnt - init-server init_links
bind pub - $uptime_command print_uptimeinfo
bind pub - !up_refresh up_refresh
bind raw - 364 links_information
bind raw - 365 links_information_end
bind raw - 242 receive_uptimeinfo 
bind raw - 402 no_such_link
bind raw - 351 receive_version
# Initial
set l_running "0"
if {![string match *start_statsu* [timers]]} {
	timer $uptime_updateinterval start_statsu
}
# Uptime refresh
proc up_refresh {nick host hand chan text} {
	retrieve_links
}
# init /links
proc init_links {type} {
	timer 1 retrieve_links
}
# Retrieve /links
proc retrieve_links {} {
	global l_name l_running l_count
        if {[info exists l_name]} {
                unset l_name
        }
	set l_running 1
	set l_count "1"
	putserv "LINKS"
} 
# Receive /links
proc links_information {from keyword text} {
	global l_name l_count l_running
	if {$l_running == 1} {
		set l_name($l_count) [lindex [split $text] 1]
		incr l_count
	}
}
# End of /links information
proc links_information_end {from keyword text} {
	global l_count l_running
	if {$l_running == 1} {
		incr l_count -1
		start_statsu
		timer 3 start_version
	} 
}
# start /version servers
proc start_version {} {
	global l_name
	foreach i [array names l_name] {
		putserv "VERSION $l_name($i)"
	}
}
# start /stats u servers
proc start_statsu {} {
	global l_name l_running uptime_updateinterval s_uptime s_count
	set l_running 1
	set s_count 1
	if {[info exists s_uptime]} {
		unset s_uptime
	}
	putserv "STATS u $l_name(1)"
	if {![string match *start_statsu* [timers]]} {
	        timer $uptime_updateinterval start_statsu
	}
}
# Receive server version
proc receive_version {from keyword text} {
	global s_version
	set REG {[][/\\:*+?{}()<>|^$\\]}
	if {[scan $text "%s %\[^\n\]" botnick text ] != 2 } { return 0 }
	regsub -all $REG $text "" text
	set scanrule {%s %s %s %s %s %s}
	if {[scan $text $scanrule version server key1 key2 key3 key4] == 6} {
		set s_version($server) $version
	}
}

# Get uptime information
proc receive_uptimeinfo {from keyword text} {
	global uptime_channelname l_name s_count l_count s_uptime l_running
	
	if {$l_running == 1} {
		# didnt timeout, so killing the answer_timeout
		if {[string match *answer_timeout* [timers]]} {foreach timr [timers] {if {[string match *answer_timeout* $timr]} {killtimer [lindex $timr 2]}}}

		set server $l_name($s_count)
		# remove the botnick from the result.
		if {[scan $text "%s %\[^\n\]" botnick text ] != 2 } { return 0 }
		# remove :
		regsub -all : $text "" text
		# identify text
		set scanrule {Server Up %d days}
	
		if {[scan $text $scanrule uptime] == 1} {
			set s_uptime($server) $uptime
		}
		if {$s_count < $l_count} {
			incr s_count
			putserv "STATS u $l_name($s_count)"
			utimer 10 answer_timeout 
		} else {
			set l_running 0	
		}
	}
}
# Do it if the server send an error
proc no_such_link {from keyword text} {
	global l_name s_count uptime_channelname l_count l_running
	if {$l_running == 1} {
		if {$s_count < $l_count} {	
			incr s_count
			putserv "STATS u $l_name($s_count)"
			utimer 10 answer_timeout
		} else {
			set l_running 0
		}
	}
}
# Do it if the server does not answer
proc answer_timeout {} {
        global s_count l_count l_name uptime_channelname l_running
	if {$l_running == 1} {
	        if {$s_count < $l_count} {
	                incr s_count
	                putserv "STATS u $l_name($s_count)"
			utimer 10 answer_timeout
	        } else {
	                set l_running 0
	        }
	}
}
# Print the results	
proc print_uptimeinfo {nick host hand chan text} {
        global s_uptime uptime_channelname l_running s_version
	if {(([lsearch -exact [string tolower $uptime_channelname] [string tolower $chan]] != -1) || ($uptime_channelname == "*")) && (![matchattr $hand b])} {
		if {$l_running == 0} {
			if {[info exists s_uptime]} {
				foreach x [array names s_uptime] {
					if {[info exists s_version($x)]} { 
						putserv "PRIVMSG $uptime_channelname :\[$x\]\t\[Uptime:\002 $s_uptime($x)\002 days\]\t\[Version: $s_version($x)\]"
					} else {
						putserv "PRIVMSG $uptime_channelname :\[$x\]\t\[Uptime:\002 $s_uptime($x)\002 days\]\t\[Version: no info\]"
					}
				}
			} else {
				putserv "PRIVMSG $uptime_channelname :$nick: No information available at this momment, try again later."
			}
			
		} else {
			putserv "PRIVMSG $uptime_channelname :$nick: I am currently busy, try again later."	
		}
	}
}
putlog "\002*Loaded* \002Uptime Information by Nando - #RizonCafe #DALnetCafe #EFnetCafe"
