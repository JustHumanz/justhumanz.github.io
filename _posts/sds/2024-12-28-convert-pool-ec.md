---
layout: post
title:  "How to change pool erasure coding in ceph"
categories: sds storage ceph infrastructure
image: https://storage.humanz.moe/humanz-blog/GfiYi2GbUAAizjR.jpeg
---
Hello all, how ur doing? happy holiday and padoru padoru.

Actually the title might a misleading information since you **cannot change the ceph erasure coding** yep that the fact. ceph erasure coding was immutable that was the short answer

ok bye bye.



no no no ofc not, we are engineer right? we do calc and build some fancy tools to solve the problem right? yes we are. now let's solve this problem

in ceph you [cannot change the ec profile](https://docs.redhat.com/en/documentation/red_hat_ceph_storage/3/html/storage_strategies_guide/erasure_code_pools#erasure_code_profiles) in example if you already create ec profile with k=2 m=1 and the faliure domain was host then you create pool above that ec profile then your pool ec was immutable. let's say in feature your cluster node has been increase so you need update the ec profile to make the pool more efficient and reliability or if you have pool with replication rule but at some point your company need to change it into erasure coding

For that case currently ceph not support those requirement but but [ceph support migration pool](https://docs.redhat.com/en/documentation/red_hat_ceph_storage/6/html/storage_strategies_guide/pools-overview_strategy#migrating-a-pool_strategy) however the Prerequisites was kinda red flag for some company i think

```
If using the rados cppool command:
    - Read-only access to the pool is required.
    - Only use this command if you do not have RBD images and its snaps and user_version consumed by librados.
```
**Read-only access to the pool is required.** this is obviously can't do while migrating a pool with large data, migration large data can't be done 1-2 hours it can days or weeks depends on hardware and how large the data and to migrate pool we need set the pool into readonly? hack it's never gonna happen

well i understand if read only pool is mandatory to avoid the data become inconsistent between two pool. in example
```
              Pool-A                    Pool-B       
          +----------------+        +----------------+
          |                |        |                |
          | +------------+ |        | +------------+ |
          | |   file1    | |        | |   file1    | |
          | +------------+ |        | +------------+ |
          | +------------+ |        | +------------+ |
          | |   file2    | |        | |   file2    | |
          | +------------+ |        | +------------+ |
          | +------------+ |        | +------------+ |
          | |   file3    | |        | |   file3    | |
          | +------------+ |        | +------------+ |
          | +------------+ |        | +------------+ |
          | |   file4    +-+--------+>|            | |
          | +------------+ |        | +------------+ |
          |                |        |                |
          |                |        |                |
          +----------------+        +----------------+

File update                                           
-------------+                                        
             |                                        
             | Pool-A                    Pool-B       
          +--+-------------+        +----------------+
          |  v             |        |                |
          | +------------+ |        | +------------+ |
          | |   file1    | |        | |   file1    | |
          | +------------+ |        | +------------+ |
          | +------------+ |        | +------------+ |
          | |   file2    | |        | |   file2    | |
          | +------------+ |        | +------------+ |
          | +------------+ |        | +------------+ |
          | |   file3    | |        | |   file3    | |
          | +------------+ |        | +------------+ |
          | +------------+ |        | +------------+ |
          | |   file4    +-+--------+>|   file4    | |
          | +------------+ |        | +------------+ |
          |                |        |                |
          |                |        |                |
          +----------------+        +----------------+

File update                                                            
-------------+                                                         
             |                                                         
             | Pool-A                    Pool-B                        
          +--+-------------+        +----------------+                 
          |  v             |        |                |                 
          | +------------+ |        | +------------+ |                 
          | |   file1    | |        | |   file1    +-+---->inconsistent
          | +------------+ |        | +------------+ |                 
          | +------------+ |        | +------------+ |                 
          | |   file2    | |        | |   file2    | |                 
          | +------------+ |        | +------------+ |                 
          | +------------+ |        | +------------+ |                 
          | |   file3    | |        | |   file3    | |                 
          | +------------+ |        | +------------+ |                 
          | +------------+ |        | +------------+ |                 
          | |   file4    +-+--------+>|   file4    | |                 
          | +------------+ |        | +------------+ |                 
          |                |        |                |                 
          |                |        |                |                 
          +----------------+        +----------------+                           
```
if the progress migrate already reach file4 but at that time file1 have some update from upstream in original pool that would make the file1 in migrate pool becomeing inconsistent.



after a while i think and find out "if we afraid with data become inconsistent then why not just sync them again? i think that was possible and can improve the pool migration"

so because of that i create a simple script to help pool migration and pool sync after migration you can see it on [my github](https://github.com/JustHumanz/Ceph-dojo/blob/master/src/migrate/migrate.py)

Here was the PoC:

[![asciicast](https://asciinema.humanz.moe/a/CqM4pu5bc78i8JWoZBs8krDKH.svg)](https://asciinema.humanz.moe/a/CqM4pu5bc78i8JWoZBs8krDKH)

let me explain a little bit in my PoC

first i have two pools, jk1.rgw.buckets.data-ec and test, jk1.rgw.buckets.data-ec was the source pool and test is the new pool for migraion.

then i just need to run the script `python3 migrate.py -p jk1.rgw.buckets.data-ec -t test -w 6`.

`-p` source pool  
`-t` new pool or target pool  
`-w` worker  

when the migrate process still running i was try to update some obj in source pool with `while true; do openssl rand -base64 12 | rados --pool jk1.rgw.buckets.data-ec put test-update-obj -; sleep 1;done` and wait until finish.

when migration process was finish now i run it once again but this time with flag `-s` for sync the object.

in last part you can see the script showing log `[WARN] obj test/test-update-obj not sync with new pool,try to sync obj` and the script will automaticly sync the object in new pool