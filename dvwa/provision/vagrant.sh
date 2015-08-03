#!/bin/bash
set -e

echo "Update the system."
apt-get update -y &> /dev/null
apt-get upgrade -y &> /dev/null
