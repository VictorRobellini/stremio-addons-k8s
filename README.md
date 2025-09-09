# Homelab - MetalLB & Stremio Addons

Homelab setup running K3s for Kubernetes, MetalLB for L2 Loadbalancers, and more.

With this setup I can access all of my Kubernetes Services by name on my local network and externally with valid SSL certs.

# Homelab Setup
- [k3s](https://k3s.io/)
- [MetalLB](https://metallb.io/)
  -  [MetalLB Github](https://github.com/metallb/metallb)
- [pfSense](https://www.netgate.com/)


*Note: pfSense is not a requirement, it just makes my life easier. There are plenty of other ways to accomplish the DNS lookup and SSL termination, but pfSense is kind of awesome and it's what I have.*

External: .mydomain.foo

 - DNS Managed by he.net 

Internal: .home.mydomain.foo

 - DNS Managed by pfSense

Internal K3s: .\<namespace\>.home.mydomain.foo

e.g. .default.home.mydomain.foo

 - DNS Managed by CoreDNS
 - Local network DNS queries sent to pfSense DNS resolver and forwarded to CoreDNS for .default.home.mydomain.foo ([Host Override](https://docs.netgate.com/pfsense/en/latest/services/dns/resolver-host-overrides.html))
 - Added as extra search domain in pfSense DHCP

pfSense Acme/LetsEncrypt manages SSL certificates and pfSense HAProxy manages inbound HTTPS termination.

## K3s
My K3s Deployment. You will want to make sure the `--flannel-iface=` matches your system.
```shell
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--flannel-iface=enp1s0 --cluster-cidr=172.16.0.0/16 --service-cidr=172.17.0.0/16 --cluster-dns=172.17.0.10 --disable traefik --disable servicelb --disable metrics-server —disable-cloud-controller" sh -
```
## CoreDNS

Create the coredns-custom configmap to allow CoreDNS to repond to \<Service Name\>.\<namespace\>.home.mydomain.foo

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  external.server: |
    home.mydomain.foo:53 {
      kubernetes
      k8s_external home.mydomain.foo
    }
```

## MetalLB
metallb-0.15.2

I switched to the helm deployment. Config options and CRs change for major releases so be sure to check the [install docs](https://metallb.io/installation/) and [release notes](https://metallb.io/release-notes/).  

```shell
helm repo add metallb https://metallb.github.io/metallb
kubectl create ns metallb-system
helm install metallb metallb/metallb -n metallb-system
```

There's something in the instructions about adding labels to the namespace, I'm not sure if I needed them, but I added them regardless.
```shell
kubectl edit ns metallb-system
```

Add the Labels
```yaml
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```
I know this can all be done during ns creation or with `kubectl label namespaces` but editing is just faster for me.

Feel free to choose your own range. In the yaml below I have the following setup:

 - DHCP Pool: 10.0.14.100 - 10.0.14.255
 - For me to manually assign: 10.0.14.20 - 10.0.14.99

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

## Expose CoreDNS
Create the DNS service LoadBalancer and give it an IP. In the below example, it's 10.0.14.20.
```yaml
metadata:
  name: ext-dns-udp
  namespace: kube-system
  annotations:
    metallb.io/allow-shared-ip: "DNS"
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.14.20
  ports:
  - port: 53
    targetPort: 53
    protocol: UDP
  selector:
    k8s-app: kube-dns
---
apiVersion: v1
kind: Service
metadata:
  name: ext-dns-tcp
  namespace: kube-system
  annotations:
    metallb.io/allow-shared-ip: "DNS"
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.14.20
  ports:
  - port: 53
    targetPort: 53
    protocol: TCP
  selector:
    k8s-app: kube-dns
```

You can verify that the services are deployed with:
```shell
kubectl -n kube-system get svc
```
You should see 2 new services, ext-dns-tcp  & ext-dns-udp, you should also see that they have the same EXTERNAL-IP associated with them.

## Testing it out
```shell
kubectl run nginx-pod --image=nginx --restart=Never --port=80 -n default
kubectl expose pod nginx-pod --type=LoadBalancer --port=80 --name=nginx-service
    
kubectl get svc
dig nginx-service.default.home.mydomain.foo @10.0.14.20
curl nginx-service
```

The IP address of the service should be returned in the results.

Enjoy!
