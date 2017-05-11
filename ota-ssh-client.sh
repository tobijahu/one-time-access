#!/bin/sh

## The configuration file should be situated at the same dir as
## this script.
PATH_TO_CONFIGURATION_FILE=$(dirname $(readlink -f $0))/ota-ssh-client.conf
[ ! -e "$PATH_TO_CONFIGURATION_FILE" ] \
	&& echo "Error: Configuration file does not exist: $PATH_TO_CONFIGURATION_FILE" \
	&& exit 1
. $PATH_TO_CONFIGURATION_FILE

# Check the configuration on this client
for constant in "$SSH_PRIVATE_ID" "$SSH_REMOTE_HOST" "$PATH_TO_FILE_DIR_ON_SERVER" "$PRINT_LINK_SCRIPT"
do
	[ -z "$constant" ] \
		&& echo "Error: A constant at the configuration is empty." \
		&& exit 1
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

## Get sha512 checksum of file
sha512SumOfFile=$(sha512sum "$1" | awk -F ' ' '{print $1}')

## Open a dash shell on this machine and advise the ssh-agent 
## to cache the password of the used ssh-id $SSH_PRIVATE_ID for 
## 40 seconds. Then run the script, which is defined in the called
## string. 
ssh-agent -t 40 /bin/dash -c "ssh-add $SSH_PRIVATE_ID
# Copy the file to the server
scp -Cp \"$1\" \"$SSH_REMOTE_HOST:$(dirname $PATH_TO_FILE_DIR_ON_SERVER)/$(basename $PATH_TO_FILE_DIR_ON_SERVER)\"
# Obtain the link from the server
ssh $SSH_REMOTE_HOST /bin/dash $PRINT_LINK_SCRIPT $sha512SumOfFile
exit"

exit 0
