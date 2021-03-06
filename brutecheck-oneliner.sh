#							   +----+----+----+----+
# 							   |    |    |    |    |
# Author: Mark David Scott Cunningham			   | M  | D  | S  | C  |
# 							   +----+----+----+----+
# Created: 2014-11-29
# Updated: 2015-04-19
#
#
#!/bin/bash

# Check for site's being brute forced (can search for a particular request)
shopt -s extglob; echo; read -p 'Search: ' SEARCH; echo; for x in $(grep -Ec "POST.*${SEARCH}" /usr/local/apache/domlogs/*/*[^_log] 2> /dev/null | grep -E [0-9]{4}$ | cut -d/ -f7 | cut -d: -f1); do echo $x; grep -E "$SEARCH" /usr/local/apache/domlogs/*/$x | awk '{freq[$1]++} END {for (x in freq) {printf "%8s %s\n",freq[x],x}}' | grep -E '[0-9]{3}\ '; echo; done
