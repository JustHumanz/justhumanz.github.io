---
layout: post
title:  "OpenStack Helm: Automate cluster part 1"
categories: openstack helm kubernetes
image: https://storage.humanz.moe/humanz-blog/photo_2025-11-01_20-59-03.jpg
img_path: ../../assets/img/openstack-helm/
---
it's has been a longgg time since i've made a post, yeah this year somehow i didn't got any motive to write about technical stuff.
i'm just feel if i didn't improve many thing for this year not sure why. but yeah after all i force my self to start my writing habbit.

Soo yeah here we are, alot things happening in my tech journey and let's start it with openstack helm, i've already know about openstack helm a long time ago but at that time i'm not very intersted with openstack helm because my lack of kube experiance untillll i'm joining [vexxhost](https://vexxhost.com), well yeah somehow i'm able joining a very cool company like vexxhost and that will be another story.

At VEXXHOST, we actually don’t use OpenStack-Helm directly. Instead, we built another tool called Atmosphere — it’s based on OpenStack-Helm but uses Ansible as the operator. You should totally check it out, it’s an awesome tool and definitely a story for another time!

OpenStack helm it's basiclly a full of kubernetes manifest to install openstack. that's all bye :) 

>lol ofc not

OpenStack-Helm uses the same OpenStack services (Nova, Cinder, Heat, Keystone, Glance, Neutron), but each service is deployed as a Deployment or DaemonSet and exposed through a Kubernetes Service. Normally, when you deploy OpenStack with Kolla, Juju, or OSA, you’d need three controllers plus HAProxy and Keepalived to handle load balancing. But with Kubernetes, that changes — you don’t need HAProxy or Keepalived anymore, since you can simply create replica pods and distribute them across nodes using node selectors. The best part is that all the services are connected through Kubernetes Service DNS!

alright, let's see the example.  
In here i have keystone pods
```bash
root@ctl1-humanz:~# kubectl -n openstack get pods -o wide -l application=keystone --field-selector=status.phase==Running
NAME                            READY   STATUS    RESTARTS        AGE   IP          NODE          NOMINATED NODE   READINESS GATES
keystone-api-6b86c59ccb-q7l44   1/1     Running   4 (6d11h ago)   16d   10.0.0.31   ctl1-humanz   <none>           <none>
root@ctl1-humanz:~# 
```
and ofc with the service
```bash
root@ctl1-humanz:~# kubectl -n openstack get svc | grep keystone
keystone-api                       NodePort    10.108.121.8     <none>        5000:32531/TCP                           16d
root@ctl1-humanz:~# 
```

Since it's was on openstack namespace and the keystone had the kube service it's should have the kube dns right, let's see

```bash
root@ctl1-humanz:~# kubectl -n kube-system get svc | grep dns
kube-dns       ClusterIP   10.96.0.10       <none>        53/UDP,53/TCP,9153/TCP   135d
root@ctl1-humanz:~# dig @10.96.0.10 keystone-api.openstack.svc.cluster.local A
; <<>> DiG 9.18.39-0ubuntu0.22.04.2-Ubuntu <<>> @10.96.0.10 keystone-api.openstack.svc.cluster.local A
; (1 server found)
;; global options: +cmd
;; Got answer:
;; WARNING: .local is reserved for Multicast DNS
;; You are currently testing what happens when an mDNS query is leaked to DNS
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 40846
;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 09ba066ece0dfbc6 (echoed)
;; QUESTION SECTION:
;keystone-api.openstack.svc.cluster.local. IN A

;; ANSWER SECTION:
keystone-api.openstack.svc.cluster.local. 30 IN A 10.108.121.8

;; Query time: 0 msec
;; SERVER: 10.96.0.10#53(10.96.0.10) (UDP)
;; WHEN: Sat Nov 01 15:03:11 UTC 2025
;; MSG SIZE  rcvd: 137
```
As you can see the it's the keystone had pods,service and the internal dns.


let's try to curl it
```bash
root@ctl1-humanz:~# curl -H "Host: keystone-api.openstack.svc.cluster.local" 10.108.121.8:5000 -s | jq
{
  "versions": {
    "values": [
      {
        "id": "v3.14",
        "status": "stable",
        "updated": "2020-04-07T00:00:00Z",
        "links": [
          {
            "rel": "self",
            "href": "http://keystone-api.openstack.svc.cluster.local/v3/"
          }
        ],
        "media-types": [
          {
            "base": "application/json",
            "type": "application/vnd.openstack.identity-v3+json"
          }
        ]
      }
    ]
  }
}
```
And yep it's was keystone endpoint.
-------------------------------------------------------------------------------------------------------------------------------

At this point, we should understand how OpenStack-Helm manages OpenStack services. It basically turns systemd or Docker services into pods and load-balances the traffic through Kubernetes Services. In the end, all OpenStack internal endpoints use Kubernetes Services. Here’s an example:

```bash
root@ctl1-humanz:~# openstack endpoint list --interface internal
+----------------------------------+-----------+--------------+-----------------+---------+-----------+-----------------------------------------------------------------------+
| ID                               | Region    | Service Name | Service Type    | Enabled | Interface | URL                                                                   |
+----------------------------------+-----------+--------------+-----------------+---------+-----------+-----------------------------------------------------------------------+
| 0ee3fdf3750c4c1db51da69f20c147c5 | RegionOne | heat-cfn     | cloudformation  | True    | internal  | http://heat-cfn.openstack.svc.cluster.local:8000/v1                   |
| 5578acda8ce04b41a932cbee29bbd44a | RegionOne | magnum       | container-infra | True    | internal  | http://magnum-api.openstack.svc.cluster.local:9511/v1                 |
| 5d6b04b454884195bd6f0c83a308cb99 | RegionOne | keystone     | identity        | True    | internal  | http://keystone-api.openstack.svc.cluster.local:5000/v3               |
| 66ba2a9dfb514cdeb30d2f8f88d4caff | RegionOne | heat         | orchestration   | True    | internal  | http://heat-api.openstack.svc.cluster.local:8004/v1/%(project_id)s    |
| 76c29ae6d3e941c284ac111ae0cfb6d2 | RegionOne | cinderv3     | volumev3        | True    | internal  | http://cinder-api.openstack.svc.cluster.local:8776/v3                 |
| 8d752dfce9b94da6a450c22659728952 | RegionOne | neutron      | network         | True    | internal  | http://neutron-server.openstack.svc.cluster.local:9696                |
| 990b0df84c604d00ba69ceaefbea3972 | RegionOne | octavia      | load-balancer   | True    | internal  | http://octavia-api.openstack.svc.cluster.local:9876                   |
| 99f49820e3c04fef83e0bfb27de973c0 | RegionOne | nova         | compute         | True    | internal  | http://nova-api.openstack.svc.cluster.local:8774/v2.1/                |
| acf4ad98e20c475da218ff8de455e9b3 | RegionOne | swift        | object-store    | True    | internal  | http://rook-ceph-rgw-swift.openstack.svc/swift/v1/AUTH_%(project_id)s |
| f25b0aade0fa48bb9a32f09ef88df6fc | RegionOne | barbican     | key-manager     | True    | internal  | http://barbican-api.openstack.svc.cluster.local:9311/                 |
| f8dfc8d6053d4182bb967d44829cef39 | RegionOne | glance       | image           | True    | internal  | http://glance-api.openstack.svc.cluster.local:9292                    |
| f98bd8ca377f4d62a5c17989c3dd5f08 | RegionOne | placement    | placement       | True    | internal  | http://placement-api.openstack.svc.cluster.local:8778/                |
+----------------------------------+-----------+--------------+-----------------+---------+-----------+-----------------------------------------------------------------------+
```