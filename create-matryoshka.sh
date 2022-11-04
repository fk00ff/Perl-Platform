#!/bin/bash
nmcli con add type bond ifname mb0
 nmcli con add type ethernet ifname enp7s0 master mb0
 nmcli con add type ethernet ifname wlp0s20f3 master mb0
 nmcli con add type vlan con-name mb0.103 ifname mb0.103 dev mb0 id 103 ip4 {10.10.103.1}/24
 nmcli con add type brudge ...
 nmcli con add type ethernet ifname -- master mb0
 nmcli con add type vlan con-name sb0.104 ifname sb0.104 dev sb0 id 104 ip4 {10.10.104.1}/24
 systemctl restart NetworkManager.service

