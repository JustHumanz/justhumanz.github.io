---
layout: post
title:  "Create a sniffer to detect kominfo blocker"
categories: c kominfo bypass
image: https://storage.humanz.moe/humanz-blog/rntszta6dpfa1.jpg
img_path: ../../assets/img/komintol
---
Hello all,long time to see.i'm litle bit busy with my rl stuff.

So yeah this time i will write about kominfo blocker,it's maybe litle bit late but i'm trying to write it because some website still blocked, at this post i don't want to write `how to bypass the blocker` rather than that i want to deeper how kominfo blocker is work.

Kominfo start blocking website at 30-31 july at this point i don't really care about this blocking mombo jumbo because it's not effect me at all also i can bypass it like open a jar, but at some point i was intrested with this bloking because some isp was using **Deep Packet Inspection**[1] or DPI, yes DPI it's not dns level anymore it's already next level if i'm not worng russia and china use this DPI too.

### Capturing the network package
![1.png](1.png)

As you can see in wireshark it can be seen that this packages has rst flag,well rst means the connections from server was suddenly cut or terminated due network error or server error[2].

![2.png](https://i2.wp.com/ipwithease.com/wp-content/uploads/2020/09/TCP-RST-FLAG1.jpg?w=800&ssl=1)


after see this flag i'm pretty sure if 100% somes ISP use this dpi for blocked website. 

### Then how to bypass it?
well because it's was not dns level anymore so it's should be from tcp level.

1. You can edit your tcp segments[1]
2. VPN or any tunneling connection

for no 1 it's litle bit hard since i can't edit every tcp segments when i create http request. the easy way still use vpn or another tunneling connections but use options 2 was pain in ass. changeing all my network into vpn is not very wise because now all account on my browser detec me in another country and make my account more sus (especially with fb).

### Can route every blocked into vpn connection?
At this point i have this question in my head.can we use vpn but not redirect all network into vpn,just the blocked website? just like firewall mangle & route in mikrotik #cmiiw

```
hemm,yeah i think i can build it
```

### Create sniffer to detect blocker
First i'm trying to create sniffer and filter the flag segments,the main goal is to check if any segments with rst flag.

The sniffer should be fast,light,support networking library. yeah first i choice use go with [gopacket](https://github.com/google/gopacket) but i kinda give up because it's still slow & high resource and i'm confuse to get segments flag.

After some reseach i found if [gopacket](https://github.com/google/gopacket) or [pyshark](https://github.com/KimiNewt/pyshark) use [libcap](https://man7.org/linux/man-pages/man3/libcap.3.html) so why not i'm natively use this lib rather than some library with porting.

### PoC
skip forward,i don't want to review or explain my code because mainly i'm just copy paste and some parts i don't too understand

[![IMAGE](https://i3.ytimg.com/vi/N-Oo62eh-uk/maxresdefault.jpg)](https://www.youtube.com/watch?v=N-Oo62eh-uk "Network sniffer with C")

Full source code : https://github.com/JustHumanz/C-hell/blob/master/network/block_sniffer.c

#### Bloker detection already created,so whats next?
i think i can add the blocked ip into some list and reroute it on vpn? so only blocked website will accesing by vpn not all web.


## Reference
1. https://geneva.cs.umd.edu/papers/geneva_ccs19.pdf
2. https://ipwithease.com/tcp-rst-flag/
