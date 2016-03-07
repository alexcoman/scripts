#!/bin/bash
set -e

echo "Disabling firewall..."
sudo ufw allow 80

echo "Restarting services..."
sudo service nginx restart
sudo service php5-fpm restart
echo "Done."
