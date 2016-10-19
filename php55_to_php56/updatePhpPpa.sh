#!/bin/sh

sudo LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php
sudo apt-get update
sudo apt-get install php5.6-fpm
# now change the socket path in your nginx/apache2 configuration
# from (/var)/run/php5-fpm.sock to /run/php/php5.6-fpm.sock
# and restart the server

#switch from php 7 to 5.6
sudo update-alternatives --set php /usr/bin/php5.6

# stop old PHP 5 FPM
sudo service php5-fpm stop
# copy the old configuration from /etc/php5/fpm/pool.d/ to /etc/php/5.6/fpm/pool.d/
# except www.conf
sudo cp /etc/php/5.6/fpm/pool.d/www.conf /etc/php/5.6/fpm/pool.d/www.conf.bak
sudo cp /etc/php5/fpm/pool.d/www.conf /etc/php/5.6/fpm/pool.d/www.conf
sudo cp /etc/php5/fpm/php.ini /etc/php/5.6/fpm/php.ini
# disable old PHP 5 FPM
sudo update-rc.d php5-fpm disable
# restart PHP 5.6 FPM to read the new configuration
sudo service php5.6-fpm stop


sudo apt-get install php5.6-curl
sudo apt-get install php5.6-dev
sudo apt-get install php5.6-gd
sudo apt-get install php5.6-intl
sudo apt-get install php5.6-mcrypt
sudo apt-get install php-memcache 
sudo apt-get install php-memcached
sudo apt-get install php-mongo
sudo apt-get install php5.6-mysql
sudo apt-get install php5.6-xml
sudo apt-get install php5.6-mbstring
sudo apt-get install php5.6-bcmath

sudo apt-get --purge remove php5-common
sudo add-apt-repository --remove ppa:ondrej/php5-5.6

sudo rm /etc/init.d/php5-fpm
