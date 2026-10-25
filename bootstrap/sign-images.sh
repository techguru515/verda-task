#!/bin/bash
# Signs one image in the lab registry and installs the Kyverno check.
# The private key and its password stay in /root/cosign. Do not commit them.
set -euo pipefail
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH="/usr/local/bin:/var/lib/rancher/rke2/bin:${PATH}"
umask 077
reg=65.109.75.15:30500

if ! command -v cosign >/dev/null 2>&1; then
  curl -fsSL -o /usr/local/bin/cosign https://github.com/sigstore/cosign/releases/download/v2.5.3/cosign-linux-amd64 \
    || curl -fsSL -o /usr/local/bin/cosign https://github.com/sigstore/cosign/releases/download/v2.4.3/cosign-linux-amd64
  chmod 755 /usr/local/bin/cosign
fi
if ! command -v crane >/dev/null 2>&1; then
  curl -fsSL -o /tmp/crane.tgz https://github.com/google/go-containerregistry/releases/download/v0.20.6/go-containerregistry_Linux_x86_64.tar.gz \
    || curl -fsSL -o /tmp/crane.tgz https://github.com/google/go-containerregistry/releases/download/v0.20.3/go-containerregistry_Linux_x86_64.tar.gz
  tar -C /usr/local/bin -xzf /tmp/crane.tgz crane
  chmod 755 /usr/local/bin/crane
fi

kubectl apply -f /root/assignment/bootstrap/namespaces.yaml
kubectl apply -f /root/assignment/bootstrap/image-registry.yaml
kubectl rollout status deploy/registry -n image-registry --timeout=180s

crane copy --insecure nginxinc/nginx-unprivileged:1.29.8-alpine "${reg}/nginx-unprivileged:signed"
crane copy --insecure curlimages/curl:8.16.0 "${reg}/curl:unsigned"

mkdir -p /root/cosign
if [ ! -f /root/cosign/cosign.key ]; then
  openssl rand -base64 24 > /root/cosign/password
  COSIGN_PASSWORD="$(cat /root/cosign/password)" cosign generate-key-pair --output-key-prefix /root/cosign/cosign
fi
export COSIGN_PASSWORD
COSIGN_PASSWORD="$(cat /root/cosign/password)"
cosign sign --yes --tlog-upload=false --allow-http-registry --key /root/cosign/cosign.key "${reg}/nginx-unprivileged:signed"

python3 - <<'PY'
import json, subprocess
dep = json.loads(subprocess.check_output([
    "kubectl", "get", "deploy", "kyverno-admission-controller", "-n", "kyverno", "-o", "json"
]))
container = dep["spec"]["template"]["spec"]["containers"][0]
args = [a.replace("--allowInsecureRegistry=false", "--allowInsecureRegistry=true") for a in container["args"]]
patch = [{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": args}]
open("/tmp/kyverno-args.json", "w").write(json.dumps(patch))
PY
kubectl patch deploy kyverno-admission-controller -n kyverno --type json --patch-file /tmp/kyverno-args.json
kubectl rollout status deploy/kyverno-admission-controller -n kyverno --timeout=180s

pubkey="$(cat /root/cosign/cosign.pub)"
cat > /root/assignment/policies/kyverno/verify-signed-images.yaml <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-signed-images
  annotations:
    policies.kyverno.io/title: Verify signed lab images
    policies.kyverno.io/severity: high
spec:
  background: false
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
              namespaces:
                - supply-chain
      verifyImages:
        - failureAction: Enforce
          imageReferences:
            - "65.109.75.15:30500/*"
          mutateDigest: true
          required: true
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: |-
$(printf '%s\n' "${pubkey}" | sed 's/^/                      /')
                    rekor:
                      ignoreTlog: true
EOF

kubectl apply -f /root/assignment/policies/kyverno/verify-signed-images.yaml
echo POLICY_READY
echo "===== PUBLIC KEY ====="
cat /root/cosign/cosign.pub
echo "===== END PUBLIC KEY ====="
