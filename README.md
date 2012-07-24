knife-spoon
===========

A knife extension supporting cookbook workflow

knife spoon status
==================

Used to determine the status of the cookbooks on the chef server and compare them to the files on the local filesystem.
The command will calculate the checksum of files to determine whether a file has changed. The -s or --show option can be
specified if the user wants to learn which files the command thinks have been modified for each cookbook.

Example Output:
---------------

<div style="font-family: monospace; background-color:black; color:white">
<span style="color:green; font-weight:bold">OK&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span>: Safe to upload 'windows' as cookbook has new version.<br/>
<span style="color:yellow; font-weight:bold">WARNING</span>: Unsafe to upload 'glassfish' as it modifies an existing cookbook.<br/>
<span style="color:red; font-weight:bold">ERROR&nbsp;&nbsp;</span>: Dangerous to upload 'fisg' as it modifies a frozen cookbook.<br/>
</div>
