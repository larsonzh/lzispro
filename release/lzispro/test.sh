#!/bin/sh

lzdate() { date +"%F %T"; }
begin="$( echo "$(lzdate)" [$$]: BEGIN )"

#cat ./isp/lz_chinabtn.txt | ./whois-aarch64 --batch --host apnic | grep -Ei '^(=== Query|netname|mnt-|e-mail)' \
./whois-aarch64 --batch --host apnic < ./isp/lz_chinabtn.txt | grep -Ei '^(=== Query|netname|mnt-|e-mail)' \
    | awk -v count=0 '/^=== Query/ {if (count ==  0) printf "%s", $4; else printf "\n%s", $4; count++; next} \
        !/^=== Query/ {printf " %s", toupper($2)} END {printf "\n"}' \
    | awk '/CNC|UNICOM/ {print $1, "CNC"; next} \
        /CHINANET|TELECOM|BJTEL/{print $1, "CHINATELECOM"; next} \
        (/ZXLYCMCC/ && /CMCC/) || (/CMIDC@CHINA-MOTION[.]COM/ && /CMNET/) \
            || /CRTC|CHINAMOBILE|CTTNET|CTTSDNET|TIETONG|CTTSH/ {print $1, "CMCC"; next} \
        /CHINABTN|HEBBTN|TJBTN|NXBCTV/ {print $1, "CBTN"; next} \
        /CERNET/ {print $1, "CERNET"; next} /GWNET|GWBN|GXBL|WSNET|DXTNET|BITNET|ZBTNET|DRPENG|BTTE/ {print $1, "GWBN"; next} \
        {print $1, "OTHER"}'

echo "${begin}"
echo "$(lzdate)" [$$]: END
