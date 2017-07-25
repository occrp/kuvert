FROM perl
MAINTAINER Michał "rysiek" Woźniak <rysiek@occrp.org>

# envvars -- runscript will handle these
ENV KUVERT_USER kuvert
ENV KUVERT_GROUP kuvert
ENV KUVERT_UID 1000
ENV KUVERT_GID 1000
ENV KUVERT_TEMP_DIR /tmp/kuvert_temp
ENV KUVERT_HOME /home/kuvert

# install inotify-tools
RUN DEBIAN_FRONTEND=noninteractive apt-get -q update && \
    apt-get -q -y --no-install-recommends install \
        # without it we're going to be getting weird errors like:
        # SMTP auth failed: 500 Command unknown: 'AUTH'
        # cannot connect to mail server example.org
        ca-certificates \
        # required for monitoring of the gnupg directory for changes
        inotify-tools && \
    apt-get -q clean && \
    apt-get -q -y autoremove && \
    rm -rf /var/lib/apt/lists/*

# install the needed CPAN modules
# divided into separate RUN commands for easier debugging
# (cpan's output does not lend itself to debugging very well...)
RUN cpan -i MIME::Parser
RUN cpan -i Mail::Address
RUN cpan -i Net::SMTP
RUN cpan -i Sys::Hostname
RUN cpan -i Net::Server::Mail
RUN cpan -i Authen::SASL
RUN cpan -i IO::Socket::INET
RUN cpan -i FileHandle
RUN cpan -i File::Slurp
RUN cpan -i File::Temp
RUN cpan -i Fcntl
RUN cpan -i Time::HiRes
RUN cpan -i Proc::ProcessTable
RUN cpan -i Encode::Locale

COPY ./ /usr/local/src/kuvert/
RUN cd /usr/local/src/kuvert/ && \
    make && \
    make install

# make sure entrypoint script is runnable
RUN chmod a+x /usr/local/src/kuvert/run.sh

ENTRYPOINT ["/usr/local/src/kuvert/run.sh"]
CMD ["kuvert", "-d"]