# one-time-access
A :deamon:, a short script written in dash/shell, that scans a specific folder for files to be then moved to a unique path to let lighttpd serve the file under an unique hard-to-guess url. 

By using the ota-ssh-client.sh script, it is possible to upload a file to the server and obtain a link to the file. Its deletion after the first access will then be handled by the one-time-access-deamon on the server. This script requires a working ssh setup (including ssh-agent) from the client to the server.

Otherwise files may be transfered for example via ssh/scp, sftp, samba or similar. An interface to send the link via email or jabber could be a great idea, but is not implemented yet.

At the moment weblinks can be found at the log files. Which may be enhanced soon.

## Installation
First install the deamon script on your server. Then install the client script on your machine.

### Deamon
Clone the repository to your current directory using git.

```$ git clone https://github.com/tobijahu/one-time-access.git one-time-access```

Copy the content to `/opt/one-time-access`, create a new user `ota-deamon` to run the deamon scrit, add it to the group of your webserver user (e.g. `www-data`) and create all necessary files and folders. Run the following commands as root user.

```cp -a one-time-access /opt/
chmod 755 /opt/one-time-access/one-time-access-deamon.sh
useradd ota-deamon
usermod -a -G www-data ota-deamon```

```mkdir /opt/one-time-access/file-dir```

```chown ota-deamon:ota-deamon /opt/one-time-access/file-dir```

```touch /opt/one-time-access/database /var/run/one-time-access.pid /var/log/one-time-access.log```

```chown ota-deamon:ota-deamon /opt/one-time-access/database /var/run/one-time-access.pid /var/log/one-time-access.log```

Adjust the configuration file using your preferred editor e.g. vim.

```$ vim /opt/one-time-access/one-time-access.conf```

To allow the script to write to a folder served by your webserver, make sure it has sufficient permissions. In case  in your configuration NAME_OF_FOLDER_SERVING_FILES is defined as `one-time-access` and PATH_TO_PUBLIC_ROOT_DIR is defined as `/var/www/html`, run the following as root.

```chmod 775 /var/www/html/one-time-access```

Finally setup autostart of the script. In case of using init.d add the following line to `/etc/rc.local`.

```su ota-deamon -c '/opt/one-time-access-deamon.sh &'```

Now on every system start the deamon is started. To see if the script is running properly, start it from the terminal by executing

```$ su ota-deamon -c '/opt/one-time-access-deamon.sh &```

### Client
To upload files to be served by the deamon you may want to install the upload script, too.
TODO


:shell: :dash: :filehosting: :privacy: :internet: :webserver: :lighttpd:
