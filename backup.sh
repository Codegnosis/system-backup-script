#!/bin/bash

################################################################################
# title         	: backup.sh
# description   	: Backup a sepcified list of directories to a designated
#			  location in tar.gz format. rsync a list of specified
#			  directories to a designated location
# author		: Paul Hodgson (hodge@64bitjungle.com)
# date          	: 2014-05-25
# version       	: 0.1   
# usage			: root backup.sh
# notes         	: Install rsync 3.1.0 to use latest rsync features
# bash_version  	: 4.2.45(1)-release
################################################################################

################################################################################
# The MIT License (MIT)
#
# Copyright (c) 2014 Paul Hodgson (hodge@64bitjungle.com)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
################################################################################

###################
# CONFIG
###################

# Base Directory where all backups will be saved.
# USE FULL PATH INCLUDING LEADING SLASH /
# E.g.
# BACKUP_BASE_DIR="/backup"
BACKUP_BASE_DIR="/backup/BACKUP"

# Array of directories to backup (tar.gz)
# USE FULL PATH INCLUDING LEADING SLASH /
# E.g.
# DIRS_TO_BACKUP=('/home'
# '/etc'
# )
DIRS_TO_BACKUP=('/home'
 '/etc'
)

# Array of directories to rsync
# USE FULL PATH INCLUDING LEADING SLASH /
# E.g.
# DIRS_TO_RSYNC=('/some_dir/sub_dir'
# '/another_dir'
# )
DIRS_TO_RSYNC=()

# Path to rsync. Default is /usr/bin/rsync.
# Useful if, for example, you have installed
# another version from source which is not
# in PATH, e.g. /usr/local/rsync/bin/rsync
RSYNC_BIN="/usr/bin/rsync"

###################################
# NOTHING PAST HERE NEEDS MODIFYING
###################################

###################
# BEGIN SCRIPT
###################

# Output Help...
HELP_SUB_DIR=`date "+%u-%A"`
TOUT=$(date "+%T %N")
BOLD=$(tput bold) # bold
NORM=$(tput sgr0) # turn off formatting
U=$(tput smul) # start underline
UE=$(tput rmul) # end underline

usage()
{
cat << EOF

${BOLD}USAGE${NORM}

	To backup, run as root:

	${BOLD}sudo $0 [options]${NORM}

	${BOLD}Note:${NORM} -h and -q options do not require root.

${BOLD}OPTIONS${NORM}

	${BOLD}-c${NORM} ${U}N${UE}
		gzip/pigz Compression level. ${U}N${UE} = 1 - 9 (default is 9)

	${BOLD}-d${NORM} ${U}DIR${UE}
		Backup to ${U}DIR${UE} (default is n-DayName, e.g. 1-Monday).
		Allowed characters: Alphanumeric and .-_

	${BOLD}-h${NORM}
		Display this help.
		root not required

	${BOLD}-K${NORM}
		Keep files removed from source in destination during rsync.
		Default is to delete (--delete)

	${BOLD}-p${NORM} ${U}N${UE}
		Number of CPU Cores pigz can use. ${U}N${UE} = 1 - $CORE_COUNT
		Default is the number of CPUs available to the system ($CORE_COUNT).

	${BOLD}-q${NORM}
		Query last backup date/time and location.
		root not required

	${BOLD}-v${NORM}
		Verbose mode

${BOLD}EXAMPLES${NORM}

	${U}Example 1${UE}${NORM}

	Run with default settings - will backup to 
	$BACKUP_BASE_DIR/$HELP_SUB_DIR with gzip compression 9 
	and vebose mode off:

	${BOLD}$ sudo $0${NORM}

	${U}Example 2${UE}${NORM}

	Backup to $BACKUP_BASE_DIR/latest with compression level 5
	using 2 CPU Cores:

	${BOLD}$ sudo $0 -d latest -c 5${NORM} -p 2

	${U}Example 3${UE}${NORM}

	Run in vervose mode with default settings:

	${BOLD}$ sudo $0 -v${NORM}

EOF
}

function timer()
{
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local  stime=$1
        etime=$(date '+%s')

        if [[ -z "$stime" ]]; then stime=$etime; fi

        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        printf '%d:%02d:%02d' $dh $dm $ds
    fi
}



# Start script timer
t=$(timer)

#############################
# CHECK ARGS AND SET DEFAULTS
#############################

# Set some defaults
VERBOSE=false
SUB_DIR=`date "+%u-%A"`
COMP_LEVEL=9
RSYNC_KEEP=false

if [[ -z "$RSYNC_BIN" ]]; then
    RSYNC_BIN=`command -v rsync`
fi

RSYNC_LATEST=3.1.0 # rsync version required for latest features
CORE_COUNT=`grep core\ id /proc/cpuinfo |wc -l` # ensure user specified core count does not exceed this

function last_backup()
{
    if [[ ! -f "$BACKUP_BASE_DIR/LASTBACKUP" ]]; then
        echo "Could not find $BACKUP_BASE_DIR/LASTBACKUP"
    else
        echo ""
        echo "Last Backup:"
        echo ""
        cat $BACKUP_BASE_DIR/LASTBACKUP
        echo ""
    fi
}

# Process CLI args
while getopts “hvKqd:c:p:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         q)
             last_backup
             exit 0
             ;;
         v)
             VERBOSE=true
             ;;
         K)
             RSYNC_KEEP=true
             ;;
         d)
             SUB_DIR=${OPTARG//[^[:alnum:].-_]/}
             ;;
         c)
             COMP_LEVEL=${OPTARG//[^[:digit:]]/}
             ;;
         p)
             NO_CORES=${OPTARG//[^[:digit:]]/}
             ;;
         ?)
             usage
             exit 1
             ;;
     esac
done

# If -d or -c has been passed without values, display help and exit
if [[ -z $SUB_DIR ]] || [[ -z $COMP_LEVEL ]]
then
     usage
     exit 1
fi

# if -p has been passed without a value, set to the default
# calculated no. cores
if [[ -z $NO_CORES ]]; then
     NO_CORES=$CORE_COUNT
fi

# If -p has been passed with more cores than the system has,
# set to calculated default
if [[ "$NO_CORES" -gt "$CORE_COUNT" ]]; then
     NO_CORES=$CORE_COUNT
fi

###################
# CHECK RUN AS ROOT
###################

# If script is not run as root, display help and exit
if [ "$(id -u)" != "0" ]; then
    usage
    exit 1
fi

#####################
# CHECK DRIVE MOUNTED
#####################

if [ ! -d "$BACKUP_BASE_DIR" ]; then
    echo [$(date "+%T")] "Can't find $BACKUP_BASE_DIR. Check it exists and is mounted."
    exit 1
else
    echo [$(date "+%T")] "Found $BACKUP_BASE_DIR. Backup Drive Mounted"
fi

##################
# OUTOUT SOME INFO
##################

if $VERBOSE; then
    echo [$(date "+%T")] "Verbose Mode"
else
    echo [$(date "+%T")] "Verbose Off"
fi

###############################
# SET AND CHECK ROOT BACKUP DIR
###############################

# Set real Backup DIR for this session
BACKUP_DIR="$BACKUP_BASE_DIR/tarballs/$SUB_DIR"
echo [$(date "+%T")] "Root Tarball Dir: $BACKUP_DIR"
echo [$(date "+%T")] "Root rsync Dir: $BACKUP_BASE_DIR/rsync"

# Check real Backup Dir exists. If not, create it

if [ ! -d "$BACKUP_DIR" ]; then
    echo [$(date "+%T")] "Can't find $BACKUP_DIR. Create it."
    echo [$(date "+%T")] "mkdir -p $BACKUP_DIR"
    mkdir -p $BACKUP_DIR
else
    echo [$(date "+%T")] "Found $BACKUP_DIR"
fi

#####################
# CHECK HAS pigz
#####################

COMP_CMD="gzip -$COMP_LEVEL"

if command -v pigz >/dev/null 2>&1; then
    COMP_CMD="pigz -$COMP_LEVEL -p$NO_CORES"
    echo [$(date "+%T")] "pigz installed. Use pigz for compression"
	echo [$(date "+%T")] "Use $NO_CORES Cores for compression"

else
    echo [$(date "+%T")] "pigz not installed. Use gzip for compression"
fi

echo [$(date "+%T")] "Compression level: $COMP_LEVEL"

echo ""
echo "----------------------"
echo "RUN MAIN BACKUP"
echo "----------------------"

#####################
# BACKUP DIRS
#####################

if [ ${#DIRS_TO_BACKUP[@]} -gt 0 ]; then
    echo [$(date "+%T")] "Directories for backup declared"
    
    for i in ${DIRS_TO_BACKUP[@]}; do
        BU=${i%/} # remove trailing slash
        TMP="${BU/\//}" #remove / prefex
        TGZ_PREFIX="${TMP//\//.}" # convert to dir.subdir.subsubdir etc
        TGZ_FILE="$TGZ_PREFIX.backup.tar.gz"
        echo ""
        echo "-----------------------------"
        echo "BACKING UP $BU"
        echo ""
        echo [$(date "+%T")] "Check for old backup file:"

        if [[ ! -f $BACKUP_DIR/$TGZ_FILE ]]; then
            echo [$(date "+%T")] "Old backup file does not exist. Continue..."
        else
            echo [$(date "+%T")] "Old backup file exists"
            echo "rm $BACKUP_DIR/$TGZ_FILE"
            rm $BACKUP_DIR/$TGZ_FILE
            echo ""
        fi

        echo [$(date "+%T")] "Please wait... calculating time to complete"

        if $VERBOSE; then
            echo "tar cpv $BU | $COMP_CMD > $BACKUP_DIR/$TGZ_FILE"
            tar cpv $BU | $COMP_CMD > $BACKUP_DIR/$TGZ_FILE
        else
            echo "tar cp $BU | pv --size `du -sb $BU | awk '{print $1}'` | $COMP_CMD > $BACKUP_DIR/$TGZ_FILE"
            tar cp $BU | pv --size `du -sb $BU | awk '{print $1}'` | $COMP_CMD > $BACKUP_DIR/$TGZ_FILE
        fi
    done
else
    echo [$(date "+%T")] "Nothing to backup!"
fi

#####################
# RUN RSYNC
#####################

echo ""
echo "----------------------"
echo "RUN rsync"
echo "----------------------"

if [ ${#DIRS_TO_RSYNC[@]} -gt 0 ]; then
    echo [$(date "+%T")] "Directories for rsync declared..."
    
    echo [$(date "+%T")] "Check rsync is installed"

    if command -v $RSYNC_BIN >/dev/null 2>&1; then
        echo [$(date "+%T")] "rsync installed. OK"

        if $RSYNC_KEEP; then
            echo [$(date "+%T")] "rsync keep removed files at destination"
        else
            echo [$(date "+%T")] "rsync delete removed files from destination"
        fi

        RSYNC_VER=`$RSYNC_BIN --version | head -c20 | cut -c16-20`
        HAS_LATEST_RSYNC=false

        echo [$(date "+%T")] "Installed rsync Version:$RSYNC_VER"
        echo [$(date "+%T")] "Required for latest features:$RSYNC_LATEST"

        if [[ "$RSYNC_VER" > "$RSYNC_LATEST" ]] || [[ "$RSYNC_VER" = "$RSYNC_LATEST" ]]; then
            echo [$(date "+%T")] "rsync $RSYNC_VER is OK"
            HAS_LATEST_RSYNC=true
        else
            echo [$(date "+%T")] "rsync $RSYNC_VER installed. Disable newer rsync features"
        fi

        VERBOSEFLAG="" # Default off

        if $HAS_LATEST_RSYNC; then
             VERBOSEFLAG="--info=progress2" #have rsync >= 3.1.0 installed. Display overall progress bar
        fi

        DELFLAG="--delete" # Default delete

        if $RSYNC_KEEP; then
            DELFLAG=""
        fi

        if $VERBOSE; then
            VERBOSEFLAG="-v --progress"
        fi

        for j in ${DIRS_TO_RSYNC[@]}; do
            RS=${j}

            echo ""
            echo "----------------------"
            echo "rsync $RS"
    
            echo ""
            echo [$(date "+%T")] "Check source dir format"
            echo ""

            case "$RS" in
                */)
                    echo [$(date "+%T")] "has trailing slash"
                    ;;
                *)
                    echo [$(date "+%T")] "does not have a slash. Add trailing slash"
                    RS="$RS/"
                    ;;
            esac

            if [ ! -d "$BACKUP_BASE_DIR/rsync$RS" ]; then
                echo [$(date "+%T")] "Can't find $BACKUP_BASE_DIR/rsync$RS. Create it."
                echo "mkdir -p $BACKUP_BASE_DIR/rsync$RS"
                mkdir -p $BACKUP_BASE_DIR/rsync$RS
            else
                echo [$(date "+%T")] "Found $BACKUP_BASE_DIR/rsync$RS"
            fi

            echo "$RSYNC_BIN -r -t $VERBOSEFLAG $DELFLAG --links --size-only -s $RS $BACKUP_BASE_DIR/rsync$RS"
            $RSYNC_BIN -r -t $VERBOSEFLAG $DELFLAG --links --size-only -s $RS $BACKUP_BASE_DIR/rsync$RS

        done
    else
        echo [$(date "+%T")] "rsync does not seem to be installed. Please install rsync"
    fi
else
    echo [$(date "+%T")] "Nothing to rsync!"
fi

#####################
# BACKUP APT SW LIST
#####################

echo ""
echo "----------------------------------"
echo "BACKING UP Installed Software List"
echo "----------------------------------"

if command -v dpkg >/dev/null 2>&1; then
    echo "dpkg --get-selections > $BACKUP_BASE_DIR/installed-software"
    dpkg --get-selections > $BACKUP_BASE_DIR/dpkg-installed-software-list
fi

if command -v aptitude >/dev/null 2>&1; then
    echo "aptitude search '!~M ~i' -F '%p' > $BACKUP_BASE_DIR/installed-software-list"
    aptitude search '!~M ~i' -F '%p' >$BACKUP_BASE_DIR/aptitude-installed-software-list
fi

if command -v yum-debug-dump >/dev/null 2>&1; then
    echo "yum-debug-dump > $BACKUP_BASE_DIR/yum-installed-software-list"
    yum-debug-dump > $BACKUP_BASE_DIR/yum-installed-software-list
fi

# Add latest Backup info to reference file

date > "$BACKUP_BASE_DIR/LASTBACKUP"
echo "$BACKUP_DIR" >> "$BACKUP_BASE_DIR/LASTBACKUP"

echo ""
echo "----------------------"
echo "BACK UP COMPLETE"
echo "----------------------"

echo ""
echo [$(date "+%T")] "Latest Backup info saved to: $BACKUP_BASE_DIR/LASTBACKUP"
echo ""

printf 'Elapsed time: %s\n' $(timer $t)

exit 0
