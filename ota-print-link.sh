#!/bin/dash

# This script returns all download links to files matching a
# given SHA512 checksum of this ota-installation


## Check for correct input here.
[ -z "$1" ] || [ $# -ne 1 ] \
	&& echo "Usage: $0 <sha512sum of file>" \
	&& exit 1

[ $(echo "$1" | sed 's/[[^a-zA-Z0-9]|[^-]]*//g' | wc -m) -ne 129 ] \
	&& echo "Argument is not a sha512sum." \
	&& exit 1


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

[ -z "$ROOT_URL_OF_PUBLIC_DIR" ] || [ -z "$NAME_OF_FOLDER_SERVING_FILES" ] \
|| [ -z "$PATH_TO_FILE_DATABASE" ] \
	&& echo "Error: Configuration incomplete." \
	&& exit 1

[ ! -f $PATH_TO_FILE_DATABASE ] \
	&& echo "Error: $PATH_TO_FILE_DATABASE does not exist." \
	&& exit 1

[ -z "$MAX_DAYS_UNTIL_DELETION" ] \
	&& echo "Error: MAX_DAYS_UNTIL_DELETION is empty." \
	&& exit 1

[ $MAX_DAYS_UNTIL_DELETION -lt 0 ] \
	&& echo "Warning: MAX_DAYS_UNTIL_DELETION is set to $MAX_DAYS_UNTIL_DELETION"

## Save the current time in seconds from 1.1.1970
nowInSeconds=$(date +%s)

echo -n "Waiting for server response."

## It takes some time until the uploaded file is added to the directory
## on the server. That the file is present, will be indicated by the
## date of modification of the file dir on the server. 
while [ $nowInSeconds -ge $(stat -c %Y $PATH_TO_FILE_DIR) ]
do
	echo -n "." # Progress point
        sleep 5
done

## Final progress dot 
echo "."

## Give the last lines of the log file, to obtain the link.
[ $(grep -c $1 $PATH_TO_FILE_DATABASE) -eq 0 ]\
	&& echo "No files found." \
	&& tail $PATH_TO_LOG_FILE \
	&& exit 1

## List all files with the given checksum and their prospective deletion times
echo 'Link(s) to file(s):'
grep $1 $PATH_TO_FILE_DATABASE | while read fileInDatabase
do
	# Print the Link
	echo $fileInDatabase | awk -F ' ' '{print "'"$ROOT_URL_OF_PUBLIC_DIR$NAME_OF_FOLDER_SERVING_FILES/"'"$1"/"$2}'
	# Print the date until the link is valid
	[ $MAX_DAYS_UNTIL_DELETION -ge 0 ] \
		&& MAX_SECONDS_UNTIL_DELETION=$(($MAX_DAYS_UNTIL_DELETION*24*60*60)) \
		&& echo "Link is valid until "$(date -d @$(($(echo $fileInDatabase | awk -F ' ' '{print $4}') + $MAX_SECONDS_UNTIL_DELETION)))
done

# Check success of the process to obtain the links.
[ $? -ne 0 ] \
	&& echo "Error: Could not print link to file." \
	&& tail $PATH_TO_LOG_FILE \
	&& exit 1

exit 0
