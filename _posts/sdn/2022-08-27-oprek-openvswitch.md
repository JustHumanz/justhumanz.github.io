---
layout: post
title:  "Create neutron from scratch"
categories: sdn network infrastructure
image: https://storage.humanz.moe/humanz-blog/20240914_110022.jpg
---

Neutron is one of openstack component that manage the networking in openstack(maybe another public) cloud, but how is actually work? or the correct question is how public cloud working with virtual network? it's really **virtual** or it's actually someone in datacenter plug & play the utp cable when you creating or deleting virtual network?

on this post i will trying to create that **virtual** network from scratch.

# Componen
- [OpenvSwitch](https://www.openvswitch.org/)
- [Kvm](https://www.linux-kvm.org/page/Main_Page)
- A cup of coffie
- A wizard hat

# Topology

### 2 Network,1 Host,2 Fip
```
                                                                                                                                    xxx x   xx
                                                                                                                                    x         x
                                                                                                                                    x         xxx   xx
                        Compute Host 1                                                                                           x      xxx  xx     xx
┌─────────────────────────────────────────────────────────────────────────────────┐                                              xxxxx                   x
│                                                                                 │                                              x                      xx
│  ┌──────────────────────────┐                         ┌─────────────────┐       │                                               x                         xx
│  │                          │                         │                 │       │                                              xxx                          x
│  │                          │                         │                 │       │                                          xx x                              x
│  │        router-ns         │169.254.31.238(rfp)      │                 │       │                                         xx                                 x
│  │                          ├─────────────────────────┤                 │       │                                         xx           xx              xxxxxx
│  │ 172.16.18.1  172.16.19.1 │      169.254.31.239(fpr)│    fip-ns       │       │                                           x      x    x       xx      x
│  └───────────────────────┬──┘                         │                 │       │                                                       xx      xxxx
│    ▲                  ▲  │                            │                 │       │                                                         xxxxxx   xx    x
│    │                  │  │vport-router                │ 192.168.100.254 │       │                                                                    xxxxx
│    │                  │  │                            └──────┬──────────┘       │                                                        Internet
│  ┌─┼──────────────────┼──┴──────┐                            ▲                  │                                                           │
│  │ │                  │         │                            │                  │                                                           │
│  │ │                  │         │                            │                  │                                                           │
│  │ │                  │         │                            │                  │                                                           │
│  │ │                  │         │                            │                  │                                                           │
│  │ │                  │         │                            │                  │                                                           │
│  │ │                  │         │            vport-fip       │                  │                                                           │
│  │ │                  │         │◄───────────────────────────┘                  │                                                           │
│  │ │                  │         │                                               │                                                           │
│  │ │   BR-INT (OVS)   │         │                                               │                                                           │
│  │ │                  │         │vport-br-int                                   │                                                           │
│  │ │                  │         │◄──────────┐                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │ peer type                         │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  └─┼──────────────────┼─────────┘           │                                   │                                                           │
│    │                  │                     │                                   │                                                           │
│    │                  │                     │       ┌──────────────┐            │                                                           │
│    │                  │                     │       │              │            │                                                           │
│    │                  │                     │       │              │            │                                                           │
│    ▼                  ▼                     │       │              │            ├─────┐                                                     │
│ ┌─────────────────┐ ┌─────────────────┐     └──────►│              │            │     │                                                     │
│ │  172.16.18.100  │ │  172.16.19.100  │ vport-br-ex │ BR-EX(OVS)   │            │     │              192.168.100.0/24                       │
│ │    (internal)   │ │   (internal)    │             ├              │◄───────────┼─────┼─────────────────────────────────────────────────────┘
│ │  192.168.100.150│ │ 192.168.100.160 │             │              │            │     │  
│ │      (fip)      │ │      (fip)      │             │              │            ├─────┘
│ │                 │ │                 │             │              │            │ enp7s0
│ │       VM        │ │       VM        │             └──────────────┘            │
│ └─────────────────┘ └─────────────────┘                                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```  
```
                                                                                                                                    xxx x   xx
                                                                                                                                    x         x
                                                                                                                                    x         xxx   xx
                        Compute Host 1                                                                                           x      xxx  xx     xx
┌─────────────────────────────────────────────────────────────────────────────────┐                                              xxxxx                   x
│                                                                                 │                                              x                      xx
│  ┌──────────────────────────┐                         ┌─────────────────┐       │                                               x                         xx
│  │                          │                         │                 │       │                                              xxx                          x
│  │                          │                         │                 │       │                                          xx x                              x
│  │        router-ns         │169.254.31.238(rfp)      │                 │       │                                         xx                                 x
│  │                          ├─────────────────────────┤                 │       │                                         xx           xx              xxxxxx
│  │ 172.16.18.1  172.16.19.1 │      169.254.31.239(fpr)│    fip-ns       │       │                                           x      x    x       xx      x
│  └───────────────────────┬──┘                         │                 │       │                                                       xx      xxxx
│    ▲                  ▲  │                            │                 │       │                                                         xxxxxx   xx    x
│    │                  │  │vport-router                │ 192.168.100.254 │       │                                                                    xxxxx
│    │                  │  │                            └──────┬──────────┘       │                                                        Internet
│  ┌─┼──────────────────┼──┴──────┐                            ▲                  │                                                           │
│  │ │                  │         │                            │                  │                                                           │
│  │ │                  │         │                            │                  │                                                           │
│  │ │                  │         │                            │                  │                                                           │
│  │ │                  │         │                            │                  │                                                           │
│  │ │                  │         │                            │                  │                                                           │
│  │ │                  │         │            vport-fip       │                  │                                                           │
│  │ │                  │         │◄───────────────────────────┘                  │                                                           │
│  │ │                  │         │                                               │                                                           │
│  │ │   BR-INT (OVS)   │         │                                               │                                                           │
│  │ │                  │         │vport-br-int                                   │                                                           │
│  │ │                  │         │◄──────────┐                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │ peer type                         │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  │ │                  │         │           │                                   │                                                           │
│  └─┼──────────────────┼─────────┘           │                                   │                                                           │
│    │                  │                     │                                   │                                                           │
│    │                  │                     │       ┌──────────────┐            │                                                           │
│    │                  │                     │       │              │            │                                                           │
│    │                  │                     │       │              │            │                                                           │
│    ▼                  ▼                     │       │              │            ├─────┐                                                     │
│ ┌─────────────────┐ ┌─────────────────┐     └──────►│              │            │     │                                                     │
│ │  172.16.18.100  │ │  172.16.19.100  │ vport-br-ex │ BR-EX(OVS)   │            │     │              192.168.100.0/24                       │
│ │    (internal)   │ │   (internal)    │             ├              │◄───────────┼─────┼─────────────────────────────────────────────────────┘
│ │  192.168.100.150│ │ 192.168.100.160 │             │              │            │     │  
│ │      (fip)      │ │      (fip)      │             │              │            ├─────┘
│ │                 │ │                 │             │              │            │ enp7s0
│ │       VM        │ │       VM        │             └──────────────┘            │
│ └─────────────────┘ └─────────────────┘                                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Walkthrough

#### create br-ex for fip connection
- `ovs-vsctl add-br br-ex`

#### add fip nic to Ovs
- `ovs-vsctl add-port br-ex enp7s0`
- `ifconfig enp7s0 up`

#### create int-br
- `ovs-vsctl add-br br-int`

#### create port for patch type 
- `ovs-vsctl add-port br-int int-ex tag=3 -- set interface int-ex type=patch options:peer=ex-int`
- `ovs-vsctl add-port br-ex ex-int -- set interface ex-int type=patch options:peer=int-ex`

#### create fip & router port in int-br
- `ovs-vsctl add-port br-int v-fip tag=3 -- set interface v-fip type=internal`
- `ovs-vsctl add-port br-int v-router_1 tag=10 -- set interface v-router_1 type=internal`
- `ovs-vsctl add-port br-int v-router_2 tag=20 -- set interface v-router_2 type=internal`

#### create fip & router ns
- `ip netns add fip-ns`
- `ip netns add router-ns`

#### add vport fip&router to ns
- `ip link set v-fip netns fip-ns`
- `ip link set v-router_1 netns router-ns`
- `ip link set v-router_2 netns router-ns`

#### add ip in fip-ns
- `ip netns exec fip-ns ip add add 192.168.100.254/24 dev v-fip`
- `ip netns exec fip-ns ip link set v-fip up`
- `ip netns exec fip-ns ip route add default via 192.168.100.1 dev v-fip`

#### add link from fip to router
- `ip link add fpr netns fip-ns type veth peer name rfp netns router-ns`

#### enable arp proxy
- `ip netns exec fip-ns sysctl net.ipv4.conf.v-fip.proxy_arp=1`

#### add ip in router-ns
- `ip netns exec router-ns ip add add 172.16.18.1/24 dev v-router_1`
- `ip netns exec router-ns ip add add 172.16.19.1/24 dev v-router_2`
- `ip netns exec router-ns ip link set v-router_1 up`
- `ip netns exec router-ns ip link set v-router_2 up`
- `ip netns exec router-ns sysctl -w net.ipv4.ip_forward=1`

#### add ip in rfp
- `ip netns exec router-ns ip add add 169.254.31.238/31 dev rfp`
- `ip netns exec router-ns ip link set rfp up`

#### add ip in fpr
- `ip netns exec fip-ns ip add add 169.254.31.239/31 dev fpr`
- `ip netns exec fip-ns ip link set fpr up`
- `ip netns exec fip-ns ip route add 192.168.100.150 via 169.254.31.238 dev fpr`
- `ip netns exec fip-ns ip route add 192.168.100.160 via 169.254.31.238 dev fpr`

#### set ip route router-ns
- `ip netns exec router-ns ip route add default via 169.254.31.239 dev rfp`

#### set nat firewall
- `ip netns exec router-ns iptables -t nat -A PREROUTING -d 192.168.100.150/32 -j DNAT --to-destination 172.16.18.100`
- `ip netns exec router-ns iptables -t nat -A POSTROUTING -s 172.16.18.100/32 -j SNAT --to-source 192.168.100.150`
- `ip netns exec router-ns iptables -t nat -A PREROUTING -d 192.168.100.160/32 -j DNAT --to-destination 172.16.19.100`
- `ip netns exec router-ns iptables -t nat -A POSTROUTING -s 172.16.19.100/32 -j SNAT --to-source 192.168.100.160`

#### Create VMS for testing
```
virt-install --import --name cirros-vm-1 --memory 512 --vcpus 1 --cpu host \
     --disk cirros-0.3.2-x86_64-disk.img,format=qcow2,bus=virtio \
     -w bridge=br-int,virtualport_type=openvswitch --check all=off
```
- `ovs-vsctl set port vnet0 tag=10`
- `virsh console cirros-vm-1`
- `ip add add 172.16.18.100/24 dev eth0`
- `ip link set eth0 up`
- `ip route add default via 172.16.18.1`
- `ping -c 3 172.16.18.1`
- `ping -c 3 172.16.19.1`

```
virt-install --import --name cirros-vm-2 --memory 256 --vcpus 1 --cpu host \
     --disk cirros-0.3.2-x86_64-disk-clone.img,format=qcow2,bus=virtio \
     -w bridge=br-int,virtualport_type=openvswitch --check all=off
```
- `ovs-vsctl set port vnet1 tag=20`
- `virsh console cirros-vm-2`
- `ip add add 172.16.19.100/24 dev eth0`
- `ip link set eth0 up`
- `ip route add default via 172.16.19.1`
- `ping -c 3 172.16.19.1`
- `ping -c 3 172.16.18.1`

#### Test Fip
- `ping -c 10 192.168.100.150`
- `ping -c 10 192.168.100.160`

# Describe
Well, i'm not gonna explain one by one of ovs commands i will explain the crucial part only

First things,OpenvSwitch is only **virtual** switch (keep in mind). but in real world if we need to create a network we need a router for manage or routing the network

*and where we can get the router?*

the answer is simple,it's *linux* yeah we running all this things in linux where almost all network device was running on linux so the os it's self will be the router.

*so we create routing table on top of os?*

well yeah,but actualy no. we create a isolated network it's called [linux namespaces](https://man7.org/linux/man-pages/man7/namespaces.7.html)  
this action was on 

#### create fip & router ns
- `ip netns add fip-ns`
- `ip netns add router-ns`

basically, we create linux namespace and isolate the routing table/iptables so the host will not fucked with routing table or iptables

*then what is fip-ns?*

same like router,fip is the middle-man or the distributor of outside network into internal network but all routing and natting still happen in router namespaces.  
and that why i create virtual interfaces with type **veth peer** so router namespaces can connect to fip namespaces. (ah btw fpr stand for *floating ip router* and rfp stand for *router floating ip*)


Yeah i think that's all for the crucial part,if you have some question you can pm me via email or another social media.

Btw all topology and Walkthrough already published on [my github](https://github.com/JustHumanz/OpenvSwitch-dojo)

# Reference 
- http://blog.gampel.net/2014/12/openstack-neutron-distributed-virtual.html
- http://blog.gampel.net/2014/12/openstack-dvr2-floating-ips.html
- http://blog.gampel.net/2015/01/openstack-DVR-SNAT.html
- https://assafmuller.com/2015/04/15/distributed-virtual-routing-floating-ips/
- https://blog.scottlowe.org/2012/11/27/connecting-ovs-bridges-with-patch-ports/
- https://www.youtube.com/watch?v=7IXEtUEZslg
- https://arxiv.org/pdf/1406.0440.pdf
- https://aptira.com/openstack-rules-how-openvswitch-works-inside-openstack/
- https://man7.org/linux/man-pages/man7/ovs-fields.7.html
- http://krnet.gagabox.com/board/data/dprogram/2001/I2-3-%BD%C9%C0%E5%C8%C6.pdf
