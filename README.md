system-backup-script
====================

A simple, configurable bash script which backs up specified directories to tar.gz.

USAGE

	To backup, run as root:

	sudo /home/tenzin/opt/Paul's Backup Script/backup.sh [options]

	Note: -h and -q options do not require root.

OPTIONS

	-c N
		gzip/pigz Compression level. N = 1 - 9 (default is 9)

	-d DIR
		Backup to DIR (default is n-DayName, e.g. 1-Monday).
		Allowed characters: Alphanumeric and .-_

	-h
		Display this help.
		root not required

	-K
		Keep files removed from source in destination during rsync.
		Default is to delete (--delete)

	-p N
		Number of CPU Cores pigz can use. N = 1 - 8
		Default is the number of CPUs available to the system (8).

	-q
		Query last backup date/time and location.
		root not required

	-v
		Verbose mode

EXAMPLES

	Example 1

	Run with default settings - will backup to 
	/media/tenzin/BACKUP_2TB_1/BACKUP/1-Monday with gzip compression 9 
	and vebose mode off:

	$ sudo /home/tenzin/opt/Paul's Backup Script/backup.sh

	Example 2

	Backup to /media/tenzin/BACKUP_2TB_1/BACKUP/latest with compression level 5
	using 2 CPU Cores:

	$ sudo /home/tenzin/opt/Paul's Backup Script/backup.sh -d latest -c 5 -p 2

	Example 3

	Run in vervose mode with default settings:

	$ sudo /home/tenzin/opt/Paul's Backup Script/backup.sh -v

