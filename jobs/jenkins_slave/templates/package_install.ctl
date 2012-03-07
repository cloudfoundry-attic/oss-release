#!/bin/bash
# abort script on any command that exit with a non zero value
set -e

if [ ! -f /var/vcap/store/jenkins_slave/tmp/ubuntu.iso ]; then
  mkdir -p /var/vcap/store/jenkins_slave/tmp/
  wget -b -r --tries=10 -O /var/vcap/store/jenkins_slave/tmp/ubuntu.iso http://releases.ubuntu.com/lucid/ubuntu-10.04.4-server-amd64.iso
  chown -R vcap:vcap /var/vcap/store/jenkins_slave/tmp/
fi
