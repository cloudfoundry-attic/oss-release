#!/bin/bash
# abort script on any command that exit with a non zero value
set -e

if [ ! -f /var/vcap/store/jenkins_slave/tmp/ubuntu.iso ]; then
  mkdir -p /var/vcap/store/jenkins_slave/tmp/
  wget -b -r --tries=10 -O /var/vcap/store/jenkins_slave/tmp/ubuntu.iso http://releases.ubuntu.com/lucid/ubuntu-10.04.4-server-amd64.iso
  chown -R vcap:vcap /var/vcap/store/jenkins_slave/tmp/
fi

PACKAGE_ROOT_DIR=/var/vcap/packages
ENABLE_ZABBIX_AGENT=<%= properties.jenkins.enable_zabbix_agent||0 %>

# install zabbix agent
if [ $ENABLE_ZABBIX_AGENT = 1 ]; then
  dpkg -iE $PACKAGE_ROOT_DIR/zabbix_agent/bds-zabbix_0.1-39_all.deb
  zabbix_running=`ps -ef | grep zabbix | grep -c -v "grep"`
  if [ $zabbix_running -eq 0 ]; then
    mkdir -p "/var/run/zabbix-agent"
    /etc/init.d/zabbix-agent start
  fi
else
  zabbix_running=`ps -ef | grep zabbix | grep -c -v "grep"`
  if [ $zabbix_running -gt 0 ]; then
    killall zabbix_agentd
  fi
  zabbix_installed=`dpkg -l | grep -c bds-zabbix`
  if [ $zabbix_installed -gt 0 ] ; then
    dpkg -P bds-zabbix
  fi
fi
