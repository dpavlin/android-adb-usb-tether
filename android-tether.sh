#!/bin/sh

# as described at
# http://www.forceclose.com/questions/2669/connect-android-to-internet-using-usb-tether-through-laptops-newtwork

sudo -p "cache root credentials with sudo" id > /dev/null

adb="adb"

devices=`adb devices | grep device$ | wc -l`

if [ $devices -gt 1 ] ; then
	SERIAL=`adb devices | grep device$ | grep -v emulator- | cut -d"	" -f1`
	echo "Using Android device with serial $SERIAL"
	adb="adb -s $SERIAL"
fi

if ! sudo ip link list usb0 ; then
	echo "ERROR: turn on tethering and restart script!"
	adb shell am start -a android.settings.SETTINGS
	exit 1
fi

android=`$adb shell ip addr list usb0 | grep 'inet ' | sed 's/^ *//g'`

if [ -z "$android" ] ; then
	echo "USB tethering interface not found"
	$adb shell ip link set tiwlan0 down
	$adb shell ip link set tiwlan0 name usb0 up
	$adb shell ip link
	$adb shell am start -a android.settings.SETTINGS
	exit
fi

a_ip=`echo $android | cut -d" " -f2 | cut -d/ -f1`
c_ip=`echo $a_ip | cut -d. -f-3`.1
netmask=`echo $android | cut -d" " -f4`

dev=`ip route | grep ^default | sed 's/.*dev //'`
echo "Android $a_ip netmask $netmask -> $c_ip $dev"

sudo ifconfig usb0 $c_ip netmask $netmask up
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo iptables -t nat -A POSTROUTING -s $a_ip -o $dev -j MASQUERADE

function setprop() {
	$adb shell setprop $1 $2
}

$adb shell ip link set usb0 down
$adb shell ip link set usb0 name tiwlan0 up
$adb shell ip route add default via $c_ip
setprop net.dns1 8.8.8.8
setprop dhcp.tiwlan0.ipaddress $a_ip
setprop dhcp.tiwlan0.gateway $c_ip
setprop dhcp.tiwlan0.server $c_ip
setprop dhcp.tiwlan0.dns1 8.8.8.8
setprop wlan.driver.status ok
setprop dhcp.tiwlan0.result ok
setprop dhcp.tiwlan0.reason BOUND

$adb shell ping -c 1 $c_ip
ping -c 1 $a_ip
