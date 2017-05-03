# one-time-access
A :deamon:, written in dash/shell, that scans a specific folder for files to be then moved to a unique path to let lighttpd serve the file under an unique address. 

Files may be transfered for example via ssh/scp, sftp, samba or similar.

A solution to provide links to the uploader is not yet implemented. At the moment weblinks can be found at the log files.

## Installation
First install the deamon script on your server. Then install the client script on your machine.

### Deamon
Clone the repository to your current directory using git.
```git clone https://github.com/tobijahu/one-time-access.git one-time-access```
Copy the content to /opt/one-time-access as root.
```su root -c 'cp -a one-time-access /opt/'```
Or in case of using sudo.
```sudo cp -a one-time-access /opt/```
Make the script executable.
```su root -c 'chmod 755 /opt/one-time-access/one-time-access-deamon.sh'```
Or
```sudo chmod 755 /opt/one-time-access/one-time-access-deamon.sh```
Now create a new user ota to run the deamon.
```su root -c 'useradd ota'```
Or
```sudo useradd ota```
Create a new directory that serves files. `ota` requires to write to this directory. So make `ota` own it.
```su root -c 'mkdir /opt/one-time-access/file-dir && chown ota /opt/one-time-access/file-dir'```
Or the sudo way:
```sudo mkdir /opt/one-time-access/file-dir && sudo chown ota /opt/one-time-access/file-dir```
Create a database file that is owned by ota.
```su root -c 'touch /opt/one-time-access/database && chown ota /opt/one-time-access/database'```
Or
```sudo touch /opt/one-time-access/database && sudo chown ota /opt/one-time-access/database'```
Adjust the configuration file using your preferred editor e.g. vim.
```vim /opt/one-time-access/one-time-access.conf```
Finnaly autostart the script. In case of using init.d add the following line to `/etc/rc.local`.
```su ota -c '/opt/one-time-access-deamon.sh &'```
Now on every system start the deamon is started. To start it right now run
```su ota -c '/opt/one-time-access-deamon.sh &```

### Client
To upload files to be served by the deamon you may want to install the upload script, too.
TODO


:shell: :dash: :filehosting: :privacy: :internet: :webserver: :lighttpd:
