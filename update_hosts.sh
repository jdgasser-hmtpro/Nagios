#!/bin/bash

# Ajoute le contenu de /mnt/config/custom_hosts à /etc/hosts
if [ -f /opt/nagios/etc/hosts ]; then
    cat /opt/nagios/etc/hosts >> /etc/hosts
fi

# Affiche le résultat (optionnel)
cat /etc/hosts
