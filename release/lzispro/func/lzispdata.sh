#!/bin/sh
# lzispdata.sh v1.0.0
# By LZ 妙妙呜 (larsonzhang@gmail.com)

# Obtain ISP attribution data script

# $1--Internet Protocol Version (ipv4 or ipv6)
# $2--Source Data File index number

#BEIGIN

# shellcheck disable=SC2034

# ------------- Data Exchange Area --------------

# Internet Protocol Version (ipv4 or ipv6)
IPV_TYPE="${1}"

# Source Data File index number
SRC_INDEX="$( printf "%u\n" "${2}" )"

# Source Data File Path
TRAN_PATH_SRC=""

# Destination data file path
TRAN_PATH_DST=""

# China ISP IPv4 Raw Data Target File Name
TRAN_ISP_DATA_0="lz_all_cn.txt"
TRAN_ISP_DATA_1="lz_chinatelecom.txt"
TRAN_ISP_DATA_2="lz_unicom_cnc.txt"
TRAN_ISP_DATA_3="lz_cmcc.txt"
TRAN_ISP_DATA_4="lz_crtc.txt"
TRAN_ISP_DATA_5="lz_cernet.txt"
TRAN_ISP_DATA_6="lz_gwbn.txt"
TRAN_ISP_DATA_7="lz_othernet.txt"
TRAN_ISP_DATA_8="lz_hk.txt"
TRAN_ISP_DATA_9="lz_mo.txt"
TRAN_ISP_DATA_10="lz_tw.txt"

# China ISP IPv6 Raw Data Target File Name
TRAN_ISP_IPV6_DATA_0="lz_all_cn_ipv6.txt"
TRAN_ISP_IPV6_DATA_1="lz_chinatelecom_ipv6.txt"
TRAN_ISP_IPV6_DATA_2="lz_unicom_cnc_ipv6.txt"
TRAN_ISP_IPV6_DATA_3="lz_cmcc_ipv6.txt"
TRAN_ISP_IPV6_DATA_4="lz_crtc_ipv6.txt"
TRAN_ISP_IPV6_DATA_5="lz_cernet_ipv6.txt"
TRAN_ISP_IPV6_DATA_6="lz_gwbn_ipv6.txt"
TRAN_ISP_IPV6_DATA_7="lz_othernet_ipv6.txt"
TRAN_ISP_IPV6_DATA_8="lz_hk_ipv6.txt"
TRAN_ISP_IPV6_DATA_9="lz_mo_ipv6.txt"
TRAN_ISP_IPV6_DATA_10="lz_tw_ipv6.txt"

# IP Address Information Details Query Host
TRAN_WHOIS_HOST="whois.apnic.net"

# Maximum Number Of Retries After IP Address Query Failure
# 0--Unlimited, 5--Default
TRAN_RETRY_NUM="5"

# Synchronization Lock File Path & Name
TRAN_PATH_LOCK="/var/lock"
TRAN_LOCK_FILE="lzispro.lock"

# ------------------ Function -------------------

init_param() {
    LOCK_ENABLE="1"
    [ "${1}" != "2" ] && return "1"
    [ "${IPV_TYPE}" != "ipv4" ] && [ "${IPV_TYPE}" != "ipv6" ] && return "1"
    SRC_INDEX="$( printf "%u\n" "${SRC_INDEX}" )"
    ! echo "${SRC_INDEX}" | grep -qE '^[0-9][0-9]*$' && return "1"
    # Source Data File Path
    PATH_SRC="${TRAN_PATH_SRC}"
    [ ! -d "${PATH_SRC}" ] && return "1"
    local index="0" ipv4_data="" ipv6_data=""
    until [ "${index}" -gt "10" ]
    do
        # China ISP IPv4 Raw Data Target File Name
        eval "ISP_DATA_${index}=\${TRAN_ISP_DATA_${index}}"
        eval [ -z "\${ISP_DATA_${index}}" ] && return "1"
        eval "unset TRAN_ISP_DATA_${index}"
        # China ISP IPv6 Raw Data Target File Name
        eval "ISP_IPV6_DATA_${index}=\${TRAN_ISP_IPV6_DATA_${index}}"
        eval [ -z "\${ISP_IPV6_DATA_${index}}" ] && return "1"
        eval "unset TRAN_ISP_IPV6_DATA_${index}"
        index="$(( index + 1 ))"
    done
    # Source Data File name
    SRC_FILENAME="${ISP_DATA_0%.*}.dat_${SRC_INDEX}"
    [ "${IPV_TYPE}" != "ipv4" ] && SRC_FILENAME="${ISP_IPV6_DATA_0%.*}.dat_${SRC_INDEX}"
    [ ! -f "${PATH_SRC}/${SRC_FILENAME}" ] && return "1"
    # Destination data file path
    PATH_DST="${TRAN_PATH_DST}"
    [ ! -d "${PATH_DST}" ] && return "1"
    # IP Address Information Details Query Host
    WHOIS_HOST="${TRAN_WHOIS_HOST}"
    [ -z "${WHOIS_HOST}" ] && return "1"
    # Maximum Number Of Retries After IP Address Query Failure
    RETRY_NUM="$( printf "%u\n" "${TRAN_RETRY_NUM}" )"
    ! echo "${RETRY_NUM}" | grep -qE '^[0-9][0-9]*$' && return "1"
    # Synchronization Lock File Path & Name
    PATH_LOCK="${TRAN_PATH_LOCK}"
    LOCK_FILE="${TRAN_LOCK_FILE}"
    [ ! -d "${PATH_LOCK}" ] && return "1"
    [ ! -f "${PATH_LOCK}/${LOCK_FILE}" ] && return "1"
    LOCK_FILE="${LOCK_FILE%.*}_${SRC_INDEX}.lock"
    LOCK_ENABLE="0"
    unset TRAN_PATH_SRC TRAN_PATH_DST TRAN_WHOIS_HOST TRAN_RETRY_NUM TRAN_PATH_LOCK TRAN_LOCK_FILE
    return "0"
}

set_lock() {
    [ ! -d "${PATH_LOCK}" ] && {
        LOCK_ENABLE="1"
        return "1"
    }
    [ -f "${PATH_LOCK}/${LOCK_FILE}" ] && {
        LOCK_ENABLE="1"
        return "1"
    }
    touch "${PATH_LOCK}/${LOCK_FILE}"
    [ ! -f "${PATH_LOCK}/${LOCK_FILE}" ] && {
        LOCK_ENABLE="1"
        return "1"
    }
    return "0"
}

unset_lock() {
    [ "${LOCK_ENABLE}" = "0" ] && [ -f "${PATH_LOCK}/${LOCK_FILE}" ] && rm -f "${PATH_LOCK}/${LOCK_FILE}" 2> /dev/null
}

init_isp_data_buf() {
    local index="1"
    until [ "${index}" -gt "7" ]
    do
        eval DATA_BUF_"${index}"=""
        index="$(( index + 1 ))"
    done
}

unset_isp_data_buf() {
    local index="1"
    until [ "${index}" -gt "7" ]
    do
        eval unset DATA_BUF_"${index}"
        index="$(( index + 1 ))"
    done
}

get_isp_details() {
    whois -h "${WHOIS_HOST}" "${1%/*}" \
        | awk 'NR == "1" || $1 ~ /netname|mnt-|e-mail/ {if (NR == "1" && $2 != "'"[${WHOIS_HOST}]"'") exit; else print $2}'
}

write_isp_data_buf() {
    # CNC
    # CHINAUNICOM
    echo "${1}" | grep -qEi 'CNC|UNICOM' && { DATA_BUF_2="$( echo -e "${DATA_BUF_2}\n${2}" )"; return; }
    # CHINATELECOM
    echo "${1}" | grep -qEi 'CHINANET|TELECOM|BJTEL' && { DATA_BUF_1="$( echo -e "${DATA_BUF_1}\n${2}" )"; return; }
    # CHINAMOBILE
    echo "${1}" | grep -qEi 'CMCC|CMNET' && { DATA_BUF_3="$( echo -e "${DATA_BUF_3}\n${2}" )"; return; }
    # CRTC
    echo "${1}" | grep -qEi 'CRTC' && { DATA_BUF_4="$( echo -e "${DATA_BUF_4}\n${2}" )"; return; }
    # CERNET
    echo "${1}" | grep -qEi 'CERNET' && { DATA_BUF_5="$( echo -e "${DATA_BUF_5}\n${2}" )"; return; }
    # GWBN
    echo "${1}" | grep -qEi 'GWBN|GXBL|DXTNET|BITNET|ZBTNET|drpeng|btte' && { DATA_BUF_6="$( echo -e "${DATA_BUF_6}\n${2}" )"; return; }
    # OTHER
    DATA_BUF_7="$( echo -e "${DATA_BUF_7}\n${2}" )"
}

write_isp_data_file() {
    local prefix="ISP_DATA_" index="1" buf="" fname=""
    [ "${IPV_TYPE}" != "ipv4" ] && prefix="ISP_IPV6_DATA_"
    until [ "${index}" -gt "7" ]
    do
        eval buf="\${DATA_BUF_${index}}"
        eval fname="${PATH_DST}/\${${prefix}${index}}"
        [ -n "${buf}" ] && buf="$( echo "${buf}" | sed '/^[ ]*$/d' )"
        [ -n "${buf}" ] && echo "${buf}" >> "${fname%.*}.dat_${SRC_INDEX}"
        index="$(( index + 1 ))"
    done
    init_isp_data_buf
}

failure_handling() {
    local prefix="ISP_DATA_" index="1" fname=""
    [ "${IPV_TYPE}" != "ipv4" ] && prefix="ISP_IPV6_DATA_"
    until [ "${index}" -gt "7" ]
    do
        eval fname="${PATH_DST}/\${${prefix}${index}}"
        if [ "${index}" = "1" ]; then
            echo "failure" > "${fname%.*}.dat_${SRC_INDEX}"
        else
            [ -f "${fname%.*}_${SRC_INDEX}.dat" ] && rm -f "${fname%.*}.dat_${SRC_INDEX}"
        fi
        index="$(( index + 1 ))"
    done
}

add_isp_data() {
    local DATA_BUF="" retval="0" count="0" line="" isp_info="" retry="0"
    [ -z "${WHOIS_HOST}" ] && WHOIS_HOST="whois.apnic.net"
    if [ "${IPV_TYPE}" = "ipv4" ]; then
        DATA_BUF="$( grep -Eo '^([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}$' "${PATH_SRC}/${SRC_FILENAME}" )"
    else
        DATA_BUF="$( grep -Eio '^[\:0-9a-f]{0,4}[\:][\:0-9a-f]*([\/][0-9]{1,3}){0,1}$' "${PATH_SRC}/${SRC_FILENAME}" )"
    fi
    while IFS= read -r line
    do
        isp_info="$( get_isp_details "${line}" )"
        if [ -z "${isp_info}" ]; then
            retval="1"
            retry="0"
            while true
            do
                isp_info="$( get_isp_details "${line}" )"
                [ -n "${isp_info}" ] && {
                    retval="0"
                    break
                }
                retry="$(( retry + 1 ))"
                if [ "${RETRY_NUM}" != "0" ]; then
                    [ "${retry}" -ge "${RETRY_NUM}" ] && break
                    sleep "$( awk 'BEGIN{printf "%d\n", "'"${RETRY_NUM}"'"*rand()+1}' )s"
                else
                    sleep "$( awk 'BEGIN{printf "%d\n", 10*rand()+1}' )s"
                fi
            done
            [ "${retval}" != "0" ] && break
        fi
        write_isp_data_buf "${isp_info}" "${line}"
        count="$(( count + 1 ))"
        [ "$(( count % 200 ))" = "0" ] && write_isp_data_file
    done <<DATA_BUF_INPUT
${DATA_BUF}
DATA_BUF_INPUT
    if [ "${retval}" = "0" ]; then
        write_isp_data_file
    else
        failure_handling
    fi
    unset_isp_data_buf
    return "${retval}"
}

get_isp_data() {
    init_isp_data_buf
    add_isp_data || return "1"
    return "0"
}

# -------------- Script Execution ---------------

while true
do
    init_param "${#}" || break
    set_lock || break
    get_isp_data
    break
done
unset_lock

exit "0"

#END

