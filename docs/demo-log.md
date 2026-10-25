# Demo log

Same commands as the security tests. Times are UTC on 2026-10-25. Transcripts are in `evidence/`.

## Network

From the team-b client, `curl http://web.team-b.svc.cluster.local:8080` returned `HTTP/1.1 200` and `Server: nginx/1.29.8`, exit 0.

From the team-a client, the same URL timed out, exit 28. Hubble on `cilium-fn9bs` (worker-1) recorded `team-a/client-587485fbf8-llpqz` to `team-b/web-7cffb889d8-2nvgp:8080` as `Policy denied DROPPED` on TCP SYN.

From the team-a client, `https://1.1.1.1/` timed out, exit 28. Hubble recorded that flow to `1.1.1.1:443 (world)` as `Policy denied DROPPED`.

## RBAC

`kubectl auth can-i get secrets -n team-b --as=system:serviceaccount:team-a:app-reader` printed `no`. Getting `team-credential` returned `Forbidden`. The same account `can-i get pods` in `team-a` printed `yes`. The check is `kubectl --as`. The client pods cannot reach the API because egress is default-deny.

## Admission

`kubectl apply` of `tests/kyverno/resources/pods.yaml` exited 1.

- `bad-latest` denied by Kyverno `reject-latest-tag`.
- `omitted-tag` denied by Kyverno `require-image-tag`.
- `bad-registry` (`docker.io/library/busybox:1.36.1`) denied by `validate-registries`.
- `privileged-pod` denied by Pod Security `restricted:latest` (privileged, allowPrivilegeEscalation, capabilities, runAsNonRoot, seccomp).
- `good-web` was created, then deleted.

`kyverno test tests/kyverno` with CLI 1.19.2 reported 7 passed and 0 failed. The CLI prints Pass when the expected result matches, including rules that are expected to fail.

## Scanner and alert

`vulnerabilityreports` in `vuln-demo` for `library/nginx:1.14.2`: 31 critical, 82 high, 54 medium, 42 low, 7 unknown.

`team-b` web image: 0 critical. `team-b` curl image: 2 critical, both CVE-2026-31789, fixed in OpenSSL 3.5.6-r0.

Prometheus query `sum(trivy_image_vulnerabilities{severity="Critical"})` returned 35. Rule `CriticalVulnerabilityDetected` was `firing` since 16:53:02Z, `for` 60 seconds, health ok. The `for` window is 1 minute so the demo can fire in one session; the guide suggested 5 minutes.

Grafana `GET /api/health` returned version 13.2.4 and `database: ok`. Dashboard search returned `Image vulnerabilities`.

## GitOps

`evidence/argocd.txt` is the 16:59Z capture against the control-node git daemon at `b989c57d4369df2ab0ed1f59318d20b5f7e57ff1`. That daemon is no longer the source. Argo CD tracks https://github.com/techguru515/verda-task.git on `main`. At 18:35Z all six Applications were Synced and Healthy at `e55ef92a74dddedcb6bd16e1b3ed5de1c8d19741` (`evidence/argocd-github.txt`). A later check the same evening showed the same six Synced and Healthy at `6f1afd2`. Argo tracks the whole `main` commit, so a docs-only push moves that revision again. Deployment `web` label `assignment.example/gitops` is `demonstrated`.

## mTLS

The team-b web pod listens on 8080 in cleartext and on 8443 with a server certificate and `ssl_verify_client on`. The client certificate is mounted from Secret `client-tls`. Private keys are not in git.

`curl https://web.team-b.svc.cluster.local:8443/` with the client certificate returned HTTP 200. The same URL with only the CA returned HTTP 400. Plain HTTP on 8080 still returns 200, so the earlier network-policy proof is unchanged. Cilium mutual authentication is not enabled. Cilium GHSA-33qq-jq9c-6gcc is a certificate-substitution bypass in that beta feature, and 1.20.2 is outside the affected ranges.

## Image signing

`cosign sign --tlog-upload=false --allow-http-registry` signed `nginx-unprivileged@sha256:0c79d56aee561a1d81c63f00eee5fb5fe29279560cdc55e91425133104c7fbe6` in the registry on port 30500. Kyverno policy `verify-signed-images` matches that registry in namespace `supply-chain`.

`pod/signed-web` was created and became Ready. `unsigned-curl`, the same curl image with no signature, was denied by `mutate.kyverno.svc-fail`: `no signatures found`.

## Host firewall

On the control node, 6443, 9345, 9418, and 8088 listen on all interfaces. ufw allows SSH only from `31.13.241.15`, plus the three node addresses and the pod and service CIDRs. 6443 is not an allow rule for the internet.
