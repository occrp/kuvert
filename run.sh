#!/bin/bash

#
# this function watches the $KUVERT_GNUPG_DIR files for changes
# and re-loads kuvert's config and keychain when they're detected
function watch_pubkeys {
    echo "+-- watching for changes in $KUVERT_GNUPG_DIR"
    # FIXME we need to handle SIGHUP/SIGTERM/SIGKILL nicely some day
    while true; do
        # wait for events
        set +e # yeah, inotifywatch can return a different return code than 0, and we have to be fine with that
        
        # watch for files depending on GnuPG version
        if stat -t *.gpg~ >/dev/null 2>&1 ; then
            # GnuPG v1.x
            inotifywait -r -e modify -e move -e create -e delete -qq "$KUVERT_GNUPG_DIR/"*.gpg "$KUVERT_GNUPG_DIR/"*.gpg~
        else
            # GnuPG v2.x
            inotifywait -r -e modify -e move -e create -e delete -qq "$KUVERT_GNUPG_DIR/"*.gpg "$KUVERT_GNUPG_DIR/"*.kbx
        fi
        
        set -e # back to being strict about stuff
        # if a watched event occured, redo authorized_keys
        if [ $? -eq 0 ]; then
            echo "    +-- files in $KUVERT_GNUPG_DIR changed"
            # we need to wait for gpg to finish its stuff
            echo "        +-- continuing in 3s..."
            sleep 3
            # permissions and ownership
            echo "        +-- making sure permissions are AOK..."
            
            # which GnuPG version are we talking about
            if stat -t "$KUVERT_GNUPG_DIR/"*.gpg~ >/dev/null 2>&1 ; then
                # just the relevant files, gpg creates .lock and .tmp files too, we're going to ignore those
                chown "$KUVERT_USER":"$KUVERT_GROUP" "$KUVERT_GNUPG_DIR/" "$KUVERT_GNUPG_DIR/"*.gpg "$KUVERT_GNUPG_DIR/"*.gpg~ || \
                    echo "WARNING: unable to change ownership!"
                chmod u=rwX,go= "$KUVERT_GNUPG_DIR/" "$KUVERT_GNUPG_DIR/"*.gpg "$KUVERT_GNUPG_DIR/"*.gpg~ || \
                    echo "WARNING: unable to change permissions!"
            else
                # just the relevant files, gpg creates .lock and .tmp files too, we're going to ignore those
                chown "$KUVERT_USER":"$KUVERT_GROUP" "$KUVERT_GNUPG_DIR/" "$KUVERT_GNUPG_DIR/"*.gpg "$KUVERT_GNUPG_DIR/"*.kbx || \
                    echo "WARNING: unable to change ownership!"
                chmod u=rwX,go= "$KUVERT_GNUPG_DIR/" "$KUVERT_GNUPG_DIR/"*.gpg "$KUVERT_GNUPG_DIR/"*.kbx || \
                    echo "WARNING: unable to change permissions!"
            fi
            # now the important stuff
            echo "        +-- reloading kuvert config and keyring..."
            su -p -c "env PATH=\"$PATH\" kuvert -r -c \"${KUVERT_CONFIG_DIR}/kuvert.conf\"" "$KUVERT_USER"
        fi
    done
}

# exit when any of the commands fails
set -e

# we need the KUVERT_USER envvar
[ -z ${KUVERT_USER+x} ] && KUVERT_USER="user"

# we need the KUVERT_GROUP envvar, but we can get it from the username, right?
[ -z ${KUVERT_GROUP+x} ] && KUVERT_GROUP="$KUVERT_USER"

echo "+-- settings:"
echo "    +-- KUVERT_USER  : $KUVERT_USER"
echo "    +-- KUVERT_GROUP : $KUVERT_GROUP"
echo "    +-- KUVERT_UID   : ${KUVERT_UID-<not set>}"
echo "    +-- KUVERT_GID   : ${KUVERT_GID-<not set>}"

# users' home directory
# TODO feature/future proof it
[ -z ${KUVERT_HOME+x} ] && KUVERT_HOME="/home/${KUVERT_USER}"

# important directories
# 
# this relies on these envvars being empty
# to differentiate between "default" and "explicitly set by user"
[ -z ${KUVERT_LOGS_DIR+x} ] && export KUVERT_LOGS_DIR="$KUVERT_HOME/logs"
[ -z ${KUVERT_QUEUE_DIR+x} ] && export KUVERT_QUEUE_DIR="$KUVERT_HOME/queue"
[ -z ${KUVERT_GNUPG_DIR+x} ] && export KUVERT_GNUPG_DIR="$KUVERT_HOME/gnupg"
[ -z ${KUVERT_CONFIG_DIR+x} ] && export KUVERT_CONFIG_DIR="$KUVERT_HOME/config"

echo "+-- directories:"
echo "    +-- KUVERT_TEMP_DIR   : ${KUVERT_TEMP_DIR}"
echo "    +-- KUVERT_HOME       : ${KUVERT_HOME}"
echo "    +-- KUVERT_LOGS_DIR   : ${KUVERT_LOGS_DIR}"
echo "    +-- KUVERT_QUEUE_DIR  : ${KUVERT_QUEUE_DIR}"
echo "    +-- KUVERT_GNUPG_DIR  : ${KUVERT_GNUPG_DIR}"
echo "    +-- KUVERT_CONFIG_DIR : ${KUVERT_CONFIG_DIR}"


# get group data, if any, and check if the group exists
echo "+-- setting up the group..."
if GROUP_DATA=`getent group "$KUVERT_GROUP"`; then
    echo "    +-- group seems to exist"
    # it does! do we have the gid given?
    if [[ "$KUVERT_GID" != "" ]]; then
        # we do! do these match?
        if [[ `echo "$GROUP_DATA" | cut -d ':' -f 3` != "$KUVERT_GID" ]]; then
            # they don't. we have a problem
            echo "ERROR: group $KUVERT_GROUP already exists, but with a different gid (`echo "$GROUP_DATA" | cut -d ':' -f 3`) than provided ($KUVERT_GID)!"
            exit 3
        fi
    fi
    # if no gid given, the existing group satisfies us regardless of the GID

# group does not exist
else
    echo -n "    +-- group does not exist, creating"
    # do we have the gid given?
    GID_ARGS=""
    if [[ "$KUVERT_GID" != "" ]]; then
        # prepare the fragment of the groupadd command
        GID_ARGS="-g $KUVERT_GID"
        
        # we do! does a group with a given id exist?
        if getent group "$KUVERT_GID" >/dev/null; then
            # let's make that non-unique, then
            echo -n ' (non-unique)'
            GID_ARGS="$GID_ARGS --non-unique"
        fi
        echo -n " with gid $KUVERT_GID"
    fi
    echo
    # we either have no GID given (and don't care about it), or have a GID given that does not exist in the system
    # great! let's add the group
    groupadd $GID_ARGS "$KUVERT_GROUP"
fi


# get user data, if any, and check if the user exists
echo "+-- setting up the user..."
if USER_DATA=`id -u "$KUVERT_USER" 2>/dev/null`; then
    echo "    +-- user seems to exist"
    # it does! do we have the uid given?
    if [[ "$KUVERT_UID" != "" ]]; then
        # we do! do these match?
        if [[ "$USER_DATA" != "$KUVERT_UID" ]]; then
            # they don't. we have a problem
            echo "ERROR: user $KUVERT_USER already exists, but with a different uid ("$USER_DATA") than provided ($KUVERT_UID)!"
            exit 5
        fi
    fi
    # if no uid given, the existing user satisfies us regardless of the uid
    # but is he in the right group?
    adduser "$KUVERT_USER" "$KUVERT_GROUP"

# user does not exist
else
    # do we have the uid given?
    echo -n "    +-- user does not exist, creating"
    UID_ARGS=""
    if [[ "$KUVERT_UID" != "" ]]; then
        # prepare the fragment of the useradd command
        UID_ARGS="-u $KUVERT_UID"
        # we do! does a group with a given id exist?
        if getent passwd "$KUVERT_UID" >/dev/null; then
            echo -n ' (non-unique)'
            UID_ARGS="$UID_ARGS --non-unique"
        fi
        echo -n " with uid $KUVERT_UID"
    fi
    echo
    # we either have no UID given (and don't care about it), or have a UID given that does not exist in the system
    # great! let's add the user
    useradd $UID_ARGS -r -g "$KUVERT_GROUP" -s /bin/bash "$KUVERT_USER"
    # by default disable the password
    passwd -d "$KUVERT_USER"
    # create home
    mkdir -p "$KUVERT_HOME"
    # and make sure that permissions and ownership are set properly
    # but don't fail completely when that's not the case
    chown -R "$KUVERT_USER:$KUVERT_GROUP" "$KUVERT_HOME" || echo "WARNING: changing ownership of $KUVERT_HOME failed!"
    chmod -R ug+rwX "$KUVERT_HOME" || echo "WARNING: changing permissions on $KUVERT_HOME failed!"
fi

# the directories
echo "+-- handling directories..."
echo "    +-- creating..."
mkdir -p "$KUVERT_TEMP_DIR"
mkdir -p "$KUVERT_LOGS_DIR"
mkdir -p "$KUVERT_QUEUE_DIR"
mkdir -p "$KUVERT_GNUPG_DIR"
mkdir -p "$KUVERT_CONFIG_DIR"
echo "    +-- changing ownership..."
chown -R "$KUVERT_USER":"$KUVERT_GROUP" "$KUVERT_TEMP_DIR"
chown -R "$KUVERT_USER":"$KUVERT_GROUP" "$KUVERT_LOGS_DIR"
chown -R "$KUVERT_USER":"$KUVERT_GROUP" "$KUVERT_QUEUE_DIR"
chown -R "$KUVERT_USER":"$KUVERT_GROUP" "$KUVERT_GNUPG_DIR"
chown -R "$KUVERT_USER":"$KUVERT_GROUP" "$KUVERT_CONFIG_DIR" || \
    echo "WARNING: unable to change ownership of $KUVERT_CONFIG_DIR!"
echo "    +-- changing permissions..."
chmod -R u=rwX,go=  "$KUVERT_TEMP_DIR"
chmod -R u=rwX,g=rX,o= "$KUVERT_LOGS_DIR"
chmod -R u=rwX,go= "$KUVERT_QUEUE_DIR" # queue dir has to be readable only to kuvert user
chmod -R u=rwX,go= "$KUVERT_GNUPG_DIR" # gnupg home dir has to be readable only to kuvert user
chmod -R u=rwX,g=rX,o= "$KUVERT_CONFIG_DIR" || \
    echo "WARNING: unable to change permissions of $KUVERT_CONFIG_DIR!"

#
# generate the config file if needed
#

source "$( dirname $0 )/generate-kuvert-conf.sh"

# 
# reality-check if the config file exists...
if [ ! -e "$KUVERT_CONFIG_DIR/kuvert.conf" ]; then
    echo "ERROR: config file '$KUVERT_CONFIG_DIR/kuvert.conf' doesn't exist!"
    exit 6
fi
# ...and if it's is readable.
if [ ! -r "$KUVERT_CONFIG_DIR/kuvert.conf" ]; then
    echo "ERROR: config file '$KUVERT_CONFIG_DIR/kuvert.conf' is not readable!"
    exit 7
fi

# making sure the env is AOK
export HOME="$KUVERT_HOME"
export GNUPGHOME="$KUVERT_GNUPG_DIR"
# make sure said settings will be in effect upon each and every
# su - $KUVERT_USER within the container
# as that's how we'll manage gpg the keyring...
echo "export GNUPGHOME=\"$KUVERT_GNUPG_DIR\"" > "$KUVERT_HOME"/.profile
chown "$KUVERT_USER":"$KUVERT_GROUP" "$KUVERT_HOME"/.profile

# let's check up on the keyring,
# creating it if needed
echo -ne "+-- keys in keyring: "
# this has to be run as the target user
su -p -c "env PATH=\"$PATH\" gpg --list-keys" "$KUVERT_USER" 2>/dev/null | egrep '^pub' | wc -l

# 
# do we need to check for secret keys?
if [ "$KUVERT_DEBUG_NO_GENKEY" != "" ]; then
    echo "WARNING: not generating private GnuPG keys, since"
    echo "WARNING: \$KUVERT_DEBUG_NO_GENKEY flag is set"
else
    # if there are no secret keys in the keyring,
    # generate a new password-less secret key

    # "|| true" required due to "set -e", in case secret keyring is empty and egrep finds nothing
    SECRET_KEYS="$( su -p -c "env PATH=\"$PATH\" gpg --list-secret-keys" "$KUVERT_USER" 2>/dev/null | egrep '^sec' )" || true
    if [[ "$SECRET_KEYS" == "" ]]; then
        echo "+-- no secret keys found, generating one for: $KUVERT_USER@localhost"
        echo
        echo "    WARNING: this secret key will not be password-protected!"
        echo
        # https://www.gnupg.org/documentation/manuals/gnupg/Unattended-GPG-key-generation.html
        su -p -c "env PATH=\"$PATH\" gpg --batch --gen-key" "$KUVERT_USER" <<EOT
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Name-Real: $KUVERT_USER
Name-Comment: Auto-generated for kuvert testing, change as soon as possible
Name-Email: $KUVERT_USER@localhost
Expire-Date: 0
%commit
EOT
        echo "    +-- done."
    else
        echo -ne "+-- secret keys in keyring: "
        echo "$SECRET_KEYS" | wc -l
    fi
fi

# watch for changes with the keyring in the background
# when changes are detected, kuvert gets reloaded
watch_pubkeys &
sleep 1

# inform
echo "========================================================================"
echo "== Starting kuvert                                                    =="
echo "========================================================================"

# change directory
echo "+-- changing directory to: $KUVERT_HOME"
cd "$KUVERT_HOME"

# time for kuvert!
echo "+-- changing user to: $KUVERT_USER"

echo -e "+-- running:\n\t$*"
exec su -p -c "env PATH=\"$PATH\" $*" "$KUVERT_USER"
