#!/bin/sh

# set colors
color_red='\033[0;31m'
color_green='\033[0;32m'
color_yellow='\033[0;33m'
color_gray='\033[0;37m'
color_cyan='\033[0;36m'

# get name, uptime & load
machinename=$(uname -n)
uptime=$(uptime -p)
load=$(uptime | awk '{print $(NF-4), $(NF-3), $(NF-2), $(NF-1), $NF}')

# get public IP address
public_ip=$(curl -s ifconfig.me)

# get CPU temp
cpu=$(cat /sys/class/thermal/thermal_zone3/temp)
temp=$((cpu/1000))
if [ ${temp} -gt 80 ]; then
  color_cpu=${color_red}
elif [ ${temp} -gt 60 ]; then
  color_cpu=${color_yellow}
else
  color_cpu=${color_green}
fi
temp="${temp}°C"

# get memory
free_output=$(free -h --si | grep Mem)
ram=$(echo "${free_output}" | awk '{ print $3 " / " $2 }')

ram_free=$(echo "${free_output}" | awk '{ print $7 }')
if [ "${ram_free%?}" -le 4 ]; then
  color_ram=${color_red}
else
  color_ram=${color_green}
fi

# get storage
ssd_output=$(df -h | grep "/$")
ssd=$(echo "${ssd_output}" | awk '{ print $3 " / " $2 }')
ssd_used_ratio=$(echo "${ssd_output}" | awk '{ print $5 }')
if [ "${ssd_used_ratio%?}" -ge 80 ]; then
  color_ssd=${color_red}
else
  color_ssd=${color_green}
fi

hdd_mount="/data" 
hdd_output=$(df -h | grep ${hdd_mount})
hdd=$(echo "${hdd_output}" | awk '{ print $3 " / " $2 }')
hdd_used_ratio=$(echo "${hdd_output}" | awk '{ print $5 }')
if [ "${hdd_used_ratio%?}" -ge 80 ]; then
  color_hdd=${color_red}
else
  color_hdd=${color_green}
fi

# get bitcoin sync
getblockchaininfo=$(bitcoin-cli getblockchaininfo)
block_chain="$(echo "${getblockchaininfo}" | jq -r '.headers')"
block_verified_btc="$(echo "${getblockchaininfo}" | jq -r '.blocks')"
block_diff_btc=$((block_chain - block_verified_btc))

if [ ${block_diff_btc} -eq 0 ]; then
  sync_btc="OK"
  color_sync_btc=${color_green}
elif [ ${block_diff_btc} -eq 1 ]; then
  sync_btc="-1"
  color_sync_btc=${color_yellow}
else
  sync_btc="-${block_diff_btc}"
  color_sync_btc=${color_red}
fi

# get bitcoin mem pool transactions
mempool="$(bitcoin-cli getmempoolinfo | jq -r '.size')"

# get bitcoin network info
networkinfo=$(bitcoin-cli getnetworkinfo)
conns="$(echo "${networkinfo}" | jq -r '.connections')"
if [ "${conns}" -le 8 ]; then
  color_conns=${color_red}
else
  color_conns=${color_green}
fi

warnings="$(echo "${networkinfo}" | jq -r '.warnings')"
if [ -z "${warnings}" ]; then
  warnings_text="No"
  color_warnings=${color_green}
else
  warnings_text="Yes"
  color_warnings=${color_red}
fi

# get electrumx info
electrumx_info=$(electrumx-rpc getinfo)
sessions=$(echo "${electrumx_info}" | jq -r '.sessions.count')
subs=$(echo "${electrumx_info}" | jq -r '.sessions.subs')
electrum_txs=$(echo "${electrumx_info}" | jq -r '."txs sent"')

# ignore rpc session
sessions=$((sessions - 1))

# get electrumx sync
block_verified_electrum=$(echo "${electrumx_info}" | jq -r '."db height"')
block_diff_electrum=$((block_chain - block_verified_electrum))

if [ ${block_diff_electrum} -eq 0 ]; then
  sync_electrum="OK"
  color_sync_electrum=${color_green}
elif [ ${block_diff_electrum} -eq 1 ]; then
  sync_electrum="-1"
  color_sync_electrum=${color_yellow}
else
  sync_electrum="-${block_diff_electrum}"
  color_sync_electrum=${color_red}
fi

# test bitcoin reachable
btc_public_test=$(nc -nz "${public_ip}" 8333; echo $?)
if [ "$btc_public_test" = "0" ]; then
  btc_public="Yes"
  color_public_btc="${color_green}"
else
  btc_public="No"
  color_public_btc="${color_red}"
fi

# test electrumx reachable
electrum_public_test=$(nc -nz "${public_ip}" 50002; echo $?)
if [ "$electrum_public_test" = "0" ]; then
  electrum_public="Yes"
  color_public_electrum="${color_green}"
else
  electrum_public="No"
  color_public_electrum="${color_red}"
fi

# check for package updates
official_update_count=$(checkupdates | wc -l)
aur_update_count=$(pikaur -Qua 2> /dev/null | wc -l)
if [ "$official_update_count" -gt 0 ] || [ "$aur_update_count" -gt 0 ]; then
  color_updates=$color_cyan
else
  color_updates=$color_gray
fi

# output
printf "${color_yellow}${machinename}${color_gray}: Status
${color_yellow}--------------------------------------------------------------
${color_gray}%-40s    ${color_gray}IP %15s
${color_gray}%-40s    ${color_gray}CPU Temp ${color_cpu}%10s
${color_gray}Memory ${color_ram}%11s    ${color_gray}SSD ${color_ssd}%14s    ${color_gray}HDD ${color_hdd}%14s

${color_yellow}%-24s%-24s
${color_gray}%-10s%b%8s    ${color_gray}%-10s%b%8s
${color_gray}%-10s%b%8s    ${color_gray}%-10s%b%8s
${color_gray}%-10s%b%8s    ${color_gray}%-10s%b%8s
${color_gray}%-10s%b%8s    ${color_gray}%-10s%b%8s
${color_gray}%-10s%b%8s    ${color_gray}%-10s%b%8s

${color_updates}${official_update_count}+${aur_update_count} updates available
${color_gray}
" \
"${uptime}" "${public_ip}" \
"${load}" "${temp}" \
"${ram}" "${ssd}" "${hdd}" \
"฿itcoin" "ElectrumX" \
"Public" "${color_public_btc}" "${btc_public}" \
"Public" "${color_public_electrum}" "${electrum_public}" \
"Sync" "${color_sync_btc}" "${sync_btc}" \
"Sync" "${color_sync_electrum}" "${sync_electrum}" \
"Warnings" "${color_warnings}" "${warnings_text}" \
"TXs" "" "${electrum_txs}" \
"Peers" "${color_conns}" "${conns}" \
"Sessions" "" "${sessions}" \
"Mempool" "" "${mempool}" \
"Subs" "" "${subs}" \
