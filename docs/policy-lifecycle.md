# Policy lifecycle

Kyverno and Cilium policies live in this repository and reach the cluster only through Argo CD.

1. A change lands in `policies/kyverno` or `policies/network`.
2. `.github/workflows/security.yml` runs `kyverno test tests/kyverno` with CLI 1.19.2, the same version as the cluster. That job passed on the control node: 7 tests, 0 failures (`evidence/kyverno-cli.txt`).
3. The image job scans the two pinned images and exits 1 on a fixed critical. `curlimages/curl:8.16.0` is expected to fail that job until it is rebuilt on OpenSSL 3.5.6. The config job exits 1 on a critical misconfiguration outside `tests/vulnerable`.
4. After the checks, Argo CD applications `kyverno-policies` and `network-policies` sync `main` with prune and self-heal.

GitHub Actions has not executed, because this directory has no GitHub remote. The Kyverno half was run on the control node against the same files.

## Exceptions

An exception is a written decision, not a silent ignore.

To waive a Trivy critical finding, the pull request must add `exceptions/<CVE-ID>.md` with the owner, the reason the finding is not exploitable here, the fixed version, and a date the waiver ends. Only then may `.trivyignore` list that id, and the workflow comment must point at the file. A waiver with no expiry date does not merge.

CVE-2026-31789 is not waived. OpenSSL rates it Low and 32-bit only, and these nodes are amd64, but a fixed package exists. The image job stays red so the rebuild is visible. Details are in `docs/cve-triage.md`.

A Kyverno bypass, if one is ever required, is a separate manifest in Git with the same owner, reason, and expiry. This cluster has no bypass. Admission for `team-a` and `team-b` is enforce.
