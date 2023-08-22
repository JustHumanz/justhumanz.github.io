---
layout: post
title:  "Into eBPF: XDP&TC"
categories: c,ebpf
published: false
image: https://eu2.contabostorage.com/0e2368a5b4d643d3a152a41a1a5eb0dc:kano/110714050_p0.jpg
---
This is was part three or maybe will be last part of eBPF topic in my blog, on this i will talk about XDP or eXpress Data Path and Traffic Controll, well yeah many people know or see how powerfull eBPF on networking level since the popular product of eBPF is calium who made significant improve on mesh service.

Before we start how ebpf works on level network better if we understand how linux handle network first

## Linux Networking Stack

![big no](https://media.tenor.com/VyugKLEBolsAAAAC/bocchi-bocchi-the-rock.gif)

NO, NO NO NO i don't want to explain it to you, you can read it by your self on this [book](https://www.beej.us/guide/bgnet/html/split/), understanding about linux networking stack can be crucial for this topic 

## Linux Packet Filtering
Since we talk about eBPF who designed for filtering package so we need to understand how linux filtering packet at first place.

Let's start with the tools who loved from networking guy until the 'fancy latest' devops guy, yep tcpdump.
wait you already read the [packet filtering](https://www.tcpdump.org/papers/bpf-usenix93.pdf) paper did you? please read it, read it please, minimum you can read it until **The Filter Model** i'm begging to you 🥺🥺🥺

if you already read it and still don't understand or kinda confused let me make it more simple

##### Packet Filtering without bpf
```
root@ubuntuvm1:/home/humanz# tcpdump -i enp2s0 -A | grep ICMP
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on enp2s0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
06:30:04.397101 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 1, seq 1, length 64
06:30:04.397838 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 1, seq 1, length 64
06:30:05.397787 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 1, seq 2, length 64
06:30:05.397990 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 1, seq 2, length 64
06:30:06.400006 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 1, seq 3, length 64
06:30:06.400215 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 1, seq 3, length 64
06:30:07.401659 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 1, seq 4, length 64
06:30:07.401865 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 1, seq 4, length 64
06:30:08.404475 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 1, seq 5, length 64
06:30:08.404702 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 1, seq 5, length 64
06:30:09.406787 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 1, seq 6, length 64
06:30:09.407052 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 1, seq 6, length 64
06:30:10.409455 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 1, seq 7, length 64
06:30:10.409663 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 1, seq 7, length 64
38 packets captured
38 packets received by filter
0 packets dropped by kernel
```

##### Packet Filtering with bpf
```
root@ubuntuvm1:/home/humanz# tcpdump -i enp2s0 icmp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on enp2s0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
06:32:57.019621 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 2, seq 1, length 64
06:32:57.020020 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 2, seq 1, length 64
06:32:58.021927 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 2, seq 2, length 64
06:32:58.022220 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 2, seq 2, length 64
06:32:59.023553 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 2, seq 3, length 64
06:32:59.023845 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 2, seq 3, length 64
06:33:00.025852 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 2, seq 4, length 64
06:33:00.026128 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 2, seq 4, length 64
06:33:01.027552 IP 200.0.0.20 > ubuntuvm1: ICMP echo request, id 2, seq 5, length 64
06:33:01.027777 IP ubuntuvm1 > 200.0.0.20: ICMP echo reply, id 2, seq 5, length 64
```


From those command the output was smillar but the process was very diffrent, well maybe you already guess it 