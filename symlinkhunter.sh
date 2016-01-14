#!/bin/bash
#                                                          +----+----+----+----+
#                                                          |    |    |    |    |
# Author: Mark David Scott Cunningham                      | M  | D  | S  | C  |
#                                                          +----+----+----+----+
# Created: 2015-12-21
# Updated: 2016-01-14
#
# Purpose: Find accounts full of symlinks (indicating symlink hacks)
#

#Utility functions
dash(){ for ((i=1;i<=$1;i++)); do printf $2; done; }

# trap command to capture ^C and cleanup function
cleanup(){
  echo -e "\n\nClosing out scan and exiting.\nTo resume rerun: $0\n";
  rm -f $tmplog; exit;
  }
trap cleanup SIGINT SIGTERM

# Resume a partial scan
resume(){
  resuming=1;
  log=$(ls -1t ${logdir}/symlinkhunter_*.log | head -1);
  echo -e "Info :: Resuming Scan :: Continuing Scan_ID ($(basename $log .log | cut -d_ -f3))\n\n";
  }

# Output help and usage information
usage(){
  echo "
  Usage: $0 [OPTIONS]

  -f ... Fast Mode, set scan directory depth to 3
  -t ... Threshold count of links to be logged
  -u ... User list: <usr1,usr2,usr3...>

  -h ... Print this help information and quit.
  "; exit;
  }

# Initialize and count the number of /home/dirs
i=0; min=1; resuming=0; t=$(ls -d /home*/*/public_html/ | wc -l); userlist="/home*/*/public_html/";

# /usr/local/maldetect/sess/session.160111-0004.20837 (for reference)
logdir="/usr/local/symdetect"
tmplog="${logdir}/symlinkhunter.tmplog"
log="${logdir}/symlinkhunter_$(date +%F_%s).log"
if [[ ! -d $logdir ]]; then mkdir -p $logdir; fi

# Argument parsing
echo; while getopts fht:u: option; do
  case "${option}" in
    f) maxdepth="-maxdepth 3";
	echo "Info :: Fast Mode Enabled :: Setting link search depth to 3" ;;
    t) min="${OPTARG}";
	echo "Info :: Min Threshold Set :: Setting logging threshold to ${OPTARG} links" ;;
    u) userlist="$(for x in $(echo ${OPTARG} | sed 's/,/ /g'); do echo /home*/${x}/public_html/; done)" ;
	t=$(echo $userlist | wc -w) ;;
    h) usage ;;
  esac
done; echo

# Check if a previous scan was running, and resume
if [[ -f $(ls ${logdir}/*.user 2>/dev/null | head -1) ]]; then
  read -p "Interrupted scan detected. Continue previous scan? [yes/no]: " yn;
  if [[ $yn =~ y ]]; then resume; else rm -f ${logdir}/*.user; fi;
fi

# Start new log only if not resuming a previous scan
if [[ $resuming != '1' ]]; then
  # Check last runs of EA to see if Symlink Protection is enabled
  echo -e "$(dash 80 -)\n  Symlink Protection Status\n$(dash 40 -)\n" | tee $log;
  for logfile in /var/cpanel/easy/apache/runlog/build.*; do
    echo -n "$(grep SymlinkProtection $logfile | sed 's/1/Enabled/g;s/0/Disabled/g') :: ";
    stat $logfile | awk '/^Modify/ {print $2}';
  done | tail -5 | tee -a $log;

  # Start Symlink Hunting
  echo -e "\n$(dash 80 -)\n  Symlink Search Results\n$(dash 40 -)\n" | tee -a $log;
  echo -e "START_SCAN: $(date +%F_%T)\n" >> $log
fi

# Loop through the homedirs
for homedir in $userlist; do
  # Print scanning progress
  count=0; i=$(($i+1));
  username="$(echo $homedir | cut -d/ -f3)"
  printf "%-80s\r" "Scanning :: [$i/$t] $username ..."

  # Actually search symlinks and count them
  if [[ ! -f ${logdir}/${username}.user ]]; then
    find $homedir $maxdepth -type l -print > $tmplog
    count=$(wc -l < $tmplog)

    # Only print the results above the $min threshold
    if [[ $count -ge $min ]]; then
      # Count per subdirectory (verbose output sent to log)
      printf "%8s :: %-80s\n" "$count" "$homedir" | tee -a $log;
      printf "%-80s\r" "Generating Report :: $username ..."
      awk -F/ '$NF=""; {freq[$0]++} END {for (x in freq) {printf "%8s :: {SYM} ::%s\n",freq[x],x}}' $tmplog\
        | sed 's/\b /\//g; s/ home/ \/home/g; s/\/:/ :/g;' >> $log;
      echo >> $log;
    else
      printf "%-80s\r" " ";
    fi
    echo $i > ${logdir}/${username}.user
  fi
done;

printf "%-80s\r" " ";
echo -e "  END_SCAN: $(date +%F_%T)\n" >> $log

# Finish and print footer
echo -e "\n$(dash 80 -)\n  Scan log: $log\n$(dash 40 -)\n"

# Final log and variable cleanup
rm -f $tmplog ${logdir}/*.user
unset logdir tmplog log userlist username homedir maxdepth count
