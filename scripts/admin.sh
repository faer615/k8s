#!/bin/bash
echo "制作admin用户证书"
cd /etc/kubernetes/ssl/
openssl pkcs12 -export -in admin.pem -inkey admin-key.pem -out /etc/kubernetes/web-cret.p12
cd /etc/kubernetes/
sz -y web-cret.p12
