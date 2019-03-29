#!/bin/bash

function getLastGithubTag {
	JSON=$(curl -s https://api.github.com/repos/${1}/${2}/tags | jq '.[0]')

	MEDIAWIKI_TAG_NAME=$(echo ${JSON} | jq '.name' | sed -e 's/"//g')
	MEDIAWIKI_VERSION=$(echo ${MEDIAWIKI_TAG_NAME} | cut -d "." -f 1,2)
	MEDIAWIKI_PATCH=$(echo ${MEDIAWIKI_TAG_NAME} | cut -d "." -f 3)
	MEDIAWIKI_TARBALL=$(echo ${JSON} | jq '.tarball_url' | sed -e 's/"//g')
}

function getLastDockerImage {
	BASE_TAG=$(wget -q https://registry.hub.docker.com/v1/repositories/${1}/tags -O - | sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' | tr '}' '\n' | awk -F: '{print $3}' | grep ${2} | sort | tail -n 1)
}

getLastGithubTag wikimedia mediawiki
getLastDockerImage ubuntu bionic-

cat > Dockerfile <<'EOF'
ARG BASE_TAG=%BASE_TAG%
  
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

RUN cd /var/lib/mysql && \
	tar -czf ../mysql.tar.gz *

RUN mkdir /var/run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
	&& chmod 777 /var/run/mysqld

ARG MEDIAWIKI_VERSION=%MEDIAWIKI_VERSION%
ARG MEDIAWIKI_PATCH=%MEDIAWIKI_PATCH%
ARG MEDIAWIKI_TARBALL=https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_VERSION}/mediawiki-${MEDIAWIKI_VERSION}.${MEDIAWIKI_PATCH}.tar.gz

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

ENTRYPOINT ["/entrypoint.sh"]
EOF

sed -i '' -e "s/%BASE_TAG%/${BASE_TAG}/g" Dockerfile
sed -i '' -e "s/%MEDIAWIKI_VERSION%/${MEDIAWIKI_VERSION}/g" Dockerfile
sed -i '' -e "s/%MEDIAWIKI_PATCH%/${MEDIAWIKI_PATCH}/g" Dockerfile

BASE_VERSION=$(echo ${BASE_TAG} | cut -d "-" -f 2)
TAGS="v${MEDIAWIKI_VERSION}.${MEDIAWIKI_PATCH} v${MEDIAWIKI_VERSION}.${MEDIAWIKI_PATCH}-${BASE_VERSION}"

TEXT="Update to ubuntu:${BASE_TAG} and Mediawiki ${MEDIAWIKI_VERSION}.${MEDIAWIKI_PATCH}"

git add Dockerfile
git commit -m "${TEXT}"

for TAG in ${TAGS}; do
	git tag -d "${TAG}"
	git push origin :refs/tags/"${TAG}"
	git tag -af "${TAG}" -m "${TEXT}"
done

git push
git push --tags
