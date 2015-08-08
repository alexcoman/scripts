#!/bin/bash
set -e

echo "Changing to /tmp directory..."
cd /tmp
echo "Done!"

echo "Downloading DVWA..."
wget https://github.com/RandomStorm/DVWA/archive/v1.0.8.zip >> /dev/null 2>&1
echo "Done!"

echo "Unzipping DVWA..."
unzip v1.0.8.zip > /dev/null
echo "Done!"

echo -n "Deleting the zip file..."
rm v1.0.8.zip > /dev/null
echo "Done!"

echo "Copying DVWA to /vagrant/.www..."
cp -R DVWA-1.0.8/* /vagrant/.www > /dev/null
echo "Done!"

echo "Clearing /tmp directory..."
rm -R DVWA-1.0.8 > /dev/null
echo "Done!"

echo "Enabling write permissions to /vagrant/.www/hackable/upload..."
chmod 777 /vagrant/.www/hackable/uploads
echo "Done!"

echo -n "Updating config file..."
sed -i "s/password' ] = 'p@ssw0rd'/password' ] = 'vagrant'/g" /vagrant/.www/config/config.inc.php
echo "Done!"

echo "Creating 'dvwa' database"
echo 'create database if not exists `dvwa`' | mysql
echo "Done"

echo "Restarting services..."
sudo service nginx restart
sudo service php5-fpm restart
echo "Done."

echo "Creating database..."
curl -X POST http://127.0.0.1/setup.php -d "create_db=Create / Reset Database" >> /dev/null 2>&1
echo "Done!"

sudo ufw allow 80
echo "DVWA install finished!"
