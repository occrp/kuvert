#!/bin/bash

# kuvert.conf generator used in the docker container
# when generating the config from envvars
#
# compare with `dot-kuvert.docker` file
#
# there are a couple of strong assumptions in the generated config file
# as opposed to the default dot-kuvert
# 
# 1. SMTP submission is the default mechanism
# 2. unattended operation means passwordless secret key
# 3. only one secret key used and available, most probably
#    auto-generated, so no need for defaultkey (let gpg select the key itself)
# 4. submission via SMTP from outside the container requires binding to 0.0.0.0
# 
# WARNING: DO NOT USE THIS FILE IN A NON-DOCKER ENVIRONMENT
# WARNING: UNLESS YOU KNOW WHAT YOU ARE DOING

#
# reality check -- make sure we have some config file to work with
if [ "$KUVERT_CONFIG_DIR" == "" ]; then
    echo "ERROR: \$KUVERT_CONFIG_DIR not set!"
    exit 1
fi

# do we have a config file already?
if [ -e "$KUVERT_CONFIG_DIR/kuvert.conf" ]; then
    # yes, no need to create one
    echo "WARNING: '$KUVERT_CONFIG_DIR/kuvert.conf' config file seems to already exist"
    echo "WARNING: *not* creating config file from scratch!"

# no config file exists, proceed!
else
    
    # inform
    echo "+-- generating a kuvert config file in:"
    echo "    $KUVERT_CONFIG_DIR/kuvert.conf"

    # $1 - kuvert config option name 
    # $2 - value (empty string means "unset")
    function optional_option {
        if [ "$2" != "" ]; then
            echo "$1 $2" > "$KUVERT_CONFIG_DIR/kuvert.conf"
        fi
    }

    # $1 - kuvert config option name 
    # $2 - value (empty string means "unset", errors out)
    function mandatory_option {
        if [ "$2" == "" ]; then
            echo "ERROR: mandatory option '$1' is not set"
            echo "ERROR: "
            echo "ERROR: either provide a complete kuvert config file in '\$KUVERT_CONFIG_DIR/kuvert.conf'"
            echo "ERROR: or make sure to set all mandatory config evironment variables"
            exit 2
        fi
        echo "$1 $2" > "$KUVERT_CONFIG_DIR/kuvert.conf"
    }

    # $1 - kuvert config option name 
    # $2 - value (empty string means "unset", uses default)
    # $3 - default value
    function default_option {
        if [ "$2" != "" ]; then
            # we have the option set explicitly, use that
            echo "$1 $2" > "$KUVERT_CONFIG_DIR/kuvert.conf"
        else
            # no explicit value, use the default
            echo "$1 $3" > "$KUVERT_CONFIG_DIR/kuvert.conf"
        fi
    }

    # 
    # preamble
    # also, cleaning of the config file
    echo <<EOF > "$KUVERT_CONFIG_DIR/kuvert.conf"

# kuvert config file generated for use in a docker container
# 
# there are a couple of strong assumptions in this config file
# as opposed to the default dot-kuvert
# 
# 1. SMTP submission is the default mechanism
# 2. unattended operation means passwordless secret key
# 3. only one secret key used and available, most probably
#    auto-generated, so no need for defaultkey (let gpg select the key itself)
# 4. submission via SMTP from outside the container requires binding to 0.0.0.0
# 
# WARNING: DO NOT USE THIS FILE IN A NON-DOCKER ENVIRONMENT
# WARNING: UNLESS YOU KNOW WHAT YOU ARE DOING

#
# these are the settings needed in the docker environment

# we should *NOT* use query-secret for getting the SMTP pasword
mspass-from-query-secret f

# we should *NOT* detach when running in docker
# otherwise docker container dies
can-detach f

# using gpg agent means that if a key is passwordless
# (as most probably be the case in a docker-based deployment)
# kuvert will not hang on asking the user for password
use-agent t

EOF

    optional_option  defaultkey    "$KUVERT_CFG_DEFAULTKEY"
    default_option   logfile       "$KUVERT_CFG_LOGFILE"       "$KUVERT_LOGS_DIR/kuvert.log"
    optional_option  mail-on-error "$KUVERT_CFG_MAILONERROR"
    default_option   queuedir      "$KUVERT_CFG_QUEUEDIR"      "$KUVERT_QUEUE_DIR" # FIXME
    default_option   tempdir       "$KUVERT_CFG_TEMPDIR"       "$KUVERT_TEMP_DIR"  # FIXME
    default_option   interval      "$KUVERT_CFG_INTERVAL"      "60"
    default_option   identify      "$KUVERT_CFG_IDENTIFY"      "f"
    default_option   preamble      "$KUVERT_CFG_PREAMBLE"      "f"
    mandatory_option msserver      "$KUVERT_CFG_MSSERVER"
    default_option   msport        "$KUVERT_CFG_MSPORT"        "587"
    # this makes it impossible to use unencrypted connections
    # either $KUVERT_CFG_SSL is unset, and then by default 'starttls' is used
    # or is set to 'ssl'
    # ifit's set to anything else, it will error out
    default_option   ssl           "$KUVERT_CFG_SSL"           "starttls"
    optional_option  ssl-key       "$KUVERT_CFG_SSLKEY"
    optional_option  ssl-cert      "$KUVERT_CFG_SSLCERT"
    optional_option  ssl-ca        "$KUVERT_CFG_SSLCA"
    mandatory_option msuser        "$KUVERT_CFG_MSUSER"
    mandatory_option mspass        "$KUVERT_CFG_MSPASS"
    default_option   maport        "$KUVERT_CFG_MAPORT"        "2587"
    default_option   mahost        "$KUVERT_CFG_MAHOST"        "0.0.0.0"
    default_option   ma-user       "$KUVERT_CFG_MAUSER"        "kuvert"
    mandatory_option ma-pass       "$KUVERT_CFG_MAPASS"
    default_option   defaultaction "$KUVERT_CFG_DEFAULTACTION" "fallback"
    default_option   alwaystrust   "$KUVERT_CFG_ALWAYSTRUST"   "t"

fi
