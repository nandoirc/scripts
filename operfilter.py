# Filter k-lines and akills to a separeted window
# Nando@DALnet - 2020/08/17
# I am not a programmer and it is my first python script, so, dont think it is a good code ;)
import hexchat
import re
__module_name__ = 'snotice oper filter by Nando@DALnet'
__module_version__ = '1.0'
__module_description__ = 'redirect some snotices'


# Filter the strings from globals and notices
FilterFrom = ['Notice' , 'Global' , 'Spam', 'G-Line', 'Expiring', 'Permanent', 'from']

def snotice_filter(word, word_eol, user_data):
  
    ServerName = hexchat.get_info("server").split(".")[0]

    ServerTemp = hexchat.get_info("server").split(".")[-2:]
    ServerEnds = ".".join(ServerTemp)
 
    tab_name = ServerName + "(BANS)"
    tab_others = ServerName + "(NOTICES)"

    snotice_context = hexchat.find_context(channel=tab_name)
    snotice_others = hexchat.find_context(channel=tab_others)

    if re.search(ServerEnds, word[0]) and "@" not in word[0]:
        if snotice_context is None:
            hexchat.command('query -nofocus {0}'.format(tab_name))
            snotice_context = hexchat.find_context(channel=tab_name)
        if snotice_others is None:
            hexchat.command('query -nofocus {0}'.format(tab_others))
            snotice_others = hexchat.find_context(channel=tab_others) 
        if ('k-line' in word_eol[0] or 'akill' in word_eol[0] or 'autokill' in word_eol[0] or 'G-Line' in word_eol[0] or 'Z-Line' in word_eol[0] or 'AKILL' in word_eol[0]) and word[4] in FilterFrom:
            snotice_context.prnt("\00308»» \00309" + word[4] + "\017 " + word_eol[5])
            return hexchat.EAT_ALL
        elif ":***" not in word[3]:
            snotice_others.prnt("\00308»» \00309" + word[3].split(":")[1] + "\017 " + word_eol[4])
            return hexchat.EAT_ALL
        else:
            snotice_others.prnt("\00308»» \00309" + word[4] + "\017 " + word_eol[5])
            return hexchat.EAT_ALL
# DEBUG
#    else:
#    snotice_others.prnt(word_eol[0])

hexchat.hook_server("NOTICE", snotice_filter)

hexchat.prnt(__module_name__ + " version " + __module_version__ + " loaded")
