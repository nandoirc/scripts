# netinfo.tcl
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
# This script collects network information (top ten channels by users and users info)
# and puts then on the topic of a channel
#
#  Original:	channelinfo.tcl for eggdrop by Ford_Lawnmower irc.geekshed.net #Script-Help 
#
#  02/2015:	modified to collect the top ten channels by users and set the topic of a channel	
#		@Nando | #RizonCafe #DALnetCafe #EFnetCafe
#
#  02/2015	added lusers information
##############################################################################################
##  ##                             Start Setup.                                         ##  ##
##############################################################################################
# Set your channel
set channelinfo_channelname "#Your_channel"
# Set the time in minuets to update the topic here.
set networkinfo_updateinterval "60"
# to avoid the bot flood the server and collect a lot of channels,
# set a min of users the channels should have
set channelinfo_minusers "100"
##############################################################################################
##  ##                           End Setup.                                              ## ##
##############################################################################################  
set topic_topten ""
set list_running "0"
# Collect /list information
bind raw - 321 channelinfo_start
bind raw - 322 channelinfo_main
bind raw - 323 channelinfo_end
# Collect /lusers information
bind raw - 251 lusers_raw
bind raw - 252 lusers_raw
bind raw - 254 lusers_raw
# Add the timer
if {![string match *network_info* [timers]]} {
        timer $networkinfo_updateinterval network_info
}
# Do /list, /lusers and check the timer
proc network_info {} {
	global channelinfo_minusers networkinfo_updateinterval
        putserv "LIST >$channelinfo_minusers"
        if {![string match *network_info* [timers]]} {
        	timer $networkinfo_updateinterval network_info
        }
}
# Clear stuff before getting the list of channels
proc channelinfo_start {from keyword text} {
	global list_data list_running
	set list_running 1
	if {[info exists list_data]} {
		unset list_data
	}
}
# Get the /list
proc channelinfo_main {from keyword text} {
	global list_data 
	regsub -all -- "^:" "[lindex [split $text] 3]" "" text2
	set text [lreplace [split $text] 3 3 $text2]
	set list_data([lindex $text 2]) "[lindex $text 1]"
}
# Put the /list in order and set the topic
proc channelinfo_end {from keyword text} {
	global list_data channelinfo_channelname topic_topten list_running
	set count 1
        foreach text [lsort -decreasing [array names list_data]] {
		if {$count <= 10} {
                regsub -all -- ":$" "[join $list_data($text)]" "" text2
                lappend topten $count. $text2 ($text)
		incr count
		}
        }
	set topic_topten $topten
	putserv "LUSERS"
}
# Get /lusers informarion
proc lusers_raw {server keyword text} {
	global channelinfo_channelname lusers_info topic_topten list_running totalusers
	if {$list_running == 1} { 
	# remove the botnick from the result.
	if {[scan $text "%s %\[^\n\]" botnick text ] != 2 } { return 0 }
	# awkward...
	regsub -all : $text "" text
	# retrieve total amount of users from raw 251
	if { $keyword == 251 } {
		set scanrule {There are %d users and %d invisible on %d servers}
		if {[scan $text $scanrule vusers iusers servers] == 3 } {
		        set totalusers [expr $vusers + $iusers]
			set totalservers $servers
			set lusers_info "Users Online: $totalusers :: Servers Linked: $totalservers"
		} 
	}
	# retrieve opers online from raw 252
	if { $keyword == 252 } {
		set scanrule {%d :IRC Operators online}
		if {[scan $text $scanrule opers] == 1 } {
			set totalopers $opers
			append lusers_info " :: Opers Online: $totalopers"
		}	
	}
	# retrieve number of channels from raw 254
        if { $keyword == 254 } {
                set scanrule {%d :channels formed}
                if {[scan $text $scanrule channels] == 1 } {
                        set totalchannels $channels
			append lusers_info " :: Channels in use: $totalchannels"
#			putserv "PRIVMSG $channelinfo_channelname :$lusers_info"
			putserv "TOPIC $channelinfo_channelname :Top ten channels: $topic_topten :: $lusers_info"
			set list_running 0
                }
        }
	}
}
putlog "\002*Loaded* \002Network Information by Nando - #RizonCafe #DALnetCafe #EFnetCafe"
