# serverusers.tcl
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
# This script shows how many users are connected on each server of the network
# its based on /links and /users, so the network must answer these commands
#
#  02/2015:	Nando | #RizonCafe #DALnetCafe #EFnetCafe
#
#  Usage:	!users			Show users information
#		!users refresh		Refresh users information
#		!users refresh all	Refresh users and links information	
##############################################################################################
##  ##                             Start Setup.                                         ##  ##
##############################################################################################
# Set your channel
set users_channelname "#YOUR_CHANNEL"
# Set the time in minuets to refresh users information.
set users_updateinterval "30"
# Set the command to show users information
set users_command "!users"
# End of configuration
bind pub - $users_command print_serverinfo
bind raw - 364 receive_links
bind raw - 365 receive_links_end
bind raw - 265 receive_localusers 
bind raw - 266 receive_globalusers
bind raw - 402 no_such_server
bind evnt - init-server start_links
# Initial
set users_working "0"
if {![string match *start_users* [timers]]} {
	timer $users_updateinterval start_users
}
# do_users_command_refresh_all
proc do_users_command_refresh_all {nick chan} {
	global users_channelname users_working
	if {$users_working == 1} {
		putserv "PRIVMSG $chan :$nick: I am currently busy, try again later."
	} else {
		do_links
		putserv "PRIVMSG $chan :$nick: Refreshing users and links information."
	}
}
# do_users_command_refresh
proc do_users_command_refresh {nick chan} {
	global users_channelname users_working
	if {$users_working == 1} {
		putserv "PRIVMSG $chan :$nick: I am currently busy, try again later."
	} else {
		putserv "PRIVMSG $chan :$nick: Refreshing users information."
		start_users 
	}
}
# init /links
proc start_links {type} {
	timer 10 do_links
}
# Retrieve /links
proc do_links {} {
	global server_name local_users users_working links_count
        if {[info exists server_name]} {
                unset server_name
        }
        if {[info exists local_users]} {
                unset local_users
        }
	set links_count 1
	set users_working 1
	putserv "LINKS"
} 
# Receive /links
proc receive_links {from keyword text} {
	global server_name links_count users_working
	if {$users_working == 1} {
		set server_name($links_count) [lindex [split $text] 1]
		incr links_count
	}
}
# End of /links information
proc receive_links_end {from keyword text} {
	global links_count users_working
	if {$users_working == 1} {
		incr links_count -1
		start_users
	} 
}
proc start_users {} {
	global server_name users_updateinterval local_users users_working server_count
	set users_working 1
	set server_count 1
	if {[info exists local_users]} {
		unset local_users
	}
	putserv "USERS $server_name($server_count)"
        if {![string match *start_users* [timers]]} {
                timer $users_updateinterval start_users
        }
}
# Get user information
proc receive_localusers {from keyword text} {
	global server_name server_count links_count local_users users_working
	
	if {$users_working == 1} {

		# didnt timeout, so killing the check_timeout
		if {[string match *check_timeout* [timers]]} {foreach timr [timers] {if {[string match *check_timeout* $timr]} {killtimer [lindex $timr 2]}}}

		set server $server_name($server_count)
		# remove the botnick from the result.
		if {[scan $text "%s %\[^\n\]" botnick text ] != 2 } { return 0 }
		# remove :
		regsub -all : $text "" text
		# identify text
		set scanrule {Current local users %d Max %d}
	
		if {[scan $text $scanrule clusers max] == 2} {
			set local_users($server) $clusers
		}
		if {$server_count < $links_count} {
			incr server_count
			putserv "USERS $server_name($server_count)"
			utimer 10 check_timeout 
		} else {
			set users_working 0	
		}
	}
}
# Set global users
proc receive_globalusers {from keyword text} {
	global users_working global_users
	if {$users_working == 1} {
                # remove the botnick from the result.
                if {[scan $text "%s %\[^\n\]" botnick text ] != 2 } { return 0 }
                # remove :
                regsub -all : $text "" text
                # identify text
                set scanrule {Current global users %d Max %d}	
                if {[scan $text $scanrule cgusers gmax] == 2} {
                        set global_users $cgusers
                }
	}
}
# Do it if the server send an error
proc no_such_server {from keyword text} {
	global server_name server_count links_count users_working
	if {$users_working == 1} {
		if {$server_count < $links_count} {	
			incr server_count
			putserv "USERS $server_name($server_count)"
			utimer 10 check_timeout
		} else {
			set users_working 0
		}
	}
}
# Do it if the server does not answer
proc check_timeout {} {
        global server_count links_count server_name users_working
	if {$users_working == 1} {
	        if {$server_count < $links_count} {
	                incr server_count
	                putserv "USERS $server_name($server_count)"
			utimer 10 check_timeout
	        } else {
	                set users_working 0
	        }
	}
}
# Print the results	
proc print_serverinfo {nick host hand chan arg} {
        global local_users users_channelname users_working global_users
	if {(([lsearch -exact [string tolower $users_channelname] [string tolower $chan]] != -1) || ($users_channelname == "*")) && (![matchattr $hand b])} {
		if {$users_working == 0} {
			set args [split $arg]
			if {([llength $args] == 2) && ([lindex $args 1] == "all")} { do_users_command_refresh_all $nick $chan }
			if {([llength $args] == 1) && ([lindex $args 0] == "refresh")} { do_users_command_refresh $nick $chan }
			if {([llength $args] == 0)} {
				if {[info exists local_users]} {
					foreach x [array names local_users] {
						set percent [expr int (100 * (double($local_users($x))) / double($global_users))]
						putserv "PRIVMSG $users_channelname :\[$x\]:\t\[Local Users:\002 $local_users($x)\002\]\t\[$percent%\]"
					}
				} else {
					putserv "PRIVMSG $users_channelname :$nick: No information available at this momment, try again later."
				}
			}	
		} else {
			putserv "PRIVMSG $users_channelname :$nick: I am currently busy, try again later."	
		}
	}
}
putlog "\002*Loaded* \002Users Information by Nando - #RizonCafe #DALnetCafe #EFnetCafe"
