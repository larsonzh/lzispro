#!/bin/sh
# lzispro.sh v1.1.8
# By LZ 妙妙呜 (larsonzhang@gmail.com)

# Multi process parallel acquisition tool for IP address data of ISP network operators in China

# Purpose:
# 1.Download the latest IP information data from APNIC.
# 2.Extract the latest IPv4/6 address raw data of Chinese Mainland, Hong Kong, Macao and Taiwan from the APINC IP
#   information data.
# 3.The multi process parallel processing method is used to query the original IPv4/6 address data in Chinese Mainland from
#   APNIC one by one to get the attribution information. The address data will be classified according to TELECOM, UNICOM/CNC,
#   CMCC, CRTC, CERNET, GWBN and other ISP operators. The data will cover all IPv4/6 addresses in Chinese Mainland.
# 4.Generate compressed IPv4/6 CIDR format address data through the CIDR aggregation algorithm.

# Available Linux platforms: Ubuntu, CentOS Stream, Rocky, Deepin, ASUSWRT-Merlin, OpenWrt, ......

# Script Command (e.g., in the lzispro Directory)
# Launch Script          ./lzispro.sh
# Forced Stop            ./lzispro.sh stop
# CIDR Merge             ./lzispro.sh cidr [4:ipv4|6:ipv6] [full path filename of the input file] [full path filename of the output file]

# Warning: 
# 1.After the script is launched through the Shell terminal, do not close the terminal window during operation, as it may
#   cause unexpected interruption of the program execution process.
# 2.When creating ISP operator data, the program needs to access APNIC through the internet for massive information queries,
#   which may take over an hour or two. During this process, please do not interrupt the execution process of the script
#   program and remain patient.

#BEIGIN

# shellcheck disable=SC2034

#  ------------- User Defined Data --------------

# Project File Deployment & Work Path
PATH_CURRENT="${0%/*}"
! echo "${PATH_CURRENT}" | grep -q '^[/]' && PATH_CURRENT="$( pwd )${PATH_CURRENT#*.}"
PATH_FUNC="${PATH_CURRENT}/func"
PATH_WHOIS="${PATH_CURRENT}/whois"
PATH_APNIC="${PATH_CURRENT}/apnic"
PATH_ISP="${PATH_CURRENT}/isp"
PATH_CIDR="${PATH_CURRENT}/cidr"
PATH_IPV6="${PATH_CURRENT}/ipv6"
PATH_IPV6_CIDR="${PATH_CURRENT}/ipv6_cidr"
PATH_TMP="${PATH_CURRENT}/tmp"

# Project script name
PROJECT_SCRIPT="${0##*/}"

# ISP Data Process Script name
ISP_DATA_SCRIPT="lzispdata.sh"

# APNIC IP Information File Target Name
APNIC_IP_INFO="lz_apnic_ip_info.txt"

# IPv4 Data
# 0--Raw Data & CIDR Data (Default)
# 1--Raw Data
# Other--Disable (e.g., 5, 8, a, x, ...)
IPV4_DATA=0

# China ISP IPv4 Raw Data Target File Name
ISP_DATA_0="lz_all_cn.txt"
ISP_DATA_1="lz_chinatelecom.txt"
ISP_DATA_2="lz_unicom_cnc.txt"
ISP_DATA_3="lz_cmcc.txt"
ISP_DATA_4="lz_chinabtn.txt"
ISP_DATA_5="lz_cernet.txt"
ISP_DATA_6="lz_gwbn.txt"
ISP_DATA_7="lz_othernet.txt"
ISP_DATA_8="lz_hk.txt"
ISP_DATA_9="lz_mo.txt"
ISP_DATA_10="lz_tw.txt"

# CIDR Aggregated IPv4 Data Target File Name
ISP_CIDR_DATA_0="lz_all_cn_cidr.txt"
ISP_CIDR_DATA_1="lz_chinatelecom_cidr.txt"
ISP_CIDR_DATA_2="lz_unicom_cnc_cidr.txt"
ISP_CIDR_DATA_3="lz_cmcc_cidr.txt"
ISP_CIDR_DATA_4="lz_chinabtn_cidr.txt"
ISP_CIDR_DATA_5="lz_cernet_cidr.txt"
ISP_CIDR_DATA_6="lz_gwbn_cidr.txt"
ISP_CIDR_DATA_7="lz_othernet_cidr.txt"
ISP_CIDR_DATA_8="lz_hk_cidr.txt"
ISP_CIDR_DATA_9="lz_mo_cidr.txt"
ISP_CIDR_DATA_10="lz_tw_cidr.txt"

# IPv6 Data
# 0--Raw Data & CIDR Data (Default)
# 1--Raw Data
# Other--Disable (e.g., 5, 8, a, x, ...)
IPV6_DATA=0

# China ISP IPv6 Raw Data Target File Name
ISP_IPV6_DATA_0="lz_all_cn_ipv6.txt"
ISP_IPV6_DATA_1="lz_chinatelecom_ipv6.txt"
ISP_IPV6_DATA_2="lz_unicom_cnc_ipv6.txt"
ISP_IPV6_DATA_3="lz_cmcc_ipv6.txt"
ISP_IPV6_DATA_4="lz_chinabtn_ipv6.txt"
ISP_IPV6_DATA_5="lz_cernet_ipv6.txt"
ISP_IPV6_DATA_6="lz_gwbn_ipv6.txt"
ISP_IPV6_DATA_7="lz_othernet_ipv6.txt"
ISP_IPV6_DATA_8="lz_hk_ipv6.txt"
ISP_IPV6_DATA_9="lz_mo_ipv6.txt"
ISP_IPV6_DATA_10="lz_tw_ipv6.txt"

# CIDR Aggregated IPv6 Data Target File Name
ISP_IPV6_CIDR_DATA_0="lz_all_cn_ipv6_cidr.txt"
ISP_IPV6_CIDR_DATA_1="lz_chinatelecom_ipv6_cidr.txt"
ISP_IPV6_CIDR_DATA_2="lz_unicom_cnc_ipv6_cidr.txt"
ISP_IPV6_CIDR_DATA_3="lz_cmcc_ipv6_cidr.txt"
ISP_IPV6_CIDR_DATA_4="lz_chinabtn_ipv6_cidr.txt"
ISP_IPV6_CIDR_DATA_5="lz_cernet_ipv6_cidr.txt"
ISP_IPV6_CIDR_DATA_6="lz_gwbn_ipv6_cidr.txt"
ISP_IPV6_CIDR_DATA_7="lz_othernet_ipv6_cidr.txt"
ISP_IPV6_CIDR_DATA_8="lz_hk_ipv6_cidr.txt"
ISP_IPV6_CIDR_DATA_9="lz_mo_ipv6_cidr.txt"
ISP_IPV6_CIDR_DATA_10="lz_tw_ipv6_cidr.txt"

# APNIC IP Information Download URL
DOWNLOAD_URL="http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest"

# IP Address Information Details Query Host
WHOIS_HOST="whois.apnic.net"

# Number of parallel query processing
# Numbers 1 and above (e.g., 1, 2, 4, 8, 16, 24, 32, 40, 48, 56, 64, ...)
# Default: 16, Min: 1. Keep per-core CPU usage under 80%.
PARA_QUERY_PROC_NUM=16

# Number of Whois Client Threads for each Query Process
# Not applicable to the official whois client
# Numbers 1 to 64 (Min: 1, Max: 64)
# Default: 1
WHOIS_CLIENT_THREAD_NUM=1

# Maximum Number Of Retries After IP Address Query Failure
# 0--Unlimited, 5--Default
RETRY_NUM=5

# CIDR Aggregation Compression Algorithm
# 0--Hash Merging (Default, Hash Table Random Access)
# 1--Sequential Merging (Sequential Index Access)
# 2--Reverse Sequential Merging (Reverse Index Access)
CIDR_MERGE_ALGO=0

# Progress Bar
# 0--Enable (Default), Other--Disable (e.g., 5, 8, a, x, ...)
PROGRESS_BAR=0

# System Event Log File
SYSLOG=""
#SYSLOG="/tmp/syslog.log"
#SYSLOG="${PATH_CURRENT}/syslog.log"

# --------------- Flobal Variable ---------------

# Forced Stop Command Word
FORCED_STOP_CMD="stop"

# CIDR Merge Command Word
CIDR_MERGE_CMD="cidr"

# IP Address Regular Expression
REGEX_IPV4_NET='(((25[0-5]|(2[0-4]|1[0-9]|[1-9])?[0-9])[.]){3}(25[0-5]|(2[0-4]|1[0-9]|[1-9])?[0-9])([/]([1-9]|[1-2][0-9]|3[0-2]))?|0[.]0[.]0[.]0[/]0)'
REGEX_IPV4="$( echo "${REGEX_IPV4_NET%([[]/[]](*}" | sed 's/^(//' )"
REGEX_SED_IPV4_NET="$( echo "${REGEX_IPV4_NET}" | sed 's/[(){}|+?]/\\&/g' )"
REGEX_IPV6_NET='(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:([0-9a-fA-F]{1,4})'
REGEX_IPV6_NET="${REGEX_IPV6_NET}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}"
REGEX_IPV6_NET="${REGEX_IPV6_NET}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}"
REGEX_IPV6_NET="${REGEX_IPV6_NET}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:))"
REGEX_IPV6_NET="${REGEX_IPV6_NET}([/]([1-9]|([1-9]|1[0-1])[0-9]|12[0-8]))?"
REGEX_IPV6="${REGEX_IPV6_NET%([[]/[]](*}"
REGEX_SED_IPV6_NET="$( echo "${REGEX_IPV6_NET}" | sed 's/[(){}|+?]/\\&/g' )"

WHOIS_MODULE="whois"

LZ_VERSION="v1.1.8"

# ------------------ Function -------------------

lz_date() { date +"%F %T"; }

lz_echo() {
    if [ -n "${SYSLOG}" ] && [ -d "${SYSLOG%/*}" ]; then
        echo "$( lz_date ) [$$]:" "${1}" | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$( lz_date ) [$$]:" "${1}"
    fi
}

proc_sync() {
    local self=$$ d pid comm
    for d in /proc/[1-9]*; do
        [ -e "${d}/comm" ] || continue
        read -r comm < "${d}/comm" 2>/dev/null || continue
        [ "${comm}" = "sh" ] || [ "${comm}" = "ash" ] || continue
        pid="${d##*/}"
        [ "${pid}" -eq "${self}" ] && continue
        grep -Fiq -- "${PROJECT_SCRIPT}" "${d}/cmdline" 2>/dev/null || continue
        lz_echo "Another instance is already running."
        return 1
    done
    return 0
}

remove_div_data() {
    local prefix="ISP_DATA_" index="0" fname=""
    [ "${1}" != "ipv4" ] && prefix="ISP_IPV6_DATA_"
    until [ "${index}" -gt "10" ]
    do
        eval fname="\${${prefix}${index}}"
        find "${PATH_TMP}" -name "${fname%.*}.dat_*" -print0 | xargs -0 rm -f
        index="$(( index + 1 ))"
    done
}

remove_tmp_data() {
    local index="0" fname="" cidr_fname="" ipv6_fname="" cidr_ipv6_fname=""
    until [ "${index}" -gt "10" ]
    do
        eval fname="\${ISP_DATA_${index}}"
        eval cidr_fname="\${ISP_CIDR_DATA_${index}}"
        eval ipv6_fname="\${ISP_IPV6_DATA_${index}}"
        eval cidr_ipv6_fname="\${ISP_IPV6_CIDR_DATA_${index}}"
        [ -f "${PATH_TMP}/${fname%.*}.dat" ] && rm -f "${PATH_TMP}/${fname%.*}.dat"
        [ -f "${PATH_TMP}/${cidr_fname%.*}.dat" ] && rm -f "${PATH_TMP}/${cidr_fname%.*}.dat"
        [ -f "${PATH_TMP}/${ipv6_fname%.*}.dat" ] && rm -f "${PATH_TMP}/${ipv6_fname%.*}.dat"
        [ -f "${PATH_TMP}/${cidr_ipv6_fname%.*}.dat" ] && rm -f "${PATH_TMP}/${cidr_ipv6_fname%.*}.dat"
        index="$(( index + 1 ))"
    done
    [ -f "${PATH_TMP}/${APNIC_IP_INFO%.*}.dat" ] && rm -f "${PATH_TMP}/${APNIC_IP_INFO%.*}.dat"
}

kill_processes() {
    local pname="$1" pattern="${2:-}" d pid comm cnt=0
    for d in /proc/[1-9]*; do
        [ -e "${d}/comm" ] || continue
        read -r comm < "${d}/comm" 2>/dev/null || continue
        [ "${comm}" = "${pname}" ] || continue
        if [ -n "${pattern}" ]; then
            grep -Fiq -- "${pattern}" "${d}/cmdline" 2>/dev/null || continue
        fi
        pid=${d##*/}
        [ "${pid}" -eq $$ ] && continue
        # printf 'kill -TERM %d # %s<%s>\n' "${pid}" "${pname}" "${pattern:-*}"
        kill -TERM "${pid}" 2>/dev/null
        # kill -KILL "${pid}"
        cnt="$((cnt + 1))"
    done
    return "${cnt}"
}

kill_others_with_same_name() {
    local pname="${1}" d pid comm
    pname="${pname:-"${0##*/}"}"
    for d in /proc/[1-9]*; do
        [ -e "${d}/comm" ] || continue
        read -r comm < "${d}/comm" 2>/dev/null || continue
        [ "${comm}" = "${pname}" ] || continue
        pid="${d##*/}"
        [ "${pid}" -eq $$ ] && continue
        kill -TERM "${pid}" 2>/dev/null
    done
}

kill_child_processes() {
    kill_processes "${ISP_DATA_SCRIPT}"
    kill_processes "awk" "^(=== Query"
    kill_processes "awk" "/CNC|UNICOM/"
    kill_processes "awk" "${PROJECT_SCRIPT%.*}"
    kill_processes "awk" "lz_lshift"
    remove_div_data "ipv4"
    remove_div_data "ipv6"
}

kill_father_processes() {
    kill_others_with_same_name "${ISP_DATA_SCRIPT}"
    kill_processes "wget" "${APNIC_IP_INFO%.*}.dat"
    remove_tmp_data
}

forced_stop_cmd() {
    [ -z "${FORCED_STOP_CMD}" ] && FORCED_STOP_CMD="stop"
    [ "$( awk 'BEGIN {print tolower("'"${1}"'")}' )" != "${FORCED_STOP_CMD}" ] && return "1"
    kill_father_processes
    kill_child_processes
    lz_echo "Forced Stop OK"
    RetVal="0"
    return "0"
}

check_module() {
    [ "${1}" = "wget" ] && uname -a | grep -qi "openwrt" \
        && [ -z "$( opkg list-installed "wget-ssl" 2> /dev/null )" ] && {
            lz_echo "No wget-ssl module. Game Over !!!"
            return "1"
        }
    if [ "${1}" = "whois" ]; then
        case "$( uname -m | awk '{print tolower($1)}' )" in
            aarch64|armv8*)
                if [ -f "${PATH_WHOIS}/whois-aarch64" ]; then
                    WHOIS_MODULE="${PATH_WHOIS}/whois-aarch64"
                    chmod +x "${WHOIS_MODULE}"
                    return "0"
                fi
            ;;
            armv7*|armv6*)
                if [ -f "${PATH_WHOIS}/whois-armv7" ]; then
                    WHOIS_MODULE="${PATH_WHOIS}/whois-armv7"
                    chmod +x "${WHOIS_MODULE}"
                    return "0"
                fi
            ;;
            x86_64|amd64)
                if [ -f "${PATH_WHOIS}/whois-x86_64" ]; then
                    WHOIS_MODULE="${PATH_WHOIS}/whois-x86_64"
                    chmod +x "${WHOIS_MODULE}"
                    return "0"
                fi
            ;;
            x86|i386|i486|i586|i686)
                if [ -f "${PATH_WHOIS}/whois-x86" ]; then
                    WHOIS_MODULE="${PATH_WHOIS}/whois-x86"
                    chmod +x "${WHOIS_MODULE}"
                    return "0"
                fi
            ;;
            mips)   # 32-bit MIPS Big Endian (No support required)
                if [ -f "${PATH_WHOIS}/whois-mips" ]; then
                    WHOIS_MODULE="${PATH_WHOIS}/whois-mips"
                    chmod +x "${WHOIS_MODULE}"
                    return "0"
                fi
            ;;
            mipsel) # 32-bit MIPS Little Endian (Mainstream support)
                if [ -f "${PATH_WHOIS}/whois-mipsel" ]; then
                    WHOIS_MODULE="${PATH_WHOIS}/whois-mipsel"
                    chmod +x "${WHOIS_MODULE}"
                    return "0"
                fi
            ;;
            mips64) # 64-bit MIPS Big Endian (No support required)
                if [ -f "${PATH_WHOIS}/whois-mips64" ]; then
                    WHOIS_MODULE="${PATH_WHOIS}/whois-mips64"
                    chmod +x "${WHOIS_MODULE}"
                    return "0"
                fi
            ;;
            mips64el) # 64-bit MIPS Little Endian (Mainstream support)
                if [ -f "${PATH_WHOIS}/whois-mips64el" ]; then
                    WHOIS_MODULE="${PATH_WHOIS}/whois-mips64el"
                    chmod +x "${WHOIS_MODULE}"
                    return "0"
                fi
            ;;
            loongarch64) # 64-bit LoongArch (Mainstream support)
                if [ -f "${PATH_WHOIS}/whois-loongarch64" ]; then
                    WHOIS_MODULE="${PATH_WHOIS}/whois-loongarch64"
                    chmod +x "${WHOIS_MODULE}"
                    return "0"
                fi
            ;;
            *)
                WHOIS_MODULE="whois"
            ;;
        esac
    fi
    which "${1}" > /dev/null 2>&1 && return "0"
    lz_echo "No ${1} module. Game Over !!!"
    return "1"
}

detect_str_space() {
    eval echo "\${${1}}" | grep -q ' ' && {
        lz_echo "${1} string cann't have any spaces."
        lz_echo "Game Over !!!"
        return "1"
    }
    return "0"
}

compare_dir_name() {
    eval [ "\${${1}}" = "\${${2}}" ] && {
        lz_echo "The ${1} directory cann't have the same name"
        lz_echo "as ${2} directory. Game Over !!!"
        return "1"
    }
    return "0"
}

create_directory() {
    eval [ ! -d "\${${1}}" ] && {
        eval mkdir -p "\${${1}}"
        eval [ ! -d "\${${1}}" ] && {
            lz_echo "${1} directory creation failed."
            lz_echo "Game Over !!!"
            return "1"
        }
    }
    return "0"
}

detect_empty_filename() {
    eval [ -z "\${${1}}" ] && {
        lz_echo "The {${1}} file name is null."
        lz_echo "Game Over !!!"
        return "1"
    }
    return "0"
}

compare_filename() {
    eval [ "\${${1}}" = "\${${2}}" ] && {
        lz_echo "${1} files and ${2} files"
        lz_echo "cann't have the same name. Game Over !!!"
        return "1"
    }
    return "0"
}

check_filename() {
    detect_empty_filename "APNIC_IP_INFO" || return "1"
    detect_str_space "APNIC_IP_INFO" || return "1"
    local index="0"
    until [ "${index}" -gt "10" ]
    do
        detect_empty_filename "ISP_DATA_${index}" || return "1"
        detect_str_space "ISP_DATA_${index}" || return "1"
        detect_empty_filename "ISP_CIDR_DATA_${index}" || return "1"
        detect_str_space "ISP_CIDR_DATA_${index}" || return "1"
        detect_empty_filename "ISP_IPV6_DATA_${index}" || return "1"
        detect_str_space "ISP_IPV6_DATA_${index}" || return "1"
        detect_empty_filename "ISP_IPV6_CIDR_DATA_${index}" || return "1"
        detect_str_space "ISP_IPV6_CIDR_DATA_${index}" || return "1"
        compare_filename "APNIC_IP_INFO" "ISP_DATA_${index}" || return "1"
        compare_filename "APNIC_IP_INFO" "ISP_CIDR_DATA_${index}" || return "1"
        compare_filename "APNIC_IP_INFO" "ISP_IPV6_DATA_${index}" || return "1"
        compare_filename "APNIC_IP_INFO" "ISP_IPV6_CIDR_DATA_${index}" || return "1"
        compare_filename "ISP_DATA_${index}" "ISP_CIDR_DATA_${index}" || return "1"
        compare_filename "ISP_DATA_${index}" "ISP_IPV6_DATA_${index}" || return "1"
        compare_filename "ISP_DATA_${index}" "ISP_IPV6_CIDR_DATA_${index}" || return "1"
        compare_filename "ISP_CIDR_DATA_${index}" "ISP_IPV6_DATA_${index}" || return "1"
        compare_filename "ISP_CIDR_DATA_${index}" "ISP_IPV6_CIDR_DATA_${index}" || return "1"
        compare_filename "ISP_IPV6_DATA_${index}" "ISP_IPV6_CIDR_DATA_${index}" || return "1"
        index="$(( index + 1 ))"
    done
    return "0"
}

init_param() {
    while true
    do
        chmod -R 775 "${PATH_CURRENT}"/*
        detect_str_space "PATH_FUNC" || break
        [ ! -d "${PATH_FUNC}" ] && {
            lz_echo "PATH_FUNC directory does not exist."
            lz_echo "Game Over !!!"
            break
        }
        detect_str_space "PATH_WHOIS" || break
        [ ! -d "${PATH_WHOIS}" ] && {
            lz_echo "PATH_WHOIS directory does not exist."
            lz_echo "Game Over !!!"
            break
        }
        compare_dir_name "PATH_FUNC" "PATH_WHOIS" || break
        detect_str_space "ISP_DATA_SCRIPT" || break
        [ ! -f "${PATH_FUNC}/${ISP_DATA_SCRIPT}" ] && {
            lz_echo "${PATH_FUNC}/${ISP_DATA_SCRIPT} does not exist."
            lz_echo "Game Over !!!"
            break
        }
        detect_str_space "PATH_APNIC" || break
        compare_dir_name "PATH_APNIC" "PATH_FUNC" || break
        compare_dir_name "PATH_APNIC" "PATH_WHOIS" || break
        detect_str_space "PATH_ISP" || break
        compare_dir_name "PATH_ISP" "PATH_FUNC" || break
        compare_dir_name "PATH_ISP" "PATH_WHOIS" || break
        detect_str_space "PATH_CIDR" || break
        compare_dir_name "PATH_CIDR" "PATH_FUNC" || break
        compare_dir_name "PATH_CIDR" "PATH_WHOIS" || break
        detect_str_space "PATH_IPV6" || break
        compare_dir_name "PATH_IPV6" "PATH_FUNC" || break
        compare_dir_name "PATH_IPV6" "PATH_WHOIS" || break
        detect_str_space "PATH_IPV6_CIDR" || break
        compare_dir_name "PATH_IPV6_CIDR" "PATH_FUNC" || break
        compare_dir_name "PATH_IPV6_CIDR" "PATH_WHOIS" || break
        detect_str_space "PATH_TMP" || break
        compare_dir_name "PATH_TMP" "PATH_FUNC" || break
        compare_dir_name "PATH_TMP" "PATH_WHOIS" || break
        compare_dir_name "PATH_TMP" "PATH_APNIC" || break
        compare_dir_name "PATH_TMP" "PATH_ISP" || break
        compare_dir_name "PATH_TMP" "PATH_CIDR" || break
        compare_dir_name "PATH_TMP" "PATH_IPV6" || break
        compare_dir_name "PATH_TMP" "PATH_IPV6_CIDR" || break
        create_directory "PATH_APNIC" || break
        if [ "${IPV4_DATA:="0"}" = "0" ] || [ "${IPV4_DATA}" = "1" ]; then
            create_directory "PATH_ISP" || break
        fi
        if [ "${IPV4_DATA}" = "0" ]; then
            create_directory "PATH_CIDR" || break
        fi
        if [ "${IPV6_DATA="0"}" = "0" ] || [ "${IPV6_DATA}" = "1" ]; then
            create_directory "PATH_IPV6" || break
        fi
        if [ "${IPV6_DATA}" = "0" ]; then
            create_directory "PATH_IPV6_CIDR" || break
        fi
        create_directory "PATH_TMP" || break
        chmod -R 775 "${PATH_CURRENT}"/*
        check_filename || break
        [ -z "${DOWNLOAD_URL}" ] && DOWNLOAD_URL="http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest"
        detect_str_space "DOWNLOAD_URL" || break
        [ -z "${WHOIS_HOST}" ] && WHOIS_HOST="whois.apnic.net"
        detect_str_space "WHOIS_HOST" || break
        ! echo "${PARA_QUERY_PROC_NUM}" | grep -qE '^[0-9]+$' && {
            lz_echo "PARA_QUERY_PROC_NUM isn't an decimal unsigned integer."
            lz_echo "Game Over !!!"
            break
        }
        PARA_QUERY_PROC_NUM="$( printf "%u\n" "${PARA_QUERY_PROC_NUM:-16}" )"
        [ "${PARA_QUERY_PROC_NUM}" = "0" ] && {
            lz_echo "PARA_QUERY_PROC_NUM cann't be less than 1."
            lz_echo "Game Over !!!"
        }
        ! echo "${WHOIS_CLIENT_THREAD_NUM}" | grep -qE '^([0-9]+)$' && {
            lz_echo "WHOIS_CLIENT_THREAD_NUM isn't an decimal unsigned integer."
            lz_echo "Game Over !!!"
            break
        }
        WHOIS_CLIENT_THREAD_NUM="$( printf "%u\n" "${WHOIS_CLIENT_THREAD_NUM:-1}" )"
        { [ "${WHOIS_CLIENT_THREAD_NUM}" -le "0" ] || [ "${WHOIS_CLIENT_THREAD_NUM}" -gt "64" ]; } && {
            lz_echo "WHOIS_CLIENT_THREAD_NUM cann't be less than 1 & great 64."
            lz_echo "Game Over !!!"
        }
        ! echo "${RETRY_NUM}" | grep -qE '^[0-9]+$' && {
            lz_echo "RETRY_NUM isn't an decimal unsigned integer."
            lz_echo "Game Over !!!"
            break
        }
        RETRY_NUM="$( printf "%u\n" "${RETRY_NUM}" )"
        [ ! "${PROGRESS_BAR}" ] && PROGRESS_BAR="0"
        kill_father_processes
        kill_child_processes
        return "0"
    done
    return "1"
}

export_env_var() {
    local index="0"
    until [ "${index}" -gt "10" ]
    do
        export ISP_DATA_"${index}"
        export ISP_IPV6_DATA_"${index}"
        index="$(( index + 1 ))"
    done
    export PATH_FUNC
    export PATH_TMP
    export ISP_DATA_SCRIPT
    export WHOIS_HOST
    export WHOIS_MODULE
    export WHOIS_CLIENT_THREAD_NUM
    export RETRY_NUM
    export REGEX_IPV4_NET
    export REGEX_IPV6_NET
}

init_isp_data_script() {
    if ! grep -qEm 1 '^[[:space:]]*#![/]bin[/]sh[[:space:]]|^[[:space:]]*#![/]bin[/]sh$' "${PATH_FUNC}/${ISP_DATA_SCRIPT}"; then
        lz_echo "${PATH_FUNC}/${ISP_DATA_SCRIPT} file is damaged."
        lz_echo "Game Over !!!"
        return "1"
    fi
    chmod +x "${PATH_FUNC}/${ISP_DATA_SCRIPT}"
    export_env_var
    return "0"
}

get_apnic_info() {
    local progress="--progress=bar:force"
    [ "${PROGRESS_BAR}" != "0" ] && progress="-q"
    lz_echo "Exciting fetch......"
    eval wget -c "${progress}" --prefer-family=IPv4 --no-check-certificate "${DOWNLOAD_URL}" -O "${PATH_TMP}/${APNIC_IP_INFO%.*}.dat"
    if [ ! -f "${PATH_TMP}/${APNIC_IP_INFO%.*}.dat" ]; then
        lz_echo "${APNIC_IP_INFO} Failed. Game Over !!!"
        return "1"
    elif ! grep -qE "[\|]${REGEX_IPV4_NET}[\|]" "${PATH_TMP}/${APNIC_IP_INFO%.*}.dat"; then
        lz_echo "${APNIC_IP_INFO} Failed. Game Over !!!"
        rm -f "${PATH_TMP}/${APNIC_IP_INFO%.*}.dat"
        return "1"
    fi
    lz_echo "${APNIC_IP_INFO} OK"
    return "0"
}

get_area_data() {
    if [ "${2}" = "ipv4" ]; then
        [ "${IPV4_DATA}" != "0" ] && [ "${IPV4_DATA}" != "1" ] && return "0"
        awk -F '|' '$1 == "apnic" \
            && $2 == "'"${1}"'" \
            && $3 == "ipv4" \
            {print $4" "32-log($5)/log(2)}' "${PATH_TMP}/${APNIC_IP_INFO%.*}.dat" \
            | sed 's/[.]/ /g' \
            | awk '{printf "%03u %03u %03u %03u %02u\n",$1,$2,$3,$4,$5}' \
            | sort -t ' ' -k1,1n -k2,2n -k3,3n -k4,4n -k5,5n -u \
            | awk '{printf "%u.%u.%u.%u/%u\n",$1,$2,$3,$4,$5}' > "${PATH_TMP}/${3%.*}.dat"
        sed -i "/^${REGEX_SED_IPV4_NET}$/!d" "${PATH_TMP}/${3%.*}.dat"
    elif [ "${2}" = "ipv6" ]; then
        [ "${IPV6_DATA}" != "0" ] && [ "${IPV6_DATA}" != "1" ] && return "0"
        awk -F '|' '$1 == "apnic" \
            && $2 == "'"${1}"'" \
            && $3 == "ipv6" \
            {print $4"/"$5}' "${PATH_TMP}/${APNIC_IP_INFO%.*}.dat" \
            | awk '!i[$0]++' > "${PATH_TMP}/${3%.*}.dat"
        sed -i -e "/^${REGEX_SED_IPV6_NET}$/!d" "${PATH_TMP}/${3%.*}.dat"
    fi
    [ -f "${PATH_TMP}/${3%.*}.dat" ] && {
        local total="$( grep -Eic "^(${REGEX_IPV4_NET}|${REGEX_IPV6_NET})$" "${PATH_TMP}/${3%.*}.dat" )"
        if [ "${total}" = "0" ]; then
            rm -f "${PATH_TMP}/${3%.*}.dat"
            lz_echo "${3} Failed. Game Over !!!"
            return "1"
        fi
        lz_echo "${3} ${total} OK"
        return "0"
    }
    lz_echo "${3} Failed. Game Over !!!"
    return "1"
}

split_data_file() {
    [ ! -f "${1}" ] && return "1"
    local findex="0"
    until [ "${findex}" -ge "${PARA_QUERY_PROC_NUM}" ]
    do
        eval [ -f "\${1}_${findex}" ] && eval rm -f "\${1}_${findex}"
        findex="$(( findex + 1 ))"
    done
    local total="$( grep -Eic "^(${REGEX_IPV4_NET}|${REGEX_IPV6_NET})$" "${1}" )"
    [ "${total}" = "0" ] && return "1"
    if [ "${PARA_QUERY_PROC_NUM}" = "1" ]; then
        cp -p "${1}" "${1}_0"
        return "0"
    fi
    local max_line_num="$(( total / PARA_QUERY_PROC_NUM ))"
    local remainder="$(( total % PARA_QUERY_PROC_NUM ))"
    [ "${max_line_num}" = "0" ] && PARA_QUERY_PROC_NUM="${remainder}"
    local bp="0" sp="0" count="0"
    findex="0"
    until [ "${findex}" -ge "${PARA_QUERY_PROC_NUM}" ]
    do
        if [ "${remainder}" = "${PARA_QUERY_PROC_NUM}" ]; then
            bp="$(( findex + 1 ))"
            sp="${bp}"
        elif [ "${remainder}" = "0" ]; then
            bp="$(( findex * max_line_num + 1 ))"
            sp="$(( bp + max_line_num - 1 ))"
        elif [ "${findex}" -lt "${remainder}" ]; then
            bp="$(( findex * ( max_line_num + 1 ) + 1 ))"
            sp="$(( bp + max_line_num ))"
        else
            bp="$(( remainder * ( max_line_num + 1 ) + count * max_line_num + 1 ))"
            sp="$(( bp + max_line_num - 1 ))"
            count="$(( count + 1 ))"
        fi
        sed -n "${bp},${sp}p" "${1}" > "${1}_${findex}"
        ! grep -qEi "^(${REGEX_IPV4_NET}|${REGEX_IPV6_NET})$" "${1}_${findex}" \
            && rm -f "${1}_${findex}"
        findex="$(( findex + 1 ))"
    done
    return "0"
}

merge_isp_data() {
    local prefix="ISP_DATA_" findex="0" index="0" fname=""
    [ "${1}" != "ipv4" ] && prefix="ISP_IPV6_DATA_"
    until [ "${findex}" -ge "${PARA_QUERY_PROC_NUM}" ]
    do
        eval fname="${PATH_TMP}/\${${prefix}1}"
        if grep -q 'failure' "${fname%.*}.dat_${findex}" 2> /dev/null; then
            remove_div_data "${1}"
            lz_echo "Transmission failure."
            lz_echo "Unable to receive ISP affiliation information."
            lz_echo "Game Over !!!"
            return "1"
        fi
        findex="$(( findex + 1 ))"
    done
    findex="0"
    until [ "${findex}" -ge "${PARA_QUERY_PROC_NUM}" ]
    do
        index="1"
        until [ "${index}" -gt "7" ]
        do
            eval fname="${PATH_TMP}/\${${prefix}${index}}"
            if [ -f "${fname%.*}.dat_${findex}" ]; then
                sed '/^[[:space:]]*$/d' "${fname%.*}.dat_${findex}" >> "${fname%.*}.dat"
            fi
            index="$(( index + 1 ))"
        done
        findex="$(( findex + 1 ))"
    done
    remove_div_data "${1}"
    return "0"
}

check_isp_data() {
    local prefix="ISP_DATA_" index="1" fname="" total="0"
    [ "${1}" != "ipv4" ] && prefix="ISP_IPV6_DATA_"
    until [ "${index}" -gt "7" ]
    do
        eval fname="\${${prefix}${index}}"
        if [ -f "${PATH_TMP}/${fname%.*}.dat" ]; then
            total="$( grep -Eic "^(${REGEX_IPV4_NET}|${REGEX_IPV6_NET})$" "${PATH_TMP}/${fname%.*}.dat" )"
            if [ "${total}" = "0" ]; then
                rm -f "${PATH_TMP}/${fname%.*}.dat"
                lz_echo "${fname} Failed. Game Over !!!"
                return "1"
            fi
            lz_echo "${fname} ${total} OK"
        else
            lz_echo "${fname} Failed. Game Over !!!"
            return "1"
        fi
        index="$(( index + 1 ))"
    done
    return "0"
}

get_shell_cmd() {
    local sh_str="$( ps a 2> /dev/null | awk '$1 == "'"$$"'" && !/awk/ {print $5; exit}' )"
    [ -z "${sh_str}" ] && sh_str="$( ps | awk '$1 == "'"$$"'" && !/awk/ {print $5; exit}' )"
    ! echo "${sh_str##*/}" | grep -qEi 'sh$' && sh_str=""
    echo "${sh_str}"
}

isp_data_multi_proc() {
    local fname="${ISP_DATA_0}" prefix_str="$( get_shell_cmd )" findex="0"
    [ "${1}" != "ipv4" ] && fname="${ISP_IPV6_DATA_0}"
    until [ "${findex}" -ge "${PARA_QUERY_PROC_NUM}" ]
    do
        [ -f "${PATH_TMP}/${fname%.*}.dat_${findex}" ] && \
            eval "${prefix_str}" "${PATH_FUNC}/${ISP_DATA_SCRIPT}" "${1}" "${findex}" > /dev/null 2>&1 &
        findex="$(( findex + 1 ))"
    done
    sleep 5s
    prefix_str=""
    ps a 2> /dev/null | awk -v count="0" '$1 == "'"$$"'" && !/awk/ {count++} END {if (count == "0") exit(1)}' && prefix_str="a"
    while true
    do
        [ "${PROGRESS_BAR}" = "0" ] && echo -n "..."
        ! ps "${prefix_str}" | awk -v count="0" '$0 ~ "'"${ISP_DATA_SCRIPT}"'" && !/awk/ {count++} END {if (count == "0") exit(1)}' && break
        sleep 3s
    done
    [ "${PROGRESS_BAR}" = "0" ] && echo ""
    merge_isp_data "${1}" || return "1"
    return "0"
}

get_isp_data() {
    [ "${1}" = "ipv4" ] && [ "${IPV4_DATA}" != "0" ] && [ "${IPV4_DATA}" != "1" ] && return "0"
    [ "${1}" = "ipv6" ] && [ "${IPV6_DATA}" != "0" ] && [ "${IPV6_DATA}" != "1" ] && return "0"
    if [ "${1}" = "ipv4" ]; then
        lz_echo "Generating IPv4 ISP item data takes a long time."
        split_data_file "${PATH_TMP}/${ISP_DATA_0%.*}.dat" || return "1"
    else
        lz_echo "Generating IPv6 ISP item data takes a long time."
        split_data_file "${PATH_TMP}/${ISP_IPV6_DATA_0%.*}.dat" || return "1"
    fi
    if [ "${PARA_QUERY_PROC_NUM}" -gt "1" ]; then
        lz_echo "Use ${PARA_QUERY_PROC_NUM} processes for parallel query processing."
        [ "${WHOIS_MODULE}" != "whois" ] \
            && lz_echo "Whois client (${WHOIS_MODULE##*/}) threads: ${WHOIS_CLIENT_THREAD_NUM}"
    else
        lz_echo "Use ${PARA_QUERY_PROC_NUM} query processing process."
        [ "${WHOIS_MODULE}" != "whois" ] \
            && lz_echo "Whois client (${WHOIS_MODULE##*/}) threads: ${WHOIS_CLIENT_THREAD_NUM}"
    fi
    lz_echo "Don't interrupt & Please wait......"
    [ "${PROGRESS_BAR}" = "0" ] && echo -n ".."
    isp_data_multi_proc "${1}" || return "1"
    check_isp_data "${1}" || return "1"
    return "0"
}

get_ipv4_extend() {
    awk -F '[./]' 'function lz_lshift(value, count) {
            return (value + 0) * (2 ^ (count + 0));
        } function lz_rshift(value, count) {
            return int((value + 0) / (2 ^ (count + 0)));
        } function fix_data(data, current_pos) {
            return (cidr + 0 < 32 && current_pos + 0 < 5) ? ((current_pos + 0 == pos) \
                ? (int((data + 0) / step) * step) : ((current_pos + 0 < pos) ? data : 0)) : data;
        } $0 ~ "'"^${REGEX_IPV4_NET}$"'" && $5 != "0" {
            cidr = ($5 ~ /^([1-9]|[1-2][0-9]|3[0-2])$/) ? $5 : 32;
            pos = int((cidr + 0) / 8) + 1;
            # step = lz_lshift(1, (32 - cidr) % 8);
            step = 2 ^ ((32 - cidr) % 8);
            printf "%03u %03u %03u %03u %02u\n", fix_data($1, 1), fix_data($2, 2), fix_data($3, 3), fix_data($4, 4), cidr;
        }' "${1}" | sort -t ' ' -k1,1n -k2,2n -k3,3n -k4,4n -k5,5n
}

get_ipv6_extend() {
    awk -F '[/]' 'function lz_lshift(value, count) {
            return (value + 0) * (2 ^ (count + 0));
        } function lz_rshift(value, count) {
            return int((value + 0) / (2 ^ (count + 0)));
        } function hex2dec(hex,    i, char, len, pos, digit, dec) {
            dec = 0;
            len = length(hex);
            for (i = 1; i <= len; ++i) {
                char = substr(hex, i, 1);
                pos = index(HEX_CHARS, char);
                digit = (pos > 0) ? (pos - 1) : 0;
                dec = dec * 16 + digit;
            }
            return dec
        } function print_fix_cidr(ipa,    i, pos, step) {
            split(ipa, arr, /[[:space:]]+/);
            for (i = 1; i < 9; ++i)
                arr[i] = (AUTO_HEX_TO_DEC) ? sprintf("%u\n", "0x"arr[i]) : hex2dec(arr[i]);
            if (arr[9] + 0 < 128) {
                pos = int((arr[9] + 0) / 16) + 1;
                # step = lz_lshift(1, (128 - arr[9]) % 16);
                step = 2 ^ ((128 - arr[9]) % 16);
                for (i = pos; i < 9; ++i)
                    arr[i] = (i == pos) ? int((arr[i] + 0) / step) * step : 0
            }
            printf "%05u %05u %05u %05u %05u %05u %05u %05u %03u\n", arr[1], arr[2], arr[3], arr[4], arr[5], arr[6], arr[7], arr[8], arr[9];
        } BEGIN {
            HEX_CHARS = "";
            AUTO_HEX_TO_DEC = 1;
            if (sprintf("%u_%u_%u_%u_%u_%u\n","0xa","0xb","0xc","0xd","0xe","0xf") != "10_11_12_13_14_15") {
                AUTO_HEX_TO_DEC = 0;
                HEX_CHARS = "0123456789abcdef";
            }
            delete arr;
        } $0 ~ "'"^${REGEX_IPV6_NET}$"'" && $2 != "0" {
            val = $1;
            str = "";
            for (i = gsub(":", ":", val); i < 8; ++i) {str = str ":0";}
            str = str ":";
            sub("::", str, val);
            val = (val ~ /:$/) ? val "0" : val;
            val = (val ~ /^:/) ? "0" val : val;
            gsub(/:/, " ", val);
            val = ($2 ~ /^([1-9]|([1-9]|1[0-1])[0-9]|12[0-8])$/) ? val " " $2 : val " 128";
            print_fix_cidr(tolower(val));
        }' "${1}" | sort -t ' ' -k1,1n -k2,2n -k3,3n -k4,4n -k5,5n -k6,6n -k7,7n -k8,8n -k9,9n
}

get_ip_extend() {
    if [ "${1}" = "4" ]; then
        get_ipv4_extend "${2}"
    elif [ "${1}" = "6" ]; then
        get_ipv6_extend "${2}"
    fi
}

# PRAMETERS:
# $1 : 4 -- ipv4 | 6 -- ipv6
# $2 : full path filename of the input file
# $3 : Full path filename of the output file
# RETVAL:
#  0 -- OK
#  1 -- Failed
cidr_hash_merge() {
    get_ip_extend "${1}" "${2}" | awk -v ip_proto="${1}" '
        function lz_lshift(value, count) { return (value + 0) * (2 ^ (count + 0)); }
        function lz_rshift(value, count) { return int((value + 0) / (2 ^ (count + 0))); }
        function to_int(str) { return str + 0; }
        BEGIN {
            OFS = " ";
            MAX_MASK = 32;
            MASK_POS = 5;
            PIPE_CMD = "sort -t '\'' '\'' -k1,1n -k2,2n -k3,3n -k4,4n -k5,5n";
            PIPE_CMD = PIPE_CMD " | awk '\''{printf \"%u.%u.%u.%u/%u\\n\",$1,$2,$3,$4,$5;}'\''";
            if (ip_proto == "6") {
                MAX_MASK = 128;
                MASK_POS = 9;
                PIPE_CMD = "sort -t '\'' '\'' -k1,1n -k2,2n -k3,3n -k4,4n -k5,5n -k6,6n -k7,7n -k8,8n -k9,9n";
                PIPE_CMD = PIPE_CMD " | awk '\''{printf \"%x:%x:%x:%x:%x:%x:%x:%x/%u\\n\",$1,$2,$3,$4,$5,$6,$7,$8,$9;}'\''";
                PIPE_CMD = PIPE_CMD " | sed -e '\''s/\\([:][0]\\)\\{2,\\}/::/'\'' -e '\''s/:::/::/'\'' -e '\''s/^0::/::/'\''"
            }
            BIT_WIDTH = int(MAX_MASK / (MASK_POS - 1));
            delete addr_arr;
            last_addr_header = "";
            last_key_pos = 0;
            last_step = 0;
            last_key_val = 0;
            last_mask = 0;
            current_mask = 0;
            min_mask = MAX_MASK + 1;
            regexp_str = "^([0-9]+[[:space:]]+){" (MASK_POS - 1) "}[0-9]+$";
        } $0 ~ regexp_str {
            for (i = 1; i <= MASK_POS; ++i)
                $(i) = $(i) + 0;
            if ($0 in addr_arr) next;
            if (last_key_pos == 0) {
                last_mask = $(MASK_POS) + 0;
                last_key_pos = int(last_mask / BIT_WIDTH) + 1;
                # last_step = lz_lshift(1, (MAX_MASK - last_mask) % BIT_WIDTH);
                last_step = 2 ^ ((MAX_MASK - last_mask) % BIT_WIDTH);
                last_key_val = int(($(last_key_pos) + 0) / last_step) * last_step;
                last_addr_header = "";
                for (i = 1; i < last_key_pos; ++i)
                    last_addr_header = (i == 1 ? "" : last_addr_header " ") $(i);
                addr_arr[$0] = $0;
            } else {
                regexp_addr_header = (last_addr_header != "") ? "^" last_addr_header "[[:space:]]" : "^[0-9]+[[:space:]]";
                if ($0 ~ regexp_addr_header \
                    && $(last_key_pos) + 0 >= last_key_val \
                    && $(last_key_pos) + 0 < last_key_val + last_step \
                    && last_mask <= $(MASK_POS) + 0)
                    next;
                last_mask = $(MASK_POS) + 0;
                last_key_pos = int(last_mask / BIT_WIDTH) + 1;
                # last_step = lz_lshift(1, (MAX_MASK - last_mask) % BIT_WIDTH);
                last_step = 2 ^ ((MAX_MASK - last_mask) % BIT_WIDTH);
                last_key_val = int(($(last_key_pos) + 0) / last_step) * last_step;
                last_addr_header = "";
                for (i = 1; i < last_key_pos; ++i)
                    last_addr_header = (i == 1 ? "" : last_addr_header " ") $(i);
                addr_arr[$0] = $0;
            }
            if (current_mask < $(MASK_POS) + 0)
                current_mask = $(MASK_POS) + 0;
            if (min_mask > $(MASK_POS) + 0)
                min_mask = $(MASK_POS) + 0;
        } END {
            if (length(addr_arr) == 0) exit;
            delete del_addr_arr;
            delete add_addr_arr;
            delete arr;
            bit_index = MAX_MASK - current_mask;
            while (bit_index < MAX_MASK ) {
                mask = MAX_MASK - bit_index;
                mask_len = length(mask);
                # step = lz_lshift(1, bit_index % BIT_WIDTH);
                step = 2 ^ (bit_index % BIT_WIDTH);
                key_pos = MASK_POS - int(bit_index / BIT_WIDTH) - 1;
                modified = 0;
                for (ip_item in addr_arr) {
                    if (substr(addr_arr[ip_item], length(addr_arr[ip_item]) - mask_len) == " " mask) {
                        split(ip_item, arr, /[[:space:]]+/);
                        if (int((arr[key_pos] + 0) / step) % 2 == 0) {
                            addr_header = "";
                            for (i = 1; i < key_pos; ++i)
                                addr_header = (i == 1 ? "" : addr_header " ") arr[i];
                            next_item = "";
                            for (i = key_pos + 1; i <= MASK_POS; ++i)
                                next_item = next_item " " arr[i];
                            next_item = (key_pos == 1 ? "" : addr_header " ") (arr[key_pos] + step) next_item;
                            if (next_item in addr_arr \
                                && addr_arr[next_item]) {
                                addr_arr[ip_item] = "";
                                del_addr_arr[ip_item];
                                sub(/[[:space:]]+[0-9]+$/, " " (arr[MASK_POS] - 1), ip_item);
                                add_addr_arr[ip_item];
                                addr_arr[next_item] = "";
                                del_addr_arr[next_item];
                                if (!modified) modified = 1;
                            }
                        } else {
                            addr_header = "";
                            for (i = 1; i < key_pos; ++i)
                                addr_header = (i == 1 ? "" : addr_header " ") arr[i];
                            prev_item = "";
                            for (i = key_pos + 1; i <= MASK_POS; ++i)
                                prev_item = prev_item " " arr[i];
                            prev_item = (key_pos == 1 ? "" : addr_header " ") (arr[key_pos] - step) prev_item;
                            if (prev_item in addr_arr \
                                && addr_arr[prev_item]) {
                                addr_arr[prev_item] = "";
                                del_addr_arr[prev_item];
                                sub(/[[:space:]]+[0-9]+$/, " " (arr[MASK_POS] - 1), prev_item);
                                add_addr_arr[prev_item];
                                addr_arr[ip_item] = "";
                                del_addr_arr[ip_item];
                                if (!modified) modified = 1;
                            }
                        }
                    }
                }
                if (modified) {
                    for (del_ip_item in del_addr_arr)
                        delete addr_arr[del_ip_item];
                    delete del_addr_arr;
                    for (add_ip_item in add_addr_arr)
                        addr_arr[add_ip_item] = add_ip_item;
                    delete add_addr_arr;
                } else if (mask <= min_mask)
                    break;
                bit_index++;
            }
            if (length(addr_arr) <= 0) exit;
            if (ip_proto == "4") {
                for (ip_item in addr_arr) {
                    split(ip_item, arr, /[[:space:]]+/);
                    printf "%03u %03u %03u %03u %02u\n", arr[1], arr[2], arr[3], arr[4], arr[5] | PIPE_CMD;
                }
            } else if (ip_proto == "6") {
                for (ip_item in addr_arr) {
                    split(ip_item, arr, /[[:space:]]+/);
                    printf "%05u %05u %05u %05u %05u %05u %05u %05u %03u\n", 
                        arr[1], arr[2], arr[3], arr[4], arr[5], arr[6], arr[7], arr[8], arr[9] | PIPE_CMD;
                }
            }
            close(PIPE_CMD);
        }' > "${3}"
    return "0"
}

# PRAMETERS:
# $1 : 4 -- ipv4 | 6 -- ipv6
# $2 : full path filename of the input file
# $3 : Full path filename of the output file
# RETVAL:
#  0 -- OK
#  1 -- Failed
cidr_seq_merge() {
    get_ip_extend "${1}" "${2}" | awk -v ip_proto="${1}" '
        function lz_lshift(value, count) { return (value + 0) * (2 ^ (count + 0)); }
        function lz_rshift(value, count) { return int((value + 0) / (2 ^ (count + 0))); }
        function to_int(str) { return str + 0; }
        BEGIN {
            OFS = " ";
            MAX_MASK = (ip_proto == "6") ? 128 : 32;
            MASK_POS = (ip_proto == "6") ? 9 : 5;
            BIT_WIDTH = int(MAX_MASK / (MASK_POS - 1));
            delete addr_arr;
            delete keys_arr;
            delete next_arr;
            item_count = 0;
            last_addr_header = "";
            last_key_pos = 0;
            last_step = 0;
            last_key_val = 0;
            last_mask = 0;
            current_mask = 0;
            min_mask = MAX_MASK + 1;
            regexp_str = "^([0-9]+[[:space:]]+){" (MASK_POS - 1) "}[0-9]+$";
        } $0 ~ regexp_str {
            # for (i = 1; i <= MASK_POS; ++i) $(i) = to_int($(i));
            for (i = 1; i <= MASK_POS; ++i) $(i) = $(i) + 0;
            if ($0 in keys_arr) next;
            if (last_key_pos == 0) {
                last_mask = $(MASK_POS) + 0;
                last_key_pos = int(last_mask / BIT_WIDTH) + 1;
                # last_step = lz_lshift(1, (MAX_MASK - last_mask) % BIT_WIDTH);
                last_step = 2 ^ ((MAX_MASK - last_mask) % BIT_WIDTH);
                last_key_val = int(($(last_key_pos) + 0) / last_step) * last_step;
                last_addr_header = "";
                for (i = 1; i < last_key_pos; ++i)
                    last_addr_header = (i == 1 ? "" : last_addr_header " ") $(i);
                addr_arr[++item_count] = $0;
                keys_arr[$0] = item_count;
                next_arr[item_count] = item_count + 1;
            } else {
                regexp_addr_header = (last_addr_header != "") ? "^" last_addr_header "[[:space:]]" : "^[0-9]+[[:space:]]";
                if ($0 ~ regexp_addr_header \
                    && $(last_key_pos) + 0 >= last_key_val \
                    && $(last_key_pos) + 0 < last_key_val + last_step \
                    && last_mask <= $(MASK_POS) + 0)
                    next;
                last_mask = $(MASK_POS) + 0;
                last_key_pos = int(last_mask / BIT_WIDTH) + 1;
                # last_step = lz_lshift(1, (MAX_MASK - last_mask) % BIT_WIDTH);
                last_step = 2 ^ ((MAX_MASK - last_mask) % BIT_WIDTH);
                last_key_val = int(($(last_key_pos) + 0) / last_step) * last_step;
                last_addr_header = "";
                for (i = 1; i < last_key_pos; ++i)
                    last_addr_header = (i == 1 ? "" : last_addr_header " ") $(i);
                addr_arr[++item_count] = $0;
                keys_arr[$0] = item_count;
                next_arr[item_count] = item_count + 1;
            }
            if (current_mask < $(MASK_POS) + 0)
                current_mask = $(MASK_POS) + 0;
            if (min_mask > $(MASK_POS) + 0)
                min_mask = $(MASK_POS) + 0;
        } END {
            if (item_count == 0) exit;
            delete arr;
            bit_index = MAX_MASK - current_mask;
            while (bit_index < MAX_MASK ) {
                mask = MAX_MASK - bit_index;
                mask_len = length(mask);
                step = 2 ^ (bit_index % BIT_WIDTH);
                key_pos = MASK_POS - int(bit_index / BIT_WIDTH) - 1;
                modified = 0;
                for (item_no = 1; item_no <= item_count; item_no = next_arr[item_no]) {
                    if (substr(addr_arr[item_no], length(addr_arr[item_no]) - mask_len) == " " mask) {
                        split(addr_arr[item_no], arr, /[[:space:]]+/);
                        if (int((arr[key_pos] + 0) / step) % 2 == 0) {
                            addr_header = "";
                            for (i = 1; i < key_pos; ++i)
                                addr_header = (i == 1 ? "" : addr_header " ") arr[i];
                            next_item = "";
                            for (i = key_pos + 1; i <= MASK_POS; ++i)
                                next_item = next_item " " arr[i];
                            next_item = (key_pos == 1 ? "" : addr_header " ") (arr[key_pos] + step) next_item;
                            if (next_item in keys_arr) {
                                delete keys_arr[addr_arr[item_no]];
                                sub(/[[:space:]]+[0-9]+$/, " " (arr[MASK_POS] - 1), addr_arr[item_no]);
                                keys_arr[addr_arr[item_no]] = item_no;
                                next_arr[item_no] = next_arr[keys_arr[next_item]];
                                delete next_arr[keys_arr[next_item]];
                                delete addr_arr[keys_arr[next_item]];
                                delete keys_arr[next_item];
                                if (!modified) modified = 1;
                            }
                        }
                    }
                }
                if (!modified && mask <= min_mask)
                    break;
                bit_index++;
            }
            if (length(addr_arr) <= 0) exit;
            if (ip_proto == "4") {
                for (i = 1; i <= item_count; i = next_arr[i]) {
                    split(addr_arr[i], arr, /[[:space:]]+/);
                    printf "%u.%u.%u.%u/%u\n", arr[1], arr[2], arr[3], arr[4], arr[5];
                }
            } else if (ip_proto == "6") {
                for (i = 1; i <= item_count; i = next_arr[i]) {
                    split(addr_arr[i], arr, /[[:space:]]+/);
                    ipv6_str = sprintf("%x:%x:%x:%x:%x:%x:%x:%x/%u", 
                                arr[1], arr[2], arr[3], arr[4], 
                                arr[5], arr[6], arr[7], arr[8], arr[9]);
                    sub(/(:0){2,}/, "::", ipv6_str);    # RFC 5952
                    sub(/:::/, "::", ipv6_str);
                    sub(/^0::/, "::", ipv6_str);
                    print ipv6_str;
                }
            }
        }' > "${3}"
    return "0"
}

# PRAMETERS:
# $1 : 4 -- ipv4 | 6 -- ipv6
# $2 : full path filename of the input file
# $3 : Full path filename of the output file
# RETVAL:
#  0 -- OK
#  1 -- Failed
cidr_rev_seq_merge() {
    get_ip_extend "${1}" "${2}" | awk -v ip_proto="${1}" '
        function lz_lshift(value, count) { return (value + 0) * (2 ^ (count + 0)); }
        function lz_rshift(value, count) { return int((value + 0) / (2 ^ (count + 0))); }
        function to_int(str) { return str + 0; }
        BEGIN {
            OFS = " ";
            MAX_MASK = (ip_proto == "6") ? 128 : 32;
            MASK_POS = (ip_proto == "6") ? 9 : 5;
            BIT_WIDTH = int(MAX_MASK / (MASK_POS - 1));
            delete addr_arr;
            delete keys_arr;
            delete next_arr;
            item_count = 0;
            last_addr_header = "";
            last_key_pos = 0;
            last_step = 0;
            last_key_val = 0;
            last_mask = 0;
            current_mask = 0;
            min_mask = MAX_MASK + 1;
            regexp_str = "^([0-9]+[[:space:]]+){" (MASK_POS - 1) "}[0-9]+$";
        } $0 ~ regexp_str {
            # for (i = 1; i <= MASK_POS; ++i) $(i) = to_int($(i));
            for (i = 1; i <= MASK_POS; ++i) $(i) = $(i) + 0;
            if ($0 in keys_arr) next;
            if (last_key_pos == 0) {
                last_mask = $(MASK_POS) + 0;
                last_key_pos = int(last_mask / BIT_WIDTH) + 1;
                # last_step = lz_lshift(1, (MAX_MASK - last_mask) % BIT_WIDTH);
                last_step = 2 ^ ((MAX_MASK - last_mask) % BIT_WIDTH);
                last_key_val = int(($(last_key_pos) + 0) / last_step) * last_step;
                last_addr_header = "";
                for (i = 1; i < last_key_pos; ++i)
                    last_addr_header = (i == 1 ? "" : last_addr_header " ") $(i);
                addr_arr[++item_count] = $0;
                keys_arr[$0] = item_count;
                next_arr[item_count] = item_count - 1;
            } else {
                regexp_addr_header = (last_addr_header != "") ? "^" last_addr_header "[[:space:]]" : "^[0-9]+[[:space:]]";
                if ($0 ~ regexp_addr_header \
                    && $(last_key_pos) + 0 >= last_key_val \
                    && $(last_key_pos) + 0 < last_key_val + last_step \
                    && last_mask <= $(MASK_POS) + 0)
                    next;
                last_mask = $(MASK_POS) + 0;
                last_key_pos = int(last_mask / BIT_WIDTH) + 1;
                # last_step = lz_lshift(1, (MAX_MASK - last_mask) % BIT_WIDTH);
                last_step = 2 ^ ((MAX_MASK - last_mask) % BIT_WIDTH);
                last_key_val = int(($(last_key_pos) + 0) / last_step) * last_step;
                last_addr_header = "";
                for (i = 1; i < last_key_pos; ++i)
                    last_addr_header = (i == 1 ? "" : last_addr_header " ") $(i);
                addr_arr[++item_count] = $0;
                keys_arr[$0] = item_count;
                next_arr[item_count] = item_count - 1;
            }
            if (current_mask < $(MASK_POS) + 0)
                current_mask = $(MASK_POS) + 0;
            if (min_mask > $(MASK_POS) + 0)
                min_mask = $(MASK_POS) + 0;
        } END {
            if (item_count == 0) exit;
            delete arr;
            bit_index = MAX_MASK - current_mask;
            while (bit_index < MAX_MASK ) {
                mask = MAX_MASK - bit_index;
                mask_len = length(mask);
                step = 2 ^ (bit_index % BIT_WIDTH);
                key_pos = MASK_POS - int(bit_index / BIT_WIDTH) - 1;
                modified = 0;
                for (item_no = item_count; item_no >= 1; item_no = next_arr[item_no]) {
                    if (substr(addr_arr[item_no], length(addr_arr[item_no]) - mask_len) == " " mask) {
                        split(addr_arr[item_no], arr, /[[:space:]]+/);
                        if (int((arr[key_pos] + 0) / step) % 2 == 1) {
                            addr_header = "";
                            for (i = 1; i < key_pos; ++i)
                                addr_header = (i == 1 ? "" : addr_header " ") arr[i];
                            prev_item = "";
                            for (i = key_pos + 1; i <= MASK_POS; ++i)
                                prev_item = prev_item " " arr[i];
                            prev_item = (key_pos == 1 ? "" : addr_header " ") (arr[key_pos] - step) prev_item;
                            if (prev_item in keys_arr) {
                                delete keys_arr[addr_arr[item_no]];
                                item_update = prev_item;
                                sub(/[[:space:]]+[0-9]+$/, " " (arr[MASK_POS] - 1), item_update);
                                addr_arr[item_no] = item_update;
                                keys_arr[addr_arr[item_no]] = item_no;
                                next_arr[item_no] = next_arr[keys_arr[prev_item]];
                                delete next_arr[keys_arr[prev_item]];
                                delete addr_arr[keys_arr[prev_item]];
                                delete keys_arr[prev_item];
                                if (!modified) modified = 1;
                            }
                        }
                    }
                }
                if (!modified && mask <= min_mask)
                    break;
                bit_index++;
            }
            item_total = length(addr_arr);
            if (item_total <= 0) exit;
            delete rev_index_arr;
            for (i = item_count; i >= 1; i = next_arr[i])
                rev_index_arr[item_total--] = i;
            item_total = length(rev_index_arr);
            if (ip_proto == "4") {
                for (i = 1; i <= item_total; ++i) {
                    split(addr_arr[rev_index_arr[i]], arr, /[[:space:]]+/);
                    printf "%u.%u.%u.%u/%u\n", arr[1], arr[2], arr[3], arr[4], arr[5];
                }
            } else if (ip_proto == "6") {
                for (i = 1; i <= item_total; ++i) {
                    split(addr_arr[rev_index_arr[i]], arr, /[[:space:]]+/);
                    ipv6_str = sprintf("%x:%x:%x:%x:%x:%x:%x:%x/%u", 
                                arr[1], arr[2], arr[3], arr[4], 
                                arr[5], arr[6], arr[7], arr[8], arr[9]);
                    sub(/(:0){2,}/, "::", ipv6_str);    # RFC 5952
                    sub(/:::/, "::", ipv6_str);
                    sub(/^0::/, "::", ipv6_str);
                    print ipv6_str;
                }
            }
        }' > "${3}"
    return "0"
}

async_cidr_task() {
    { { [ "${1}" != "4" ] && [ "${1}" != "6" ]; } || [ ! -f "${2}" ] || [ ! -d "${3%/*}" ]; } && { echo ""; return "1"; }
    if [ "${CIDR_MERGE_ALGO}" = "1" ]; then
        cidr_seq_merge "${1}" "${2}" "${3}" &
    elif [ "${CIDR_MERGE_ALGO}" = "2" ]; then
        cidr_rev_seq_merge "${1}" "${2}" "${3}" &
    else
        cidr_hash_merge "${1}" "${2}" "${3}" &
    fi
    ASYNC_PID="$!"
    while true
    do
        [ "${4}" = "0" ] && echo -n "..."
        ! kill -0 "${ASYNC_PID}" 2> /dev/null && break
        sleep 3s
    done
    [ "${4}" != "1" ] && echo  "..."
    rm -f "${3}.tmp"
    [ ! -f "${3}" ] && return "1"
    ! grep -qEi "^(${REGEX_IPV4_NET}$|${REGEX_IPV6_NET})$" "${3}" && { rm -f "${3}"; return "1"; }
    return "0"
}

get_ipv4_cidr_data() {
    [ "${IPV4_DATA}" != "0" ] && return "0"
    lz_echo "Generating IPv4 CIDR Data takes some time."
    if [ "${CIDR_MERGE_ALGO}" = "1" ]; then
        lz_echo "Sequential Merging (Sequential Index Access)"
    elif [ "${CIDR_MERGE_ALGO}" = "2" ]; then
        lz_echo "Reverse Sequential Merging (Reverse Index Access)"
    else
        lz_echo "Hash Merging (Hash Table Random Access)"
    fi
    lz_echo "Don't interrupt & Please wait......"
    local index="0" sfname="" fname="" total="0"
    until [ "${index}" -gt "10" ]
    do
        eval sfname="\${ISP_DATA_${index}}"
        eval fname="\${ISP_CIDR_DATA_${index}}"
        if async_cidr_task "4" "${PATH_TMP}/${sfname%.*}.dat" "${PATH_TMP}/${fname%.*}.dat" "${PROGRESS_BAR}"; then
            total="$( grep -Ec "^${REGEX_IPV4_NET}$" "${PATH_TMP}/${fname%.*}.dat" )"
            lz_echo "${fname} ${total} OK"
        else
            lz_echo "${fname} Failed. Game Over !!!"
            return "1"
        fi
        index="$(( index + 1 ))"
    done
    return "0"
}

get_ipv6_cidr_data() {
    [ "${IPV6_DATA}" != "0" ] && return "0"
    lz_echo "Generating IPv6 CIDR Data takes some time."
    if [ "${CIDR_MERGE_ALGO}" = "1" ]; then
        lz_echo "Sequential Merging (Sequential Index Access)"
    elif [ "${CIDR_MERGE_ALGO}" = "2" ]; then
        lz_echo "Reverse Sequential Merging (Reverse Index Access)"
    else
        lz_echo "Hash Merging (Hash Table Random Access)"
    fi
    lz_echo "Don't interrupt & Please wait......"
    local index="0" sfname="" fname="" total="0"
    until [ "${index}" -gt "10" ]
    do
        eval sfname="\${ISP_IPV6_DATA_${index}}"
        eval fname="\${ISP_IPV6_CIDR_DATA_${index}}"
        if async_cidr_task "6" "${PATH_TMP}/${sfname%.*}.dat" "${PATH_TMP}/${fname%.*}.dat" "${PROGRESS_BAR}"; then
            total="$( grep -Eic "^${REGEX_IPV6_NET}$" "${PATH_TMP}/${fname%.*}.dat" )"
            lz_echo "${fname} ${total} OK"
        else
            lz_echo "${fname} Failed. Game Over !!!"
            return "1"
        fi
        index="$(( index + 1 ))"
    done
    return "0"
}

show_elapsed_time() {
    local end_time="$( date +%s -d "$( date +"%F %T" )" )"
    local elapsed_hour="$( printf "%02u\n" "$(( ( end_time - BEGIN_TIME ) / 3600 ))" )"
    local elapsed_min="$( printf "%02u\n" "$(( ( ( end_time - BEGIN_TIME ) % 3600 ) / 60 ))" )"
    local elapsed_sec="$( printf "%02u\n" "$(( ( end_time - BEGIN_TIME ) % 60 ))" )"
    lz_echo "Elapsed Time           ${elapsed_hour}:${elapsed_min}:${elapsed_sec}"
}

cidr_merge_cmd() {
    [ -z "${CIDR_MERGE_CMD}" ] && CIDR_MERGE_CMD="cidr"
    [ "$( awk 'BEGIN {print tolower("'"${1}"'")}' )" != "${CIDR_MERGE_CMD}" ] && return "1"
    local total="0"
    if [ "${2}" != "4" ] && [ "${2}" != "6" ]; then
        lz_echo "Parameter 2 ( 4 or 6 ) Invalid. Game Over !!!"
        return "0"
    elif [ "${3}" = "${4}" ]; then
        lz_echo "Input is Output. Game Over !!!"
        return "0"
    elif [ ! -f "${3}" ]; then
        lz_echo "File ${3} not found. Game Over !!!"
        return "0"
    elif [ ! -d "${4%/*}" ]; then
        lz_echo "No directory: ${4%/*}. Game Over !!!"
        return "0"
    fi
    if [ "${2}" = "4" ]; then
        total="$( grep -Ec "^${REGEX_IPV4_NET}$" "${3}" )"
    else
        total="$( grep -Eic "^${REGEX_IPV6_NET}$" "${3}" )"
    fi
    if [ "${total}" = "0" ]; then
        lz_echo "File ${3}: No Data Available. Game Over !!!"
        return "0"
    else
        lz_echo "${3} ${total} OK"
    fi
    lz_echo "---------------------------------------------"
    if [ "${2}" = "4" ]; then
        lz_echo "Generating IPv4 CIDR Data takes some time."
    elif [ "${2}" = "6" ]; then
        lz_echo "Generating IPv6 CIDR Data takes some time."
    fi
    if [ "${CIDR_MERGE_ALGO}" = "1" ]; then
        lz_echo "Sequential Merging (Sequential Index Access)"
    elif [ "${CIDR_MERGE_ALGO}" = "2" ]; then
        lz_echo "Reverse Sequential Merging (Reverse Index Access)"
    else
        lz_echo "Hash Merging (Hash Table Random Access)"
    fi
    lz_echo "Don't interrupt & Please wait......"
    if async_cidr_task "${2}" "${3}" "${4}" "0"; then
        if [ "${2}" = "4" ]; then
            total="$( grep -Ec "^${REGEX_IPV4_NET}$" "${4}" )"
        else
            total="$( grep -Eic "^${REGEX_IPV6_NET}$" "${4}" )"
        fi
        if [ "${total}" = "0" ]; then
            rm -f "${4}"
            lz_echo "CIDR Merge ${3} Failed. Game Over !!!"
        else
            lz_echo "${4} ${total} OK"
            lz_echo "CIDR Merge ${3} OK"
            lz_echo "---------------------------------------------"
            show_elapsed_time
        fi
    else
        lz_echo "CIDR Merge ${3} Failed. Game Over !!!"
        return "0"
    fi
    RetVal="0"
    return "0"
}

save_target_data() {
    [ -f "${PATH_TMP}/${2%.*}.dat" ] && mv -f "${PATH_TMP}/${2%.*}.dat" "${1}/${2}"
    [ -f "${1}/${2}" ] && {
        touch -c -r "${PATH_APNIC}/${APNIC_IP_INFO}" "${1}/$2}"
        return "0"
    }
    lz_echo "Save ${2} Failed. Game Over !!!"
    return "1"
}

save_data() {
    [ -f "${PATH_TMP}/${APNIC_IP_INFO%.*}.dat" ] && mv -f "${PATH_TMP}/${APNIC_IP_INFO%.*}.dat" "${PATH_APNIC}/${APNIC_IP_INFO}"
    [ ! -f "${PATH_APNIC}/${APNIC_IP_INFO}" ] && {
        lz_echo "Save ${APNIC_IP_INFO} Failed. Game Over !!!"
        return "1"
    }
    local index="0"
    if [ "${IPV4_DATA}" = "0" ] || [ "${IPV4_DATA}" = "1" ]; then
        until [ "${index}" -gt "10" ]
        do
            save_target_data "${PATH_ISP}" "$(eval echo "\${ISP_DATA_${index}}")" || return "1"
            index="$(( index + 1 ))"
        done
        if [ "${IPV4_DATA}" = "0" ]; then
            index="0"
            until [ "${index}" -gt "10" ]
            do
                save_target_data "${PATH_CIDR}" "$(eval echo "\${ISP_CIDR_DATA_${index}}")" || return "1"
                index="$(( index + 1 ))"
            done
        fi
    fi
    if [ "${IPV6_DATA}" = "0" ] || [ "${IPV6_DATA}" = "1" ]; then
        index="0"
        until [ "${index}" -gt "10" ]
        do
            save_target_data "${PATH_IPV6}" "$(eval echo "\${ISP_IPV6_DATA_${index}}")" || return "1"
            index="$(( index + 1 ))"
        done
        if [ "${IPV6_DATA}" = "0" ]; then
            index="0"
            until [ "${index}" -gt "10" ]
            do
                save_target_data "${PATH_IPV6_CIDR}" "$(eval echo "\${ISP_IPV6_CIDR_DATA_${index}}")" || return "1"
                index="$(( index + 1 ))"
            done
        fi
    fi
    return "0"
}

get_file_time_stamp() {
    local time_stamp="$( stat -c %y "${1}" 2> /dev/null | awk -F '.' '{print $1}' )"
    [ -z "${time_stamp}" ] && {
        # shellcheck disable=SC2012
        if uname -a | grep -qi "asuswrt-merlin"; then
            time_stamp="$( ls -let "${1}" 2> /dev/null \
                        | awk 'NF >= "11" \
                            && $7 ~ /^[A-S][a-u][b-y]$/ \
                            && $8 ~ /^[1-9]$|^[1-2][0-9]$|^[3][0-1]$|^[0][1-9]$/ \
                            && $9 ~ /^[0-2][0-9][:][0-5][0-9][:][0-5][0-9]$/ \
                            && $10 ~ /^[1-9][0-9][0-9][0-9]$/ {
                                month = ""
                                if ($7 == "Jan") month = "01"
                                else if ($7 == "Feb") month = "02"
                                else if ($7 == "Mar") month = "03"
                                else if ($7 == "Apr") month = "04"
                                else if ($7 == "May") month = "05"
                                else if ($7 == "Jun") month = "06"
                                else if ($7 == "Jul") month = "07"
                                else if ($7 == "Aug") month = "08"
                                else if ($7 == "Sep") month = "09"
                                else if ($7 == "Oct") month = "10"
                                else if ($7 == "Nov") month = "11"
                                else if ($7 == "Dec") month = "12"
                                if (month != "") print $10"-"month"-"$8,$9}' )"
        elif uname -a | grep -qi "openwrt"; then
            time_stamp="$( ls -lt --full-time "${1}" 2> /dev/null | awk 'NF >= "9" {print $6,$7}' )"
        else
            time_stamp="$( ls -lt "${1}" 2> /dev/null \
                        | awk 'NF >= "9" \
                            && $6 ~ /^[A-S][a-u][b-y]$/ \
                            && $7 ~ /^[1-9]$|^[1-2][0-9]$|^[3][0-1]$|^[0][1-9]$/ \
                            && $8 ~ /^[0-2][0-9][:][0-5][0-9][:][0-5][0-9]$/ {
                                month = ""
                                if ($6 == "Jan") month = "01"
                                else if ($6 == "Feb") month = "02"
                                else if ($6 == "Mar") month = "03"
                                else if ($6 == "Apr") month = "04"
                                else if ($6 == "May") month = "05"
                                else if ($6 == "Jun") month = "06"
                                else if ($6 == "Jul") month = "07"
                                else if ($6 == "Aug") month = "08"
                                else if ($6 == "Sep") month = "09"
                                else if ($6 == "Oct") month = "10"
                                else if ($6 == "Nov") month = "11"
                                else if ($6 == "Dec") month = "12"
                                if (month != "") print month"-"$7,$8}' )"
        fi
    }
    echo "${time_stamp}"
}

show_header() {
    BEGIN_TIME="$( date +%s -d "$( date +"%F %T" )" )"
    [ -z "${LZ_VERSION}" ] && LZ_VERSION="v1.1.8"
    lz_echo
    lz_echo "LZ ISPRO ${LZ_VERSION} script commands start......"
    lz_echo "By LZ (larsonzhang@gmail.com)"
    lz_echo "---------------------------------------------"
    lz_echo "Command in the ${PATH_CURRENT}"
    lz_echo "Launch Script  ./lzispro.sh"
    lz_echo "Forced Stop    ./lzispro.sh stop"
    lz_echo "CIDR Merge     ./lzispro.sh cidr [4:ipv4|6:ipv6] [input file] [output file]"
    lz_echo "---------------------------------------------"
    local sys_info="$( uname -srmo )"
    local sys_ver="$( uname -v )"
    [ -n "${sys_info}" ] && lz_echo "${sys_info}"
    [ -n "${sys_ver}" ] && lz_echo "${sys_ver}"
    { [ -n "${sys_info}" ] || [ -n "${sys_ver}" ]; } \
    && lz_echo "---------------------------------------------"
}

show_data_path() {
    local file_time_stamp="$( get_file_time_stamp "${PATH_APNIC}/${APNIC_IP_INFO}" )"
    lz_echo "---------------------------------------------"
    [ -n "${file_time_stamp}" ] && lz_echo "Data Time       ${file_time_stamp}"
    lz_echo "APNIC IP INFO   ${PATH_APNIC}"
    if [ "${IPV4_DATA}" = "0" ] || [ "${IPV4_DATA}" = "1" ]; then
        lz_echo "ISP IPv4        ${PATH_ISP}"
        [ "${IPV4_DATA}" = "0" ] && lz_echo "ISP IPv4 CIDR   ${PATH_CIDR}"
    fi
    if [ "${IPV6_DATA}" = "0" ] || [ "${IPV6_DATA}" = "1" ]; then
        lz_echo "ISP IPv6        ${PATH_IPV6}"
        [ "${IPV6_DATA}" = "0" ] && lz_echo "ISP IPv6 CIDR   ${PATH_IPV6_CIDR}"
    fi
    show_elapsed_time
    RetVal="0"
}

show_tail() {
    lz_echo "---------------------------------------------"
    lz_echo "LZ ISPRO ${LZ_VERSION} script commands executed!"
    lz_echo
}

# -------------- Script Execution ---------------

show_header
while true
do
    forced_stop_cmd "${1}" && break
    cidr_merge_cmd "$@" && break
    proc_sync || break
    check_module "whois" || break
    check_module "wget" || break
    init_param || break
    init_isp_data_script || break
    get_apnic_info || break
    { [ "${IPV4_DATA}" = "0" ] || [ "${IPV4_DATA}" = "1" ]; } \
        && lz_echo "---------------------------------------------"
    get_area_data "CN" "ipv4" "${ISP_DATA_0}" || break
    { [ "${IPV4_DATA}" = "0" ] || [ "${IPV4_DATA}" = "1" ]; } \
        && lz_echo "---------------------------------------------"
    get_isp_data "ipv4" || break
    get_area_data "HK" "ipv4" "${ISP_DATA_8}" || break
    get_area_data "MO" "ipv4" "${ISP_DATA_9}" || break
    get_area_data "TW" "ipv4" "${ISP_DATA_10}" || break
    [ "${IPV4_DATA}" = "0" ] \
        && lz_echo "---------------------------------------------"
    get_ipv4_cidr_data || break
    { [ "${IPV6_DATA}" = "0" ] || [ "${IPV6_DATA}" = "1" ]; } \
        && lz_echo "---------------------------------------------"
    get_area_data "CN" "ipv6" "${ISP_IPV6_DATA_0}" || break
    { [ "${IPV6_DATA}" = "0" ] || [ "${IPV6_DATA}" = "1" ]; } \
        && lz_echo "---------------------------------------------"
    get_isp_data "ipv6" || break
    get_area_data "HK" "ipv6" "${ISP_IPV6_DATA_8}" || break
    get_area_data "MO" "ipv6" "${ISP_IPV6_DATA_9}" || break
    get_area_data "TW" "ipv6" "${ISP_IPV6_DATA_10}" || break
    [ "${IPV6_DATA}" = "0" ] \
        && lz_echo "---------------------------------------------"
    get_ipv6_cidr_data || break
    save_data || break
    show_data_path
    break
done
show_tail

exit "${RetVal:="1"}"

#END
