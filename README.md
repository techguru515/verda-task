# Kubernetes security baseline

Hardened RKE2 cluster on three Verda Cloud VMs. Workloads arrive through Argo CD. Cilium default-deny, Pod Security Standards, and Kyverno block the paths that were tested. Trivy Operator reports vulnerabilities, and Prometheus is firing `CriticalVulnerabilityDetected`.

The Git remote is https://github.com/techguru515/verda-task.git. Argo CD tracks `main` there. The Kyverno CLI test from `.github/workflows/security.yml` was run on the control node: 7 passed, 0 failed (`evidence/kyverno-cli.txt`). On GitHub the policy test passes, the config scan passes, and the nginx image scan passes. The curl image scan fails on a fixed critical.

## What is running

| Piece | Where |
| --- | --- |
| Nodes | `k8s-control` 65.109.75.15, `k8s-worker-1` 65.109.75.39, `k8s-worker-2` 135.181.63.166 |
| Kubernetes | RKE2 v1.36.5+rke2r1, Cilium 1.20.2 with kube-proxy replacement and Hubble |
| Teams | `team-a` and `team-b`, Pod Security `restricted` |
| Scanner fixture | `vuln-demo`, Pod Security `privileged`, image `nginx:1.14.2` |
| GitOps | Argo CD, six Applications, all Synced and Healthy |
| Admission | Kyverno `disallow-latest-tag`, `restrict-image-registries` |
| Detection | Trivy Operator, Grafana dashboard `Image vulnerabilities` |
| Alert | `CriticalVulnerabilityDetected`, firing, `for: 1m` |

Versions are in `VERSIONS`. Command transcripts are in `evidence/`.

## Layout

- `bootstrap/` RKE2 and Cilium HelmChartConfig. The node token is not in git.
- `argocd/applications.yaml` the six Applications.
- `apps/team-a`, `apps/team-b` the demo client and web.
- `policies/network` Cilium default-deny and the narrow allows.
- `policies/kyverno` tag and registry rules.
- `policies/rbac` per-team read access, no secrets.
- `monitoring/` Prometheus values, the alert, Cilium scrape, Grafana dashboard.
- `trivy/values.yaml` one scan at a time, only the three app namespaces.
- `tests/` admission fixtures and the old nginx image.
- `.github/workflows/security.yml` policy test, config scan, image scan.
- `docs/` threat model, access, demo log, scale, CVE triage, one-page summary.

## Access

`docs/access.md`. Dashboards stay on ClusterIP. Use an SSH tunnel. The API port is listening on the host and is not in the public ufw allow list (`evidence/firewall.txt`).

## Still open

team-b web requires a client certificate on port 8443. Cilium's own mutual-auth feature is left off because GHSA-33qq-jq9c-6gcc is a bypass in that beta. Images pulled from the lab registry on port 30500 must be signed with the cosign key in `/root/cosign`; the private key is not in git. The public key is in `policies/kyverno/verify-signed-images.yaml`. The control plane is a single node. `ClusterPolicy` is deprecated in Kyverno 1.19 and still enforces. GitOps tracks https://github.com/techguru515/verda-task.git. The old git daemon on the control node is still installed and is no longer the Argo source. Scanning reports vulnerabilities and does not block them. The curl image job in CI fails the critical scan; triage is in `docs/cve-triage.md`. The nginx image job passes. Policy rollout is described in `docs/policy-lifecycle.md`.

## Cost

Three `CPU.4V.16G` VMs are about $0.21 per hour. Shut them down when you stop reviewing:

```text
verda vm shutdown 03dd1118-9d1c-46de-96b4-227de53a81f4
verda vm shutdown d7f18431-a8f6-49e3-8e27-aaf74beffee0
verda vm shutdown 4d0f2fe7-1c4a-48a9-a9b7-b45c303d4bad
```
