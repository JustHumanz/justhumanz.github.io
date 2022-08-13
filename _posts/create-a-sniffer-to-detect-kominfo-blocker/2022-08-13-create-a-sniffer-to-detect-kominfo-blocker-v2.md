---
layout: post
title:  "Create a sniffer to detect kominfo blocker v2"
categories: c,kominfo,block
image: https://eu2.contabostorage.com/0e2368a5b4d643d3a152a41a1a5eb0dc:kano/MKLNtic.png
---
This post was part 2 of my article.

In my last post was i already create the sniffer and can detect if kominfo do blocking on some website or not, for this post i will focus on **how i avoid the blocking whitout rerouting all network to vpn**.

the scenario :
```
         Internet

    xx      xxxxx
 xxx  xxxxxx     xx
 x       xx       xxxxxxx
  xx     x              xxx
  xxxx                     x
 xx  x                 xxxx                                             VPN Server
 xx                        xxx                                      ┌───────────────┐
    xxxxx                    xx                                     │               │
     xxx                x     xx◄───────────────────────────────────┤               │
     xx    x      xx     xx  xxx                                    │               │
       xxxx x      xx    x xxx                                      │               │
             xx   x xxxxxx                                          └───────────────┘
              xxxx                                                          ▲
               ▲                                                            │
               │                                                            │
               │                                                            │
               │                                                            │
               │                                                            │
               │                                                            │
               │                                                            │
               │                                                            │
               │                                                            │
               │                                                            │
               │                                                            │
               │                                                            │                                   PC
               │                                                            │                VPN interface┌─────────────┐
               │                                ISP                         └─────────────────────────────┤             │
               │                          ┌──────────────┐                                                │             │
               │                          │              │                                                │             │
               │                          │              │                                   Raw interface│             │
               └──────────────────────────┤              │◄───────────────────────────────────────────────┤             │
                                          │              │                                                └─────────────┘
                                          │              │
                                          └──────────────┘
```

First i still need vpn for secondary network, at this point i use [OpenConnect](https://wiki.archlinux.org/title/OpenConnect).

the workflow is very simple.

1. First we access the blocked site,as example i will vist reddit so the flow will be like this.  
    1. My pc will asking to ISP for accessing reddit  
    2. ISP will forward my pc request to the internet
    3. ISP found if reddit was blocked so ISP send the RST segment to my pc request

```
         Internet

    xx      xxxxx
 xxx  xxxxxx     xx
 x       xx       xxxxxxx
  xx     x              xxx
  xxxx                     x                              ┌────────────┐                3             ┌────────────┐
 xx  x                 xxxx                               │            ├─────────────────────────────►│            │
 xx                        xxx              2             │            │                              │            │
    xxxxx                    xx ◄─────────────────────────┤            │◄─────────────────────────────┤            │
     xxx                x     xx                          │            │                1             │            │
     xx    x      xx     xx  xxx                          └────────────┘                              └────────────┘
       xxxx x      xx    x xxx                                 ISP                                         PC
             xx   x xxxxxx
              xxxx
```
2. Then the sniffer will check very segments
    4. `is this segments contain rst flag?` if the segments contain rst flag the script will extract segments information like ip address,port,etc and tell pc to rerouting the ip into secondary network
```
         Internet

    xx      xxxxx
 xxx  xxxxxx     xx
 x       xx       xxxxxxx
  xx     x              xxx                                                                                 4
  xxxx                     x                              ┌────────────┐                3                ┌──────┐   ┌────────────┐
 xx  x                 xxxx                               │            ├────────────────────────────────►│      ├──►│            │
 xx                        xxx              2             │            │                                 └──────┘   │            │
    xxxxx                    xx ◄─────────────────────────┤            │                                  Sniffer   │            │
     xxx                x     xx                          │            ├────────────────────────────────────────────┤            │
     xx    x      xx     xx  xxx                          └────────────┘                1                           └────────────┘
       xxxx x      xx    x xxx                                 ISP                                                       PC
             xx   x xxxxxx
              xxxx
```

3. The pc will reroute the blocked website traffic to vpn connection.
```
                                                        ┌─────────────┐
                                                        │             │
             ┌──────────────────────────────────────────┤             │◄──────────────────────────────────────────────────┐
             │                                          │             │                                                   │
             │                                          └─────────────┘                                                   │
             │                                            VPN server                                                      │
             │                                                                                                            │
             ▼                                                                                                            │
         Internet                                                                                                         │
                                                                                                                          │
    xx      xxxxx                                                                                                         │
 xxx  xxxxxx     xx                                                                                                       │
 x       xx       xxxxxxx                                                                                                 │5
  xx     x              xxx                                                                                 4             │
  xxxx                     x                              ┌────────────┐                3                ┌──────┐   ┌─────┴──────┐
 xx  x                 xxxx                               │            ├────────────────────────────────►│      ├──►│    tun0    │
 xx                        xxx              2             │            │                                 └──────┘   │            │
    xxxxx                    xx ◄─────────────────────────┤            │                                  Sniffer   │            │
     xxx                x     xx                          │            ├────────────────────────────────────────────┤eth0        │
     xx    x      xx     xx  xxx                          └────────────┘                1                           └────────────┘
       xxxx x      xx    x xxx                                 ISP                                                       PC
             xx   x xxxxxx
              xxxx
```


### PoC
Full source code : https://github.com/JustHumanz/C-hell/blob/master/network/block_sniffer-v3.c

[![IMAGE](https://i3.ytimg.com/vi/hlg8pPS2Muk/maxresdefault.jpg)](https://www.youtube.com/watch?v=hlg8pPS2Muk "Network sniffer with C")

Now i can enjoy browsing without afraid kominfo blocking or my account suddenly got blocked because vpn.

