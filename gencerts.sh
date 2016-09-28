#!/bin/bash
#
# Automated cert generation script for Hadoop cluster and other PKI integrated hosts
#
# Version 1.1
# dereksdata.com
#
# Changelog 
#   1.0 Initial release 
#   1.1 Mod for subject alternate name 
#

echo "gencerts v1.1"

# Standard locations and host information
DOMAIN_NAME=$(dnsdomainname)
HOST_NAME=$(hostname)
IP_ADDRESSES=$(/sbin/ifconfig | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')

#Public default settings
KEY_VALIDITY=730
STOREPASS=changeit
PKI_PATH=/etc/pki/unified
ROOT_CA_DOWNLOAD_URL=
# example ROOT_CA_DOWNLOAD_URL=http://spacewalk.$DOMAIN_NAME/pub/root_ca.$DOMAIN_NAME.crt

# Java locations and information
JAVA_PATH=$(type -p java)
SYSTEM_JAVA_CACERTS=/usr/java/latest/jre/lib/security/cacerts
CACERTS=$PKI_PATH/cacerts
KEYSTORE=$PKI_PATH/keystore
JETTYOBS=$PKI_PATH/jettyobs

ShowHelp() {
    echo "Usage gencerts.sh [OPTION]"
    echo "Generate OpenSSH and Java keys and Jetty obscured password for the local host"
    echo
    echo "  -a,--aliases <additional aliases to use, delimited>  e.g. fred.nerk.local"
    echo "  -k,--key-validity <key validity in days>             default=$KEY_VALIDITY"
    echo "  -p,--password <keystore password>                    default=$STOREPASS"
    echo "  -d,--directory <directory to locate files>           default=$PKI_PATH"
    echo "  -r,--root-cert-url <url to download private root ca cert> "
    if [ ! -z "$ROOT_CA_DOWNLOAD_URL" ]; then    
        echo "     default=$ROOT_CA_DOWNLOAD_URL"
    fi
    echo "" 
    echo "Example:"
    echo "  ./gencerts.sh -a www.fred.nerk.local,admin.fred.nerk.local -p supersecret"
    echo ""
}

ImportCert() {
    if [ -f "$1" ] && [ -f "$2" ]; then
        alias_present=$(keytool -list -v -keystore $1 -storepass $STOREPASS | grep "Alias name: $3")
        if [ -z "$alias_present" ]; then 
            if [[ $1 == "$SYSTEM_JAVA_CACERTS" ]]; then
                echo "Backing up $1"
                cp -n $1 $1.original
            fi
            echo "Adding $2 to $1 as alias $3"
            keytool -import -trustcacerts -alias $3 -file $2 -keystore $1 -storepass $STOREPASS -noprompt
            ACTION=true
        fi
    fi
}

if [ "$1" == "--help" ] || [ "$1" == "-?" ]; then
    ShowHelp
    exit 0
fi

while [[ $# -gt 1 ]]
do
    key="$1"

    case $key in
        -k|--key-validity)
        KEY_VALIDITY="$2"
        if ! [[ $KEY_VALIDITY =~ '^[0-9]+$' ]] ; then
            echo "ERROR: Key validity period must be numeric ($KEY_VALIDITY)"
        fi
        shift # past argument
        ;;
        -p|--password)
        STOREPASS="$2"
        shift # past argument
        ;;
        -d|--directory)
        PKI_PATH="$2"
        if [ ! -d $PKI_PATH ]; then
            echo "ERROR: PKI directory $PKI_PATH does not exist"
        fi
        shift # past argument
        ;;
        -r|--root-cert-url)
        ROOT_CA_DOWNLOAD_URL="$2"
        shift # past argument
        ;;
        -a|--aliases)
        ALIASESDESC=$2
        ALIASES=$(echo $2 | tr "," "\n")
        shift # past argument
        ;;
        --default)
        DEFAULT=YES
        ;;
        *)
        # unknown option
        echo "Unknown option '$2'"
        WriteHelp
        ;;
    esac
    shift # past argument or value
done

echo
echo "Generating keys using"
echo "  Directory = $PKI_PATH"
echo "  Key validity period = $KEY_VALIDITY"
if [ ! -z $ROOT_CA_DOWNLOAD_URL ]; then
    echo "  Root CA Certificate URL = $ROOT_CA_DOWNLOAD_URL"
fi
echo "  Aliases = $ALIASESDESC"

# Get the local executable path
pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd -P`
popd > /dev/null

# Check for a local Jetty jar
# Download from here https://mvnrepository.com/artifact/org.eclipse.jetty/jetty-util
JETTY_UTIL=$(ls $SCRIPTPATH/jetty-util-*.jar 2> /dev/null | sort -n | head -1)
if [ ! -z "$JETTY_UTIL" ] && [ -f $JETTY_UTIL ]; then
    echo "  Jetty util = $JETTY_UTIL"
fi
echo

# Java test
if [ ! -z "$JAVA_PATH" ] > /dev/null; then
    if [ ! -f $SYSTEM_JAVA_CACERTS ]; then
        echo "System Java cacerts cannot be found at $SYSTEM_JAVA_CACERTS"
    fi
else
    echo "Java has not been installed, Java cacerts and keystore will not be generated"
fi

# Create the path and test for Java
mkdir -p $PKI_PATH

# Get the root CA cert 
root_ca_cert=$PKI_PATH/root_ca.$DOMAIN_NAME.crt
if [ ! -z $ROOT_CA_DOWNLOAD_URL ] && [ ! -f $root_ca_cert ]; then
    echo "Fetching the private root CA certificate file"
    wget -O $root_ca_cert $ROOT_CA_DOWNLOAD_URL  > /dev/null 2>&1
fi

# Create the Java cacerts and keystore files as well as Jetty obfuscated passwords
if [ ! -z "$JAVA_PATH" ]; then
    if [ ! -f $KEYSTORE ]; then
        echo "Creating empty java keystore"
        keytool -genkey -alias temp -keystore $KEYSTORE --storepass $STOREPASS -keypass $STOREPASS -noprompt -dname "CN=temp"
        keytool -delete -alias temp -keystore $KEYSTORE --storepass $STOREPASS -keypass $STOREPASS -noprompt
        ACTION=true
    fi 
    if [ -f $SYSTEM_JAVA_CACERT ]; then
        echo "Copying default Java cacerts"
        cp $SYSTEM_JAVA_CACERTS $CACERTS
    fi
    
    echo "Adding private root CA to system-wide $SYSTEM_JAVA_CACERTS"
    ImportCert $SYSTEM_JAVA_CACERTS $root_ca_cert $DOMAIN_NAME
    
    echo "Importing CA root certificate into $PKI_PATH/cacerts"
    ImportCert $CACERTS $root_ca_cert $DOMAIN_NAME
    
    echo "Importing CA root certificate into $PKI_PATH/keystore"
    ImportCert $KEYSTORE $root_ca_cert $DOMAIN_NAME
            
    if [ -f $JETTY_UTIL ]; then
        if [ ! -f $JETTYOBS ]; then
            echo "Generating Jetty obscured password to $JETTYOBS"
            java -cp $JETTY_UTIL org.eclipse.jetty.util.security.Password $STOREPASS >  $JETTYOBS 2>&1 
            ACTION=true
        fi         
    fi     
fi

# Generate Subject Alternate Names
SAN_OPENSSL="DNS.1:localhost"
SAN_JAVA="dns:localhost,ip:127.0.0.1"
count=1
for ipaddress in $IP_ADDRESSES
do
    SAN_JAVA="$SAN_JAVA,ip:$ipaddress"
    SAN_OPENSSL="$SAN_OPENSSL,IP.$count:$ipaddress"
    count=$((count+1))
done
count=2
for alias in $ALIASES
do
    SAN_JAVA="$SAN_JAVA,dns:$alias"
    SAN_OPENSSL="$SAN_OPENSSL,DNS.$count:$alias"
    count=$((count+1))
done

# Generate the openssl key and csr
if [ ! -f $PKI_PATH/$HOST_NAME.openssl.key ] || [ ! -f $PKI_PATH/$HOST_NAME.openssl.csr ]; then
    echo "Generating OpenSSL CSR $HOST_NAME.openssl.csr"
    echo "Aliases CN=$HOST_NAME SAN=$SAN_OPENSSL"
    openssl req -new -newkey rsa:2048 -days $KEY_VALIDITY -nodes -keyout $PKI_PATH/$HOST_NAME.openssl.key -out $PKI_PATH/$HOST_NAME.openssl.csr -subj "/CN=$HOST_NAME" -config \
        <(printf "[req]\ndistinguished_name = req_distinguished_name\nreq_extensions = v3_req\nprompt = no\n[req_distinguished_name]\nCN = $HOST_NAME\n[v3_req]\nkeyUsage = keyEncipherment, dataEncipherment\nextendedKeyUsage = serverAuth\nsubjectAltName = $SAN_OPENSSL") \
          > /dev/null 2>&1
    ACTION=true
fi        

# Add to the local openssl certs
if [ -f $PKI_PATH/$HOST_NAME.openssl.crt ]; then            
    mkdir -p /etc/pki/tls/certs
    cp $PKI_PATH/$HOST_NAME.openssl.crt /etc/pki/tls/certs
    cp $PKI_PATH/$HOST_NAME.openssl.key /etc/pki/tls/certs
fi

# Create the csr or import the certificate if the alias is not already present
if [ -f $SYSTEM_JAVA_CACERTS ]; then
    if [ -f $KEYSTORE ]; then
        alias_present=$(keytool -list -v -keystore $KEYSTORE -storepass $STOREPASS | grep "Alias name: $HOST_NAME")
        if [ ! -z "$alias_present" ]; then 
            if [ -f $PKI_PATH/$HOST_NAME.java.crt ]; then
                echo "Importing certificate $HOST_NAME.java.crt into Java keystore $KEYSTORE"
                #echo "keytool -importcert -file $PKI_PATH/$HOST_NAME.java.crt -keystore $KEYSTORE -alias "$HOST_NAME" -storepass $STOREPASS -keypass $STOREPASS -noprompt"
                keytool -importcert -file $PKI_PATH/$HOST_NAME.java.crt -keystore $KEYSTORE -alias "$HOST_NAME" -storepass $STOREPASS -keypass $STOREPASS -noprompt
                ACTION=true
            fi
        else                
            if [ ! -f $PKI_PATH/$HOST_NAME.java.csr ]; then
                echo "Generating Java CSR $HOST_NAME.java.csr"
                echo "Aliases CN=$HOST_NAME,$SAN_JAVA"
                #echo "keytool -genkeypair -keyalg RSA -keysize 2048 -validity $KEY_VALIDITY -alias $HOST_NAME -keystore $KEYSTORE -storepass $STOREPASS -keypass $STOREPASS -noprompt -dname \"CN=$HOST_NAME\" -ext san=$SAN_JAVA"
                keytool -genkeypair -keyalg RSA -keysize 2048 -validity $KEY_VALIDITY -alias $HOST_NAME -keystore $KEYSTORE -storepass $STOREPASS -keypass $STOREPASS -noprompt -dname "CN=$HOST_NAME" -ext san=$SAN_JAVA
                #echo "keytool -certreq -keyalg -RSA -alias $HOST_NAME -keystore $KEYSTORE -file $PKI_PATH/$HOST_NAME.java.csr -storepass $STOREPASS -keypass $STOREPASS -noprompt -ext san=$SAN_JAVA"
                keytool -certreq -keyalg -RSA -alias $HOST_NAME -keystore $KEYSTORE -file $PKI_PATH/$HOST_NAME.java.csr -storepass $STOREPASS -keypass $STOREPASS -noprompt -ext san=$SAN_JAVA
                ACTION=true
            fi
        fi
    fi     
fi

if [ -z "$ACTION" ]; then
    echo
    echo "Nothing to do: Certs have already been generated"
    echo "Do you need to generate a certificate (crt) from the csr file with your CA?"
    echo
else
    echo "Contents of $PKI_PATH"
    echo
    ls -1 $PKI_PATH
fi
