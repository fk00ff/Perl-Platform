#!/bin/bash
nmcli con add type bond ifname mb0 bond.options "mode=802.3ad" ipv4.method=disabled ipv6.method=ignore
 nmcli con add type ethernet slave-type bond ifname ens192 master mb0 ipv4.method=disabled ipv6.method=ignore
 nmcli con add type bridge ifname br-mb0.102 ipv4.method=manual ipv6.method=ignore ipv4.addresses=10.190.174.195 
 nmcli con add type vlan con-name mb0.102 ifname mb0.102 dev mb0 id 102 ipv4.method=disabled ipv6.method=ignore
 
 nmcli con add type ethernet ifname ens192 master mb0
 nmcli con add type vlan con-name sb0.103 ifname sb0.103 dev sb0 id 103 ip4 10.190.174.196/24 gw4 10.190.174.196
 
 systemctl restart NetworkManager.service

