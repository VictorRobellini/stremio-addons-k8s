# Homelab - MetalLB & Stremio Addons

Homelab setup running K3s for Kubernetes, MetalLB for L2 Loadbalancers, and more.

# Homelab Setup
[k3s](https://k3s.io/)

[MetalLB](https://metallb.io/)

[pfSense](https://www.netgate.com/)

External: .mydomain.foo

 - DNS Managed by he.net 

Internal: .home.mydomain.foo

 - DNS Managed by pfSense

Internal K3s: .default.k8s.home.mydomain.foo

 - DNS Managed by CoreDNS
 - Local DNS queries sent to pfSense DNS resolver and forwarded to CoreDNS
 - Added as extra search domain in pfSense DHCP

With the above stack, all deployments/services are registered with DNS and can be accessed by name within my network. pfSense Acem/LetsEncrypt manages SSL certificates and pfSense HAProxy manages inbound HTTPS termination.

With this setup I can access all of my Kubernetes Deployments/Services by name on my local network and externally with valid SSL certs.


## K3s
My K3s Deployment. You will want to make sure the `--flannel-iface=` matches your system.

    curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-iface=enp1s0 --cluster-cidr=172.16.0.0/16 --service-cidr=172.17.0.0/16 --cluster-dns=172.17.0.10 --disable traefik --disable servicelb --disable metrics-server —disable-cloud-controller" sh -
## CoreDNS
```
helm repo add coredns https://coredns.github.io/helm
helm --namespace=kube-system install coredns coredns/coredns --set service.clusterIP="172.17.0.10"
```

## MetalLB
metallb-0.15.2

I switched to the helm deployment. Config options and CRs change for major releases so be sure to check the [install docs](https://metallb.io/installation/) and [release notes](https://metallb.io/release-notes/).  

```
helm repo add metallb https://metallb.github.io/metallb
kubectl create ns metallb-system
helm install metallb metallb/metallb -n metallb-system
```

There's something in the instructions about adding labels to the namespace, I'm not sure if I needed them, but I added them regardless.

    kubectl edit ns metallb-system
Add the Labels
```yaml
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```
I know this can all be done during ns creation or with `kubectl label namespaces` but editing is just faster for me.

metallb-config.yaml
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 10.0.14.100-10.0.14.255
  avoidBuggyIPs: true
  autoAssign: true
  
---

apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: reserved
  namespace: metallb-system
spec:
  addresses:
  - 10.0.14.20-10.0.14.99
  avoidBuggyIPs: true
  autoAssign: false
  
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
  - reserved
```
