# Threat model

Scope is this three-node cluster and the two demo namespaces. The attacker is someone on the internet, a workload in the other team, or a developer pushing a bad manifest.

## Assets

The Kubernetes API, etcd, node SSH, the team-b web service, the dummy team secret, and the images that are allowed to run.

## What we treat as in scope

- Internet access to the API, kubelet, or etcd.
- A pod in `team-a` calling `team-b` or the public internet.
- A `team-a` identity reading `team-b` secrets.
- A privileged pod, a `:latest` tag, a missing tag, or a registry outside the allow list in a team namespace.
- A known-vulnerable image running where the scanner can see it, and an alert when the critical count is above zero.

## Controls and what they actually stop

| Threat | Control | Evidence |
| --- | --- | --- |
| Internet to the API | ufw default deny; 6443 is not in the public allow list | `evidence/firewall.txt` |
| Cross-namespace HTTP | Cilium default-deny | Hubble `Policy denied DROPPED`, curl exit 28 |
| Egress to 1.1.1.1 | Same default-deny, no world egress allow | Hubble drop to `world` |
| In-namespace app traffic | Explicit TCP 8080 allow | HTTP 200 from the team-b client |
| Cross-team secret read | RBAC Role without secrets | `Forbidden` as `team-a:app-reader` |
| `:latest`, untagged image, other registry | Kyverno enforce | webhook `validate.kyverno.svc-fail` |
| Privileged pod | Pod Security `restricted` | API `Forbidden` before the workload exists |
| Vulnerable image already running | Trivy plus Prometheus | 31 criticals on nginx 1.14.2; alert firing |
| Bad manifest in git | `kyverno test` in CI | 7/7 on CLI 1.19.2 |
| Critical CVE in an allowed image | Trivy image job, fail on CRITICAL, ignore unfixed | curl image has a fixed critical; the job is written to fail |
| Caller without a team-b client certificate | nginx `ssl_verify_client on` on port 8443 | HTTP 400 without the certificate, HTTP 200 with it |

## Residual risk

A single control plane and a single etcd member. Namespace isolation is not a separate cluster. The git daemon and the unused HTTP server listen on the control node; ufw is what keeps them off the internet. Kyverno does not verify signatures. Port 8443 checks the team-b client certificate. Port 8080 is still open to any pod the network policy allows, so the cleartext listener does not prove identity. Cilium mutual authentication is off. Trivy reports and the alert fires; neither deletes the pod. The critical count includes CVE-2026-31789, which OpenSSL rates Low and which applies to 32-bit platforms. The nodes are amd64, so the firing alert is wider than the exploitable set. Admission will still accept `curlimages/curl:8.16.0` because the registry is allow-listed. The prevent gate for that CVE is the image job in CI, which has not run on GitHub.
