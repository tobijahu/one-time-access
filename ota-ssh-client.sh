#!/bin/sh

## The configuration file should be situated at the same dir as
## this script.
PATH_TO_CONFIGURATION_FILE=$(dirname $(readlink -f $0))/ota-ssh-client.conf
[ ! -e "$PATH_TO_CONFIGURATION_FILE" ] \
	&& echo "Error: Configuration file does not exist: $PATH_TO_CONFIGURATION_FILE" \
	&& exit 1
. $PATH_TO_CONFIGURATION_FILE

for constant in "$SSH_PRIVATE_ID" "$SSH_REMOTE_HOST" "$PATH_TO_FILE_DIR_ON_SERVER" \
"$PATH_TO_LOG_FILE_ON_SERVER"
do
	[ -z "$constant" ] \
		&& echo "Error: A constant at the configuration is empty."
done

if [ $# -ne 1 ]
then
	echo "Usage: $(basename $0) <file-name>"
	exit 1
fi

## Validate the path to the file that is selected for upload.
[ ! -e "$1" ] \
	&& echo "Error: $1 does not exist." \
	&& exit 1

[ ! -f "$1" ] \
	&& echo "Error: $1 is not a file." \
	&& exit 1

## Open a dash shell on this machine and advise the ssh-agent 
## to cache the password of the used ssh-id $SSH_PRIVATE_ID for 
## 40 seconds. Then run the script, which is defined in the called
## string. 
ssh-agent -t 40 /bin/dash -c "ssh-add $SSH_PRIVATE_ID
# Copy the file to the server
scp -Cp \"$1\" $SSH_REMOTE_HOST:$PATH_TO_FILE_DIR_ON_SERVER/
# Save the current time in seconds from 1.1.1970
nowInSeconds=\$(ssh $SSH_REMOTE_HOST date +%s)
# It takes some time until the uploaded file is added to the directory
# on the server. That the file is present, will be indicated by the
# date of modification of the file dir on the server. 
while [ \$nowInSeconds -ge \$(ssh $SSH_REMOTE_HOST stat -c %Y $PATH_TO_FILE_DIR_ON_SERVER) ]
do
	sleep 5
done
# Then give the last lines of the log file, to obtain the link.
ssh $SSH_REMOTE_HOST tail $PATH_TO_LOG_FILE_ON_SERVER
exit"

exit 0
