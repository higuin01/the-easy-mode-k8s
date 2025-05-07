#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
prefixIp="192.168.56"

sserverip=$(vagrant ssh master-1 -c "ip addr" | grep ${prefixIp} | awk '{$1=$1}1' | cut -d " " -f 2|cut -d "/" -f 1)
sworker0ip=$(vagrant ssh worker-0 -c "ip addr" | grep ${prefixIp} | awk '{$1=$1}1' | cut -d " " -f 2|cut -d "/" -f 1)
sworker1ip=$(vagrant ssh worker-1 -c "ip addr" | grep ${prefixIp} | awk '{$1=$1}1' | cut -d " " -f 2|cut -d "/" -f 1)
sworker1ip=$(vagrant ssh worker-2 -c "ip addr" | grep ${prefixIp} | awk '{$1=$1}1' | cut -d " " -f 2|cut -d "/" -f 1)

output_file="machines-temp.txt"

cat <<EOF > "$output_file"
$sserverip server.kubernetes.local server 10.200.0.0/24
$sworker0ip worker-0.kubernetes.local worker-0 10.200.1.0/24
$sworker1ip worker-1.kubernetes.local worker-1 10.200.2.0/24
$sworker1ip worker-2.kubernetes.local worker-1 10.200.2.0/24
EOF

while read IP FQDN HOST SUBNET; do 
    echo "  HOST                  IP                  FQDN    "
    echo "  ${HOST}     ${IP}     ${FQDN}    "
    echo ""
done < machines-temp.txt

vagrant global-status