FROM perl
MAINTAINER Michał "rysiek" Woźniak <rysiek@occrp.org>

# envvars -- runscript will handle these
ENV KUVERT_USER kuvert
ENV KUVERT_GROUP kuvert
ENV KUVERT_UID 1000
ENV KUVERT_GID 1000
ENV KUVERT_HOME /home/kuvert

# install the needed CPAN modules
RUN echo | cpan -i MIME::Parser Mail::Address Net::SMTPS Sys::Hostname Net::Server::Mail Authen::SASL IO::Socket::INET Filehandle File::Slurp File::Temp Fcntl Time::HiRes

COPY ./ /usr/local/src/kuvert/
RUN cd /usr/local/src/kuvert/ && \
    make && \
    make install
    
RUN chmod a+x /usr/local/src/kuvert/run.sh

ENTRYPOINT ["/usr/local/src/kuvert/run.sh"]
CMD ["kuvert"]