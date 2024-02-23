---
layout: post
title:  "Kubevirt: The Next Gen Of VM Orchestration? part 3"
categories: kubernetes infrastructure 
image: https://storage.humanz.moe/humanz-blog/4d491fdec21c47428c61abe501173cf2755c41c3_s2_n3_y1.png
img_path: ../../assets/img/kubernetes/
---
jeng jeng jeng, it's time to part three or the last part for kubevirt in networking world.

Just like i mentioned in part two this time let’s focus on kubeovn and why kubeovn is more powerful than multus-cni, also to provide if kubevirt really can change the behavior of VM Orchestration?

First, let's talk about the problem with multus-cni.

Here the full pic pod/vm with multus-cni  

![multus-cni-full](kubevirt/multus-cni-topo.png)


As an infrastructure engineer do you see any problem? any inefficient workloads?

3..2..1..timeout

the correct answer is..... **too many nic and can lead to spof(single point of failure) in one worker/compute**

Let me explain that argument.

![multus-cni-prob](kubevirt/multus-cni-prob.png)

As you can see every worker/compute needs additional nic to reach the outside network and that was very very **pricey**, imagine if i want to build 200 kube workers so i need 400 nic? wow, that doubles from the current vm Orchestration requirement, another thing is if that one nic was broken that make the whole pod/vm on that worker/compute inaccessible.

![multus-cni-prob-2](kubevirt/multus-cni-prob-2.png)


that problem can be solved by ovn :) Yep that problem can be solved by sdn like ovn

## Action
Since i'm already write the kube-ovn in part 1 so i'll skip this step.

first create external gateway as ConfigMap
```bash
root@ubuntu-kube-1:/home/humanz/kubeovn# nano external-gw.yaml
``` 
external-gw.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ovn-external-gw-config
  namespace: kube-system
data:
  type: "centralized"
  enable-external-gw: "true"
  external-gw-nodes: "ubuntu-kube-1"
  external-gw-nic: "enp8s0"
  external-gw-addr: "192.168.100.1/24"
  nic-ip: "192.168.100.254/24"
  nic-mac: "16:52:f3:13:6a:25"
```

```bash
root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl apply -f external-gw.yaml
configmap/ovn-external-gw-config created
``` 
Now recheck if external-gw already created or not
```bash
root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl ko vsctl ubuntu-kube-1 show
27a24c28-f098-4c52-8e3b-be4849b06a69
    Bridge br-int
      ....................
        Port patch-br-int-to-localnet.external
            Interface patch-br-int-to-localnet.external
                type: patch
                options: {peer=patch-localnet.external-to-br-int}
        Port ovn-f724ab-0
            Interface ovn-f724ab-0
                type: geneve
                options: {csum="true", key=flow, remote_ip="201.0.0.30"}
                bfd_status: {diagnostic="No Diagnostic", flap_count="1", forwarding="true", remote_diagnostic="No Diagnostic", remote_state=up, state=up}
    Bridge br-external
        Port patch-localnet.external-to-br-int
            Interface patch-localnet.external-to-br-int
                type: patch
                options: {peer=patch-br-int-to-localnet.external}
        Port br-external
            Interface br-external
                type: internal
        Port enp8s0
            Interface enp8s0
    ovs_version: "3.1.4"
```
We can see if the bridge **br-external** was created along with port **enp8s0** which is our secoundary interface, let's check from ovn pov
```bash
root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl ko nbctl show
switch f309f98f-d11b-4c96-9179-c61e1c561a21 (external)
    port external-ovn-cluster
        type: router
        router-port: ovn-cluster-external
    port localnet.external
        type: localnet
        addresses: ["unknown"]
router 97329c2e-4908-412d-9690-b52316399335 (ovn-cluster)
    port ovn-cluster-join
        mac: "00:00:00:F9:1D:6E"
        networks: ["100.64.0.1/16"]
    port ovn-cluster-external
        mac: "16:52:f3:13:6a:25"
        networks: ["192.168.100.254/24"]
        gateway chassis: [f724abcf-585d-4780-be2c-3f166c3aad43 698ec803-da8b-4599-9d88-ea91d96f18a0 205e2f13-bccc-4df9-9c0d-fa994cb79ccc]
    port ovn-cluster-ovn-default
        mac: "00:00:00:CD:DB:BA"
        networks: ["100.0.0.1/16"]
```
from ovn pov port **ovn-cluster-external** was created with have same ip and mac from our ConfigMap, can we test ping from outside?

```bash
====================================VM===========================================================  =========================================Outside====================
root@ubuntu-kube-1:/home/humanz/kubeovn# tcpdump -i enp8s0 icmp                                   │
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode                         │╭─[403] as humanz in /var/lib/libvirt/images/kube
listening on enp8s0, link-type EN10MB (Ethernet), snapshot length 262144 bytes                    │╰──➤ ping -c 3 192.168.100.254
12:59:46.436014 IP 192.168.100.1 > 192.168.100.254: ICMP echo request, id 52, seq 1, length 64    │PING 192.168.100.254 (192.168.100.254) 56(84) bytes of data.
12:59:46.436383 IP 192.168.100.254 > 192.168.100.1: ICMP echo reply, id 52, seq 1, length 64      │64 bytes from 192.168.100.254: icmp_seq=1 ttl=254 time=0.490 ms
12:59:47.443319 IP 192.168.100.1 > 192.168.100.254: ICMP echo request, id 52, seq 2, length 64    │64 bytes from 192.168.100.254: icmp_seq=2 ttl=254 time=0.372 ms
12:59:47.443586 IP 192.168.100.254 > 192.168.100.1: ICMP echo reply, id 52, seq 2, length 64      │64 bytes from 192.168.100.254: icmp_seq=3 ttl=254 time=0.424 ms
12:59:48.456666 IP 192.168.100.1 > 192.168.100.254: ICMP echo request, id 52, seq 3, length 64    │
12:59:48.456982 IP 192.168.100.254 > 192.168.100.1: ICMP echo reply, id 52, seq 3, length 64      │--- 192.168.100.254 ping statistics ---
                                                                                                  │3 packets transmitted, 3 received, 0% packet loss, time 2021ms
                                                                                                  │rtt min/avg/max/mdev = 0.372/0.428/0.490/0.048 ms
```
Great, the ip pingable from outside.


and the final one, let's try it on kubevirt vm

```bash
root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl apply -f vm.yaml
virtualmachine.kubevirt.io/testvm created
root@ubuntu-kube-1:/home/humanz/kubeovn# virtctl start testvm
VM testvm was scheduled to start
root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl get vm
NAME                   AGE   STATUS     READY
testvm                 14s   Starting   False
vm-cirros-datavolume   9d    Running    True
root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl get vm
NAME                   AGE   STATUS    READY
testvm                 27s   Running   True
vm-cirros-datavolume   9d    Running   True
```
Attach the eip/fio

```bash
root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl get pods -o wide
NAME                                               READY   STATUS    RESTARTS      AGE     IP           NODE            NOMINATED NODE   READINESS GATES
nfs-subdir-external-provisioner-5b67d5c597-55pmr   1/1     Running   2             9d      100.0.0.8    ubuntu-kube-3   <none>           <none>
virt-launcher-testvm-gbx7h                         3/3     Running   0             49s     100.0.0.14   ubuntu-kube-3   <none>           1/1
virt-launcher-vm-cirros-datavolume-l2j6f           2/2     Running   0             15h     100.0.0.21   ubuntu-kube-3   <none>           1/1
root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl annotate pod virt-launcher-testvm-gbx7h ovn.kubernetes.io/eip=192.168.100.101 --overwrite
pod/virt-launcher-testvm-gbx7h annotate
root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl annotate pod virt-launcher-testvm-gbx7h ovn.kubernetes.io/routed-
pod/virt-launcher-testvm-gbx7h annotate
```
Recheck from ovn pov
```bash
root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl ko nbctl show
switch 83cc5b01-c8cb-4897-82c1-ced7e0182a0d (ovn-default)
   ......
    port ovn-default-ovn-cluster
        type: router
        router-port: ovn-cluster-ovn-default
   ......
    port testvm.default
        addresses: ["00:00:00:F3:5D:F1 100.0.0.14"]
    port virt-api-76b596f8b6-2l25k.kubevirt
        addresses: ["00:00:00:D7:F6:F1 100.0.0.10"]
    port coredns-5d78c9869d-6d95d.kube-system
        addresses: ["00:00:00:C5:AB:F5 100.0.0.13"]
    port cdi-uploadproxy-5df78c78db-5s4rw.cdi
        addresses: ["00:00:00:E2:7A:26 100.0.0.18"]
switch d2ecc276-11fa-4fa2-8ba6-a9ec0bc89205 (join)
    port node-ubuntu-kube-2
        addresses: ["00:00:00:46:8B:9E 100.64.0.6"]
    port node-ubuntu-kube-1
        addresses: ["00:00:00:8E:0B:F1 100.64.0.2"]
    port node-ubuntu-kube-3
        addresses: ["00:00:00:35:0D:99 100.64.0.5"]
    port join-ovn-cluster
        type: router
        router-port: ovn-cluster-join
switch f309f98f-d11b-4c96-9179-c61e1c561a21 (external)
    port external-ovn-cluster
        type: router
        router-port: ovn-cluster-external
    port localnet.external
        type: localnet
        addresses: ["unknown"]
router 97329c2e-4908-412d-9690-b52316399335 (ovn-cluster)
    port ovn-cluster-join
        mac: "00:00:00:F9:1D:6E"
        networks: ["100.64.0.1/16"]
    port ovn-cluster-external
        mac: "ac:1f:6b:2d:33:f1"
        networks: ["192.168.100.254/24"]
        gateway chassis: [f724abcf-585d-4780-be2c-3f166c3aad43 698ec803-da8b-4599-9d88-ea91d96f18a0 205e2f13-bccc-4df9-9c0d-fa994cb79ccc]
    port ovn-cluster-ovn-default
        mac: "00:00:00:CD:DB:BA"
        networks: ["100.0.0.1/16"]
    nat 2eefe108-10cc-42ff-ba7b-8dfdac7fd2a1
        external ip: "192.168.100.101"
        logical ip: "100.0.0.14"
        type: "dnat_and_snat"

root@ubuntu-kube-1:/home/humanz/kubeovn# kubectl ko nbctl lr-nat-list ovn-cluster
TYPE             GATEWAY_PORT          EXTERNAL_IP        EXTERNAL_PORT    LOGICAL_IP          EXTERNAL_MAC         LOGICAL_PORT
dnat_and_snat                          192.168.100.101                     100.0.0.14
```
Niceee ovn working fine and create the fip/eip port, time to test drive

```bash
====================================VM===========================================  =========================================Outside====================
root@ubuntu-kube-1:/home/humanz/kubeovn# virtctl console testvm                   │
Successfully connected to testvm console. The escape sequence is ^]               │╭─[403] as humanz in /var/lib/libvirt/images/kube
                                                                                  │╰──➤ ping -c 3 192.168.100.101
login as 'cirros' user. default password: 'gocubsgo'. use 'sudo' for root.        │PING 192.168.100.101 (192.168.100.101) 56(84) bytes of data.
testvm login: cirros                                                              │64 bytes from 192.168.100.101: icmp_seq=1 ttl=62 time=3.10 ms
Password:                                                                         │64 bytes from 192.168.100.101: icmp_seq=2 ttl=62 time=1.06 ms
$ sudo -i                                                                         │64 bytes from 192.168.100.101: icmp_seq=3 ttl=62 time=0.622 ms
# ping -c 3 192.168.100.1                                                         │
PING 192.168.100.1 (192.168.100.1): 56 data bytes                                 │--- 192.168.100.101 ping statistics ---
64 bytes from 192.168.100.1: seq=0 ttl=62 time=4.272 ms                           │3 packets transmitted, 3 received, 0% packet loss, time 2002ms
64 bytes from 192.168.100.1: seq=1 ttl=62 time=0.987 ms                           │rtt min/avg/max/mdev = 0.622/1.594/3.103/1.081 ms
64 bytes from 192.168.100.1: seq=2 ttl=62 time=0.614 ms                           │
                                                                                  │╭─[403] as humanz in /var/lib/libvirt/images/kube
--- 192.168.100.1 ping statistics ---                                             │╰──➤ ssh cirros@192.168.100.101
3 packets transmitted, 3 packets received, 0% packet loss                         │cirros@192.168.100.101's password:
round-trip min/avg/max = 0.614/1.957/4.272 ms                                     │$ sudo -i
# ip a                                                                            │# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1                      │1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00                         │    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo                                                │    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever                                    │       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host                                                      │    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever                                    │       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc pfifo_fast qlen 1000    │2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc pfifo_fast qlen 1000
    link/ether 00:00:00:f3:5d:f1 brd ff:ff:ff:ff:ff:ff                            │    link/ether 00:00:00:f3:5d:f1 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.2/24 brd 10.0.2.255 scope global eth0                             │    inet 10.0.2.2/24 brd 10.0.2.255 scope global eth0
       valid_lft forever preferred_lft forever                                    │       valid_lft forever preferred_lft forever
    inet6 fe80::200:ff:fef3:5df1/64 scope link                                    │    inet6 fe80::200:ff:fef3:5df1/64 scope link
       valid_lft forever preferred_lft forever                                    │       valid_lft forever preferred_lft forever
#                                                                                 │#
```
ggez, eip/fip working like eip/fip in other vm orchestration

But how this happen? and what the diffrent with multus-cni? is there any point plus from ovn?


## Digging down the rabbit hole
let's start with our ConfigMap,

external-gw.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ovn-external-gw-config
  namespace: kube-system
data:
  type: "centralized"
  enable-external-gw: "true"
  external-gw-nodes: "ubuntu-kube-1"
  external-gw-nic: "enp8s0"
  external-gw-addr: "192.168.100.1/24"
  nic-ip: "192.168.100.254/24"
  nic-mac: "16:52:f3:13:6a:25"
```
I’ll explain some parameters from this config, the **type** is “centralized” because i want to use one or more nodes as an external gateway if you want to use all nodes as an external gateway you can choose “distributed” and for this case, i only use 1 node which is on parameter **external-gw-nodes** and **ubuntu-kube-1** will become an external gateway, next is **enable-external-gw** set in true for enabling eip/fip function and the last is nic-ip is for a bridge between my physical network with ovn network also you can see if i can ping that ip from both sides (physical network&ovn network) but now the question is, where that ip was attached? and if we think more clearly about when&where the translating ip happens.

ok let's start with sniff the interface from **ubuntu-kube-3** since the pod&vm was there.

[![asciicast](https://asciinema.humanz.moe/a/QcxUWl7ojKg8tU0QnqHLBkbFS.svg)](https://asciinema.humanz.moe/a/QcxUWl7ojKg8tU0QnqHLBkbFS)

From that terminal record we can see if the secondary nic was not sniffed any icmp traffic even the pod&vm was on there, how can this happen? 

now let's move into **ubuntu-kube-1**

[![asciicast](https://asciinema.humanz.moe/a/i1ohWABMf4nEfu4v5wF9d8tW7.svg)](https://asciinema.humanz.moe/a/i1ohWABMf4nEfu4v5wF9d8tW7)

ahaaaa there we go, so all trafic was going into **ubuntu-kube-1** then moveout to **ubuntu-kube-3**

![ovn-flow](kubevirt/ovn_flow.png)

this was the point plus from ovn, ovn can decide who will be the external gateway and doesn't need all nodes to have the same interfaces we can decade only a few nodes have a secondary interface and make that node become external gateway nodes.


So the ovn can be more efficient since ovn only need a few nodes who have nic 

![ovn-flow](kubevirt/ovn_flow_2.png)

### OpenFlow, the core of OVN
all that process was happening in openflow unlike multus-cni or other cni who only using bridge/tunnel/routing for manage kube networking ovn use openflow for their networking language. well you can search more if you curious about OpenFlow and SDN stuff.


Here the example of OpenFlow

[![asciicast](https://asciinema.humanz.moe/a/SBPAxYcQMjGbqm8G5tPAG8BVs.svg)](https://asciinema.humanz.moe/a/SBPAxYcQMjGbqm8G5tPAG8BVs)

When i do ping into pod/vm the table **cookie=0xb0ec47a1, duration=471.084s, table=12, n_packets=78, n_bytes=7793, idle_age=0, priority=100,ip,reg10=0/0x1,reg14=0x3,metadata=0x1,nw_dst=192.168.100.101 actions=ct(table=13,zone=NXM_NX_REG11[0..15],nat)** was increasing(see the n_bytes) and stop when ping was stoped.

also you can see the table **cookie=0x8b46db38, duration=487.598s, table=11, n_packets=8, n_bytes=336, idle_age=9, priority=92,arp,reg14=0x3,metadata=0x1,arp_tpa=192.168.100.101** was increasing when i delete the arp then do ping (which is automatically send arp request too)

This is was one of example of how ovn running and doesn't need any another tools for bridge/tunnel/routing/natting.

Ahh i almost forgot about the "centralized". so i choice **ubuntu-kube-1** as "centralized" and that make all natting/ingress/egress process was happening on there.

[![asciicast](https://asciinema.humanz.moe/a/4PQ5VH7J6CP0eb5UWJawvw3yz.svg)](https://asciinema.humanz.moe/a/4PQ5VH7J6CP0eb5UWJawvw3yz)

here the example, i was ping eip/fip from **ubuntu-kube-2** into vm which is on **ubuntu-kube-3** and the result is OpenFlow on **ubuntu-kube-1** was increasing and because of that the latecy was diffrent when i ping the eip/fip and cni ip

![ovn-flow](kubevirt/ovn_flow_3.png)

pod -> node ovn -> centralized ovn -> dst node ovn -> dst pod

well yes, it's inefficient, but hey who the F want use eip/fip for connection between pod who already have local ip? 



## Summary
Ok i'm already create a lot of study case, but what the meaning of this all? it's kubevirt is next gen of vm Orchestration?


*Here was my opinion*
>Kubevirt and ovn was change the vm Orchestration behavor the most significant thing is they move the cloud init from network web service to CD room disk and totaly remove the dhcp server and from functionality especialy from network stuff Kubevirt+ovn can provide almost same with another VM Orchestration tools(openstack,proxmox,vmware) i didn't see any minus point in here.

Butttt the goal of kubevirt is *KubeVirt technology addresses the needs of development teams that have adopted or want to adopt Kubernetes but possess existing Virtual Machine-based workloads that cannot be easily containerized* not to replace existing VM Orchestration tools, because of that i think kubevirt won't replace VM Orchestration tools for **NOW** maybe some company want to take this seriously and buld VM Orchestration on top of kubernetes with modified kubevirt+kubeovn in future? well, who knows ;) 


