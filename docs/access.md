# Access

SSH user is `root`, key only. The private key stays on your machine (`C:\Users\j\.ssh\id_ed25519`). Password authentication is off.

```text
ssh -i C:\Users\j\.ssh\id_ed25519 root@65.109.75.15
```

On the control node:

```text
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH="/usr/local/bin:/var/lib/rancher/rke2/bin:$PATH"
```

ufw allows TCP/22 only from `31.13.241.15`. If your home address changes, SSH stops until that rule is updated on each node. The same host firewall allows all traffic from the three node public IPs and from `10.42.0.0/16` and `10.43.0.0/16`, so the cluster can mesh. It does not allow the internet to reach 6443, 9345, or the git daemon.

| Node | Public IP | Verda id |
| --- | --- | --- |
| k8s-control | 65.109.75.15 | 03dd1118-9d1c-46de-96b4-227de53a81f4 |
| k8s-worker-1 | 65.109.75.39 | d7f18431-a8f6-49e3-8e27-aaf74beffee0 |
| k8s-worker-2 | 135.181.63.166 | 4d0f2fe7-1c4a-48a9-a9b7-b45c303d4bad |

## Argo CD

On the control node, forward the ClusterIP service to localhost, then tunnel that port from your laptop.

```text
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

```text
ssh -i C:\Users\j\.ssh\id_ed25519 -L 8080:127.0.0.1:8080 root@65.109.75.15
```

Open `https://127.0.0.1:8080`. User `admin`. The password is the `password` key in secret `argocd-initial-admin-secret` in namespace `argocd`. Do not commit it.

## Grafana

Grafana 13.2.4 answered `GET /api/health` from inside the cluster (`database: ok`). The dashboard `Image vulnerabilities` is registered (`uid` `trivy-image-vulns`). The UI was not clicked; there is no browser on this machine.

```text
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

```text
ssh -i C:\Users\j\.ssh\id_ed25519 -L 3000:127.0.0.1:3000 root@65.109.75.15
```

Open `http://127.0.0.1:3000`. User `admin`. Read the password from secret `monitoring-grafana` in namespace `monitoring`, key `admin-password`. Do not commit it.

Prometheus is `monitoring-kube-prometheus-prometheus` at `10.43.127.27:9090`, ClusterIP only.
