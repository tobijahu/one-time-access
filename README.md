# one-time-access
In connection with a webserver (lighttpd), this deamon serves files under an unique hard-to-guess url until first access. 

The general usecase is a single user who wants to assure, that a file was only downloaded once.

## How it works
The deamon, written in dash/shell, monitors a specific folder for files to be then moved to a unique path to let lighttpd serve the file under a unique url. The deamon monitors the access file of the webserver to detected, if a file was accessed. If so, it will be deleted. If the file was not accessed for 14 days, it will be deleted anyway.

To serve files using this script/deamon from a remote machine, put files into the monitored folder via the one-time-access-client script (introduced below) finally this will return the link to the file automatically to the user. This script requires a working ssh setup (including ssh-agent) from the client to the server.

Otherwise files may be transfered for example via ssh/scp, sftp, samba or similar. An interface for this usecase to send the link via email or jabber could be a great idea, but is not yet implemented.

At the moment weblinks can be found at the log files. Which may be enhanced soon. So currently the usecase is dedicated to a single user or the administrator only.

## Installation
First install the deamon script on your server. Then install the client script on your client machine.

### Install the deamon
Clone the repository to your current directory using git.

```$ git clone https://github.com/tobijahu/one-time-access.git one-time-access```

Execute the following commands as root user. This will copy the content of the cloned repository to `/opt/one-time-access`, create a new user `ota-deamon` to run the deamon script, add ota-deamon to the group of your webserver user (e.g. `www-data`) and create all necessary files and folders. 

```
cp -a one-time-access /opt/
chmod 755 /opt/one-time-access/one-time-access-deamon.sh
useradd ota-deamon
usermod -a -G www-data ota-deamon
mkdir /opt/one-time-access/file-dir
chown ota-deamon:ota-deamon /opt/one-time-access/file-dir
touch /opt/one-time-access/database /var/run/one-time-access.pid /var/log/one-time-access.log
chown ota-deamon:ota-deamon /opt/one-time-access/database /var/run/one-time-access.pid /var/log/one-time-access.log
```

Adjust the configuration file using your preferred editor (in this instruction _vim_ is used).

```$ vim /opt/one-time-access/one-time-access.conf```

To give the script write permissions to a folder served by your webserver, make sure it has sufficient permissions. In case at your configuration the variable NAME_OF_FOLDER_SERVING_FILES is defined as `one-time-access` and PATH_TO_PUBLIC_ROOT_DIR is defined as `/var/www/html`, execute the following as root.

```chmod 775 /var/www/html/one-time-access```

To see if the script is running properly, start it from the terminal by executing

```$ su ota-deamon -c '/opt/one-time-access-deamon.sh```

If no errors show up, stop execution by typing ```Strg + C``` to return to your command line.

#### Autostart
Finally setup autostart of the script. In case of using _init.d_ add the following line to `/etc/rc.local`.

```su ota-deamon -c '/opt/one-time-access-deamon.sh &'```

In case of using _cron_, edit the crontab of _ota-deamon_ by executing 

```$ su ota-deamon -c 'crontab -e'```

and add the following line.

```@reboot /opt/one-time-access-deamon.sh &```

Now on every system start the deamon is started. 

### Install the client script for ssh
To upload files to be served by the deamon you may want to install the upload script, too.
TODO


:deamon: :shell: :dash: :filehosting: :privacy: :internet: :webserver: :lighttpd:
