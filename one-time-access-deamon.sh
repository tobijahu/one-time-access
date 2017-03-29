#!/bin/dash

CONFIGURATION_FILE=/opt/one-time-access/one-time-access.conf

# Include configuration file
if [ ! -e "$CONFIGURATION_FILE" ]
then
	echo "$CONFIGURATION_FILE does not exist."
	[ ! -w "$(dirname $CONFIGURATION_FILE)" ] \
		&& echo "Error: Could not create $CONFIGURATION_FILE\
$USER does not have write permissions to $(dirname $CONFIGURATION_FILE)" \
		&& exit 1
	echo "Creating configuration file at $CONFIGURATION_FILE"
	echo "## Configuration of one-time-access deamon
# Directories and paths
PATH_TO_FILE_DIR=\"/opt/one-time-access/file-dir\"
PATH_TO_FILE_DATABASE=/opt/one-time-access/database
NAME_OF_FOLDER_SERVING_FILES=one-time-access

# Webserver specific configuration
PATH_TO_PUBLIC_ROOT_DIR=\"/sites/vhosts/yourdomain.tld/www\"
ROOT_URL_OF_PUBLIC_DIR=\"https://www.yourdomain.tld/\"
WEBSERVER_ACCESS_LOGFILE=/var/log/lighttpd/yourdomain.tld.access.log

# General
MAX_DAYS_UNTIL_DELETION=14
PATH_TO_PID_FILE=/var/run/one-time-access.pid
LOGFILE=/var/log/one-time-access.log" > $CONFIGURATION_FILE
fi

[ ! -f "$CONFIGURATION_FILE" ] \
	&& echo "Error: $CONFIGURATION_FILE is not a file." \
	&& exit 1
[ ! -r "$CONFIGURATION_FILE" ] \
	&& echo "Error: $USER does not have read permissions to $CONFIGURATION_FILE" \
	&& exit 1

. "$CONFIGURATION_FILE"

for variable in "$PATH_TO_FILE_DIR" "$PATH_TO_PUBLIC_ROOT_DIR" "$NAME_OF_FOLDER_SERVING_FILES" "$MAX_DAYS_UNTIL_DELETION"
do
	[ -z "$variable" ] \
		&& echo "Warning: Configuration is incomplete. Some variables are empty."	
done

# Check pid file
[ -z "$PATH_TO_PID_FILE" ] \
	&& PATH_TO_PID_FILE=/var/run/one-time-access.pid
if [ -e "$PATH_TO_PID_FILE" ]
then
	ps -p $(cat $PATH_TO_PID_FILE) >/dev/null
	[ $? -eq 0 ] \
		&& echo "Error: Another instance of $0 is already running." \
		&& exit 1
fi
echo $$ > $PATH_TO_PID_FILE
[ $? -ne 0 ] \
	&& echo "Error: Could not write to pid file." \
	&& exit 1

# Preprocess max serving time
[ -z "$MAX_DAYS_UNTIL_DELETION" ] || [ $MAX_DAYS_UNTIL_DELETION -le 0 ] \
	&& MAX_DAYS_UNTIL_DELETION=14 \
	&& echo "MAX_DAYS_UNTIL_DELETION set to $MAX_DAYS_UNTIL_DELETION"
MAX_SECONDS_UNTIL_DELETION=$(($MAX_DAYS_UNTIL_DELETION*24*60*60))

[ -z "$WEBSERVER_ACCESS_LOGFILE" ] || [ ! -f "$WEBSERVER_ACCESS_LOGFILE" ] \
	&& echo "Error: WEBSERVER_ACCESS_LOGFILE is not set properly or is not a file.
Configure lighttpd to log accesses. Then define for example 
/var/log/lighttpd/access.log
as the desired logging file and define this path at 
$CONFIGURATION_FILE" \
	&& exit 1

# Check for user
# give commands to create user with specific name
# check, if the user can write to the necessary folders

## Preprocessing $PATH_TO_FILE_DIR
if [ ! -e "$PATH_TO_FILE_DIR" ] || [ ! -d "$PATH_TO_FILE_DIR" ]
then
	[ -z "$PATH_TO_FILE_DIR" ] \
		&& echo "Error: PATH_TO_FILE_DIR is not set or empty." \
		&& exit 1
	
	echo "Creating $PATH_TO_FILE_DIR"
	mkdir -p "$PATH_TO_FILE_DIR"
	[ $? -ne 0 ] \
		&& echo "Error: $PATH_TO_FILE_DIR was not created successfully. " \
		&& exit 1
fi

[ ! -r "$PATH_TO_FILE_DIR" ] || [ ! -w "$PATH_TO_FILE_DIR" ] \
	&& echo "Error: $USER requires write and read permission to $PATH_TO_FILE_DIR" \
	&& exit 1

## Preprocessing $PATH_TO_PUBLIC_ROOT_DIR
[ -z "$PATH_TO_PUBLIC_ROOT_DIR" ] \
	&& echo "Error: PATH_TO_PUBLIC_ROOT_DIR is not set or is empty." \
	&& exit 1

[ -z "$NAME_OF_FOLDER_SERVING_FILES" ] \
	&& NAME_OF_FOLDER_SERVING_FILES=one-time-access \
	&& echo "NAME_OF_FOLDER_SERVING_FILES set to $NAME_OF_FOLDER_SERVING_FILES"

if [ ! -e "$PATH_TO_PUBLIC_ROOT_DIR/$NAME_OF_FOLDER_SERVING_FILES" ] || [ ! -d "$PATH_TO_PUBLIC_ROOT_DIR/$NAME_OF_FOLDER_SERVING_FILES" ]
then
	echo "Creating $PATH_TO_PUBLIC_ROOT_DIR/$NAME_OF_FOLDER_SERVING_FILES"
	mkdir -p "$PATH_TO_PUBLIC_ROOT_DIR/$NAME_OF_FOLDER_SERVING_FILES"
	[ $? -ne 0 ] \
		&& echo "Error: $PATH_TO_PUBLIC_ROOT_DIR/$NAME_OF_FOLDER_SERVING_FILES was not created successfully. " \
		&& exit 1
fi

[ ! -r "$PATH_TO_PUBLIC_ROOT_DIR" ] || [ ! -w "$PATH_TO_PUBLIC_ROOT_DIR" ] \
	&& echo "Error: $USER requires write and read permission to $PATH_TO_PUBLIC_ROOT_DIR" \
	&& exit 1



DeleteFile()
{
	# $1 : path to file
	
	# Delete the file
	rm -r $(dirname $1)
	
	# remove the file from database
	sed -i '\|^'"$1"'|d' $PATH_TO_FILE_DATABASE
	
	# log the deletion
	echo "[$(date +%F\ %R)] Removed file: $1" >> $LOGFILE
	
	return 0
}

EchoNewFiles()
{
	# $PATH_TO_FILE_DATABASE
	# $PATH_TO_FILE_DIR
	
	find $PATH_TO_FILE_DIR | while read filePath
	do
		if [ -z "$filePath" ]
		then
			continue
		fi
		
		if [ ! -f $filePath ]
		then
			continue
		fi
		
		echo $filePath
	done
	return 0
}

AddNewFile()
{
	# $1 filePath (from EchoNewFiles)
	
	# Check, if $1 is empty
	if [ -z "$1" ]
	then
		return 1
	fi
	
	# replace some special characters with underscore i.e. _
	newBasename="$(basename "$1" | sed -e 's/[\\\(\)\{\}\&:%\$§\*<>~?!^°+\`\´=;#|,"]/_/g')"
	# do some individual replacements
	newBasename="$(echo "$newBasename" | sed -e 's/@/_at_/g')"
	# NTFS does not allow \ / : * ? " < > |
	# Unix allows some more
	
	# remove all unwelcome symbols from the new file name
	newBasename=$(echo "$newBasename" | sed -e 's/[[^0-9a-zA-Z\.\_]|[^-]]*//g')
	
	# replace capital letters with lowercase
	newBasename=$(echo "$newBasename" | awk '{print tolower($0)}')
	
	if [ "$PATH_TO_FILE_DIR/$newBasename" != "$1" ]
	then
		[ -e "$PATH_TO_FILE_DIR/$newBasename" ] \
			&& echo "Error: $PATH_TO_FILE_DIR/$newBasename already exists." \
			&& return 1
		
		# move and rename the file
		mv "$1" "$PATH_TO_FILE_DIR/$newBasename"
	fi
	
	# Generate a unique name for the file
	folderName=$(sha512sum "$PATH_TO_FILE_DIR/$newBasename" | awk -F ' ' '{print $1}')$(date +%s)
	
	# shorten the unique folderName by using the md5sum of the folderName
	folderName=$(echo $folderName | md5sum | awk -F ' ' '{print $1}')
	
	# shorten the unique name by removing the first and the last 4 symbols
	folderName=$(echo $folderName | sed -e 's/^.\{4\}\|.\{4\}$//g')
	
	# Note that sha512 seems to be faster than md5sum for example
	# Files could collide, but that does not matter so much
	newPath="$PATH_TO_PUBLIC_ROOT_DIR/$NAME_OF_FOLDER_SERVING_FILES/$folderName/$newBasename"
	
	# Move the file to the serving dir
	mkdir $(dirname $newPath)
	[ $? -ne 0 ] \
		&& return $?
	mv "$PATH_TO_FILE_DIR/$newBasename" "$newPath"
	[ $? -ne 0 ] \
		&& return $?
	
	# Add the new file with date to the database
	echo "$newPath $folderName $(date +%s)" >> $PATH_TO_FILE_DATABASE
	
	# Log the added file
	echo "[$(date +%F\ %R)] Added file for download: $newPath\n $ROOT_URL_OF_PUBLIC_DIR$NAME_OF_FOLDER_SERVING_FILES/$folderName/$newBasename" >> $LOGFILE
	return $?
}


#############################
# start loop
#

touch $PATH_TO_FILE_DATABASE
[ $? -ne 0 ] \
	&& echo "Error: $PATH_TO_FILE_DATABASE was not created successfully" \
	&& exit 1
	
for path in $PATH_TO_FILE_DIR $PATH_TO_FILE_DATABASE
do
	[ ! -e $path ] \
		&& echo "Error: $path does not exist." \
		&& return 1
done

lastChangeOfLogFile=$(stat -c %Y $WEBSERVER_ACCESS_LOGFILE)
lastRunOfAddNewFile=0

while true
do
	# process new files
	if [ $(stat -c %Y $PATH_TO_FILE_DIR ) -ge $lastRunOfAddNewFile ]
	then
		lastRunOfAddNewFile=$(date +%s)
		echo "$(EchoNewFiles)" | while read newFile
		do
			AddNewFile "$newFile"
		done
	fi
	
	# check for access
	for second in $(seq 1 6)
	do
		# Check the access log file of the webserver for changes/accesses
		if [ $(stat -c %Y $WEBSERVER_ACCESS_LOGFILE ) -eq $lastChangeOfLogFile ]
		then
			sleep 5
			continue
		fi
		
		# The log file was changed at the meantime, so save the moment when this was checked
		lastChangeOfLogFile=$(stat -c %Y $WEBSERVER_ACCESS_LOGFILE)
		
		# Delete all accessed files, based on database entries
		cat $PATH_TO_FILE_DATABASE | while read fileEntry
		do
			pathToThisFile=$(echo "$fileEntry" | awk -F ' ' '{print $1}')
			for logFile in $WEBSERVER_ACCESS_LOGFILE*
			do
				numberOfAccesses=$(grep -c "$(echo $fileEntry | awk -F ' ' '{print $2}')" $logFile)
				
				# Detect multiple downloads/accesses
				if [ $numberOfAccesses -gt 1 ]
				then
					# log the deletion
					echo "[$(date +%F\ %R)] $pathToThisFile was downloaded multiple times. Check your webserver's log files!" >> $LOGFILE
				fi
				
				# Delete accessed files
				if [ $numberOfAccesses -ne 0 ]
				then
					DeleteFile $pathToThisFile
				fi
			done
			
			# Delete old files
			if [ $(date +%s) -gt $(($(echo $fileEntry | awk -F ' ' '{print $3}') + $MAX_SECONDS_UNTIL_DELETION)) ]
			then
				echo "[$(date +%F\ %R)] Initiating deletion of file, since it is older than $MAX_SECONDS_UNTIL_DELETION seconds." >> $LOGFILE
				DeleteFile $pathToThisFile
			fi
		done
		sleep 5
	done
done
