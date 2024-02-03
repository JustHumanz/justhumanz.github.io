---
layout: post
title:  "Kubevirt: The Next Gen Of VM Orchestration?"
categories: kubernetes infrastructure 
image: https://storage.humanz.moe/humanz-blog/F_XdW5wagAAM7V0.jpeg
img_path: ../../assets/img/kubernetes/
---
[Kubevirt](https://kubevirt.io/) first time i hear it was from my friend [kuliserper](https://twitter.com/kuliserper) who brought this tools when he becoming speaker at [openinfra meetup 13](https://www.openinfra.id/portfolio/meetup-13/) but sadly i can't to see his presentation cuz at that time i'm not in jkt :'( .

At first time i hear it i was not very excited honestly, cuz it's like running a vm over container or [qemu-docker](https://github.com/qemus/qemu-docker) which is nothing special, but all my perspective was changed after hearing "the problem with kubevirt is the vm was not accessible from outside cluster by default, if you want it accessible you should use [multus-cni](https://github.com/k8snetworkplumbingwg/multus-cni) and need another nic for the provider network/floating ip network"

*WHATTT?? WHAYY?? HOWW?*

that was nonsense, what the point of having vm if no one can access it from outside right, theoretically the vm can use SNAT fuction. but attaching another nic for the provider network/floating ip network it's technically garbage expect you have special case like you need SR-IOV into your vm. then what if i want to add another network? i should attach new nic? or i should create new vlan&bridge subnet in all nodes? that very ineffective.

*ok enough with this nonsense, let's dig dipper and proof if my theory was possible with snat&dnat func*

## Setup
wait let me show you my kube topology

![topology](kubevirt/topo.png)

So i have 3 nodes, 1 is master and others 2 is worker also all nodes have two nic, one is for kube communication between nodes and second nic is for provider network. the networking is simple the red is provider network/floating ip, green is internal node network and purple is pod network

here the detail subnet:
- Green: 201.0.0.0/24
- Red: 192.168.100.0/24
- Purple: 100.0.0.0/24

let's start our setup, first is installing the kube-ovn since only kube-ovn who can provide snat funcion as af as i know.

### Install kube-ovn

- `wget https://raw.githubusercontent.com/kubeovn/kube-ovn/release-1.12/dist/images/install.sh`
- `nano install.sh` #Change POD_CIDR,POD_GATEWAY,EXCLUDE_IPS
- `bash install.sh`

And wait until all pods was running. to verify if the kube-ovn was running you can use
- `kubectl ko nbctl show`

### Install kubevirt
- `export RELEASE=$(curl https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)`
- `kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-operator.yaml`
- `kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-cr.yaml`
- `kubectl get pods -A`
And wait until all pods was running

and don't forget to install virtctl
- `wget https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/virtctl-${VERSION}-linux-amd64`


Now let's try to create vm

vm.yaml
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: testvm
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/size: small
        kubevirt.io/domain: testvm
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
        resources:
          requests:
            memory: 64M
      networks:
      - name: default
        pod: {}
      volumes:
        - name: containerdisk
          containerDisk:
            image: quay.io/kubevirt/cirros-container-disk-demo
        - name: cloudinitdisk
          cloudInitNoCloud:
            userDataBase64: SGkuXG4=
```
```bash
root@ubuntu-kube-1:/home/humanz# kubectl apply -f vm.yaml
virtualmachine.kubevirt.io/testvm created
root@ubuntu-kube-1:/home/humanz# kubectl get vm
NAME                   AGE   STATUS    READY
testvm                 91s   Stopped   False
```
Now start the vm
```bash
root@ubuntu-kube-1:/home/humanz# virtctl start testvm
VM testvm was scheduled to start
root@ubuntu-kube-1:/home/humanz# kubectl get vm
NAME                   AGE    STATUS    READY
testvm                 3m6s   Running   True
```
Let's try to console it
```bash
root@ubuntu-kube-1:/home/humanz# virtctl console testvm
Successfully connected to testvm console. The escape sequence is ^]

login as 'cirros' user. default password: 'gocubsgo'. use 'sudo' for root.
testvm login: cirros
Password:
$ sudo -i
#
```

Nice, now the vm was running and accessible.

## Digging down the rabbit hole
ladies and gentlemen, let's start our journey.

first let's check the ip address of vm
```bash
# ifconfig
eth0      Link encap:Ethernet  HWaddr 00:00:00:F8:96:4E
          inet addr:10.0.2.2  Bcast:10.0.2.255  Mask:255.255.255.0
          inet6 addr: fe80::200:ff:fef8:964e/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:8900  Metric:1
          RX packets:445 errors:0 dropped:0 overruns:0 frame:0
          TX packets:495 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:59203 (57.8 KiB)  TX bytes:53577 (52.3 KiB)

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

```
the ip address was **10.0.2.2**, huh that strange since i never define this ip on my kube cluster, let's check from pod ip

```bash
root@ubuntu-kube-1:/home/humanz# kubectl get pods -o wide
NAME                                               READY   STATUS    RESTARTS   AGE   IP           NODE            NOMINATED NODE   READINESS GATES
nfs-subdir-external-provisioner-5b67d5c597-55pmr   1/1     Running   0          35h   100.0.0.8    ubuntu-kube-3   <none>           <none>
virt-launcher-testvm-szq8b                         3/3     Running   0          78m   100.0.0.22   ubuntu-kube-3   <none>           1/1
virt-launcher-vm-cirros-datavolume-d9phb           2/2     Running   0          34h   100.0.0.21   ubuntu-kube-3   <none>           1/1
```
huh so the ip from vm was **100.0.0.22** but how can it become **10.0.2.2** in vm? let's try ping and ssh

```bash
root@ubuntu-kube-1:/home/humanz# ping -c 3 10.0.2.2
PING 10.0.2.2 (10.0.2.2) 56(84) bytes of data.

--- 10.0.2.2 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 2039ms

root@ubuntu-kube-1:/home/humanz# ping -c 3 100.0.0.22
PING 100.0.0.22 (100.0.0.22) 56(84) bytes of data.
64 bytes from 100.0.0.22: icmp_seq=1 ttl=62 time=1.67 ms
64 bytes from 100.0.0.22: icmp_seq=2 ttl=62 time=1.46 ms
64 bytes from 100.0.0.22: icmp_seq=3 ttl=62 time=0.818 ms

--- 100.0.0.22 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 0.818/1.314/1.670/0.361 ms
```
yeah sure the ip **10.0.2.2** was unreachable but **100.0.0.22** can, let's ssh to the vm

```bash
root@ubuntu-kube-1:/home/humanz# ssh cirros@100.0.0.22
cirros@100.0.0.22's password:
$ sudo -i
# ifconfig
eth0      Link encap:Ethernet  HWaddr 00:00:00:F8:96:4E
          inet addr:10.0.2.2  Bcast:10.0.2.255  Mask:255.255.255.0
          inet6 addr: fe80::200:ff:fef8:964e/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:8900  Metric:1
          RX packets:537 errors:0 dropped:0 overruns:0 frame:0
          TX packets:559 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:73430 (71.7 KiB)  TX bytes:62799 (61.3 KiB)

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

```
sure the ssh was working well, but how can be ip from **10.0.2.2** becoming **100.0.0.22** in pod level? let's find out.

```bash
root@ubuntu-kube-1:/home/humanz# kubectl exec -it virt-launcher-testvm-szq8b -c compute bash
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl exec [POD] -- [COMMAND] instead.
bash-5.1$ id
uid=107(qemu) gid=107(qemu) groups=107(qemu)
```
hemm, crap i don't have root level >:'( i just hate it  
let's escalate it.

```bash
root@ubuntu-kube-3:/home/humanz# crictl ps -a | grep virt-launcher-testvm-szq8b
a5eae1b6f29a0       d340d99a7f602d364b5e26566a8e315d9f530332d8e43bd5a141a1058c62330e                                                                      2 hours ago         Running             guest-console-log                 0                   8f9ba90bc68bb       virt-launcher-testvm-szq8b
8d23679bfd2d2       quay.io/kubevirt/cirros-container-disk-demo@sha256:0e5ac38b20abcc7752293425b239a147868facd62cd5030dede6da6f2fc526a1                   2 hours ago         Running             volumecontainerdisk               0                   8f9ba90bc68bb       virt-launcher-testvm-szq8b
621a06bc3851e       d340d99a7f602d364b5e26566a8e315d9f530332d8e43bd5a141a1058c62330e                                                                      2 hours ago         Running             compute                           0                   8f9ba90bc68bb       virt-launcher-testvm-szq8b
56654182c5130       quay.io/kubevirt/cirros-container-disk-demo@sha256:0e5ac38b20abcc7752293425b239a147868facd62cd5030dede6da6f2fc526a1                   2 hours ago         Exited              volumecontainerdisk-init          0                   8f9ba90bc68bb       virt-launcher-testvm-szq8b
ad71e10028d6a       d340d99a7f602d364b5e26566a8e315d9f530332d8e43bd5a141a1058c62330e                                                                      2 hours ago         Exited              container-disk-binary             0                   8f9ba90bc68bb       virt-launcher-testvm-szq8b
root@ubuntu-kube-3:/home/humanz# crictl inspect 621a06bc3851e | grep pid
    "pid": 3300896,
          "pids": {
            "type": "pid"
root@ubuntu-kube-3:/home/humanz# nsenter --all -S 0 -G 0 -t 3300896
[root@testvm /]# id
uid=0(root) gid=0(root) groups=0(root)
[root@testvm /]#
```
ggez, anyway let's check the network

```bash
[root@testvm /]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: k6t-eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc noqueue state UP group default qlen 1000
    link/ether 02:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.1/24 brd 10.0.2.255 scope global k6t-eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::ff:fe00:0/64 scope link
       valid_lft forever preferred_lft forever
3: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc fq_codel master k6t-eth0 state UP group default qlen 1000
    link/ether 5e:4b:5a:69:35:8e brd ff:ff:ff:ff:ff:ff
    inet6 fe80::5c4b:5aff:fe69:358e/64 scope link
       valid_lft forever preferred_lft forever
34: eth0@if35: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc noqueue state UP group default
    link/ether 00:00:00:f8:96:4e brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 100.0.0.22/16 brd 100.0.255.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::200:ff:fef8:964e/64 scope link
       valid_lft forever preferred_lft forever
[root@testvm /]# ss -tulpn
Netid                            State                             Recv-Q                             Send-Q                                                         Local Address:Port                                                         Peer Address:Port                            Process
udp                              UNCONN                            0                                  0                                                                    0.0.0.0:67                                                                0.0.0.0:*                                users:(("virt-launcher",pid=13,fd=12))
[root@testvm /]#
```
hemmm, nothing special in here. we have the pod ip **eth0** who veth peer with cni in host and tap interface pairing with **k6t-eth0** which is qemu interface


***psttt, see some [fun fact](#fun-fact-about-kube-virt-dhcp-server)

```bash
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: k6t-eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc noqueue state UP mode DEFAULT group default qlen 1000
    link/ether 02:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
3: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc fq_codel master k6t-eth0 state UP mode DEFAULT group default qlen 1000
    link/ether 5e:e0:c9:74:76:65 brd ff:ff:ff:ff:ff:ff
36: eth0@if37: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8900 qdisc noqueue state UP mode DEFAULT group default
    link/ether 00:00:00:f8:96:4e brd ff:ff:ff:ff:ff:ff link-netnsid 0
    alias f5f4cbdae79f_c
```
look at **tap0** that interface have interface master **k6t-eth0**, let verify if **tap0** was vm interface 
```bash
[root@testvm ~]# virsh dumpxml 1 | grep -m 1 interface -A 8
Authorization not available. Check if polkit service is running or see debug message for more information.
    <interface type='ethernet'>
      <mac address='00:00:00:f8:96:4e'/>
      <target dev='tap0' managed='no'/>
      <model type='virtio-non-transitional'/>
      <mtu size='8900'/>
      <alias name='ua-default'/>
      <rom enabled='no'/>
      <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
    </interface>
```
yep **tap0** vm interface, let me draw it   

![vm-peer](kubevirt/vm-peer.png)

the funcion of **k6t-eth0** interface was to becoming master interface of vm and to serve dhcp-server

now the question is how can pod ip serve as vm ip, as you can see i can ping and ssh into vm it self with pod ip  
what magic behind this? 

the most logical answer is DNAT(Destination Network Address Translation) because the Destination was changed right? the Destination was **100.0.0.22** but it's changed into **10.0.2.2**. now let me check the iptables

```bash
root@testvm:~# iptables -t nat -nvL
iptables v1.8.7 (nf_tables): table `nat' is incompatible, use 'nft' tool.
```
huh, look like kube-virt dev perfer use nftables rathet than iptables

```
root@testvm:~# nft list table nat
table ip nat {
        chain prerouting {
                type nat hook prerouting priority dstnat; policy accept;
                iifname "eth0" counter packets 3 bytes 180 jump KUBEVIRT_PREINBOUND
        }

        chain input {
                type nat hook input priority 100; policy accept;
        }

        chain output {
                type nat hook output priority -100; policy accept;
                ip daddr 127.0.0.1 counter packets 0 bytes 0 dnat to 10.0.2.2
        }

        chain postrouting {
                type nat hook postrouting priority srcnat; policy accept;
                ip saddr 10.0.2.2 counter packets 3 bytes 202 masquerade
                oifname "k6t-eth0" counter packets 5 bytes 624 jump KUBEVIRT_POSTINBOUND
        }

        chain KUBEVIRT_PREINBOUND {
                counter packets 3 bytes 180 dnat to 10.0.2.2
        }

        chain KUBEVIRT_POSTINBOUND {
                ip saddr 127.0.0.1 counter packets 0 bytes 0 snat to 10.0.2.1
        }
}
```
And bingoo the natting process was happening in here, as you can see the prerouting chain was redirect/jumping all packet from eth0 into KUBEVIRT_PREINBOUND chain and change the dest ip to **10.0.2.2**



Great now we understand how kubevirt working with pod ip and the VM behavor, next part maybe i'll trying with [multus-cni](https://github.com/k8snetworkplumbingwg/multus-cni)








----------------------------------------------------------------------------------------
### Fun fact about kube-virt dhcp server

As you can see if kubevirt was creating their own dhcp-server and kubevirt dev who decade write a empty file just for verification if the dhcp server was already running

![dhcp-server](kubevirt/dhcp-server.png)

![empty-file](kubevirt/empty.png)

[source code](https://github.com/kubevirt/kubevirt/blob/1fc531ab74e7b52be5afbedbb06fc75e1d5af2cb/pkg/network/dhcp/configurator.go#L87)

giga chad dev   
![giga-chad](https://i.imgflip.com/52wp8m.png)
