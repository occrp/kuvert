FROM perl
MAINTAINER Michał "rysiek" Woźniak <rysiek@occrp.org>

# envvars -- runscript will handle these
ENV KUVERT_USER kuvert
ENV KUVERT_GROUP kuvert
ENV KUVERT_UID 1000
ENV KUVERT_GID 1000
ENV KUVERT_HOME /home/kuvert

# install the needed CPAN modules
# divided into separate RUN commands for easier debugging
# (cpan's output does not lend itself to debugging very well...)
RUN cpan -i MIME::Parser
RUN cpan -i Mail::Address
RUN cpan -i Net::SMTPS
RUN cpan -i Sys::Hostname
RUN cpan -i Net::Server::Mail
RUN cpan -i Authen::SASL
RUN cpan -i IO::Socket::INET
RUN cpan -i FileHandle
RUN cpan -i File::Slurp
RUN cpan -i File::Temp
RUN cpan -i Fcntl
RUN cpan -i Time::HiRes

COPY ./ /usr/local/src/kuvert/
RUN cd /usr/local/src/kuvert/ && \
    make && \
    make install
    
RUN chmod a+x /usr/local/src/kuvert/run.sh

ENTRYPOINT ["/usr/local/src/kuvert/run.sh"]
CMD ["kuvert"]