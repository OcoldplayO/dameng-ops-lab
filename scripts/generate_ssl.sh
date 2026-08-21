#!/bin/bash
HOST_IP=$(hostname -I | awk '{print $1}')

echo "[INFO] 正在为泛域名 *.xinchuang.internal 与 IP 生成证书..."

# 1. 生成包含泛域名的扩展配置文件
cat << CONFIG_EOF > ssl/openssl.cnf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = CN
ST = Yunnan
L = Kunming
O = Xinchuang Lab
OU = SRE Department
CN = *.xinchuang.internal

[v3_req]
basicConstraints = CA:TRUE
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.xinchuang.internal
DNS.2 = xinchuang.internal
DNS.3 = localhost
IP.1 = ${HOST_IP}
IP.2 = 127.0.0.1
CONFIG_EOF

# 2. 重新签发 10 年期自签名证书
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout ssl/server.key \
  -out ssl/server.crt \
  -config ssl/openssl.cnf

rm -f ssl/openssl.cnf
chmod 600 ssl/server.key
echo "✅ [SUCCESS] 包含泛域名的 SSL 证书重新生成完毕！"
