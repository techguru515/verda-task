#!/bin/bash
# Issues the team-b mTLS material and stores it in Secrets.
# Private keys stay on the control node in /root/mtls. Do not commit that directory.
set -euo pipefail
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH="/usr/local/bin:/var/lib/rancher/rke2/bin:${PATH}"
umask 077
dir=/root/mtls
mkdir -p "${dir}"
cd "${dir}"
if [ ! -f ca.crt ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -keyout ca.key -out ca.crt -days 365 -subj "/CN=team-b-ca"
  openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr -subj "/CN=web.team-b.svc"
  printf 'subjectAltName=DNS:web.team-b.svc,DNS:web.team-b.svc.cluster.local\n' > server.ext
  openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extfile server.ext
  openssl req -newkey rsa:2048 -nodes -keyout client.key -out client.csr -subj "/CN=team-b-client"
  openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365
fi
kubectl -n team-b create secret generic web-tls \
  --from-file=tls.crt=server.crt \
  --from-file=tls.key=server.key \
  --from-file=ca.crt=ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n team-b create secret generic client-tls \
  --from-file=tls.crt=client.crt \
  --from-file=tls.key=client.key \
  --from-file=ca.crt=ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -
echo CERTS_APPLIED
