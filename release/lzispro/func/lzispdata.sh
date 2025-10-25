#!/bin/sh
# lzispdata.sh v1.1.8
# By LZ 妙妙呜 (larsonzhang@gmail.com)

# ISP Data Process Script

# $1--Internet Protocol Version (ipv4 or ipv6)
# $2--Source Data File index number

#BEIGIN

# shellcheck disable=SC2034

# ------------- Data Exchange Area --------------

# Internet Protocol Version (ipv4 or ipv6)
IPV_TYPE="${1}"

# Source Data File index number
SRC_INDEX="$( echo "${2}" | sed -n '/^[0-9]$\|^[1-9][0-9]*$/{1p;q}' )"

# ------------------ Function -------------------

init_param() {
    while true
    do
        local path_cur="${2%/*}"
        ! echo "${path_cur}" | grep -q '^[/]' && path_cur="$( pwd )${path_cur#*.}"
        [ "${path_cur}/${2##*/}" != "${PATH_FUNC}/${ISP_DATA_SCRIPT}" ] && break
        [ "${1}" != "2" ] && break
        [ "${IPV_TYPE}" != "ipv4" ] && [ "${IPV_TYPE}" != "ipv6" ] && break
        [ -z "${SRC_INDEX}" ] && break
        # Source Data File Path
        PATH_SRC="${PATH_TMP}"
        [ ! -d "${PATH_SRC}" ] && break
        # Source Data File name
        SRC_FILENAME="${ISP_DATA_0%.*}.dat_${SRC_INDEX}"
        [ "${IPV_TYPE}" != "ipv4" ] && SRC_FILENAME="${ISP_IPV6_DATA_0%.*}.dat_${SRC_INDEX}"
        [ ! -f "${PATH_SRC}/${SRC_FILENAME}" ] && break
        # Destination data file path
        PATH_DST="${PATH_TMP}"
        [ ! -d "${PATH_DST}" ] && break
        # IP Address Information Details Query Host
        [ -z "${WHOIS_HOST}" ] && break
        # Maximum Number Of Retries After IP Address Query Failure
        ! echo "${RETRY_NUM}" | grep -qE '^[0-9][0-9]*$' && break
        RETRY_NUM="$( printf "%u\n" "${RETRY_NUM}" )"
        return "0"
    done
    echo "$( date +"%F %T" ) [$$]:" "Illegal call. Bye ~ !!!" 2> /dev/null
    return "1"
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
    "${WHOIS_MODULE}" -h "${WHOIS_HOST}" "${1%/*}" 2> /dev/null | grep -Ei '^(netname|mnt-|e-mail)'
}

write_isp_data_buf() {
    # CNC & CHINAUNICOM
    echo "${1}" | grep -qEi 'CNC|UNICOM' && { DATA_BUF_2="${DATA_BUF_2}n${2}"; return; }
    # CHINATELECOM
    echo "${1}" | grep -qEi 'CHINANET|TELECOM|BJTEL' && { DATA_BUF_1="${DATA_BUF_1}n${2}"; return; }
    # CHINAMOBILE & CRTC
    echo "${1}" | grep -vi 'ZXLYCMCC' | grep -qEi 'CMCC' && { DATA_BUF_3="${DATA_BUF_3}n${2}"; return; }
    echo "${1}" | grep -vi 'cmidc@china-motion.com' | grep -qEi 'CMNET' && { DATA_BUF_3="${DATA_BUF_3}n${2}"; return; }
    echo "${1}" | grep -qEi 'CRTC|CHINAMOBILE|CTTNET|CTTSDNET|TIETONG|CTTSH' && { DATA_BUF_3="${DATA_BUF_3}n${2}"; return; }
    # CBTN
    echo "${1}" | grep -qEi 'CHINABTN|HEBBTN|TJBTN|NXBCTV' && { DATA_BUF_4="${DATA_BUF_4}n${2}"; return; }
    # CERNET
    echo "${1}" | grep -qEi 'CERNET' && { DATA_BUF_5="${DATA_BUF_5}n${2}"; return; }
    # GWBN
    echo "${1}" | grep -qEi 'GWNET|GWBN|GXBL|WSNET|DXTNET|BITNET|ZBTNET|drpeng|btte' && { DATA_BUF_6="${DATA_BUF_6}n${2}"; return; }
    # OTHER
    DATA_BUF_7="${DATA_BUF_7}n${2}"
}

write_isp_data_file() {
    local prefix="ISP_DATA_" index="1" fname=""
    [ "${IPV_TYPE}" != "ipv4" ] && prefix="ISP_IPV6_DATA_"
    until [ "${index}" -gt "7" ]
    do
        eval fname="${PATH_DST}/\${${prefix}${index}}"
        eval [ -n "\${DATA_BUF_${index}}" ] && {
            eval echo "\${DATA_BUF_${index}}" | sed -e 's/^n//g' -e 's/n/\n/g' >> "${fname%.*}.dat_${SRC_INDEX}"
            eval DATA_BUF_"${index}"=""
        }
        index="$(( index + 1 ))"
    done
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
            [ -f "${fname%.*}.dat_${SRC_INDEX}" ] && rm -f "${fname%.*}.dat_${SRC_INDEX}"
        fi
        index="$(( index + 1 ))"
    done
}

add_isp_data() {
    local DATA_BUF="" retval="0" count="0" line="" isp_info="" retry="0"
    if [ "${IPV_TYPE}" = "ipv4" ]; then
        DATA_BUF="$( grep -Eo "^${REGEX_IPV4_NET}$" "${PATH_SRC}/${SRC_FILENAME}" )"
    else
        DATA_BUF="$( grep -Eio "^${REGEX_IPV6_NET}$" "${PATH_SRC}/${SRC_FILENAME}" )"
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

get_batch_isp_data() {
    local retval="0" regexp="^${REGEX_IPV4_NET}$" prefix="ISP_DATA_" index="1" \
        fname_1="" fname_2="" fname_3="" fname_4="" fname_5="" fname_6="" fname_7="" \
        WHOIS_EXTRA_ARGS=""
    if [ "${IPV_TYPE}" != "ipv4" ]; then
        regexp="^${REGEX_IPV6_NET}$"
        prefix="ISP_IPV6_DATA_"
    fi
    until [ "${index}" -gt "7" ]
    do
        eval fname_${index}="${PATH_DST}/\${${prefix}${index}}"
        index="$(( index + 1 ))"
    done

    # Internal pacing defaults (can be overridden by env) — keep simple for users
    local _WHOIS_TIMEOUT="${WHOIS_TIMEOUT:-5}"
    local _WHOIS_RETRY_INTERVAL_MS="${WHOIS_RETRY_INTERVAL_MS:-300}"
    local _WHOIS_RETRY_JITTER_MS="${WHOIS_RETRY_JITTER_MS:-300}"
    WHOIS_EXTRA_ARGS="--timeout ${_WHOIS_TIMEOUT} --retry-interval-ms ${_WHOIS_RETRY_INTERVAL_MS} --retry-jitter-ms ${_WHOIS_RETRY_JITTER_MS}"
    grep -Eo "${regexp}" "${PATH_SRC}/${SRC_FILENAME}" \
        | "${WHOIS_MODULE}" --batch --host "${WHOIS_HOST}" --retries "${RETRY_NUM}" ${WHOIS_EXTRA_ARGS} 2> /dev/null \
        | grep -Ei '^(=== Query:|netname|mnt-|e-mail|=== Authoritative RIR:)' \
        | awk -v count=0 '/^=== Query/ {if (count ==  0) printf "%s", $3; else printf "\n%s", $3; count++; next} \
            /^=== Authoritative RIR:/ {printf " %s", toupper($4)} \
            !/^=== Query:/ && !/^=== Authoritative RIR:/ {printf " %s", toupper($2)} END {printf "\n"}' \
        | awk -v sfx=".dat_${SRC_INDEX}" 'BEGIN {
            fname_1 = "'"${fname_1%.*}"'" sfx;
            fname_2 = "'"${fname_2%.*}"'" sfx;
            fname_3 = "'"${fname_3%.*}"'" sfx;
            fname_4 = "'"${fname_4%.*}"'" sfx;
            fname_5 = "'"${fname_5%.*}"'" sfx;
            fname_6 = "'"${fname_6%.*}"'" sfx;
            fname_7 = "'"${fname_7%.*}"'" sfx;
        } \
        toupper($(NF)) == "UNKNOWN" { next } \
        /CNC|UNICOM/ {print $1 >> fname_2; next} \
        /CHINANET|TELECOM|BJTEL/ {print $1 >> fname_1; next} \
        (!/ZXLYCMCC/ && /CMCC/) || (!/CMIDC@CHINA-MOTION[.]COM/ && /CMNET/) \
            || /CRTC|CHINAMOBILE|CTTNET|CTTSDNET|TIETONG|CTTSH/ {print $1 >> fname_3; next} \
        /CHINABTN|HEBBTN|TJBTN|NXBCTV/ {print $1 >> fname_4; next} \
        /CERNET/ {print $1 >> fname_5; next} \
        /GWNET|GWBN|GXBL|WSNET|DXTNET|BITNET|ZBTNET|DRPENG|BTTE/ {print $1 >> fname_6; next} \
        {print $1 >> fname_7}' || retval="1"
    return "${retval}"
}

# -------------- Script Execution ---------------

init_param "${#}" "${0}" || exit "1"
if [ "${WHOIS_MODULE}" = "whois" ]; then
    get_isp_data || exit "1"
else
    get_batch_isp_data || exit "1"
fi

exit "0"

#END

