#!/bin/bash
nmcli con add type bond ifname mb0
 nmcli con add type ethernet ifname ens192 master mb0
 nmcli con add type ethernet ifname docker0 master mb0
 nmcli con add type vlan id=103
 nmcli con add type brudge ...
 nmcli con add type ethernet ifname ens192 master mb0
 nmcli con add type vlan id=104

