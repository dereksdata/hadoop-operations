
##Gencerts (gencerts.sh)

###Usage 
gencerts.sh [OPTION]

Generate OpenSSH and Java keys and Jetty obscured password for the local host

  -a,--aliases <additional aliases to use, delimited>  e.g. fred.nerk.local
  
  -k,--key-validity <key validity in days>             default=$KEY_VALIDITY
  
  -p,--password <keystore password>                    default=$STOREPASS
  
  -d,--directory <directory to locate files>           default=$PKI_PATH
  
  -r,--root-cert-url <url to download private root ca cert> 

Example:

./gencerts.sh -a www.fred.nerk.local,admin.fred.nerk.local -p supersecret

###Notes
- Local host and IP combinations all auto-generated
- Private Root CA support
- Safe to repeatedly re-execute 
- Originals backed up to original where applicable

###Initial execution
- Generates OpenSSL key, Java keystore+cacerts 
- Generates OpenSSL and Java CSR files for all alises as Subject Alternate Names (SAN - or multiple DNS names and IPs for the same server)
- Generates Jetty obscured password for the keystore password

###Once certificate files (crt) are generated from CSRs and places into the pki directory
On the subsequent execution of the script
- Certificate files are copied into the keystore and OS certificate directories
