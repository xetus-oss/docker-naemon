FROM phusion/baseimage
MAINTAINER Terence Kent <tkent@xetus.com>

#
# Follow the quickstart guide for installing naemon's most recent release. 
# Note! Currently nagios3 is aslso installed because it's the easiest way to get the
# npre plugin to be available
#
RUN apt-get update &&\
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -y apache2 apache2-utils libapache2-mod-fcgid\
    libfontconfig1 libjpeg62 libgd3 libxpm4 xvfb libmysqlclient18\
    ssmtp ruby python-boto &&\
  gpg --keyserver keys.gnupg.net --recv-keys F8C1CA08A57B9ED7 &&\
  gpg --armor --export F8C1CA08A57B9ED7 | apt-key add - &&\
  echo 'deb http://labs.consol.de/repo/testing/ubuntu trusty main' \
  > /etc/apt/sources.list.d/consol.list && apt-get update &&\
  DEBIAN_FRONTEND=noninteractive apt-get install -y nagios-plugins nagios-nrpe-plugin

#
# Do to a recent bug in naemon the first installation attempt fails, and
# the second one succeeds.
#
RUN  DEBIAN_FRONTEND=noninteractive apt-get install -y naemon ||\
  DEBIAN_FRONTEND=noninteractive apt-get install -y naemon

#
# Install jabber notification support through the sendxmpp
# project
#
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y sendxmpp

#
# Do post setup configuration
#
RUN sed -i 's/^#\(.*livestatus.so.*\)/\1/' /etc/naemon/naemon.cfg &&\
  sed -i 's/^#\(FromLineOverride=.*\)/FromLineOverride=YES/' /etc/ssmtp/ssmtp.conf &&\
  sed -i 's,/usr/lib/naemon/plugins,/usr/lib/nagios/plugins,' /etc/naemon/resource.cfg

ADD notify_jabber.cfg /etc/naemon/conf.d/notify_jabber.cfg
ADD check_nrpe.cfg /etc/naemon/conf.d/check_nrpe.cfg
ADD thruk_root_redirect.conf /etc/apache2/conf-enabled/

#
# Perform the data directory initialization
#
ADD data_dirs.env /data_dirs.env
ADD init.bash /init.bash
# Sync calls are due to https://github.com/docker/docker/issues/9547
RUN chmod 755 /init.bash &&\
  sync && /init.bash &&\
  sync && rm /init.bash

#
# Add the bootstrap script
#
ADD run.bash /run.bash
RUN chmod 755 /run.bash

#
# All data is stored on the root data volme
#
VOLUME ["/data"]

# Expose ports for sharing
EXPOSE 80/tcp 443/tcp

ENTRYPOINT ["/run.bash"]