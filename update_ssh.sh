#!/bin/bash
mkdir -p ~/.ssh/
# Ajoute le contenu de /mnt/config/custom_hosts à /etc/hosts
if [ -f /opt/nagios/etc/ssh/id_rsa ]; then
    cp /opt/nagios/etc/ssh/id_rsa /opt/nagios/.ssh/id_rsa
    echo "copy id_rsa ok"
fi
if [ -f /opt/nagios/etc/ssh/id_rsa.pub ]; then
    cp /opt/nagios/etc/ssh/id_rsa.pub /opt/nagios/.ssh/id_rsa.pub
    echo "copy id_rsa.pub ok"
fi
if [ -f /opt/nagios/etc/ssh/knwon_hosts ]; then
    cp /opt/nagios/etc/ssh/id_rsa /opt/nagios/.ssh/known_hosts
    echo "copy known_host ok"
fi
chmod 700 /opt/nagios/.ssh/
chmod 600 /opt/nagios/.ssh/id_rsa
chmod 600 /opt/nagios/.ssh/id_rsa.pub
chmod 600 /opt/nagios/.ssh/known_hosts
chown -R nagios:nagios /opt/nagios/.ssh
