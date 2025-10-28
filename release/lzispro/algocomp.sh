#!/bin/sh

DEVICE_MODEL="gt-ax6000"
PARA_QUERY_PROC_NUM=48

PATH_CURRENT="${0%/*}"
! echo "${PATH_CURRENT}" | grep -q '^[/]' && PATH_CURRENT="$( pwd )${PATH_CURRENT#*.}"

chmod 775 "${PATH_CURRENT}/lzispro.sh"

rm -f "${PATH_CURRENT}/${DEVICE_MODEL}_syslog.log" > /dev/null 2>&1

sed -i -e 's/^[[:space:]]*IPV4_DATA=.*$/IPV4_DATA=0/' \
    -e 's/^[[:space:]]*IPV6_DATA=.*$/IPV6_DATA=0/' \
    -e "s/^[[:space:]]*PARA_QUERY_PROC_NUM=.*$/PARA_QUERY_PROC_NUM=${PARA_QUERY_PROC_NUM}/" \
    -e 's/^[[:space:]]*CIDR_MERGE_ALGO=.*$/CIDR_MERGE_ALGO=2/' \
    -e "s/^[[:space:]]*#SYSLOG=\"\${PATH_CURRENT}\/syslog.log\".*$/SYSLOG=\"\${PATH_CURRENT}\/${DEVICE_MODEL}_syslog.log\"/" "${PATH_CURRENT}/lzispro.sh"
sh "${PATH_CURRENT}/lzispro.sh"

sed -i 's/^[[:space:]]*CIDR_MERGE_ALGO=.*$/CIDR_MERGE_ALGO=1/' "${PATH_CURRENT}/lzispro.sh"
sh "${PATH_CURRENT}/lzispro.sh"

sed -i 's/^[[:space:]]*CIDR_MERGE_ALGO=.*$/CIDR_MERGE_ALGO=0/' "${PATH_CURRENT}/lzispro.sh"
sh "${PATH_CURRENT}/lzispro.sh"

sed -i "s/^SYSLOG=\"\${PATH_CURRENT}\/${DEVICE_MODEL}_syslog.log\"/#&/" "${PATH_CURRENT}/lzispro.sh"
