FROM centos:7
MAINTAINER Erich Bremer "erich.bremer@stonybrook.edu"
#
# QuIP - PathDB Docker Container
#
### update OS
RUN yum -y update
RUN yum -y install wget which zip unzip telnet java-1.8.0-openjdk epel-release
RUN rpm -Uvh http://mirror.bebout.net/remi/enterprise/remi-release-7.rpm
RUN yum-config-manager --enable remi-php72
RUN yum -y install httpd openssl mod_ssl mod_php php-opcache php-xml php-mcrypt php-gd php-devel php-mysql php-intl php-mbstring php-uploadprogress php-pecl-zip
RUN yum -y install mariadb-server mariadb-client
RUN yum -y install git
RUN sed -i 's/;date.timezone =/date.timezone = America\/New_York/g' /etc/php.ini
RUN sed -i 's/;always_populate_raw_post_data = -1/always_populate_raw_post_data = -1/g' /etc/php.ini
RUN yum -y install initscripts

# download Drupal management tools
WORKDIR /build
RUN wget https://getcomposer.org/installer
RUN php installer
RUN rm -f installer
RUN mv composer.phar /usr/local/bin/composer

# download caMicroscope
git clone --single-branch --branch develop https://github.com/camicroscope/caMicroscope.git

# create initial Drupal environment
RUN composer create-project drupal-composer/drupal-project:8.x-dev quip --stability dev --no-interaction
RUN mv quip /quip

# copy Drupal QuIP module over
WORKDIR /quip/web/modules
RUN mkdir quip
COPY quip/ quip/

WORKDIR /quip/web
COPY images/ images/

# download and install extra Drupal modules
WORKDIR /quip
RUN composer require drupal/restui
RUN composer require drupal/search_api
RUN composer require drupal/token
RUN composer require drupal/typed_data
RUN composer require drupal/jwt
RUN composer require drupal/d8w3css
RUN composer require drupal/hide_revision_field
RUN composer require drupal/field_group
RUN composer require drupal/tac_lite
RUN composer require drupal/field_permissions
RUN composer require drupal/views_taxonomy_term_name_depth
RUN composer require drupal/ds
RUN composer require drupal/taxonomy_unique
RUN composer require drupal/prepopulate
# set permissions correctly for apache demon access
RUN chown -R apache ../quip
RUN chgrp -R apache ../quip
# adjust location of Drupal-supporting MySQL database files
RUN sed -i 's/datadir=\/var\/lib\/mysql/datadir=\/data\/pathdb\/mysql/g' /etc/my.cnf
# increase php file upload sizes and posts
RUN sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 2G/g' /etc/php.ini
RUN sed -i 's/post_max_size = 8M/post_max_size = 1G/g' /etc/php.ini
# set up Drupal private file area
RUN mkdir -p /data/pathdb/files
RUN chown -R apache /data/pathdb/files
RUN echo "\$settings['file_private_path'] = '/data/pathdb/files';" >> web/sites/default/settings.php

# create self-signed digital keys for JWT
WORKDIR /etc/httpd/conf
RUN openssl req -subj '/CN=www.mydom.com/O=My Company Name LTD./C=US' -x509 -nodes -newkey rsa:2048 -keyout quip.key -out quip.crt

# copy over Docker initialization scripts
EXPOSE 80
COPY run.sh /root/run.sh
COPY httpd.conf /etc/httpd/conf
RUN mkdir /quip/pathdbconfig
COPY config/* /quip/pathdbconfig/
RUN mkdir /quip/content
COPY content/* /quip/content/
RUN mkdir /quip/web/sup
COPY sup/* /quip/web/sup/
RUN mkdir /quip/web/caMicroscope
COPY /build/caMicroscope/* /quip/web/caMicroscope
RUN chmod 755 /root/run.sh
CMD ["sh", "/root/run.sh"]
