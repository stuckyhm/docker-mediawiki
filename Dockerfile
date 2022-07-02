ARG BASE_IMAGE_TAG=1.38.2

FROM mediawiki:${BASE_IMAGE_TAG}

MAINTAINER Sebastian Stuckenbrock sstuckenbrock@efhm.de

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get -y install \
		wget \
		supervisor \
		imagemagick \
		libgd3 \
		git \
		pwgen \
		default-mysql-server

RUN cd /var/lib/mysql \
	&& tar -czf ../mysql.tar.gz *

RUN mkdir /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
	&& chmod 777 /var/run/mysqld

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
      org.label-schema.version=${BASE_IMAGE_TAG} \
      org.label-schema.schema-version="1.0"
