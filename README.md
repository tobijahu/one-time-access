# one-time-access
A :deamon:, a short script written in dash/shell, that scans a specific folder for files to be then moved to a unique path to let lighttpd serve the file under an unique address. 

By using the ota-ssh-client.sh script, it is possible to upload a file to the server and obtain a link to the file. Its deletion after the first access will then be handled by the one-time-access-deamon on the server. This script requires a working ssh setup (including ssh-agent) from the client to the server.

Otherwise files may be transfered for example via ssh/scp, sftp, samba or similar. An interface to send the link via email or jabber could be a great idea, but is not implemented yet.

A solution to provide links to the uploader is not yet implemented. At the moment weblinks can be found at the log files.

:shell: :dash: :filehosting: :privacy: :internet: :webserver: :lighttpd:
