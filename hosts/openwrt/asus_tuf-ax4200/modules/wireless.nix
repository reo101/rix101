# Wireless: radios + interfaces, derived entirely from secrets
# (radio hardware params and SSIDs/keys live there).
{ lib, openwrt, secrets }:

openwrt.wirelessPrimaryLines secrets.wirelessNetworks
++ openwrt.wirelessExtraIfaceLines secrets.wirelessExtraIfaces
++ [ "" ]