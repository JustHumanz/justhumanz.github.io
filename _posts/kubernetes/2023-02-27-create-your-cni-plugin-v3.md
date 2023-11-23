---
layout: post
title:  "Create cni plugin from scratch with go part 3"
categories: kubernetes,network,go
image: https://storage.humanz.moe/humanz-blog/FE42T_IWUAELTxR.jpeg
---
This is will be the last part of **Create cni plugin from scratch with go**.


In my last post i'm was asking how to automate the adding ip route,firewall,cni config into kube deployment right?

Now let' me answer it.

but before that let me apply my cni deployment

```bash
root@ubuntu-nested-1:~# kubectl get pods -o wide -A
NAMESPACE        NAME                                        READY   STATUS    RESTARTS   AGE     IP           NODE              NOMINATED NODE   READINESS GATES
default          alpine-deployment-6d7b74c778-wm9lg          0/1     Pending   0          36m     <none>       <none>            <none>           <none>
default          gcc-deployment-864cc9b57b-w94bz             0/1     Unknown   231        23d     <none>       ubuntu-nested-3   <none>           <none>
default          golang-deployment-84f5dfdc6f-bhjjm          0/1     Unknown   3          5d18h   <none>       ubuntu-nested-3   <none>           <none>
default          kano-deployment-6c6c494846-rsdcj            0/2     Unknown   86         34d     <none>       ubuntu-nested-3   <none>           <none>
default          lon-deployment-6bfc6dcfb-h26z2              0/2     Unknown   68         23d     <none>       ubuntu-nested-3   <none>           <none>
ingress-nginx    ingress-nginx-controller-85786f6c49-zhvk7   0/1     Error     6          6d4h    <none>       ubuntu-nested-2   <none>           <none>
kube-system      coredns-74ff55c5b-5z5gh                     0/1     Unknown   5          6d4h    <none>       ubuntu-nested-3   <none>           <none>
kube-system      coredns-74ff55c5b-hmnt8                     0/1     Unknown   2          6d4h    <none>       ubuntu-nested-2   <none>           <none>
kube-system      etcd-ubuntu-nested-1                        1/1     Running   77         66d     200.0.0.10   ubuntu-nested-1   <none>           <none>
kube-system      kube-apiserver-ubuntu-nested-1              1/1     Running   75         59d     200.0.0.10   ubuntu-nested-1   <none>           <none>
kube-system      kube-controller-manager-ubuntu-nested-1     1/1     Running   149        66d     200.0.0.10   ubuntu-nested-1   <none>           <none>
kube-system      kube-proxy-6jlfh                            1/1     Running   77         66d     200.0.0.10   ubuntu-nested-1   <none>           <none>
kube-system      kube-proxy-764tr                            1/1     Running   76         66d     200.0.0.20   ubuntu-nested-2   <none>           <none>
kube-system      kube-proxy-w9s96                            1/1     Running   73         66d     200.0.0.30   ubuntu-nested-3   <none>           <none>
kube-system      kube-scheduler-ubuntu-nested-1              1/1     Running   149        66d     200.0.0.10   ubuntu-nested-1   <none>           <none>
kube-system      metrics-server-56ccf9dff5-sl6z2             0/1     Error     7          6d4h    <none>       ubuntu-nested-2   <none>           <none>
metallb-system   controller-84645df84b-rpz2x                 0/1     Error     9          6d5h    <none>       ubuntu-nested-2   <none>           <none>
metallb-system   speaker-6fhkq                               1/1     Running   96         39d     200.0.0.30   ubuntu-nested-3   <none>           <none>
metallb-system   speaker-dvjhr                               1/1     Running   103        39d     200.0.0.20   ubuntu-nested-2   <none>           <none>
metallb-system   speaker-kpz8z                               1/1     Running   49         13d     200.0.0.10   ubuntu-nested-1   <none>           <none>
root@ubuntu-nested-1:~# kubectl apply -f https://raw.githubusercontent.com/JustHumanz/Kube-dojo/CNI_Deployment/Network/CNI/humanz-cni.yml
clusterrole.rbac.authorization.k8s.io/humanz-cni created
serviceaccount/humanz-cni created
clusterrolebinding.rbac.authorization.k8s.io/humanz-cni created
daemonset.apps/humanz-cni-node created
root@ubuntu-nested-1:~# sleep 5
root@ubuntu-nested-1:~# kubectl get pods -o wide -A
NAMESPACE        NAME                                        READY   STATUS    RESTARTS   AGE     IP            NODE              NOMINATED NODE   READINESS GATES
default          alpine-deployment-6d7b74c778-wm9lg          0/1     Pending   0          45m     <none>        <none>            <none>           <none>
default          gcc-deployment-864cc9b57b-w94bz             1/1     Running   232        23d     100.100.2.5   ubuntu-nested-3   <none>           <none>
default          golang-deployment-84f5dfdc6f-bhjjm          1/1     Running   4          5d18h   100.100.2.3   ubuntu-nested-3   <none>           <none>
default          kano-deployment-6c6c494846-rsdcj            2/2     Running   88         34d     100.100.2.4   ubuntu-nested-3   <none>           <none>
default          lon-deployment-6bfc6dcfb-h26z2              2/2     Running   70         23d     100.100.2.2   ubuntu-nested-3   <none>           <none>
ingress-nginx    ingress-nginx-controller-85786f6c49-zhvk7   0/1     Running   7          6d4h    100.100.1.3   ubuntu-nested-2   <none>           <none>
kube-system      coredns-74ff55c5b-5z5gh                     0/1     Running   6          6d4h    100.100.2.6   ubuntu-nested-3   <none>           <none>
kube-system      coredns-74ff55c5b-hmnt8                     0/1     Running   3          6d4h    100.100.1.5   ubuntu-nested-2   <none>           <none>
kube-system      etcd-ubuntu-nested-1                        1/1     Running   77         66d     200.0.0.10    ubuntu-nested-1   <none>           <none>
kube-system      humanz-cni-node-4w94n                       1/1     Running   0          8m20s   200.0.0.10    ubuntu-nested-1   <none>           <none>
kube-system      humanz-cni-node-p78tm                       1/1     Running   0          8m20s   200.0.0.30    ubuntu-nested-3   <none>           <none>
kube-system      humanz-cni-node-ztvzk                       1/1     Running   0          8m20s   200.0.0.20    ubuntu-nested-2   <none>           <none>
kube-system      kube-apiserver-ubuntu-nested-1              1/1     Running   75         59d     200.0.0.10    ubuntu-nested-1   <none>           <none>
kube-system      kube-controller-manager-ubuntu-nested-1     1/1     Running   149        66d     200.0.0.10    ubuntu-nested-1   <none>           <none>
kube-system      kube-proxy-6jlfh                            1/1     Running   77         66d     200.0.0.10    ubuntu-nested-1   <none>           <none>
kube-system      kube-proxy-764tr                            1/1     Running   76         66d     200.0.0.20    ubuntu-nested-2   <none>           <none>
kube-system      kube-proxy-w9s96                            1/1     Running   73         66d     200.0.0.30    ubuntu-nested-3   <none>           <none>
kube-system      kube-scheduler-ubuntu-nested-1              1/1     Running   149        66d     200.0.0.10    ubuntu-nested-1   <none>           <none>
kube-system      metrics-server-56ccf9dff5-sl6z2             0/1     Running   8          6d4h    100.100.1.2   ubuntu-nested-2   <none>           <none>
metallb-system   controller-84645df84b-rpz2x                 0/1     Running   10         6d5h    100.100.1.4   ubuntu-nested-2   <none>           <none>
metallb-system   speaker-6fhkq                               1/1     Running   96         39d     200.0.0.30    ubuntu-nested-3   <none>           <none>
metallb-system   speaker-dvjhr                               1/1     Running   103        39d     200.0.0.20    ubuntu-nested-2   <none>           <none>
metallb-system   speaker-kpz8z                               1/1     Running   49         13d     200.0.0.10    ubuntu-nested-1   <none>           <none>
root@ubuntu-nested-1:~# ip route
default via 192.168.122.1 dev enp1s0 proto dhcp src 192.168.122.173 metric 100 
100.100.1.0/24 via 200.0.0.20 dev enp8s0 
100.100.2.0/24 via 200.0.0.30 dev enp8s0 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown 
192.168.122.0/24 dev enp1s0 proto kernel scope link src 192.168.122.173 
192.168.122.1 dev enp1s0 proto dhcp scope link src 192.168.122.173 metric 100 
192.168.123.0/24 dev virbr0 proto kernel scope link src 192.168.123.1 linkdown 
200.0.0.0/24 dev enp8s0 proto kernel scope link src 200.0.0.10 
root@ubuntu-nested-1:~# iptables -t nat -nvL | grep 100.100.0.0/24
    0     0 MASQUERADE  all  --  *      enp1s0  100.100.0.0/24       0.0.0.0/0            /* Nat from pods to outside */
root@ubuntu-nested-1:~#
```

Ok now all pods was ready and already get the ip address,let's me explain the deployment

```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: humanz-cni
  labels:
    app: humanz-cni
rules:
  - apiGroups: [""]
    resources: ["pods", "nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: humanz-cni
  namespace: kube-system
  labels:
    app: humanz-cni
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: humanz-cni
  labels:
    app: humanz-cni
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: humanz-cni
subjects:
- kind: ServiceAccount
  name: humanz-cni
  namespace: kube-system
---
```

In here i'm just creating rbac for my cni agent,i'm need privilage to get nodes & pods info also watch it

```yaml
# This manifest used to installs the humanz-cni plugin and config on each master and worker node
# in a Kubernetes cluster with install-humanz-cni.sh script in the container.
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: humanz-cni-node
  namespace: kube-system
  labels:
    app: humanz-cni
spec:
  selector:
    matchLabels:
      app: humanz-cni
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: humanz-cni
      annotations:
        # Mark this pod as a critical add-on to ensure it gets
        # priority scheduling and that its resources are reserved
        # if it ever gets evicted.
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      nodeSelector:
        # The humanz-cni currently only works on linux node.
        beta.kubernetes.io/os: linux
      hostNetwork: true
      tolerations:
        # Make sure humanz-cni-node gets scheduled on all nodes.
        - effect: NoSchedule
          operator: Exists
        # Mark the pod as a critical add-on for rescheduling.
        - key: CriticalAddonsOnly
          operator: Exists
        - effect: NoExecute
          operator: Exists
      serviceAccountName: humanz-cni
      containers:
        # This container installs the humanz-cni binary
        # and CNI network config file on each node.
        - name: install-humanz-cni
          image: docker.io/justhumanz/humanz-cni:latest
          imagePullPolicy: IfNotPresent
          env:
            # Pod name
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            # Node name
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName

          volumeMounts:
            - mountPath: /app/bin
              name: cni-bin-dir
            - mountPath: /app/config
              name: cni-net-dir

          securityContext:
            capabilities:
              add:
              - NET_ADMIN
      volumes:
        # CNI bininary and configuration directories
        - name: cni-bin-dir
          hostPath:
            path: /opt/cni/bin
        - name: cni-net-dir
          hostPath:
            path: /etc/cni/net.d
```
Like others cni,i'm was setting the pods into daemon set so all nodes will spwan my cni and ofc i'm attach the pods with rbac

In that deployment it's will pull `docker.io/justhumanz/humanz-cni:latest` image,now let see the dockerfile from this image

```Dockerfile
from golang:alpine
RUN apk update && apk add --no-cache iptables 
COPY . /app
RUN mkdir config
WORKDIR /app/cmd/humanz-cni
RUN go build -o /humanz-cni .
RUN chmod 755 /humanz-cni
WORKDIR /app/cmd/humanz-cni-agent
RUN go build -o /humanz-cni-agent .
ENTRYPOINT /humanz-cni-agent
```
Now from that deployemnt we know if inside `humanz-cni` image will create dir `/app/config` and if we see at daemonset deployment `/app/config` will mount it into `/etc/cni/net.d`, anyway let's continue

The secound things is the `humanz-cni` image will build two binary, one is `/humanz-cni` and another one is `/humanz-cni-agent`, also `/humanz-cni-agent` will be the ENTRYPOINT, now let's see what is `humanz-cni-agent`

let me explain humanz-cni-agent [main.go](https://github.com/JustHumanz/Kube-dojo/blob/CNI_Deployment/Network/CNI/cmd/humanz-cni-agent/main.go)

```golang
const (
	CNI_CONFIG_PATH  = "/app/config/10-humanz-cni-plugin.conf"
	CNI_BIN_PATH_SRC = "/humanz-cni"
	CNI_BIN_PATH_DST = "/app/bin/humanz-cni"
)
```
first let's declare the constanta of config file/binary path


```golang
NodeHostName := os.Getenv("HOSTNAME")
log.WithFields(log.Fields{
    "Hostname": NodeHostName,
}).Info("Init CNI")

config, err := rest.InClusterConfig()
if err != nil {
    log.Fatal(err)
}

clientset, err := kubernetes.NewForConfig(config)
if err != nil {
    log.Fatal(err)
}

nodeList, err := clientset.CoreV1().Nodes().List(context.Background(), v1.ListOptions{})
if err != nil {
    log.Fatal(err)
}
```

The first thing is to get node hostname by env,after that i'm need to connect into kube api through RBAC and get the node list

```golang
HostPodCIDR := ""
for _, Node := range nodeList.Items {
    if Node.Name != NodeHostName {
        //Do ip route
        PodCIDR := Node.Spec.PodCIDR
        NodeIP := func() string {
            for _, v := range Node.Status.Addresses {
                if v.Type == "InternalIP" {
                    return v.Address
                }
            }

            return ""
        }()

        err := iface.AddNewRoute(PodCIDR, NodeIP)
        if err != nil {
            log.Panic(err)
        }

    } else {
        HostPodCIDR = Node.Spec.PodCIDR
    }
}
```
After that i'm was find the Host CIDR from kube-api and i'm also add the ip route from 'this host to another host'


```golang
myCni := db.Humanz_CNI{
    CniVersion: "0.3.1",
    Name:       "humanz-cni",
    Type:       "humanz-cni",
    Bridge:     "humanz-cni0",
    Subnet:     HostPodCIDR,
}

log.WithFields(log.Fields{
    "Hostname": NodeHostName,
    "Path":     CNI_CONFIG_PATH,
}).Info("Dump cni plugin config")

file, _ := json.MarshalIndent(myCni, "", " ")
err = ioutil.WriteFile(CNI_CONFIG_PATH, file, 0755)
if err != nil {
    log.Error(err)
}
```
In here i'm was dump the cni config file,`myCni` variable was cni config file in json format and i'm dump it into `CNI_CONFIG_PATH` which is in `/app/config/10-humanz-cni-plugin.conf` and don't forget if `/app/config` was mounting into `/etc/cni/net.d` in host level, in simple way it's will dump the cni config into `/etc/cni/net.d/10-humanz-cni-plugin.conf`

```golang
log.WithFields(log.Fields{
    "src path": CNI_BIN_PATH_SRC,
    "dst path": CNI_BIN_PATH_DST,
}).Info("Copy cni bin")

cmd := exec.Command("mv", CNI_BIN_PATH_SRC, CNI_BIN_PATH_DST)
err = cmd.Run()
if err != nil {
    log.Fatal(err)
}
```
Remember if i'm was build two binary? yes now i'm moveing the `/humanz-cni` into `/app/bin/humanz-cni` don't forget if i'm also mount `/app/bin` into `/opt/cni/bin` 

```golang
tab, err := iptables.New()
if err != nil {
    log.Error(err)
}

err = tab.AppendUnique("filter", "FORWARD", "-s", HostPodCIDR, "-j", "ACCEPT", "-m", "comment", "--comment", "ACCEPT src pods network")
if err != nil {
    log.Error(err)
}

err = tab.AppendUnique("filter", "FORWARD", "-d", HostPodCIDR, "-j", "ACCEPT", "-m", "comment", "--comment", "ACCEPT dst pods network")
if err != nil {
    log.Error(err)
}

NatIface := iface.DetectOutsideNat()
if NatIface == "" {
    log.Warn("Nat to outside network can't be found on all interface,skip the nat")
} else {
    err = tab.AppendUnique("nat", "POSTROUTING", "-s", HostPodCIDR, "-o", NatIface, "-j", "MASQUERADE", "-m", "comment", "--comment", "Nat from pods to outside")
    if err != nil {
        log.Error(err)
    }
}
```

And yes, don't forget about iptables

```golang
knodeList := make(map[string]bool)

for _, v := range nodeList.Items {
    knodeList[v.Name] = true
}

NodesWatch, err := clientset.CoreV1().Nodes().Watch(context.TODO(), v1.ListOptions{})
if err != nil {
    log.Fatal(err)
}

for NodesEvent := range NodesWatch.ResultChan() {
    Node := NodesEvent.Object.(*k8sv1.Node)
    if !knodeList[Node.Name] {

        newNode, err := clientset.CoreV1().Nodes().Get(context.TODO(), Node.Name, v1.GetOptions{})
        if err != nil {
            log.Fatal(err)
        }

        PodCIDR := newNode.Spec.PodCIDR
        NodeIP := func() string {
            for _, v := range newNode.Status.Addresses {
                if v.Type == "InternalIP" {
                    return v.Address
                }
            }

            return ""
        }()

        log.WithFields(log.Fields{
            "NodeName": Node.Name,
            "PodsCIDR": PodCIDR,
            "NodeIP":   NodeIP,
        }).Info("New node join")

        //Add ip route to new node
        err = iface.AddNewRoute(PodCIDR, NodeIP)
        if err != nil {
            log.Fatal(err)
        }

        knodeList[Node.Name] = true
    }
}

os.Exit(0)
```
And here was the last part, in here i'm just creating `node watcher` so if new node was joining the cluster `humanz-cni-agent` will add the ip route automatically.


And now all was fully automatic,no more set ip route or setup nat in each nodes.