set -euo pipefail
umask 077

# create the root ca
cat > root.cnf <<'EOF'
\[ req ]
default\_bits        = 4096
prompt              = no
default\_md          = sha256
x509\_extensions     = v3\_ca
distinguished\_name  = dn
\[ dn ]
C  = IM
ST = Douglas
L  = Douglas
O  = MobileANPR
CN = MobileANPR Root CA
\[ v3\_ca ]
basicConstraints       = critical,CA\:TRUE
keyUsage               = critical,keyCertSign,cRLSign
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid\:always,issuer
EOF

openssl req -config root.cnf -new -x509 -days 1825&#x20;
-keyout MobileANPRRootCA.key -out MobileANPRRootCA.crt

# key + CSR
cat > server.cnf <<'EOF'
\[ req ]
default\_bits        = 2048
prompt              = no
default\_md          = sha256
req\_extensions      = v3\_req
distinguished\_name  = dn
\[ dn ]
C  = IM
ST = Douglas
L  = Douglas
O  = MobileANPR
CN = mobileanpr.local
\[ v3\_req ]
basicConstraints = CA\:FALSE
keyUsage         = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName   = @alt\_names
\[ alt\_names ]
DNS.1 = mobileanpr.local
EOF

openssl genrsa -out MobileANPR.local.key 2048
openssl req -config server.cnf -new -key MobileANPR.local.key&#x20;
-out MobileANPR.local.csr

openssl x509 -req -in MobileANPR.local.csr&#x20;
-CA MobileANPRRootCA.crt -CAkey MobileANPRRootCA.key -CAcreateserial&#x20;
-out MobileANPR.local.crt -days 398 -sha256&#x20;
-extfile server.cnf -extensions v3\_req

# build full-chain
cat MobileANPR.local.crt MobileANPRRootCA.crt > MobileANPR.local.fullchain.crt
