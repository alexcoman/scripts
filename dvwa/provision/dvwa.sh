#!/bin/bash
set -e

echo "Creating 'dvwa' database"
echo 'create database if not exists `dvwa`' | mysql

sudo service nginx restart
sudo service php5-fpm restart

sudo ufw allow 80