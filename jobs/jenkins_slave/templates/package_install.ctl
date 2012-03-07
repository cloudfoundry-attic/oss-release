#!/bin/bash
# abort script on any command that exit with a non zero value
set -e

# The legacy installed packages from puppet
# TODO: Add stuff here according to the test

apt-get install libsqlite3-dev

if [ ! -f /var/vcap/store/jenkins_slave/tmp/ubuntu.iso ]; then
  mkdir -p /var/vcap/store/jenkins_slave/tmp/
  wget -r --tries=10 -O /var/vcap/store/jenkins_slave/tmp/ubuntu.iso http://releases.ubuntu.com/lucid/ubuntu-10.04.4-server-amd64.iso
  chown -R vcap:vcap /var/vcap/store/jenkins_slave/tmp/
fi
