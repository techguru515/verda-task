# Architecture

Three Ubuntu 24.04 VMs in Verda location FIN-01, plan `CPU.4V.16G`, legacy public networking. The public address is on `eth0`. There is no metadata service and the CLI could not attach a private subnet, so the host firewall is the network boundary.

RKE2 v1.36.5+rke2r1 runs on all three. `k8s-control` is control-plane and etcd. Workers take the workloads. Secrets encryption is on. kube-proxy is disabled; Cilium 1.20.2 runs with `kubeProxyReplacement` and Hubble. Pod CIDR `10.42.0.0/16`, service CIDR `10.43.0.0/16`. No kube-proxy pods are left.

ufw default-deny incoming. SSH is limited to the admin address. Node-to-node traffic and the pod and service CIDRs are allowed so the API, etcd, and VXLAN work. Kubernetes ports listen on the host and are absent from the public allow list.

Argo CD (one replica, Redis HA off) syncs six Applications from https://github.com/techguru515/verda-task.git: namespaces, network policies, Kyverno policies, RBAC, team-a, team-b. A git daemon still listens on 9418 on the control node, and an earlier dumb HTTP server on 8088 is still running. Argo does not use either of them. ufw keeps both off the internet.

`team-a` and `team-b` enforce Pod Security `restricted`. `vuln-demo` is `privileged` and is only the scanner fixture. It is outside the Kyverno namespace match and outside Argo.

Kyverno 1.19.2 enforces an explicit image tag, rejects `:latest`, and allow-lists `nginxinc/`, `docker.io/nginxinc/`, `curlimages/`, `docker.io/curlimages/`, and `ghcr.io/`. The chart is one replica. `ClusterPolicy` is deprecated in this version and the policies are Ready.

Each team has a ServiceAccount `app-reader` that can get pods, services, and configmaps in its own namespace. It cannot get secrets. `team-b` holds a dummy Secret `team-credential`.

Cilium default-deny covers `team-a`, `team-b`, and `vuln-demo`. Allows are DNS to CoreDNS, kubelet probes from the host and remote nodes, and in `team-b` only TCP 8080 from `app=client` to `app=web`. There is no cross-namespace allow and no general egress.

Trivy Operator scans `vuln-demo`, `team-a`, and `team-b` one job at a time. The first wave, before that limit, also wrote reports for platform namespaces. kube-prometheus-stack scrapes Trivy, Cilium, and Hubble. The rule `CriticalVulnerabilityDetected` is `sum(trivy_image_vulnerabilities{severity="Critical"}) > 0` for 1 minute. Grafana loads the dashboard ConfigMap labeled `grafana_dashboard=1`.

Demo images: `nginxinc/nginx-unprivileged:1.29.8-alpine` (uid 101, port 8080) and `curlimages/curl:8.16.0` (uid 100). The fixture is `docker.io/library/nginx:1.14.2`. The same web pod also listens on 8443 and requires a client certificate. The key pair is issued by `bootstrap/issue-mtls-certs.sh` into Secrets. The private keys stay on the control node. A registry Deployment in `image-registry` listens on NodePort 30500. Kyverno requires a cosign signature for images from that registry when the pod is created in `supply-chain`. The signing key stays in `/root/cosign` on the control node.
