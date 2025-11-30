---
layout: post
title:  "OpenStack Helm: Automate cluster part 2"
categories: openstack helm kubernetes
image: https://storage.humanz.moe/humanz-blog/GjGTjcEbIAMgj99.jpeg
img_path: ../../assets/img/openstack-helm/
---
Alright this is part two after my previous post about OpenStack Helm, This time i'll write about the storage of OpenStack Helm

>but which storage? the cinder one or the kubernetes CSI one?

Well it's both storage, since ceph pretty powerfull with both env(openstack and kubernetes) so i use ceph for this one.

```
                                                            
 ┌─────────┐                          ┌─────────┐           
 │ K8s CSI │                          │ Cinder  │           
 └──────┬──┘                          │ Nova    │           
        │                             └────┬────┘           
        │                                  │                
        │                                  │                
  ┌─────▼──────┐                    ┌──────▼───────────────┐
  │ pool: kube │                    │ pool: ciner,nova,etc │
  └────────────┴────────┐           └───────┬──────────────┘
                        │                   │               
                        │                   │               
                        │                   │               
                 ┌──────▼───────┐           │               
                 │ Ceph Cluster │◄──────────┘               
                 └──────────────┘
```
so basically it’s come from 1 same ceph cluster but have different pool storage, in my opinion this architecture is not great architecture since this arch can lean to SPOF.

My ideal storage is to separate the cluster but yeah it's will be costly but don't worry the kube csi is need small amount of disk size since it's only for mysql and rabbitmq volume, another thing is the kube csi should be NFS or cephfs don't use rbd for kube csi since rbd isn't great about multiattach(sometimes rbd stuck at umount and make the volume unusable).

## Setup
For setup ceph you can use any deployment however ceph rook is the best option since it's had mature with kubernetes, however i had 0 expriance with rook and i personaly more comfortable working with cephadm.  

To import ceph cluster into rook you can following this [guide](https://rook.io/docs/rook/latest/CRDs/Cluster/external-cluster/external-cluster/?h=external+storage+cluster)

and after import ceph cluster into rook your kubernetes should can use ceph as the csi, here the example:  
Storage Class
```
root@ctl1-humanz:~# kubectl get sc
NAME       PROVISIONER                  RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
ceph-rbd   rook-ceph.rbd.csi.ceph.com   Delete          Immediate           true                   44d
root@ctl1-humanz:~# 
```

CephCluster
```
root@ctl1-humanz:~# kubectl get CephCluster -n openstack
NAME        DATADIRHOSTPATH   MONCOUNT   AGE   PHASE       MESSAGE                          HEALTH        EXTERNAL   FSID
openstack   /var/lib/rook     3          44d   Connected   Cluster connected successfully   HEALTH_WARN   true       1648bb50-4c66-11f0-b9b1-999f3aca76b9
root@ctl1-humanz:~# 
```

PV and PVC
```
root@ctl1-humanz:~# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                         STORAGECLASS   REASON   AGE
pvc-16c40b56-5e72-4fed-b0b6-0e33fa5fa9ac   5Gi        RWO            Delete           Bound    openstack/mysql-data-mariadb-server-0         ceph-rbd                44d
pvc-2ac598b8-008f-437f-885d-d4c2c6f6a770   5Gi        RWO            Delete           Bound    openstack/data-ovn-ovsdb-sb-0                 ceph-rbd                44d
pvc-9395fdcc-18d9-444f-b0f3-e9c60313f3aa   5Gi        RWO            Delete           Bound    openstack/data-ovn-ovsdb-nb-0                 ceph-rbd                44d
pvc-aba26476-ba82-4151-a79b-41d63b0c9d3d   768Mi      RWO            Delete           Bound    openstack/rabbitmq-data-rabbitmq-rabbitmq-0   ceph-rbd                44d
root@ctl1-humanz:~# kubectl get pvc -n openstack
NAME                                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-ovn-ovsdb-nb-0                 Bound    pvc-9395fdcc-18d9-444f-b0f3-e9c60313f3aa   5Gi        RWO            ceph-rbd       44d
data-ovn-ovsdb-sb-0                 Bound    pvc-2ac598b8-008f-437f-885d-d4c2c6f6a770   5Gi        RWO            ceph-rbd       44d
mysql-data-mariadb-server-0         Bound    pvc-16c40b56-5e72-4fed-b0b6-0e33fa5fa9ac   5Gi        RWO            ceph-rbd       44d
rabbitmq-data-rabbitmq-rabbitmq-0   Bound    pvc-aba26476-ba82-4151-a79b-41d63b0c9d3d   768Mi      RWO            ceph-rbd       44d
root@ctl1-humanz:~# 
```
And for cinder you can just create a configmap with the ceph config as the content.
```
tee /tmp/ceph.conf <<EOF
[global]
cephx = true
cephx_cluster_require_signatures = true
cephx_require_signatures = false
cephx_service_require_signatures = false
fsid = 65ac0dac-4acf-11f0-9751-a3dd4eabfabf
mon_allow_pool_delete = true
mon_compact_on_trim = true
mon_initial_members = "192.168.18.100"
mon_host = [v2:192.168.18.100:3300/0,v1:192.168.18.100:6789/0]
public_network = 192.168.18.0/24
cluster_network = 192.168.18.0/24

[osd]
cluster_network = 192.168.18.0/24
ms_bind_port_max = 7100
ms_bind_port_min = 6800
osd_max_object_name_len = 256
osd_mkfs_options_xfs = -f -i size=2048
osd_mkfs_type = xfs
public_network = 192.168.18.0/24
EOF

kubectl create configmap ceph-etc -n openstack --from-file=/tmp/ceph.conf
```
And by default the cinder will pick it up and mount it on `/etc/ceph/ceph.conf`  
```
root@ctl1-humanz:~# kubectl -n openstack describe deploy/cinder-volume | grep ceph-etc
      /etc/ceph/ceph.conf from ceph-etc (ro,path="ceph.conf")
   ceph-etc:
    Name:      ceph-etc
```

After that you can just create the pool or let the cinder create it for you.
```
conf:
  ceph:
    pools:
      backup:
        replication: 1
      cinder.volumes:
        replication: 1
```

it's had same steps for glance and nova if you want to use it as default backend storage