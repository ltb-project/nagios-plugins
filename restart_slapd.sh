#!/bin/sh

# Restart OpenLDAP if LDAP service in in hard state

# Configuration
SLAPD_PID_FILE="/var/run/slapd/slapd.pid"
SLAPD_START_CMD="/etc/init.d/slapd start"
TIMEOUT="10"

# Main
usage() {
	echo "This script is an event handler designed for Nagios"
        echo "Usage: $0 \$SERVICESTATE$ \$STATETYPE$ \$SERVICEATTEMPT$"
	exit 1
}

restart_slapd() {

	# Stop
	if [ ! -r $SLAPD_PID_FILE ]
	then
		echo "Can't read PID file $SLAPD_PID_FILE"
		exit 1
	else
		PID=`cat $SLAPD_PID_FILE`
		kill -INT $PID

		# Waiting loop
		i=0
		while [ -e /proc/$PID ]
			do
			if [ $i -eq $TIMEOUT ]
			then
				# Kill with force
				kill -KILL $PID
			fi
			i=`expr $i + 1`
			sleep 1
			done

	echo "OpenLDAP stopped after $i seconds"
	fi
	
	# Start
	$SLAPD_START_CMD
}

case $1 in
OK)
;;
WARNING)
;;
UNKNOWN)
;;
CRITICAL)
	case $2 in
	SOFT)
	;;
	HARD)
		restart_slapd
	;;
	*)
		usage
	;;
	esac
;;
*)
	usage
;;
esac

exit 0
