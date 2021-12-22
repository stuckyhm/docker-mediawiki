ARG BASE_IMAGE_TAG=bionic-20210930

FROM ubuntu:${BASE_IMAGE_TAG}

MAINTAINER Sebastian Stuckenbrock sstuckenbrock@efhm.de

ARG MEDIAWIKI_VERSION=1.37.1
ARG MEDIAWIKI_VERSION_MAJOR=1
ARG MEDIAWIKI_VERSION_MINOR=37
ARG MEDIAWIKI_VERSION_PATCH=1 
ARG MEDIAWIKI_TARBALL=https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_VERSION_MAJOR}.${MEDIAWIKI_VERSION_MINOR}/mediawiki-${MEDIAWIKI_VERSION}.tar.gz

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y install apt-transport-https apt-utils curl gpg software-properties-common

RUN echo 'deb http://ppa.launchpad.net/ondrej/php/ubuntu bionic main' > /etc/apt/sources.list.d/dotdeb.list \
	&& add-apt-repository ppa:ondrej/php \
	&& apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y install \
		wget \
		supervisor \
		libapache2-mod-php7.3 \
		php7.3 \
		php7.3-gd \
		php7.3-intl \
		php7.3-mysql \
		php7.3-xml \
		php7.3-apcu \
		php7.3-mbstring \
		imagemagick \
		libgd3 \
		git \
		pwgen \
		mysql-server \
	&& php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
	&& php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
	&& php -v \
	&& rm composer-setup.php
RUN php -v && date

RUN sed -i 's|DocumentRoot /var/www/html| DocumentRoot /var/www/mediawiki|g' /etc/apache2/sites-available/000-default.conf

RUN cd /var/lib/mysql && \
	tar -czf ../mysql.tar.gz *

RUN mkdir /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
	&& chmod 777 /var/run/mysqld

RUN cd /var/www \
	&& wget -O mediawiki-${MEDIAWIKI_VERSION}.tar.gz ${MEDIAWIKI_TARBALL} \
	&& tar -xf mediawiki-${MEDIAWIKI_VERSION}.tar.gz && rm *.tar.gz \
	&& mv mediawiki-* mediawiki
RUN php -v && date
ADD supervisord.conf /etc/supervisor/conf.d/mediawiki.conf
ADD entrypoint.sh /entrypoint.sh

EXPOSE 80

VOLUME /var/lib/mysql
VOLUME /etc/mysql/conf.d
VOLUME /var/www/mediawiki/extensions
VOLUME /var/www/mediawiki/images

ENTRYPOINT ["/entrypoint.sh"]

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=${BUILD_DATE} \
      org.label-schema.name="Mediawiki" \
      org.label-schema.description="Simple Mediawiki Container with mysql-server included." \
      org.label-schema.url="https://hub.docker.com/r/stucky/mediawiki" \
      org.label-schema.vcs-ref=${VCS_REF} \
      org.label-schema.vcs-url="https://github.com/stuckyhm/docker-mediawiki" \
      org.label-schema.version=${MEDIAWIKI_VERSION}-${BASE_IMAGE_TAG} \
      org.label-schema.schema-version="1.0"
