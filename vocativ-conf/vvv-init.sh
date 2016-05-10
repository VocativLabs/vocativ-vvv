#!/bin/bash

echo "Commencing Vocativ Base Setup as user: $USER"

cd /srv/www/

echo "Setting permissions..."
sudo touch /var/log/php5-fpm.log

echo "Copying vagrant ssh settings to root..."
sudo su - root -c 'cp /home/vagrant/.ssh/id_rsa* /root/.ssh/ && eval "$(ssh-agent -s)" && ssh-add /root/.ssh/id_rsa'

echo "Creating database (if it does not exist already)"
mysql -u root --password=root -e "CREATE DATABASE vocativ" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON vocativ.* TO root@localhost IDENTIFIED BY 'root';"

    if [ -f /srv/database/init-vocativ.sql ]; then
        mysql -u root --password=root vocativ < /srv/database/init-vocativ.sql
    else
        echo "Unable to find /srv/database/init-vocativ.sql. Halting!"
        exit 1
    fi
else
    echo "Database already exists. Skipping database setup..."
fi

# Check for the presence of the vocativ folder
if [ ! -d vocativ ]; then
    echo "Cloning Vocativ Repo..."
    git clone git@github.com:Vocativ/wp-site.git vocativ

    if [ $? -ne 0 ]; then
        echo "Unable to clone Vocativ repo. Halting!"
        exit 1
    fi
else
    echo "Vocativ directory already exists. Skipping..."
fi

if [ ! -d vocativ ]; then
    echo "Still can't find Vocativ directory. Halting!"
    exit 1
fi

# Check for .dev.json and create it if it doesn't exist
echo "Creating .dev.json if it doesn't exist already"
if [ ! -f vocativ/.dev.json ]; then
    echo "Creating .dev.json file"
    echo "{
   \"db\": {
     \"host\": \"localhost\",
     \"port\": 3306,
     \"name\": \"vocativ\",
     \"user\": \"root\",
     \"pass\": \"root\"
   },
   \"site\": {
     \"url\": \"http://vocativ.dev\",
     \"admin_hostname\" : \"cms.vocativ.dev\"
   },
   \"wordpress\": {
     \"debug\": true,
     \"constants\": {
       \"COOKIE_DOMAIN\": \".vocativ.dev\",
       \"SCRIPT_DEBUG\": true,
       \"VOCATIV_ACCOUNTS_FACEBOOK_APP_ID\": \"479334422145013\",
       \"VOCATIV_ACCOUNTS_FACEBOOK_APP_SECRET\": \"a61733d814cfbc8cc951ac65411ff1c6\",
       \"WP_POST_REVISIONS\": 5,
       \"WP_DEBUG\": true,
       \"WP_DEBUG_LOG\": true,
       \"WP_MEMORY_LIMIT\": \"2048M\",
       \"PL_HOST\" : \"localhost:8000\"
     }
   }
 }" > vocativ/.dev.json
else
    echo ".dev.json already exists. Skipping..."
fi

PHP_INSTALLED=$(phpbrew  list | grep '5.6' | wc -l)

if [ $PHP_INSTALLED == 0 ]; then
    echo "PHP 5.6 not found. Installing..."
    phpbrew install 5.6
fi

echo "Setting PHPBrew to use 5.6"
phpbrew use $(phpbrew list | grep -v system | grep '5.6' | head -n 1)

echo "Running composer and submodule init in Vocativ directory"
cd vocativ
sudo -u vagrant git submodule update --init --recursive
sudo -u vagrant composer install
