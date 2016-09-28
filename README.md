# hadoop-operations
Scripts to support Hadoop Operations such as Linux kernel configuration, PKI, etc.

**Gencerts (gencerts.sh)**
Notes
- Local host and IP combinations all auto-generated
- Private Root CA support
- Safe to repeatedly re-execute 
- Originals backed up to original where applicable

Initial execution
- Generates OpenSSL key, Java keystore+cacerts 
- Generates OpenSSL and Java CSR files for all alises as Subject Alternate Names (SAN - or multiple DNS names and IPs for the same server)
- Generates Jetty obscured password for the keystore password

Once certificate files (crt) are generated from CSRs and places into the pki directory
On the subsequent execution of the script
- Certificate files are copied into the keystore and OS certificate directories
