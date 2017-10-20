# Kuvert

This is `kuvert`, a wrapper around `sendmail` or other MTAs that
does gpg signing/signing+encrypting transparently, based
on the content of your public keyring(s) and your preferences.

This is a dockerized version of `kuvert`. You can run it standalone,
or build a docker container and use that.

## How it works

You need to configure your MUA to submit mails to kuvert instead of 
directly. You configure kuvert either to present an SMTP server to
your MUA, or you make your MUA to use kuvert_submit instead of executing
`/usr/sbin/sendmail`. `kuvert_submit` will spool the mail
in kuvert's queue iff there is a suitable configuration file.

`kuvert` is the tool that takes care of mangling the email. It reads the 
queue periodically and handles emails in the queue: signing or encrypting
the mail, then handing it over to `/usr/lib/sendmail` or an external SMTP 
server for transport.

(Why a queue? Because i thought it might be useful to make sure that none of
your emails leaves your system without kuvert handing it. You might be 
very paranoid, and kill kuvert whenever you leave your box (and remove
the keyrings as well).)

## Running in docker

Build it:

```
docker build --tag kuvert ./
```

Create a config file as per "Configuration" section below, name it as `kuvert.conf`. Please use the `dot-kuvert.docker` example configuration file instead of the default `dot-kuvert`! Set the environment variables as required and volume-mount the required directories (see below) when running the container.

Directories will be created and correct permissions will be set. If no GnuPG keyring is available, one will be created, along with a default key for signing (using the e-mail: `$KUVERT_USER@localhost`. `$KUVERT_GNUPG_DIR` will be watched for changes and `kuvert` will be reloaded each time a change in that directory occurs.

### Docker environment variables

 - `KUVERT_USER` (default: `kuvert`)
 - `KUVERT_GROUP` (default: `kuvert`)
 - `KUVERT_UID` (default: `1000`)
 - `KUVERT_GID` (default: `1000`)

User, group, `uid`, and `gid` of the user that will be created in the docker container and under which `kuvert` will be run.

 - `KUVERT_TEMP_DIR` (default: `/tmp/kuvert_temp`)
 
Temporary files directory. It will be created. Make sure it matches the `tempdir` option from the config file.

 - `KUVERT_HOME` (default: `/home/kuvert`)
 
Home directory of the user `kuvert` will be run under in the container. It will be created. It's used as base directory for `KUVERT_*_DIR` envvars described below.

 - `KUVERT_LOGS_DIR` (default: `$KUVERT_HOME/logs`)

Logs directory. Set it to whatever directory contains the `logfile` configured in `kuvert.conf` config file located in `$KUVERT_CONFIG_DIR`. The directory will be created and permissions will be set as required. Volume-mount it into the docker container upon running it to have logs available outside the container (and survive container restarts).
 
 - `KUVERT_QUEUE_DIR` (default: `$KUVERT_HOME/queue`)

Queue directory. Set it to whatever `queuedir` is set to in the `kuvert.conf` config file. The directory will be created and permissions will be set as required. Volume-mount it into the docker container upon running it to have the queue available outside the container (and survive container restarts).

 - `KUVERT_GNUPG_DIR` (default: `$KUVERT_HOME/gnupg`)

GnuPG data directory, containing the keyring. Location will be used by `kuvert` (via the automagically set `GNUPGHOME` envvar) and also will be watched for changes. When changes are detected, `kuvert` will be reloaded in order to load the new andmodified keys. The directory will be created and permissions will be set as required. Volume-mount it into the docker container upon running it to have the keyring available outside the container (and survive container restarts).
 
 - `KUVERT_CONFIG_DIR` (default: `$KUVERT_HOME/config`)
 
Config directory, should contain a `kuvert.conf` file, which will be used it by `kuvert`. The directory will be created and permissions will be set as required. Volume-mount it into the docker container upon running it to make the config from the host system available in the container for `kuvert` to use. If the config file is not provided, an attempt will be made to generate one (read on).

### Generated config

Optionally, a config file can be auto-generated based on environment variables from this section. The config will be generated if `$KUVERT_CONFIG_DIR/kuvert.conf` file does not exist (otherwise it is assumed that it contains a valid config).

Please note, not all `kuvert` config options are exposed this way, since exposing some would simply not make any sense. Certain assumptions are made in the generated config file, please refer to comments in `generate-kuvert-conf.sh` file.

 - `$KUVERT_CFG_DEFAULTKEY` (optional)  
    kuvert config option: `defaultkey`)

 - `$KUVERT_CFG_LOGFILE` (default: "`$KUVERT_LOGS_DIR/kuvert.log`")  
    kuvert config option: `logfile`
    
 - `$KUVERT_CFG_MAILONERROR` (optional)  
    kuvert config option: `mail-on-error`
    
 - `$KUVERT_CFG_INTERVAL` (default: "`60`")  
    kuvert config option: `interval`
 
 - `$KUVERT_CFG_IDENTIFY` (default: "`f`")  
    kuvert config option: `identify`
    
 - `$KUVERT_CFG_PREAMBLE` (default: "`f`")  
    kuvert config option: `preamble`
    
 - `$KUVERT_CFG_MSSERVER` (**mandatory**)  
    kuvert config option: `msserver`
    
 - `$KUVERT_CFG_MSPORT` (default: "`587`")  
    kuvert config option: `msport`
    
 - `$KUVERT_CFG_SSL` (default: "`starttls`")  
    kuvert config option: `ssl`  
    Notice: the way this option is handled means it's impossible to use cleartext connections when using a generated `kuvert.conf`.
    
 - `$KUVERT_CFG_SSLKEY` (optional)  
    kuvert config option: `ssl-key`
    
 - `$KUVERT_CFG_SSLCERT` (optional)  
    kuvert config option: `ssl-cert`
    
 - `$KUVERT_CFG_SSLCA` (optional)  
    kuvert config option: `ssl-ca`
    
 - `$KUVERT_CFG_MSUSER` (**mandatory**)  
    kuvert config option: `msuser`
    
 - `$KUVERT_CFG_MSPASS` (**mandatory**)  
    kuvert config option: `mspass`
    
 - `$KUVERT_CFG_MAPORT` (default: "`2587`")  
    kuvert config option: `maport`
    
 - `$KUVERT_CFG_MAHOST` (default: "`0.0.0.0`")  
    kuvert config option: `mahost`
    
 - `$KUVERT_CFG_MAUSER` (default: "`kuvert`")  
    kuvert config option: `ma-user`
    
 - `$KUVERT_CFG_MAPASS` (**mandatory**)  
    kuvert config option: `ma-pass`
    
 - `$KUVERT_CFG_DEFAULTACTION` (default: "`fallback`")  
    kuvert config option: `defaultaction`
    
 - `$KUVERT_CFG_ALWAYSTRUST` (default: "`t`")  
    kuvert config option: `alwaystrust`
    

### Reporting issues with docker configuration

Please report errors and request feature requests regarding operation in a docker container as [GitHub issues in this project](https://github.com/occrp/kuvert/issues).

## Non-docker Installation

On Debian systems you simply install the `kuvert` package, construct
a suitable `.kuvert` configuration file and off you go. 
An example config file is provided
at `/usr/share/doc/kuvert/examples/dot-kuvert`.

On other systems you need to do the following:

You need `perl` 5.10+, `gpg` and a raft of perl modules:
`MIME::Parser`, `Mail::Address`, `Net::SMTP` 1.28 (in core but not new enough
with some distributions), `IO::Socket::SSL` 2.007, `Net::Server::Mail::ESMTP`,
`Sys::Hostname`, `Authen::SASL`, `IO::Socket::INET`, `FileHandle`, `File::Slurp`,
`File::Temp`, `Fcntl`, `Time::HiRes`, `Proc::ProcessTable`, and `Encode::Locale`.
Some of those are part of a standard perl intall, others you'll have to
get from your nearest CPAN archive and install.
Optional: get linux-kernel keyutils package, the gpg-agent or some 
other passphrase cache of your choice.

Run `make`, `make install DESTDIR=/` as root
-> `kuvert`, `kuvert_submit`, the manpages and one helper module 
will be installed in `/usr/bin`, `/usr/share/man/man1` and 
`/usr/share/perl5/Net/Server/Mail/ESMTP/`, respectively.

## Configuration

Read the manpages for `kuvert(1)` and `kuvert_submit(1)` and 
consult the example config file "`dot-kuvert`". You will need
to create your own config file as `~/.kuvert`. Sorry, no autoconfig here:
this step is too crucial for a mere robot to perform. 

Then start `kuvert` and inject a testmail, look at the logs to check
if everything works correctly.

(Historical note: `kuvert` came into existence in 1996 as `pgpmail` and
was used only privately until 99, when it was extended and renamed
to `guard`. Some of my friends started using this software, and in 
2001 it was finally re-christened `kuvert`, extended even further
and debianized. In 2008 it received a major overhaul to also provide 
inbound SMTP as submission mechanism, outbound SMTP transport and better
controllability via email addresses. Until 2008 `kuvert` supported pgp2.x.)

Please report bugs to me, Alexander Zangerl, <az@snafu.priv.at>.

The original source can always be found at:
	http://www.snafu.priv.at/kuvert/

```
Copyright (C) 1999-2013 Alexander Zangerl

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2
  as published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License with
  the Debian GNU/Linux distribution in file /usr/share/common-licenses/GPL;
  if not, write to the Free Software Foundation, Inc., 59 Temple Place,
  Suite 330, Boston, MA  02111-1307  USA
```
