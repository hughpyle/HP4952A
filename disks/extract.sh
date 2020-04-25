#!/bin/bash

# with the bug400 version of lifutils https://github.com/bug400/lifutils
# (has different flags from the original)


dskconv -otype raw "$1" /tmp/tmpdisk.raw

echo "rm dir.txt" > /tmp/extract2.sh

lifdir -c /tmp/tmpdisk.raw \
   | sed s/[\?\(\)]//g \
   | awk -F, '{print "lifget -l -r /tmp/tmpdisk.raw " $1 " " $1 "." $2}' \
   | sed s/C403/APP/g \
   | sed s/C402/DAT/g \
   >> /tmp/extract2.sh

AWKCMD='{print $1 "   " $3}'
lifdir -c /tmp/tmpdisk.raw \
   | sed s/[\?\(\)]//g \
   | awk -F, -v ACMD="$AWKCMD" 'apos="'"'"'" {print "strings -s, " $1 "." $2 " | awk -F, " apos ACMD apos " >> dir.txt"}' \
   | sed s/C403/APP/g \
   | sed s/C402/DAT/g \
   >> /tmp/extract2.sh

echo "cat dir.txt" >> /tmp/extract2.sh

chmod +x /tmp/extract2.sh
cat /tmp/extract2.sh