#!/bin/bash

/srv/bin/init-hosts.sh

/usr/local/sbin/nginx -t || exit 1

#/etc/init.d/lancache start

/usr/local/sbin/nginx -c /usr/local/nginx/nginx.conf

/usr/sbin/sniproxy -c /srv/etc/sniproxy.conf -f 
