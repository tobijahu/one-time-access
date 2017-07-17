# one-time-access
In connection with a webserver (lighttpd), this deamon serves files under an unique hard-to-guess url until first access. 

The general usecase is a single user who wants to assure, that a file was only downloaded once.

## Requirements
* Linux with dash support.
* Webserver installation (here: lighttpd) that logs accesses and forces strong encryption.
* root-access to the system (installation only)
* Properly configured ssh installation with ssh-agent (client script only)

## How it works
The deamon, written in dash/shell, monitors a specific folder for files to be then moved to a unique path to let lighttpd serve the file under a unique url. The deamon monitors the access file of the webserver to detected, if a file was accessed. If so, it will be deleted. If the file was not accessed for 14 days, it will be deleted anyway.

To serve files using this script/deamon from a remote machine, put files into the monitored folder via the one-time-access-client script (introduced below) finally this will return the link to the file automatically to the user. This script requires a working ssh setup (including ssh-agent) from the client to the server.

Otherwise files may be transfered for example via ssh/scp, sftp, samba or similar. An interface for this usecase to send the link via email or jabber could be a great idea, but is not yet implemented.

At the moment weblinks can be found at the log files. Which may be enhanced soon. So currently the usecase is dedicated to a single user or the administrator only.

## Installation
First make sure your server meets the above requirements. Then follow the instructions in the below sections.

The following files are supposed to be on your _server_. Instructions can be found at the below section [Install the deamon](#install-the-deamon).
* ota-deamon.conf
* ota-deamon.sh
* ota-print-link.sh
* ota-move-lock.sh

The following files are supposed to be on your _client machine_ and will be discussed at the section [Install the client script](#install-the-client-script).
* ota-ssh-client.conf
* ota-ssh-client.sh

### Configure Lighttpd
The configuration of the webserver is crucial to the thought behind one-time-access. First you will need to configure lighttpd such that only ciphers are supported that are not broken. So you may configure your `/etc/lighttpd/lighttpd.conf` so that you webserver only serves port 443 connections. So modify the server.port entry from ```server.port = 80``` to ```server.port = 443```.
Then add the following settings at the end of the file to configure encryption.
```
# Verschlüsselung hinzufügen
ssl.engine = "enable",
ssl.pemfile = "/etc/lighttpd/certs/lighttpd.pem",
# Weitere Einstellungen zur Absicherung:
#ssl.use-compression = "disable", #this is disabled at compile time since 1.4.28
ssl.use-sslv2 = "disable",
ssl.use-sslv3 = "disable",
ssl.cipher-list = "EECDH+AESGCM:EDH+AESGCM:AES128+EECDH:AES128+EDH",
ssl.dh-file = "/etc/lighttpd/certs/dhparam.pem",
ssl.ec-curve = "secp384r1",
ssl.ca-file = "/etc/lighttpd/certs/lets-encrypt-x3-cross-signed.pem",

# HTTP_Strict_Transport_Security
server.modules += ( "mod_setenv" )
$HTTP["scheme"] == "https" {
  setenv.add-response-header  = ( "Strict-Transport-Security" => "max-age=63072000; includeSubdomains; preload", "X-Frame-Options" => "DENY" )
}
```
It is worth to mention that the above cipher-list excludes a number of ciphers that are deprecated, but still in use. Windows XP users for example may not be able to connect to your webserver with the above settings.

To detect that a file has been accessed via the webserver, it is necessary to activate access logging. Therefor I added the following lines to my `lighttpd.conf` file.
```
# Logging
server.modules += ( "mod_accesslog" )
accesslog.filename = "/var/log/lighttpd/access.log"
# %h : name or address of remote-host
# %s : status code
# %b : bytes sent for the body
# %I : bytes incoming
# %O : bytes outgoing
# %U : request URL
# %t : timestamp of the end-time of the request
accesslog.format = "%h %s %b %I %O %U %t \"%{Referer}i\" \"%{User-Agent}i\""
```
In case you still want to serve port 80 connections, which is in contrast to the above configuration, you may add one of the following redirects.

To redirect all requests via port 80 of the one-time-access folder (here "ota") to port 443. The following code may be added.
```
# Redirect only traffic of one-time-access to https
$SERVER["socket"] == ":80" {
  $HTTP["host"] =~ "(ota/.*)" {
    url.redirect = ( "^/(ota/.*)" => "https://%1/ota/$1" )
  }
}
```
To redirect all port 80 requests to port 443 add the following code to your `lighttpd.conf`.
```
# Redirect all traffic to https
$SERVER["socket"] == ":80" {
  $HTTP["host"] =~ "(.*)" {
    url.redirect = ( "^/(.*)" => "https://%1/$1" )
  }
}
```

### Install the deamon
Clone the repository to your current directory using git (alternatively download the .zip-archive).

```dash
$ git clone https://github.com/tobijahu/one-time-access.git one-time-access
```

Now copy all files to the server making use of `scp`. Replace `root@yourserver` according to your setup.
```dash
$ scp one-time-access root@yourserver:/opt/
```
If you executed the above git clone command on the server, just copy the files using `cp`.
```dash
$ cp -a one-time-access /opt/
```

Execute the following commands with root privileges. This will create a new user `ota-deamon` to run the deamon script, add ota-deamon to the group of your webserver user `www-data` (if your webserver user is not www-data, replace it with yours) and set all necessary permissions. 

```dash
chmod 755 /opt/one-time-access/ota-deamon.sh /opt/one-time-access/ota-print-link.sh /opt/one-time-access/ota-move-lock.sh
useradd -c "User that runs the one-time-access-deamon" ota-deamon
usermod -a -G www-data ota-deamon
touch /opt/one-time-access/database
mkdir /opt/one-time-access/file-dir /var/log/one-time-access /var/run/one-time-access
chown -R ota-deamon:ota-deamon /opt/one-time-access/database /opt/one-time-access/file-dir /var/log/one-time-access /var/run/one-time-access
```

Adjust the configuration file using your preferred editor (here _vim_ is used).

```dash
$ vim /opt/one-time-access/ota-deamon.conf
```
Adjust `PATH_TO_PUBLIC_ROOT_DIR`, `ROOT_URL_OF_PUBLIC_DIR` and `WEBSERVER_ACCESS_LOGFILE` according to your setup and uncomment the lines.

To give the script write permissions to a folder served by your webserver, make sure it has sufficient permissions. In case at your configuration the variable NAME_OF_FOLDER_SERVING_FILES is defined as `ota` and PATH_TO_PUBLIC_ROOT_DIR is defined as `/var/www/html`, execute the following as root.

```dash
chmod 775 /var/www/html/ota
```

To see if the script is running properly, start it from the terminal by executing
```dash
$ su ota-deamon -c '/opt/one-time-access/ota-deamon.sh'
```
If no errors show up, stop the execution by typing ```Strg + C``` to return to your command line.

#### Autostart
Finally setup the script to start up on system start. Here three different ways are described: [systemd](#systemd), [init.d / file-rc](#initd--file-rc) and [cron](#cron). The systemd method is recommended. 
##### systemd
In case of systemd create a service file under `/etc/systemd/system/ota-deamon.service` as follows.
```dash
echo '[Unit]
Description=one-time-access deamon control script
After=network.target

[Service]
Type=simple
User=ota-deamon
ExecStart=/opt/one-time-access/ota-deamon.sh systemd
KillMode=process

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/ota-deamon.service
```
Let systemd reload all available deamons by executing the following command.
```
systemctl daemon-reload
```
Check, if the service file is running by executing both of the following commands.
```
systemctl start ota-deamon.service
systemctl status ota-deamon.service
```
The output of the latter command will look for example like
```
● ota-deamon.service - one-time-access deamon control script
   Loaded: loaded (/etc/systemd/system/ota-deamon.service; enabled)
   Active: inactive (dead) since Fri 2017-05-05 08:32:47 UTC; 12min ago
 Main PID: 23143 (code=killed, signal=TERM)

May 05 08:32:34 machine2 systemd[1]: Started one-time-access deamon control script.
```
Finally, if everything is running, enable autostart by executing the following command.
```
systemctl enable ota-deamon.service
```

##### init.d / file-rc
In case of using _init.d_ add the following line to `/etc/rc.local`.

```
mkdir -p /var/run/one-time-access && chown ota-deamon:ota-deamon /var/run/one-time-access && su ota-deamon -c '/opt/one-time-access/ota-deamon.sh &'
```

##### cron
To autostart the deamon using _cron_, edit the crontab of user _root_ by executing 
```
$ crontab -e
```
and add the following line.
```
@reboot mkdir -p /var/run/one-time-access && chown ota-deamon:ota-deamon /var/run/one-time-access && su ota-deamon -c '/opt/one-time-access/ota-deamon.sh &'
```


#### Logrotate
By and by the log file will grow and thus waste space on your hard drive. To compress log files you may use _logrotate_. The following command will configure logrotate to split and compress log files of the `ota-deamon.sh`.

```dash
echo '/var/log/one-time-access/deamon.log {
  rotate 12
  monthly
  compress
  missingok
  notifempty
}' > /etc/logrotate.d/one-time-access
```

### Install the client script
To upload files to be served by the deamon you may want to install the upload script, too. 
* Setup ssh to connect to the server using public-private-key authentification.
* Adjust the configuration at `ota-ssh-client.conf` accordingly to your system setup
  * In case `PATH_TO_FILE_DIR` was changed on the server at `ota-deamon.conf`, `PATH_TO_FILE_DIR_ON_SERVER` should be defined accordingly. 
  * Uncomment `SSH_REMOTE_HOST` and set it identical to the user@hostname combination when using ssh at the CLI. 
  * Uncomment `SSH_PRIVATE_ID` and define it simply as the path to the private key that is setup to authenticate at the server. So the path could be for example `~/.ssh/id_rsa`.
  * In case the executing user of ota-deamon.sh is not `ota-deamon`, adjust `OTAUSER` accordingly. 

`cd` to the folder of the client script. Then for example upload a file `readme.md` by executing
```
/bin/dash ota-ssh-client.sh readme.md
```
Since the script uses _ssh-agent_, enter the credentials for the given user on the host. The output will look like the following.
```
Enter passphrase for /home/youruser/.ssh/id_rsa:
Copying file to server...
readme.md                                   100%  155    48.5KB/s   00:00
Waiting for server response.....
Link(s) to file(s):
https://mettenbr.ink/ota/c78a96a540869dfdb7d6e51617d962b/readme.md
Link is valid until Thu Jul 20 21:44:09 UTC 2017
```
Send the second-to-last line to a person of your choice since this is the online link to the file that can only be downloaded once. The last line gives the associated expiration date (here this date is 14 days in the future).

#### Create an alias at .bashrc
To use the script from command line just add an alias to your `.bashrc`. Replace `~/github/one-time-access/ota-ssh-client.sh` according to your setup.
```
echo 'alias ota-ssh-client="/bin/dash ~/github/one-time-access/ota-ssh-client.sh"' >> ~/.bashrc
. ~/.bashrc
```
Then just execute 
```
ota-ssh-client <file-name>
```
to upload a file `<file-name>` from any directory.

:deamon: :shell: :dash: :filehosting: :privacy: :internet: :webserver: :lighttpd:
