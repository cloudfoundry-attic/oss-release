#!/bin/bash
# abort script on any command that exit with a non zero value
set -e

if [ ! -f /var/vcap/store/jenkins_slave/tmp/ubuntu.iso ]; then
  mkdir -p /var/vcap/store/jenkins_slave/tmp/
  wget -b -r --tries=10 -O /var/vcap/store/jenkins_slave/tmp/ubuntu.iso http://releases.ubuntu.com/lucid/ubuntu-10.04.4-server-amd64.iso
  chown -R vcap:vcap /var/vcap/store/jenkins_slave/tmp/
fi

# As a work-around to install backport
set +e
ubuntu_version=`/usr/bin/lsb_release -r | grep 10.04`
if [ ! -z "$ubuntu_version" ]; then
  will_reboot=0
  backport_installed=`dpkg --get-selections | grep linux-image-server-lts-backport-natty | grep install`
  if [ -z "$backport_installed" ]; then
    apt-get install -y linux-image-server-lts-backport-natty
    will_reboot=1
  fi
  apt-get install -y debootstrap
  if [ $will_reboot -eq 1 ]; then
    reboot
  fi
fi
set -e
