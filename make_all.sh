#!/bin/bash



for I in iproute2 usbutils ntp ntpdate gpsd gpsd-clients 
do
        if  test  "`dpkg -l | grep \" $I \"`" = ""
        then
                echo "Installing $I..."
                apt-get update
                apt-get --assume-yes  --quiet  install $I 
        fi
done



if test `lsusb  | grep -i U-Blox` = ""
then
        echo "Cannot find USB GPS dongle. Stop here..."
        exit 1
fi



F=/etc/default/gpsd
if test -e $F
then
        cp $F ${F}_`date +'%s'`

        cat > $F <<_EOF_
START_DAEMON="true"
USBAUTO="true"
DEVICES="/dev/ttyACM0"
GPSD_OPTIONS="-n"
_EOF_

fi


IPV=`ip a | grep "inet "`
IPV6=`ip a | grep "inet6 "`


F=/etc/ntp.conf
if test -e $F
then
        cp $F ${F}_`date +'%s'`

        cat > $F <<_EOF_
driftfile /var/lib/ntp/ntp.drift
logfile     /var/log/ntp.log

leapfile /usr/share/zoneinfo/leap-seconds.list

statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

#pool 0.de.pool.ntp.org iburst minpoll 5 maxpoll 5
#pool 1.de.pool.ntp.org iburst minpoll 5 maxpoll 5
#pool 2.de.pool.ntp.org iburst minpoll 5 maxpoll 5
#pool 3.de.pool.ntp.org iburst minpoll 5 maxpoll 5

#pool de.pool.ntp.org iburst minpoll 10 maxpoll 10

restrict source notrap nomodify noquery

restrict -4             default                 kod notrap nomodify nopeer noquery notrust
restrict -6             default                 kod notrap nomodify nopeer noquery notrust

restrict 10.0.0.0       mask 255.0.0.0          nomodify noquery
restrict 172.16.0.0     mask 255.240.0.0        nomodify noquery
restrict 169.254.0.0    mask 255.255.0.0        nomodify noquery
restrict 192.168.0.0    mask 255.255.0.0        nomodify noquery
restrict 127.0.0.0      mask 255.0.0.0          nomodify noquery
restrict 192.0.2.0      mask 255.255.255.0      ignore
restrict 192.0.0.0      mask 255.255.255.248    ignore
restrict 240.0.0.0      mask 240.0.0.0          ignore
restrict 0.0.0.0        mask 255.0.0.0          ignore

restrict 127.0.0.1
restrict ::1

broadcast       192.168.0.255   autokey ttl 3
broadcast       224.0.1.1       autokey ttl 3
broadcast       169.254.255.255 autokey ttl 3
multicastclient 224.0.1.1

disable         auth
enable          bclient
manycastclient  224.0.1.1
manycastserver  224.0.1.1

#see http://doc.ntp.org/4.2.6/refclock.html

server 127.127.28.0 minpoll 4 maxpoll 4 prefer
fudge 127.127.28.0 time1 0.07 refid GPS

server 127.127.1.0 minpoll 4 maxpoll 4
fudge  127.127.1.0 stratum 12


_EOF_

        echo "Check $F for network restriction. This config file has 192.168.0.0/16 set"
else
        echo "Error: Cannot find $F. You need to set your values manually"

fi


F=/etc/systemd/system/sockets.target.wants/gpsd.socket
if test -e $F
then
        cp $F ${F}_`date +'%s'`

        cat > $F <<_EOF_
[Unit]
Description=GPS (Global Positioning System) Daemon Sockets

[Install]
WantedBy=sockets.target

[Socket]
ListenStream=/var/run/gpsd.sock
SocketMode=0600
_EOF_

        if ! test "`echo $IPV`" = ""
        then
                echo "ListenStream=127.0.0.1:2947" >> $F
        fi

        if ! test "`echo $IPV6`" = ""
        then
                echo "ListenStream=[::1]:2947" >> $F
        fi
fi


F=/usr/share/zoneinfo/leap-seconds.list
if test -e $F
then
        T=`date +'%s'`
        cp -f $F ${F}_$T

        echo "Leap second list download"

        wget https://hpiers.obspm.fr/iers/bul/bulc/ntp/leap-seconds.list -O ${F}_new

        if ! test -e ${F}_new
        then
                cp ${F}_new  $F
        fi

        echo "Keep in mind to renew this list (/usr/share/zoneinfo/leap-seconds.list) every year..."
fi

service gpsd restart
service ntp restart

service gpsd status
service ntp status


ntpd -q

#tail -n 30 /var/log/ntp.log

timedatectl status

ntpq -c rl


# cgps

echo "Press crtl-C to stop..."

echo
echo "try watch ntpq -p "
echo



# gpds need option -n to start....

