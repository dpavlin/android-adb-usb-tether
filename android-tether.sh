#!/bin/sh -x

# as described at
# http://www.forceclose.com/questions/2669/connect-android-to-internet-using-usb-tether-through-laptops-newtwork

sudo id

android=`adb shell ip addr list usb0 | grep 'inet ' | sed 's/^ *//g'`

a_ip=`echo $android | cut -d" " -f2 | cut -d/ -f1`
c_ip=`echo $a_ip | cut -d. -f-3`.1
netmask=`echo $android | cut -d" " -f4`

echo "Android $a_ip netmask $netmask -> $c_ip"

sudo ifconfig usb0 $c_ip netmask $netmask up
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo iptables -t nat -A POSTROUTING -s $a_ip -o br0 -j MASQUERADE

adb shell ip route add default via $c_ip
adb shell setprop net.dns1 8.8.8.8

adb shell ping -c 1 $c_ip
ping -c 1 $a_ip
