---
layout: post
title:  "Kubevirt: The Next Gen Of VM Orchestration? part 2"
categories: kubernetes infrastructure 
image: https://storage.humanz.moe/humanz-blog/20240916_123640.jpg
img_path: ../../assets/img/kubernetes/
---
Ok back to part 2 of kubevirt topic, i don't want to create a too much texto (which is i'm not good at it tho).

As i mention before the vm was inaccesable from outside and need a secondary nic and need attached into pod&vm so the vm have connection direcly into outside and that flow need a [multus-cni](https://github.com/k8snetworkplumbingwg/multus-cni).

let me draw the flow so you can easly understand the goal and the function of [multus-cni](https://github.com/k8snetworkplumbingwg/multus-cni).

## Flow
![flow](kubevirt/flow.png)

hemm the flow more look like this, the pod&vm will have two interface, one is for kubernets network and another nic for direct connection to outside. and how manage that two interfaces? yep multus-cni will take the action

## Setup
```bash
root@ubuntu-kube-1:/home/humanz# git clone https://github.com/k8snetworkplumbingwg/multus-cni
Cloning into 'multus-cni'...
remote: Enumerating objects: 44533, done.
remote: Counting objects: 100% (6028/6028), done.
remote: Compressing objects: 100% (1641/1641), done.
remote: Total 44533 (delta 4422), reused 4822 (delta 4342), pack-reused 38505
Receiving objects: 100% (44533/44533), 50.16 MiB | 15.44 MiB/s, done.
Resolving deltas: 100% (22751/22751), done.
root@ubuntu-kube-1:/home/humanz# cd multus-cni/
root@ubuntu-kube-1:/home/humanz/multus-cni# cat ./deployments/multus-daemonset.yml | kubectl apply -f -
customresourcedefinition.apiextensions.k8s.io/network-attachment-definitions.k8s.cni.cncf.io created
clusterrole.rbac.authorization.k8s.io/multus created
clusterrolebinding.rbac.authorization.k8s.io/multus created
serviceaccount/multus created
configmap/multus-cni-config created
daemonset.apps/kube-multus-ds created
```

And wait until all container running
```bash
root@ubuntu-kube-1:/home/humanz/multus-cni# kubectl get pods -A | grep multus
kube-system   kube-multus-ds-8rbhd                               1/1     Running   0          58s
kube-system   kube-multus-ds-jth6d                               1/1     Running   0          58s
kube-system   kube-multus-ds-phw2c                               1/1     Running   0          58s
```

Great now all pod running.

Since multus-cni was cni plugin so the config are same with cni plugin which is many type was supported like ovs,bridge,ipvlan,macvlan,etc, but this time i'll use bridge.


### Config bridge on host

```bash
root@ubuntu-kube-2:/home/humanz# ip link show enp8s0
4: enp8s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:c7:55:1e brd ff:ff:ff:ff:ff:ff
root@ubuntu-kube-2:/home/humanz# brctl addbr multus-bridge
root@ubuntu-kube-2:/home/humanz# brctl addif multus-bridge enp8s0
```
So in here i have **enp8s0** my secondary nic and then i create a bridge named **multus-bridge** and the last is adding **enp8s0** into **multus-bridge**, now the output should like this
```bash
root@ubuntu-kube-2:/home/humanz# brctl show
bridge name     bridge id               STP enabled     interfaces
multus-bridge           8000.1e995806693f       no              enp8s0
```

also do the same in another worker.

now let's create **NetworkAttachmentDefinition**

multus-bridge.yaml
```yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: multus-br
spec:
  config: '{
      "cniVersion": "0.3.1",
      "name": "multus-br",
      "type": "bridge",
      "bridge": "multus-bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "192.168.100.0/24"
      }
    }
```
apply it

```bash
root@ubuntu-kube-1:/home/humanz# kubectl apply -f multus-bridge.yaml
networkattachmentdefinition.k8s.cni.cncf.io/multus-br created
root@ubuntu-kube-1:/home/humanz# kubectl get net-attach-def
NAME        AGE
multus-br   2m13s
```

now the final one, create the vm with multus-br.

vm-2.yaml
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: testvm-2
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/size: small
        kubevirt.io/domain: testvm-2
    spec:
      domain:
        devices:
          disks:
            - name: containerdisk
              disk:
                bus: virtio
            - name: cloudinitdisk
              disk:
                bus: virtio
          interfaces:
          - name: default
            masquerade: {}
          - name: ext-net
            bridge: {}
        resources:
          requests:
            memory: 64M
      networks:
      - name: default
        pod: {}
      - name: ext-net
        multus:
          default:
          networkName: multus-br
      volumes:
        - name: containerdisk
          containerDisk:
            image: quay.io/kubevirt/cirros-container-disk-demo
        - name: cloudinitdisk
          cloudInitNoCloud:
            userDataBase64: SGkuXG4=
```
check&start the vm
```bash
root@ubuntu-kube-1:/home/humanz# kubectl get VirtualMachine
NAME                   AGE     STATUS    READY
testvm                 2d19h   Running   True
testvm-2               9s      Stopped   False
root@ubuntu-kube-1:/home/humanz# virtctl start testvm-2
VM testvm-2 was scheduled to start
root@ubuntu-kube-1:/home/humanz# kubectl get VirtualMachine
NAME                   AGE     STATUS    READY
testvm                 2d19h   Running   True
testvm-2               29s     Running   True
```
Great, vm was in running state

let's look at inside
```bash
root@ubuntu-kube-1:/home/humanz# virtctl console testvm-2
Successfully connected to testvm-2 console. The escape sequence is ^]

login as 'cirros' user. default password: 'gocubsgo'. use 'sudo' for root.
testvm-2 login: cirros
Password:
$ sudo -i
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc pfifo_fast qlen 1000
    link/ether 00:00:00:e1:86:16 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.2/24 brd 10.0.2.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::200:ff:fee1:8616/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop qlen 1000
    link/ether 26:af:db:b9:9f:d2 brd ff:ff:ff:ff:ff:ff
```
As you can see now the vm have two interface, eth0 and eth1 of course the eth0 for kubernetes networking stuff and eth1 for the outside network, let give eth1 ip address and try to ping gateway

```bash

====================================VM===========================================  =========================================Outside=================================================
# ip a                                                                            
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1                      │╭─[403] as humanz in /var/lib/libvirt/images/kube                                                  
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00                         │╰──➤ ifconfig virbr1
    inet 127.0.0.1/8 scope host lo                                                │virbr1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
       valid_lft forever preferred_lft forever                                    │        inet 192.168.100.1  netmask 255.255.255.0  broadcast 192.168.100.255
    inet6 ::1/128 scope host                                                      │        ether 52:54:00:75:b7:ae  txqueuelen 1000  (Ethernet)
       valid_lft forever preferred_lft forever                                    │        RX packets 109  bytes 9516 (9.2 KiB)
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc pfifo_fast qlen 1000    │        RX errors 0  dropped 0  overruns 0  frame 0
    link/ether 00:00:00:e1:86:16 brd ff:ff:ff:ff:ff:ff                            │        TX packets 5734  bytes 1106327 (1.0 MiB)
    inet 10.0.2.2/24 brd 10.0.2.255 scope global eth0                             │        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
       valid_lft forever preferred_lft forever                                    │
    inet6 fe80::200:ff:fee1:8616/64 scope link                                    │
       valid_lft forever preferred_lft forever                                    │╭─[403] as humanz in /var/lib/libvirt/images/kube                                                  
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000    │╰──➤ sudo tcpdump -ni virbr1 icmp
    link/ether 26:af:db:b9:9f:d2 brd ff:ff:ff:ff:ff:ff                            │[sudo] password for humanz:
    inet 192.168.100.99/24 scope global eth1                                      │tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
       valid_lft forever preferred_lft forever                                    │listening on virbr1, link-type EN10MB (Ethernet), snapshot length 262144 bytes
    inet6 fe80::24af:dbff:feb9:9fd2/64 scope link                                 │15:36:49.775572 IP 192.168.100.99 > 192.168.100.1: ICMP echo request, id 29442, seq 0, length 64
       valid_lft forever preferred_lft forever                                    │15:36:49.775615 IP 192.168.100.1 > 192.168.100.99: ICMP echo reply, id 29442, seq 0, length 64
# ping -c 3 192.168.100.1                                                         │15:36:50.775417 IP 192.168.100.99 > 192.168.100.1: ICMP echo request, id 29442, seq 1, length 64
PING 192.168.100.1 (192.168.100.1): 56 data bytes                                 │15:36:50.775452 IP 192.168.100.1 > 192.168.100.99: ICMP echo reply, id 29442, seq 1, length 64
64 bytes from 192.168.100.1: seq=0 ttl=64 time=0.810 ms                           │15:36:51.775700 IP 192.168.100.99 > 192.168.100.1: ICMP echo request, id 29442, seq 2, length 64
64 bytes from 192.168.100.1: seq=1 ttl=64 time=0.350 ms                           │15:36:51.775741 IP 192.168.100.1 > 192.168.100.99: ICMP echo reply, id 29442, seq 2, length 64
64 bytes from 192.168.100.1: seq=2 ttl=64 time=0.317 ms                           │
                                                                                  │
--- 192.168.100.1 ping statistics ---                                             │
3 packets transmitted, 3 packets received, 0% packet loss                         │
round-trip min/avg/max = 0.317/0.492/0.810 ms                                     │
```
Let's try ssh from gateway

```bash
╭─[403] as humanz in /var/lib/libvirt/images/kube
╰──➤ ssh cirros@192.168.100.99
cirros@192.168.100.99's password:
$ sudo -i
# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc pfifo_fast qlen 1000
    link/ether 00:00:00:e1:86:16 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.2/24 brd 10.0.2.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::200:ff:fee1:8616/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether 26:af:db:b9:9f:d2 brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.99/24 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::24af:dbff:feb9:9fd2/64 scope link
       valid_lft forever preferred_lft forever
```
Great it's working, now we have accessible vm from outside kube cluster. but wait how it's work?

## Digging down the rabbit hole
Let's start with find out where the vm was deployed.

```bash
root@ubuntu-kube-1:/home/humanz# kubectl get pods -o wide
NAME                                               READY   STATUS    RESTARTS   AGE    IP           NODE            NOMINATED NODE   READINESS GATES
nfs-subdir-external-provisioner-5b67d5c597-55pmr   1/1     Running   1          4d5h   100.0.0.8    ubuntu-kube-3   <none>           <none>
virt-launcher-testvm-2-qqcvp                       3/3     Running   0          21m    100.0.0.3    ubuntu-kube-3   <none>           1/1
virt-launcher-testvm-d5wq7                         3/3     Running   0          159m   100.0.0.22   ubuntu-kube-3   <none>           1/1
```
ok the vm was deployed on **ubuntu-kube-3** let check the bridge on there
```bash
root@ubuntu-kube-3:/home/humanz# brctl show
bridge name     bridge id               STP enabled     interfaces
multus-bridge           8000.fea4992c5949       no              enp8s0
                                                        veth926399a4
root@ubuntu-kube-3:/home/humanz# ip link show veth926399a4
31: veth926399a4@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master multus-bridge state UP mode DEFAULT group default
    link/ether b2:b4:96:86:fb:a4 brd ff:ff:ff:ff:ff:ff link-netns 14a804a0-bef8-4874-a878-55fd8f16dfb3                                                        
```
in here bridge **multus-bridge** have two slave/connection one is from my seconday nic (enp8s0) and another is (veth926399a4) from vm? let digging more deep.

on link detail output showing **link-netns 14a804a0-bef8-4874-a878-55fd8f16dfb3** maybe we can check inside that namespace.

```bash
root@ubuntu-kube-3:/home/humanz# ip netns exec 14a804a0-bef8-4874-a878-55fd8f16dfb3 ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: 2df796c6902-nic@if31: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master k6t-2df796c6902 state UP group default
    link/ether e2:df:3b:ea:be:dd brd ff:ff:ff:ff:ff:ff link-netns d8ed1634-05f7-436c-aef6-fe86ec643dce
    inet6 fe80::e0df:3bff:feea:bedd/64 scope link
       valid_lft forever preferred_lft forever
3: k6t-eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc noqueue state UP group default qlen 1000
    link/ether 02:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.1/24 brd 10.0.2.255 scope global k6t-eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::ff:fe00:0/64 scope link
       valid_lft forever preferred_lft forever
4: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc fq_codel master k6t-eth0 state UP group default qlen 1000
    link/ether e2:9c:12:6c:1f:c5 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::e09c:12ff:fe6c:1fc5/64 scope link
       valid_lft forever preferred_lft forever
5: k6t-2df796c6902: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether da:2d:33:5a:57:17 brd ff:ff:ff:ff:ff:ff
    inet 169.254.75.11/32 scope global k6t-2df796c6902
       valid_lft forever preferred_lft forever
    inet6 fe80::e0df:3bff:feea:bedd/64 scope link
       valid_lft forever preferred_lft forever
6: tap2df796c6902: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master k6t-2df796c6902 state UP group default qlen 1000
    link/ether da:2d:33:5a:57:17 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::d82d:33ff:fe5a:5717/64 scope link
       valid_lft forever preferred_lft forever
7: pod2df796c6902: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 26:af:db:b9:9f:d2 brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.2/24 brd 192.168.100.255 scope global pod2df796c6902
       valid_lft forever preferred_lft forever
    inet6 fe80::24af:dbff:feb9:9fd2/64 scope link
       valid_lft forever preferred_lft forever
29: eth0@if30: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc noqueue state UP group default
    link/ether 00:00:00:e1:86:16 brd ff:ff:ff:ff:ff:ff link-netns d8ed1634-05f7-436c-aef6-fe86ec643dce
    inet 100.0.0.3/16 brd 100.0.255.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::200:ff:fee1:8616/64 scope link
       valid_lft forever preferred_lft forever
```
i thing this is kubevirt namespace, so the pair nic **veth926399a4** is **2df796c6902-nic** but who can **2df796c6902-nic** can connect into vm?

if you see in detail you can see if **2df796c6902-nic** have master with **k6t-2df796c6902** it's mean they have some relationship between them?, maybe a bridge?

```bash
root@ubuntu-kube-3:/home/humanz# ip netns exec 14a804a0-bef8-4874-a878-55fd8f16dfb3 brctl show
bridge name     bridge id               STP enabled     interfaces
k6t-2df796c6902         8000.da2d335a5717       no              2df796c6902-nic
                                                        tap2df796c6902
k6t-eth0                8000.020000000000       no              tap0
```
and yeahhh that was a bridge interface, so the flow is secondary interface -> bridge interface -> veethpeer -> bridge interface -> vm

let me draw it. 

![full-flow](kubevirt/full-flow.png)

Great now we understand how kubevirt working with multus cni, next part or the final part i'll trying with [kube-ovn](https://github.com/kubeovn/kube-ovn/) and why kube-ovn can do it more than multus cni.