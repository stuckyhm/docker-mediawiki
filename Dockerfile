ARG BASE_TAG=bionic-20190307
FROM ubuntu:${BASE_TAG}

MAINTAINER Sebastian Stuckenbrock sstuckenbrock@efhm.de

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y install apt-transport-https apt-utils curl gpg

RUN echo 'deb http://packages.dotdeb.org jessie all' > /etc/apt/sources.list.d/dotdeb.list \
	&& curl http://www.dotdeb.org/dotdeb.gpg | apt-key add - \
	&& apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y install \
		wget \
		supervisor \
		libapache2-mod-php7.2 \
		php7.2 \
		php7.2-gd \
		php7.2-intl \
		php7.2-mysql \
		php7.2-xml \
		php7.2-apcu \
		php7.2-mbstring \
		composer \
		imagemagick \
		libgd3 \
		git \
		pwgen \
		mysql-server

RUN sed -i 's|DocumentRoot /var/www/html| DocumentRoot /var/www/mediawiki|g' /etc/apache2/sites-available/000-default.conf

RUN mkdir /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
	&& chmod 777 /var/run/mysqld

RUN cd /var/lib/mysql && \
	tar -czf ../mysql.tar.gz *

ARG MEDIAWIKI_VERSION=1.32
ARG MEDIAWIKI_PATCH=0 
ARG MEDIAWIKI_TARBALL="https://releases.wikimedia.org/mediawiki/$MEDIAWIKI_VERSION/mediawiki-$MEDIAWIKI_VERSION.$MEDIAWIKI_PATCH.tar.gz"

RUN cd /var/www \
	&& wget -O mediawiki-${MEDIAWIKI_VERSION}.${MEDIAWIKI_PATCH}.tar.gz ${MEDIAWIKI_TARBALL} \
	&& tar -xf mediawiki-${MEDIAWIKI_VERSION}.${MEDIAWIKI_PATCH}.tar.gz && rm *.tar.gz \
	&& mv mediawiki-* mediawiki

ADD supervisord.conf /etc/supervisor/conf.d/mediawiki.conf
ADD entrypoint.sh /entrypoint.sh

EXPOSE 80

VOLUME /var/lib/mysql
VOLUME /etc/mysql/conf.d
VOLUME /var/www/mediawiki/extensions
VOLUME /var/www/mediawiki/images

#CMD ["/usr/bin/supervisord"]
ENTRYPOINT ["/entrypoint.sh"]
