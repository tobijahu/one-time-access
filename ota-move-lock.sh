#!/bin/dash

# This script creates or removes a lock file on this server to 
# prevent the main script from moving files / adding files to 
# the database


CONFIGURATION_FILE=/opt/one-time-access/ota-deamon.conf

# Check, if $CONFIGURATION_FILE exists. 
[ ! -f "$CONFIGURATION_FILE" ] || [ ! -e "$CONFIGURATION_FILE" ] \
	&& echo "Error: $CONFIGURATION_FILE does not exist or is not a file." \
	&& exit 1

# Check permissions
for file in "$0" "$CONFIGURATION_FILE"
do
	[ $(stat -c %U "$file") != "root" ] \
		&& echo "Error: root should be owner of $file. To fix this run the following as root" \
		&& echo "chown root:root $file" \
		&& exit 1
done
[ $(stat -c %a "$0") -ne 755 ] \
	&& echo "Error: File permissions of $0 are not 755. \
Execute the following as root to fix this." \
	&& echo "chmod 755 $0" \
	&& exit 1
[ $(stat -c %a "$CONFIGURATION_FILE") -ne 644 ] \
	&& echo "Error: File permissions of $CONFIGURATION_FILE are not 644. \
Execute the following as root to fix this." \
	&& echo "chmod 644 $CONFIGURATION_FILE" \
	&& exit 1
[ "$USER" = "root" ] \
	&& echo "Warning: For security reasons it might be better to run this deamon as \
another user than root."

# After all security checks are done, the configuration file can safely be
# included.
. "$CONFIGURATION_FILE"


## Processing move-file lock file
[ -z "$PATH_TO_MOVE_LOCK" ] \
	&& echo "Error: PATH_TO_MOVE_LOCK is not set or is empty." \
        && exit 1

Usage()
{
	echo "Usage: $(basename "$0") create
or
$(basename "$0") remove"
	exit 1
}

CreateMoveLockFile()
{
	# $PATH_TO_MOVE_LOCK
	
	# Check, if the lock file already exists
	if [ -e "$PATH_TO_MOVE_LOCK" ]
	then
		echo "Warning: $PATH_TO_MOVE_LOCK already exists."
		exit 0
	else
		## Create the lock file
		touch $PATH_TO_MOVE_LOCK
		exitCode=$?
		[ $exitCode -ne 0 ] \
			&& echo "Error: Cannot create $PATH_TO_MOVE_LOCK."
		exit $exitCode
	fi
}

RemoveMoveLockFile()
{
	# $PATH_TO_MOVE_LOCK
	
	# Check, if move-lock file exists. If so, remove it
	if [ -e "$PATH_TO_MOVE_LOCK" ] 
	then
		rm $PATH_TO_MOVE_LOCK
		exit $?
	else
		echo "Warning: $PATH_TO_MOVE_LOCK does not exists."
		exit 1
	fi
}

## Execute the given action
if [ "$1" = "create" ]
then
	CreateMoveLockFile
elif [ "$1" = "remove" ]
then
	RemoveMoveLockFile
else
	Usage
fi

