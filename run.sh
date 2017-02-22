#!/bin/bash

# exit when any of the commands fails
set -e

# users' home directory
# TODO feature/future proof it
HOMEDIR="/home/${KUVERT_USER}"

# we need the KUVERT_USER envvar
[ -z ${KUVERT_USER+x} ] && KUVERT_USER="user"

# we need the KUVERT_GROUP envvar, but we can get it from the username, right?
[ -z ${KUVERT_GROUP+x} ] && KUVERT_GROUP="$KUVERT_USER"


echo "+-- settings:"
echo "    +-- KUVERT_USER  : $KUVERT_USER"
echo "    +-- KUVERT_GROUP : $KUVERT_GROUP"
echo "    +-- KUVERT_UID   : ${KUVERT_UID-<not set>}"
echo "    +-- KUVERT_GID   : ${KUVERT_GID-<not set>}"


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
    mkdir -p "/home/$KUVERT_USER"
    # and make sure that permissions and ownership are set properly
    # but don't fail completely when that's not the case
    chown -R "$KUVERT_USER:$KUVERT_GROUP" "/home/$KUVERT_USER" || echo "WARNING: changing ownership of /home/$KUVERT_USER failed!"
    chmod -R ug+rwX "/home/$KUVERT_USER" || echo "WARNING: changing permissions on /home/$KUVERT_USER failed!"
fi

# inform
echo "========================================================================"
echo "== Starting kuvert                                                    =="
echo "========================================================================"

# change directory
echo "+-- changing directory to: $HOMEDIR"
cd "$HOMEDIR"

# time for kuvert!
echo "+-- changing user to: $KUVERT_USER"
echo -e "+-- running:\n\t$*"
exec su -p -c "env PATH=\"$PATH\" $*" "$KUVERT_USER"