#!/bin/sh
# Import NordVPN https://nordvpn.com/ configuration files to Network Manager (Ubuntu)
#
# Parameters: country number [tcp|udp]
#
# Examples:
#   norvpn-import.sh de 3 
#   norvpn-import.sh de 2 tcp

# OpenVPN configuration files location
path_ovpn="/etc/nordvpn/config"

# CA/TLS certificates location
path_cert="/etc/nordvpn/certs"

# NordVPN username
username="milosz@example.org"

# generate config
generate_config(){
  server="$1"
  protocol="$2"
  address="$3"
  crt_file="$4"
  key_file="$5"
  username="$6"

  if test "$protocol" = "tcp"; then
    line_tcp="proto-tcp=yes"
    line_port="port=443"
  else
    line_tcp=""
    line_port=""
  fi

# the ugly part
cat << EOF 
[connection]
id=NordVPN $(echo $server |  awk -v FS="." '{print toupper($1)}') [${protocol}]
uuid=$(uuidgen)
type=vpn
permissions=
secondaries=

[vpn]
ta-dir=1
connection-type=password
password-flags=1
tunnel-mtu=1500
cipher=AES-256-CBC
comp-lzo=yes
remote=${address}
reneg-seconds=0
${line_tcp}
${line_port}
mssfix=yes
dev-type=tun
username=${username}
remote-cert-tls=server
ca=${crt_file}
dev=tun
ta=${key_file}
service-type=org.freedesktop.NetworkManager.openvpn

[ipv4]
dns-search=
method=auto

[ipv6]
dns-search=
ip6-privacy=0
method=auto
EOF

}

# this shell script requires root privileges
if ! test "$(whoami)" = "root"; then
  echo "This shell script requires root privileges"
  exit 1
fi

# this shell script requires network-manager-openvpn-gnome package
if ! dpkg-query -s network-manager-openvpn-gnome 1>/dev/null 2>&-; then
  echo "Please install network-manager-openvpn-gnome package"
  exit 1
fi

# parse parameters
if test "$#" -ge 2; then
  country="$1"
  number="$2"
  
  if test "$#" -eq "3"; then
    case "$3" in
      "tcp") type="tcp443" ;;
      "udp") type="udp1194" ;;
      *)     type=".*"   ;;
    esac
  else
    type=".*"
  fi
else
  echo "Parameters: $0 country number [tcp|udp]"
  echo "Example:    $0 de 3"
  echo "            $0 de 4 tcp"
  exit 1
fi

# main loop
for configuration in $(find "${path_ovpn}/" -maxdepth 1 -regex ".*/\(${country}\)\(${number}\).nordvpn.com.\(${type}\).ovpn"); do
  server="$(basename $configuration | awk -v FS="." '{print $1".nordvpn.com"}')"
  protocol="$(basename $configuration | sed "s/.*\.nordvpn\.com\.\(.*\)\(443\|1194\)\.ovpn/\1/")"
  address="$(cat $configuration | sed -ne "s/remote \([.0-9]*\) \(443\|1194\)*/\1/p")"
  crt_file="$path_cert/$(echo $server | tr "." "_")_ca.crt"
  key_file="$path_cert/$(echo $server | tr "." "_")_tls.key"

  output_file="/etc/NetworkManager/system-connections/nordvpn-${server}-${protocol}"

  if ! test -f "$output_file"; then
    generate_config "$server" "$protocol" "$address" "$crt_file" "$key_file" "$username" | tee "$output_file" 1>/dev/null
    echo "Imported $server [$protocol]" 
    chmod 600 "$output_file"
  fi
done

# reload Network Manager
nmcli connection reload
