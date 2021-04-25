##############################################################################################
## Permissions of this strong copyleft license are conditioned on making available complete
## source code of licensed works and modifications, which include larger works using a
## licensed work, under the same license. Copyright and license notices must be preserved.
## Contributors provide an express grant of patent rights.
##############################################################################################
## This is a complete text flood protection
##
##  TextFlood.tcl
##
##  04/2021:	Original by Nando <nando@dal.net>	
##              https://github.com/nandoirc
##              I'm not a professional programmer, so don't expect a beautiful code :D
##
##  Features: Monologue kick, repeat kick and text flood kick
##
##  Thanks ComputerTech for the ideas
##
##############################################################################################
###### CONFIGURATION #####
#
# Enable channels
# Example: "#channel1 #channel2 #channel3"
set channels_enabled "#dalnetcafe #test"
#
# Configure the text flood tolerance lines per seconds
# "0:0" will disable
# Example: "4:10" -- the user can speak 4 lines in 10 seconds, will be kicked on the 5th 
set text_tolerance "4:10"
#
# Configure the repeat kick, it should be less or equal than the flood tolerance, if not, will not make sense
# "0" = disable, "2" = kick if talk 2 equal lines, "3" = kick if talk 3 equal lines and so on...
set text_repeat_kick "3"
#
# Configure monologue kick, if the user talks alone more than X lines,
# idependent of the time, the bot will kick -- it should be greater than 4 or 5
# Example "6", "0" will disable
set text_monologue_kick "6"
#
# Kick if is op? "0" = no, "1" = yes
set text_kick_op "0"
#
# Also ban?
# "0" = no, "1" = yes, "2" = only after the first kick
set text_ban "2"
# How long to ban (in minutes) -- "0" will be permanent
# Example: "60"
set text_ban_lifetime "60"
# What is the ban type?
#
# 0: *!user@full.host.tld
# 1: *!*user@full.host.tld
# 2: *!*@full.host.tld
# 3: *!*user@*.host.tld
# 4: *!*@*.host.tld
# 5: nick!user@full.host.tld
# 6: nick!*user@full.host.tld
# 7: nick!*@full.host.tld
# 8: nick!*user@*.host.tld
# 9: nick!*@*.host.tld
# Example: "1"
set text_ban_type "1"
#
# Set the kick message for text flood
set message_text_flood "Text Flood"
# Set the kick message for repeat text flood
set message_repeat_flood "Repeat Flood"
# Set the kick message for monologue
set message_monologue "WHO ARE YOU TALKING TO?"
#
##### END OF CONFIGURATION #####
#
# binds
bind pubm - * chan_flood
bind cron - "0 * * * *" clear_memory
#
# variables
set channels_enabled [string tolower $channels_enabled]
set last_message_nick ""
#
# text flood
proc chan_flood {nick uhost hand chan text} {
  global text_tolerance text_lines text_seconds line_count line_time botnick channels_enabled text_kick_op text_ban text_ban_lifetime text_ban_type nick_already_kicked text_repeat_count text_repeat_kick message_text_flood message_repeat_flood last_message_nick monologue_nick_count text_monologue_kick message_monologue

  set text_lines [lindex [split $text_tolerance :] 0]
  set text_seconds [lindex [split $text_tolerance :] 1] 

  if { (([lsearch -exact $channels_enabled $chan] >= 0) && ([isop $botnick $chan]) && ($text_lines > 1) && ($text_seconds > 1)) && (($text_kick_op == 1) || ([isop $nick $chan] == 0)) } {
      
    incr line_count($uhost:$chan) 
    set line_count_now $line_count($uhost:$chan)
    set line_time($uhost:$chan:$line_count_now) [unixtime]
    set kick_message $message_text_flood

    if { $text_repeat_kick > 1 } {
      set text2 [regsub -all { } [stripcodes abcgru $text] ""]
      incr text_repeat_count($uhost:$chan:$text2)
     
      if { $text_repeat_kick > $text_lines } { set text_repeat_kick $text_lines }
    
      if { $text_repeat_count($uhost:$chan:$text2) == $text_repeat_kick } { 
        set text_lines [expr {$text_repeat_kick - 1}]
        set kick_message $message_repeat_flood
      }
    }

    if {$text_monologue_kick > 3} {
      if {$last_message_nick == $nick} {
        incr monologue_nick_count($nick)
        } else {
        set monologue_nick_count($nick) 1 
      }
      if {$monologue_nick_count($nick) >= $text_monologue_kick} {
        set text_lines 0
        set kick_message $message_monologue
      }
    }

    set last_message_nick $nick

    if { $line_count($uhost:$chan) > $text_lines } {

      set first_message [expr {$line_count($uhost:$chan) - $text_lines}]

      if { [expr {$line_time($uhost:$chan:$line_count_now) - $line_time($uhost:$chan:$first_message)}] < $text_seconds } {

        set line_count($uhost:$chan) 0
        set monologue_nick_count($nick) 0 
        set text_repeat_count($uhost:$chan:$text2) 0
        
        switch $text_ban {

          0 {
            putnow "kick $chan $nick :$kick_message"
          }

          1 {
            newchanban $chan [maskhost $nick!$uhost $text_ban_type] $botnick "$nick Text Flood" $text_ban_lifetime
            putnow "kick $chan $nick :$kick_message"
          }

          2 {
            if { [info exists nick_already_kicked($uhost:$chan)] } {
              newchanban $chan [maskhost $nick!$uhost $text_ban_type] $botnick "$nick Text Flood" $text_ban_lifetime
              putnow "kick $chan $nick :$kick_message"
            } else {
              putnow "kick $chan $nick :$kick_message"
              set nick_already_kicked($uhost:$chan) yes
              }
          }
        }
      }
    }
  }
}
proc clear_memory {mi ho da mo ye} {
  global line_count line_time nick_already_kicked text_repeat_count monologue_nick_count
  unset line_count line_time nick_already_kicked text_repeat_count monologue_nick_count
}
