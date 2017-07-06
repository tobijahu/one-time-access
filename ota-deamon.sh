#!/bin/dash

# one-time-access deamon
#
# This deamon watches $PATH_TO_FILE_DIR for new files, which should be served
# by a webserver (e.g. lighttpd) under a certain URL. This URL is desired to 
# be hard to guess.
# After a file was downloaded once, the deamon will delete the served file by
# reading the access logs of the webserver i.e. $WEBSERVER_ACCESS_LOGFILE.
# Links to new files may be found at $LOGFILE. If necessary, this should be 
# adjusted to provide the link via jabber, email or similar.

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

# After all security checks are done, th configuration file can safely be
# included.
. "$CONFIGURATION_FILE"


## Checking for access log file of the webserver application
[ -z "$WEBSERVER_ACCESS_LOGFILE" ] || [ ! -f "$WEBSERVER_ACCESS_LOGFILE" ] \
	&& echo "Error: WEBSERVER_ACCESS_LOGFILE is not set properly or is not a file.
Configure lighttpd to log accesses. Then define for example 
/var/log/lighttpd/access.log
as the desired logging file and define this path at 
$CONFIGURATION_FILE" \
	&& exit 1

## Check permissions for a specific file to be created and to be writable
CheckForTempFilePermissions()
{
	# $1 : path to file
	
	[ ! -d "$(dirname $1)" ] \
		&& echo "Error: $(dirname $1) does not exist or is not a directory." \
		&& return 1
	[ ! -w "$(dirname $1)" ] \
		&& echo "Error: $(dirname $1) is not writeable by $USER." \
		&& return 1
	return 0
}

## Check, if $OTA_TMP_FILE can be used accordingly
CheckForTempFilePermissions "$OTA_TMP_FILE"
[ $? -ne 0 ] && exit 1

## Processing $PATH_TO_PID_FILE
if [ "$1" != "systemd" ]
then
	CheckForTempFilePermissions "$PATH_TO_PID_FILE"
	[ $? -ne 0 ] && exit 1
	# The deamon should only be running once, otherwise it may produce errors.
	if [ -e "$PATH_TO_PID_FILE" ]
	then
		ps -p $(cat $PATH_TO_PID_FILE) >/dev/null
		[ $? -eq 0 ] \
			&& echo "Error: Another instance of $0 is already running." \
			&& exit 1
	fi
	echo $$ > $PATH_TO_PID_FILE
	[ $? -ne 0 ] \
		&& echo "Error: Could not write to pid file $PATH_TO_PID_FILE." \
		&& exit 1
fi


## Preprocess max serving time
[ -z "$MAX_DAYS_UNTIL_DELETION" ] || [ $MAX_DAYS_UNTIL_DELETION -le 0 ] \
	&& MAX_DAYS_UNTIL_DELETION=14 \
	&& echo "MAX_DAYS_UNTIL_DELETION is not set or not set properly." \
	&& echo "Setting MAX_DAYS_UNTIL_DELETION to $MAX_DAYS_UNTIL_DELETION"
MAX_SECONDS_UNTIL_DELETION=$(($MAX_DAYS_UNTIL_DELETION*24*60*60))


## Preprocessing $PATH_TO_FILE_DIR
[ -z "$PATH_TO_FILE_DIR" ] \
	&& echo "Error: PATH_TO_FILE_DIR is not set or empty." \
	&& exit 1

## Preprocessing $PATH_TO_PUBLIC_ROOT_DIR
[ -z "$PATH_TO_PUBLIC_ROOT_DIR" ] \
	&& echo "Error: PATH_TO_PUBLIC_ROOT_DIR is not set or is empty." \
	&& exit 1
[ ! -d "$PATH_TO_PUBLIC_ROOT_DIR" ] \
	&& echo "Error: PATH_TO_PUBLIC_ROOT_DIR does not exist: $PATH_TO_PUBLIC_ROOT_DIR" \
	&& exit 1

## Processing move-file lock file
[ -z "$PATH_TO_MOVE_LOCK" ] \
	&& echo "Error: PATH_TO_MOVE_LOCK is not set or is empty." \
        && exit 1
if [ -e "$PATH_TO_MOVE_LOCK" ]
then
	echo "Warning: $PATH_TO_MOVE_LOCK exists. Removing file."
	rm -f $PATH_TO_MOVE_LOCK
	[ $? -ne 0 ] \
		&& echo "Error: Cannot delete $PATH_TO_MOVE_LOCK." \
		&& exit 1
fi

## Preprocessing $NAME_OF_FOLDER_SERVING_FILES
# This name will be part of the link to the file and thus visible to others. 
# If desired, this name can be adjusted.
[ -z "$NAME_OF_FOLDER_SERVING_FILES" ] \
	&& NAME_OF_FOLDER_SERVING_FILES=ota \
	&& echo "NAME_OF_FOLDER_SERVING_FILES set to $NAME_OF_FOLDER_SERVING_FILES"
[ "$NAME_OF_FOLDER_SERVING_FILES" != "$(basename $NAME_OF_FOLDER_SERVING_FILES)" ] \
	&& NAME_OF_FOLDER_SERVING_FILES="$(basename $NAME_OF_FOLDER_SERVING_FILES)" \
	&& echo "NAME_OF_FOLDER_SERVING_FILES set to $NAME_OF_FOLDER_SERVING_FILES"

## Check, if all necessary objects are correctly installed.
for file in "$PATH_TO_FILE_DATABASE" "$LOGFILE"
do
	if [ ! -e $file ]
	then
		touch $file
		[ $? -ne 0 ] \
			&& echo "Error: $file was not created successfully" \
			&& exit 1
	fi
	
	[ ! -r "$file" ] || [ ! -w "$file" ] \
		&& echo "Error: $USER requires write and read permission to $file" \
		&& exit 1
done	
for folder in "$PATH_TO_FILE_DIR" "$(dirname $PATH_TO_PUBLIC_ROOT_DIR)/$(basename $PATH_TO_PUBLIC_ROOT_DIR)/$NAME_OF_FOLDER_SERVING_FILES"
do
	mkdir -p "$folder"
	[ $? -ne 0 ] \
		&& echo "Error: $folder was not created successfully." \
		&& exit 1
	[ ! -r "$folder" ] || [ ! -w "$folder" ] \
		&& echo "Error: $USER requires write and read permission to $folder" \
		&& exit 1
done



DeleteFile()
{
	# $1 : path of file
	# $2 : foldername identifier
	
	# $OTA_TMP_FILE
	# $PATH_TO_FILE_DATABASE
	# $LOGFILE
	
	[ -z "$1" ] || [ -z "$2" ] \
		&& return 1
	
	# Delete the file
	rm -rf $(dirname $1)
	if [ $? -eq 0 ]
	then
		delExitCode=0
		# remove the file from database
		sed '\|^'"$2"'|d' $PATH_TO_FILE_DATABASE > $OTA_TMP_FILE
		delExitCode=$(($delExitCode + $?))
		cat $OTA_TMP_FILE > $PATH_TO_FILE_DATABASE
		delExitCode=$(($delExitCode + $?))
		rm $OTA_TMP_FILE
		delExitCode=$(($delExitCode + $?))
		
		# log the deletion
		if [ $delExitCode -ne 0 ]
		then
			echo "[$(date +%F\ %R)] Error: Could not delete file from database: $1" >> $LOGFILE
		else
			echo "[$(date +%F\ %R)] Removed file: $1" >> $LOGFILE
		fi
	else
		# log the deletion
		echo "[$(date +%F\ %R)] Error: Could not remove file: $1" >> $LOGFILE
	fi
	
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

GetRandomFolderName()
{
	## Give a folder name using the output of /dev/urandom
	
	cat /dev/urandom | tr -cd 'a-z0-9' | head -c 32
	return $?
}

GetFolderNameViaCurrentTimeAndChecksum()
{
	# $1 checksum of file
	
	## Give a folder name based on the hash of the file and the current time
	
	[ -z "$1" ] \
		&& return 1
	
	# To be able to serve the files with idenitcal names twice, the seconds since 1970 are used
	# to provide a unique, hard-to-guess folder name
	string=$1$(date +%s)
	
	# If two files with the same file name should be served at the same time $folderName
	# differs only in the last characters/digits. In this case it is better to have a whole
	# new checksum, to do the next step of shortening afterwards.
	string=$(echo $string | sha512sum | awk -F ' ' '{print $1}')
	
	# The folder name is now 129 symbols long. To prevent that somebody guesses this string, this 
	# length is not necessary. So it should be shortened for practical reasons. Still after
	# shortening it would be not probable that this folder already exists. Still if it exists, it 
	# should not be probable that a file with the same name/basename already exists.
	string=$(echo $string | sed -e 's/^.\{48\}\|.\{49\}$//g')
	# Now folderName has a length of 32.
	
	[ ! -z "$string" ] \
		&& echo "$string" \
		&& return 0
	return 1
}

AddNewFile()
{
	# $1 filePath (from EchoNewFiles)
	
	# $PATH_TO_FILE_DIR
	# $WEBSERVER_ACCESS_LOGFILE
	# $PATH_TO_PUBLIC_ROOT_DIR
	# $NAME_OF_FOLDER_SERVING_FILES
	# $LOGFILE
	
	# Check, if $1 is empty
	if [ -z "$1" ]
	then
		return 1
	fi
	
	# Replace some special characters with underscore i.e. _
	newBasename="$(basename "$1" | sed -e 's/[\\\(\)\{\}\&:%\$§\*<>~?!^°+\`\´=;#|,"]/_/g')"
	# Do some individual replacements
	newBasename="$(echo "$newBasename" | sed -e 's/@/_at_/g')"
	# NTFS does not allow \ / : * ? " < > |
	# Unix filesystems allow some more
	
	# Remove all unwelcome symbols from the new file name
	newBasename=$(echo "$newBasename" | sed -e 's/[[^0-9a-zA-Z\.\_]|[^-]]*//g')
	
	# Replace capital letters with lowercase
	newBasename=$(echo "$newBasename" | awk '{print tolower($0)}')
	
	if [ "$PATH_TO_FILE_DIR/$newBasename" != "$1" ]
	then
		[ -e "$PATH_TO_FILE_DIR/$newBasename" ] \
			&& echo "Error: $PATH_TO_FILE_DIR/$newBasename already exists." \
			&& return 1
		
		# (Move and) rename the file
		mv "$1" "$PATH_TO_FILE_DIR/$newBasename"
	fi
	
	# Get a Checksum of the file. This is primarily to recognize it in the later process.
	# sha512 is as fast as md5sum. 
	sha512SumOfFile=$(sha512sum "$PATH_TO_FILE_DIR/$newBasename" | awk -F ' ' '{print $1}')
	
	folderName=""
	while [ -z "$folderName" ]
	do
		
		# Create a folder name
		#folderName=$(GetFolderNameViaCurrentTimeAndChecksum "$sha512SumOfFile")
		folderName=$(GetRandomFolderName)
		
		# But since in the whole process the folder (not the file) will be selected for deletetion, 
		# the folder name should be a unique identifier. So here we go with checking and testing for 
		# uniqueness. 
		[ $(grep -c $folderName $PATH_TO_FILE_DATABASE) -ne 0 ] \
			&& folderName=""
		
		for logfile in $WEBSERVER_ACCESS_LOGFILE*
		do
			[ $(grep -c $folderName $logfile) -ne 0 ] && folderName=""
		done
		
		# The elapsed time will be different for each circle of the while loop and so does $folderName.
	done
	
	# Now the path is complete
	newPath="$PATH_TO_PUBLIC_ROOT_DIR/$NAME_OF_FOLDER_SERVING_FILES/$folderName/$newBasename"
	
	# Move the file to the serving dir
	mkdir $(dirname $newPath)
	[ $? -ne 0 ] \
		&& return $?
	mv "$PATH_TO_FILE_DIR/$newBasename" "$newPath"
	[ $? -ne 0 ] \
		&& return $?
	
	# Add the new file with date to the database
	echo "$folderName $(basename $newPath) $sha512SumOfFile $(date +%s)" >> $PATH_TO_FILE_DATABASE
	
	# Log the added file and provide a URL to the file
	echo "[$(date +%F\ %R)] Added file for download: $newPath" >> $LOGFILE
	return $?
}



#############################
# start loop
#


lastChangeOfLogFile=$(stat -c %Y $WEBSERVER_ACCESS_LOGFILE)
lastRunOfAddNewFile=0

while true
do
	# process new files
	# check, if the folder $PATH_TO_FILE_DIR was changed -- for example by adding a new file to it.
	if [ $(stat -c %Y $PATH_TO_FILE_DIR ) -ge $lastRunOfAddNewFile ]
	then
		if [ ! -e "$PATH_TO_MOVE_LOCK" ]
		then
			# save current time in seconds
			lastRunOfAddNewFile=$(date +%s)
			# serve all new files from $PATH_TO_FILE_DIR under a hard-to-guess link
			EchoNewFiles | while read newFile
			do
				AddNewFile "$newFile"
			done
		else
			echo "[$(date +%F\ %R)] Lock file for move process exists. Skipping to \
add new files" >> $LOGFILE
		fi
	fi
	
	# check for access each 5 seconds and add new files after 30 seconds
	for cycle in $(seq 1 6)
	do
		# Check the access log file of the webserver for changes/accesses
		if [ $(stat -c %Y $WEBSERVER_ACCESS_LOGFILE ) -eq $lastChangeOfLogFile ]
		then
			sleep 5
			continue
		fi
		
		# The log file was changed at the meantime, so save the moment when this was checked
		lastChangeOfLogFile=$(stat -c %Y $WEBSERVER_ACCESS_LOGFILE)
		
		# Delete all accessed files, based on database entries. 
		# If there are no files listed, the deamon does not have to do anything
		cat $PATH_TO_FILE_DATABASE | while read fileEntry
		do
			pathToThisFile=$PATH_TO_PUBLIC_ROOT_DIR/$NAME_OF_FOLDER_SERVING_FILES/
			pathToThisFile=$pathToThisFile$(echo "$fileEntry" | awk -F ' ' '{print $1"/"$2}')
			for logFile in $WEBSERVER_ACCESS_LOGFILE*
			do
				thisFileName="$(echo $fileEntry| awk -F ' ' '{print $2}')"
				thisFileFolder="$(echo $fileEntry| awk -F ' ' '{print $1}')"
				thisFilePath="/$NAME_OF_FOLDER_SERVING_FILES/$thisFileFolder/$thisFileName"
				# Note that a line in the access log is expected to look as the following
				# 87.253.189.229 206 303793 490 304169 /ota/y9rhjf1nrzelyyafz0thiyri1qb6a0nh/bewerbung-data-scientist-tm.pdf [05/Jul/2017:11:36:08 +0000] "https://mettenbr.ink/ota/y9rhjf1nrzelyyafz0thiyri1qb6a0nh/bewerbung-data-scientist-tm.pdf" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36" 
				numberOfAccesses=$(grep -c " $thisFilePath " $logFile)
#				# Old method
#				numberOfAccesses=$(awk -F ' ' '{print $}' | grep -c "$(echo $fileEntry \
#					| awk -F ' ' '{print $1}')" $logFile)
				
				# Detect and log multiple downloads/accesses
				if [ $numberOfAccesses -gt 1 ]
				then
					# log the deletion
					echo "[$(date +%F\ %R)] $pathToThisFile was downloaded multiple\
 times. Check your webserver's log files!" >> $LOGFILE
				fi
				
				# Delete accessed files
				if [ $numberOfAccesses -ne 0 ]
				then
					DeleteFile $pathToThisFile $(echo "$fileEntry" | awk -F ' ' '{print $1}')
				fi
			done
			
			# Delete old files
			if [ $(date +%s) -gt $(($(echo $fileEntry \
				| awk -F ' ' '{print $4}') + $MAX_SECONDS_UNTIL_DELETION)) ]
			then
				echo "[$(date +%F\ %R)] Initiating deletion of file, since it is older \
than $MAX_SECONDS_UNTIL_DELETION seconds." >> $LOGFILE
				DeleteFile $pathToThisFile $(echo "$fileEntry" | awk -F ' ' '{print $1}')
			fi
		done
		sleep 5
	done
done
