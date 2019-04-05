# Mediawiki
[![](https://images.microbadger.com/badges/image/stucky/mediawiki.svg)](https://microbadger.com/images/stucky/mediawiki)
[![](https://images.microbadger.com/badges/version/stucky/mediawiki.svg)](https://microbadger.com/images/stucky/mediawiki)
[![](https://images.microbadger.com/badges/commit/stucky/mediawiki.svg)](https://microbadger.com/images/stucky/mediawiki)
[![Docker Pulls](https://img.shields.io/docker/pulls/stucky/mediawiki.svg)]()
## How to use this image
### Start without existing *LocalSettings.php*

 1. Create a temporary container without mounting the *LocalSettings.php*
```bash
$ docker run -d \
  --name wiki-temp \
  -v <your-path>/mysql:/var/lib/mysql \
  -p 8080:80 \
  stucky/mediawiki:v1.32.1-20190307
```
 2. While the first start of the container an empty mysql database would be created. Your will find the mysql root password in the log.
```bash
$ docker logs wiki-temp
GENERATED ROOT PASSWORD: quaeniQu3wohmeishie3eekauphaiB8e
2019-03-25 13:03:08,165 CRIT Supervisor running as root (no user in config file)
2019-03-25 13:03:08,165 INFO Included extra file "/etc/supervisor/conf.d/mediawiki.conf" during parsing
2019-03-25 13:03:08,173 INFO RPC interface 'supervisor' initialized
...
```
Keep it on save place. You will need it later.
 3. Open your wiki (e.g. http://127.0.0.1:8080) in your browser and follow the config creating assistant to the end. In the database section use 127.0.0.1, root and your mysql root password from step 2. In the last step download the completed *LocalSettings.php*.
 4. Now you can destroy the container. We don't need it anymore.
```bash
$ docker stop wiki-temp
$ docker rm wiki-temp
```
 5. Create the final container with your new *LocalSettings.php*
```bash
docker run -d \
  --restart=always \
  --name my-wiki \
  -v <your-path>/mysql:/var/lib/mysql \
  -v <your-path>/images:/var/www/mediawiki/images \
  -v <your-path>/extensions:/var/www/mediawiki/extensions \
  -v <your-path>/skins:/var/www/mediawiki/skins \
  -v <your-path>/LocalSettings.php:/var/www/mediawiki/LocalSettings.php \
  -p 8080:80 \
  stucky/mediawiki:v1.32.1-20190307
```
