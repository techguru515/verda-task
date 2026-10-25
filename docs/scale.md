# Scale

This cluster is three 4-vCPU nodes and one etcd member. That is enough to show the controls. It is not a production topology.

What is pinned small on purpose: Kyverno, Argo CD, Prometheus, Alertmanager, and the Trivy operator are one replica. Prometheus retention is 6 hours with a 512Mi request and a 2Gi limit, on `k8s-worker-2`. Trivy runs one scan job at a time against three namespaces. A full-cluster parallel scan died with `cache may be in use by another process` on these 16 GB nodes.

What has to change before more teams or more nodes:

- Add control-plane members before losing `k8s-control` is an outage. etcd and the API sit there. An unused git daemon and HTTP server still listen on that node.
- GitOps already tracks https://github.com/techguru515/verda-task.git. The leftover daemon still listens on the control node, is reachable from the pod CIDR, and is closed to the internet by ufw.
- Give Kyverno three replicas before relying on it during a node drain. One replica is a single webhook path.
- Raise Trivy concurrency only with a separate disk for the vulnerability database. The failure was the shared DB lock.
- Generate ufw peer rules from the node list. A replaced VM gets a new public IP, and the mesh allow is written by hand today.
- Private node addresses would remove the public IP from etcd and the API. Verda’s CLI could not attach a private subnet on this account, so the guest firewall is the boundary.

Cilium is already in kube-proxy replacement mode, which is the shape you keep when the node count grows. This lab still runs `kube-proxy` on `k8s-worker-2`. The control node and worker-1 do not. Hubble metrics are scraped. The alert expression is a cluster-wide sum, so one noisy namespace pages everyone. Split it by namespace before a second team owns the pager.

## At 10 clusters and 500 nodes

This section is a design note. Nothing here was built.

Policy rollout. One Git repository stays the source. Each cluster is an Argo CD ApplicationSet entry, and the Kyverno and Cilium bundles sync from the same commit. CI runs `kyverno test` on the pull request. The merge lands on one canary cluster first. The other nine sync only after that Application is Healthy. A broken policy then stops at the canary instead of at all 500 nodes. The webhook failure policy stays Fail on the team namespaces, so a canary that cannot reach Kyverno rejects new pods rather than skipping the check.

Break-glass. A production bypass is a pull request that adds a Kyverno PolicyException, or a namespace label the policy match excludes, with an owner, a reason, and an expiry date in the same commit. The pipeline rejects an exception whose expiry is missing or already past. After the date, a scheduled job deletes the exception. There is no standing cluster-admin shortcut in this design. On this three-node lab the same idea is the exception note in `docs/policy-lifecycle.md`.

Cilium upgrades without dropping traffic. The agent is a DaemonSet. A minor upgrade rolls one node at a time, and existing connections survive a short agent restart when kube-proxy replacement is already on and the upgrade notes say the datapath is compatible. Do not run kube-proxy beside Cilium during that roll. Hubble stays up so a policy drop during the roll is visible. The control plane of each cluster needs three members before a node drain is safe. This lab has one member, so a Cilium upgrade here is a planned outage.

Fleet CVE patching. Trivy in each cluster exports the critical count with a `cluster` label. The page names the image and the namespace. The fix is a new image tag in Git, then Argo rolls the Deployment. Node CVEs are a new VM image or an RKE2 patch, drained one node at a time. CVE-2026-2270 is the pattern: the fixed release is 1.36.5, this lab is already on it, and a fleet would pin that version in the same repository that pins Cilium 1.20.2 and containerd 2.3.4. Leave containerd's experimental checkpoint restore disabled.
