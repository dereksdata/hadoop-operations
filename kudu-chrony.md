Gotchas for chrony and kudu.

inside chrony.conf

    server <time server> maxdelay 0.3
    maxupdateskew 5
    logchange 0.5
    lock_all

You also need ntp installed even if you are not using it (like you're running chrony) as "ntptime" is used for the time testing

yum -y install ntp
