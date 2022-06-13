---
layout: post
title:  "Improving IOPS in public cloud and reduce cost with bcache"
categories: tips,storage,infrastructure,public cloud
image: https://pbs.twimg.com/media/FVCrqRmUYAAESUq?format=jpg&name=4096x4096
---
in my previous post i talk about `A block layer cache aka Bcache` and after that i realize, can bcache **Improving IOPS and reduce the cost at same time** ?

Ok let's trying, in this lab i use alicloud for the public cloud platform and for the disk type i use `Ultra Disk` for hdd and `Enhanced SSD PL1` for ssd

Here the lab environment
- Ubuntu 20.04
- 4 vCPU 4 GiB (ecs.ic5.xlarge)
- 1 20GiB Enhanced SSD (ESSD) PL1 (2800 IOPS) **Cache device**
- 1 80GiB Ultra Disk (2440 IOPS) **Backing device**
------------------------------------------------------------
- 1 80GiB Ultra Disk (2440 IOPS)
- 1 80GiB Enhanced SSD (ESSD)  PL1 80GiB (5800 IOPS)

Because alicloud use IOPS limitation per size so for the disk size will be same,except for the cache device

## Partition scenario
```
root@iZk1afu8yjxaqjmtrmahbnZ:~# lsblk 
NAME      MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
vda       252:0    0  80G  0 disk 
└─vda1    252:1    0  20G  0 part /
vdb       252:16   0  20G  0 disk 
└─bcache0 251:0    0  80G  0 disk /mnt/bcache
vdc       252:32   0  80G  0 disk 
└─bcache0 251:0    0  80G  0 disk /mnt/bcache
vdd       252:48   0  80G  0 disk /mnt/ssd
vde       252:64   0  80G  0 disk /mnt/hdd
root@iZk1afu8yjxaqjmtrmahbnZ:~# 
```
the env kinda same like previous post but this time the cache device (/dev/vdb) size only 1/3 from backing device (/dev/vdc)

the bcache environment
- [x] writeback
- [x] disabled sequential_cutoff

## Fio benchmark
in this benchmark i will use fio for the tools

here the full command&parameter i will use
```
##Random write IOPS (4 KB for single I/O):
    fio -direct=1 -iodepth=128 -rw=randwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Rand_Write_Testing  

##Random read IOPS (4KB for single I/O):
    fio -direct=1 -iodepth=128 -rw=randread -ioengine=libaio -bs=4k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Rand_Read_Testing  

##Sequential write throughput (write bandwidth) (1024 KB for single I/O):
    fio -direct=1 -iodepth=64 -rw=write -ioengine=libaio -bs=1024k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Write_PPS_Testing  

##Sequential read throughput (read bandwidth) (1024 KB for single I/O):
    fio -direct=1 -iodepth=64 -rw=read -ioengine=libaio -bs=1024k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Read_PPS_Testing  

##Random write latency (4 KB for single I/O):
    fio -direct=1 -iodepth=1 -rw=randwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Write_Latency_Testing  

##Random read latency (4KB for single I/O):
    fio -direct=1 -iodepth=1 -rw=randread -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Read_Latency_Testingrandwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Write_Latency_Testing  
```

### Random write IOPS (4 KB for single I/O)

#### HDD
```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/hdd# fio -direct=1 -iodepth=128 -rw=randwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Rand_Write_Testing  
Rand_Write_Testing: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=128
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [w(1)][100.0%][w=10.8MiB/s][w=2771 IOPS][eta 00m:00s]
Rand_Write_Testing: (groupid=0, jobs=1): err= 0: pid=40240: Sun Jun 12 21:11:08 2022
  write: IOPS=2470, BW=9884KiB/s (10.1MB/s)(1024MiB/106091msec); 0 zone resets
    slat (usec): min=2, max=175, avg= 5.55, stdev= 2.85
    clat (usec): min=293, max=118511, avg=51795.17, stdev=47598.46
     lat (usec): min=302, max=118515, avg=51800.79, stdev=47598.11
    clat percentiles (usec):
     |  1.00th=[  1336],  5.00th=[  1795], 10.00th=[  2008], 20.00th=[  2343],
     | 30.00th=[  2606], 40.00th=[  2966], 50.00th=[ 95945], 60.00th=[ 96994],
     | 70.00th=[ 98042], 80.00th=[ 98042], 90.00th=[ 99091], 95.00th=[ 99091],
     | 99.00th=[100140], 99.50th=[100140], 99.90th=[101188], 99.95th=[101188],
     | 99.99th=[115868]
   bw (  KiB/s): min= 9704, max=12224, per=100.00%, avg=9886.00, stdev=219.14, samples=212
   iops        : min= 2426, max= 3056, avg=2471.50, stdev=54.78, samples=212
  lat (usec)   : 500=0.01%, 750=0.04%, 1000=0.16%
  lat (msec)   : 2=9.48%, 4=38.18%, 10=0.33%, 20=0.01%, 100=50.96%
  lat (msec)   : 250=0.85%
  cpu          : usr=0.54%, sys=1.54%, ctx=24203, majf=0, minf=10
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=0,262144,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
  WRITE: bw=9884KiB/s (10.1MB/s), 9884KiB/s-9884KiB/s (10.1MB/s-10.1MB/s), io=1024MiB (1074MB), run=106091-106091msec

Disk stats (read/write):
  vde: ios=0/261533, merge=0/0, ticks=0/13538337, in_queue=12976768, util=99.87%
```

#### SSD
```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/ssd# fio -direct=1 -iodepth=128 -rw=randwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Rand_Write_Testing  
Rand_Write_Testing: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=128
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [w(1)][100.0%][w=22.7MiB/s][w=5800 IOPS][eta 00m:00s]
Rand_Write_Testing: (groupid=0, jobs=1): err= 0: pid=45805: Sun Jun 12 21:28:47 2022
  write: IOPS=5943, BW=23.2MiB/s (24.3MB/s)(1024MiB/44109msec); 0 zone resets
    slat (nsec): min=2539, max=67254, avg=3950.45, stdev=1483.14
    clat (usec): min=557, max=130286, avg=21532.52, stdev=11628.39
     lat (usec): min=561, max=130292, avg=21536.53, stdev=11628.40
    clat percentiles (usec):
     |  1.00th=[  1352],  5.00th=[  9372], 10.00th=[  9765], 20.00th=[ 10028],
     | 30.00th=[ 10683], 40.00th=[ 19792], 50.00th=[ 20055], 60.00th=[ 20317],
     | 70.00th=[ 29492], 80.00th=[ 30016], 90.00th=[ 39584], 95.00th=[ 40109],
     | 99.00th=[ 60031], 99.50th=[ 69731], 99.90th=[ 80217], 99.95th=[ 89654],
     | 99.99th=[109577]
   bw (  KiB/s): min=23088, max=73832, per=100.00%, avg=23776.01, stdev=5397.44, samples=88
   iops        : min= 5772, max=18458, avg=5944.00, stdev=1349.36, samples=88
  lat (usec)   : 750=0.01%, 1000=0.11%
  lat (msec)   : 2=1.91%, 4=0.16%, 10=15.65%, 20=28.28%, 50=51.38%
  lat (msec)   : 100=2.48%, 250=0.02%
  cpu          : usr=1.04%, sys=2.57%, ctx=16215, majf=0, minf=10
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=0,262144,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
  WRITE: bw=23.2MiB/s (24.3MB/s), 23.2MiB/s-23.2MiB/s (24.3MB/s-24.3MB/s), io=1024MiB (1074MB), run=44109-44109msec

Disk stats (read/write):
  vdd: ios=0/260905, merge=0/0, ticks=0/5596429, in_queue=5068208, util=99.80%
```

#### Bcache
```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/bcache# fio -direct=1 -iodepth=128 -rw=randwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Rand_Write_Testing  
Rand_Write_Testing: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=128
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [w(1)][100.0%][w=22.6MiB/s][w=5794 IOPS][eta 00m:00s]
Rand_Write_Testing: (groupid=0, jobs=1): err= 0: pid=20767: Sun Jun 12 20:00:16 2022
  write: IOPS=5240, BW=20.5MiB/s (21.5MB/s)(1024MiB/50027msec); 0 zone resets
    slat (usec): min=3, max=39616, avg=44.16, stdev=917.57
    clat (usec): min=119, max=130363, avg=24377.44, stdev=35978.96
     lat (usec): min=129, max=130372, avg=24421.70, stdev=35977.61
    clat percentiles (usec):
     |  1.00th=[   930],  5.00th=[  1663], 10.00th=[  1844], 20.00th=[  2147],
     | 30.00th=[  2474], 40.00th=[  2900], 50.00th=[  3818], 60.00th=[  6718],
     | 70.00th=[ 17433], 80.00th=[ 41157], 90.00th=[ 98042], 95.00th=[ 98042],
     | 99.00th=[100140], 99.50th=[100140], 99.90th=[102237], 99.95th=[103285],
     | 99.99th=[129500]
   bw (  KiB/s): min=18024, max=36360, per=100.00%, avg=20959.25, stdev=3351.12, samples=100
   iops        : min= 4506, max= 9090, avg=5239.79, stdev=837.79, samples=100
  lat (usec)   : 250=0.05%, 500=0.14%, 750=0.15%, 1000=0.83%
  lat (msec)   : 2=13.73%, 4=35.94%, 10=17.42%, 20=2.36%, 50=10.76%
  lat (msec)   : 100=17.53%, 250=1.09%
  cpu          : usr=0.89%, sys=3.09%, ctx=120929, majf=0, minf=11
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=0,262144,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
  WRITE: bw=20.5MiB/s (21.5MB/s), 20.5MiB/s-20.5MiB/s (21.5MB/s-21.5MB/s), io=1024MiB (1074MB), run=50027-50027msec

Disk stats (read/write):
    bcache0: ios=0/261858, merge=0/0, ticks=0/5585908, in_queue=5585908, util=99.31%, aggrios=15/132153, aggrmerge=0/5, aggrticks=9/2781286, aggrin_queue=2572096, aggrutil=79.70%
  vdb: ios=31/142788, merge=0/0, ticks=19/519306, in_queue=336012, util=27.55%
  vdc: ios=0/121518, merge=0/11, ticks=0/5043266, in_queue=4808180, util=79.70%
```

## Random read IOPS (4KB for single I/O):

### HDD

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/hdd# fio -direct=1 -iodepth=128 -rw=randread -ioengine=libaio -bs=4k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Rand_Read_Testing  
Rand_Read_Testing: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=128
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [r(1)][100.0%][r=9.88MiB/s][r=2530 IOPS][eta 00m:00s]
Rand_Read_Testing: (groupid=0, jobs=1): err= 0: pid=42428: Sun Jun 12 21:17:28 2022
  read: IOPS=2467, BW=9868KiB/s (10.1MB/s)(1024MiB/106256msec)
    slat (usec): min=2, max=136, avg= 5.69, stdev= 2.72
    clat (usec): min=229, max=110813, avg=51875.22, stdev=47767.87
     lat (usec): min=237, max=110817, avg=51880.99, stdev=47767.64
    clat percentiles (usec):
     |  1.00th=[   750],  5.00th=[  1287], 10.00th=[  1598], 20.00th=[  1991],
     | 30.00th=[  2409], 40.00th=[  3064], 50.00th=[ 94897], 60.00th=[ 96994],
     | 70.00th=[ 98042], 80.00th=[ 98042], 90.00th=[ 99091], 95.00th=[100140],
     | 99.00th=[101188], 99.50th=[101188], 99.90th=[102237], 99.95th=[103285],
     | 99.99th=[105382]
   bw (  KiB/s): min= 9424, max=11920, per=100.00%, avg=9869.58, stdev=151.05, samples=212
   iops        : min= 2356, max= 2980, avg=2467.40, stdev=37.76, samples=212
  lat (usec)   : 250=0.01%, 500=0.16%, 750=0.83%, 1000=1.44%
  lat (msec)   : 2=17.75%, 4=25.64%, 10=2.27%, 20=0.01%, 50=0.04%
  lat (msec)   : 100=48.97%, 250=2.89%
  cpu          : usr=0.52%, sys=1.92%, ctx=59942, majf=0, minf=139
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=262144,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
   READ: bw=9868KiB/s (10.1MB/s), 9868KiB/s-9868KiB/s (10.1MB/s-10.1MB/s), io=1024MiB (1074MB), run=106256-106256msec

Disk stats (read/write):
  vde: ios=261820/0, merge=0/0, ticks=13571440/0, in_queue=13038252, util=99.88%
```

### SSD

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/ssd# fio -direct=1 -iodepth=128 -rw=randread -ioengine=libaio -bs=4k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Rand_Read_Testing  
Rand_Read_Testing: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=128
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [r(1)][100.0%][r=22.7MiB/s][r=5820 IOPS][eta 00m:00s]
Rand_Read_Testing: (groupid=0, jobs=1): err= 0: pid=46254: Sun Jun 12 21:30:24 2022
  read: IOPS=5942, BW=23.2MiB/s (24.3MB/s)(1024MiB/44111msec)
    slat (usec): min=2, max=101, avg= 3.73, stdev= 1.44
    clat (usec): min=474, max=129383, avg=21533.73, stdev=11635.99
     lat (usec): min=477, max=129386, avg=21537.53, stdev=11635.99
    clat percentiles (usec):
     |  1.00th=[  1287],  5.00th=[  9503], 10.00th=[  9765], 20.00th=[ 10028],
     | 30.00th=[ 11207], 40.00th=[ 19792], 50.00th=[ 20055], 60.00th=[ 20317],
     | 70.00th=[ 29230], 80.00th=[ 30016], 90.00th=[ 39584], 95.00th=[ 40109],
     | 99.00th=[ 60031], 99.50th=[ 69731], 99.90th=[ 80217], 99.95th=[ 89654],
     | 99.99th=[109577]
   bw (  KiB/s): min=22760, max=73816, per=100.00%, avg=23776.09, stdev=5396.13, samples=88
   iops        : min= 5690, max=18454, avg=5944.02, stdev=1349.03, samples=88
  lat (usec)   : 500=0.01%, 750=0.07%, 1000=0.23%
  lat (msec)   : 2=1.54%, 4=0.48%, 10=15.10%, 20=29.30%, 50=50.90%
  lat (msec)   : 100=2.36%, 250=0.02%
  cpu          : usr=1.11%, sys=2.64%, ctx=24904, majf=0, minf=140
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=262144,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
   READ: bw=23.2MiB/s (24.3MB/s), 23.2MiB/s-23.2MiB/s (24.3MB/s-24.3MB/s), io=1024MiB (1074MB), run=44111-44111msec

Disk stats (read/write):
  vdd: ios=260903/1, merge=0/0, ticks=5606140/75, in_queue=5092684, util=99.64%
```

### Bcache

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/bcache# fio -direct=1 -iodepth=128 -rw=randread -ioengine=libaio -bs=4k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Rand_Read_Testing  
Rand_Read_Testing: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=128
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [r(1)][100.0%][r=18.4MiB/s][r=4712 IOPS][eta 00m:00s]
Rand_Read_Testing: (groupid=0, jobs=1): err= 0: pid=30055: Sun Jun 12 20:33:45 2022
  read: IOPS=5286, BW=20.7MiB/s (21.7MB/s)(1024MiB/49586msec)
    slat (usec): min=3, max=1924, avg= 7.30, stdev= 6.42
    clat (usec): min=56, max=124766, avg=24203.12, stdev=36608.81
     lat (usec): min=63, max=124774, avg=24210.50, stdev=36609.20
    clat percentiles (usec):
     |  1.00th=[    94],  5.00th=[   449], 10.00th=[   725], 20.00th=[  1205],
     | 30.00th=[  1614], 40.00th=[  2024], 50.00th=[  2671], 60.00th=[  6456],
     | 70.00th=[ 17433], 80.00th=[ 51119], 90.00th=[ 98042], 95.00th=[ 99091],
     | 99.00th=[100140], 99.50th=[100140], 99.90th=[102237], 99.95th=[103285],
     | 99.99th=[123208]
   bw (  KiB/s): min=16584, max=38248, per=99.86%, avg=21115.59, stdev=2837.84, samples=99
   iops        : min= 4146, max= 9562, avg=5278.87, stdev=709.46, samples=99
  lat (usec)   : 100=1.11%, 250=1.25%, 500=3.43%, 750=4.74%, 1000=4.93%
  lat (msec)   : 2=23.98%, 4=16.99%, 10=11.83%, 20=3.03%, 50=8.48%
  lat (msec)   : 100=19.25%, 250=0.99%
  cpu          : usr=0.94%, sys=4.39%, ctx=28812, majf=0, minf=139
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=0.1%, >=64=100.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.1%
     issued rwts: total=262144,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=128

Run status group 0 (all jobs):
   READ: bw=20.7MiB/s (21.7MB/s), 20.7MiB/s-20.7MiB/s (21.7MB/s-21.7MB/s), io=1024MiB (1074MB), run=49586-49586msec

Disk stats (read/write):
    bcache0: ios=260769/1, merge=0/0, ticks=6309336/40, in_queue=6309376, util=99.73%, aggrios=130681/889, aggrmerge=390/148, aggrticks=3165339/2931, aggrin_queue=2938760, aggrutil=85.55%
  vdb: ios=139869/1778, merge=781/297, ticks=1121073/5819, in_queue=896732, util=27.93%
  vdc: ios=121494/1, merge=0/0, ticks=5209605/43, in_queue=4980788, util=85.55%
```

## Sequential write throughput (write bandwidth) (1024 KB for single I/O):

### HDD
```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/hdd# fio -direct=1 -iodepth=64 -rw=write -ioengine=libaio -bs=1024k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Write_PPS_Testing  
Write_PPS_Testing: (g=0): rw=write, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=64
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [W(1)][100.0%][w=70.1MiB/s][w=70 IOPS][eta 00m:00s]
Write_PPS_Testing: (groupid=0, jobs=1): err= 0: pid=43405: Sun Jun 12 21:19:26 2022
  write: IOPS=113, BW=113MiB/s (119MB/s)(1024MiB/9035msec); 0 zone resets
    slat (usec): min=32, max=160, avg=115.11, stdev=18.05
    clat (msec): min=53, max=1197, avg=563.78, stdev=147.82
     lat (msec): min=53, max=1197, avg=563.89, stdev=147.82
    clat percentiles (msec):
     |  1.00th=[  241],  5.00th=[  317], 10.00th=[  397], 20.00th=[  489],
     | 30.00th=[  527], 40.00th=[  535], 50.00th=[  584], 60.00th=[  584],
     | 70.00th=[  592], 80.00th=[  651], 90.00th=[  684], 95.00th=[  785],
     | 99.00th=[ 1167], 99.50th=[ 1183], 99.90th=[ 1200], 99.95th=[ 1200],
     | 99.99th=[ 1200]
   bw (  KiB/s): min=102400, max=145408, per=99.75%, avg=115772.24, stdev=8354.16, samples=17
   iops        : min=  100, max=  142, avg=113.06, stdev= 8.16, samples=17
  lat (msec)   : 100=0.68%, 250=3.42%, 500=18.26%, 750=70.90%, 1000=5.37%
  lat (msec)   : 2000=1.37%
  cpu          : usr=1.00%, sys=0.52%, ctx=940, majf=0, minf=12
  IO depths    : 1=0.1%, 2=0.2%, 4=0.4%, 8=0.8%, 16=1.6%, 32=3.1%, >=64=93.8%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.9%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=0,1024,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: bw=113MiB/s (119MB/s), 113MiB/s-113MiB/s (119MB/s-119MB/s), io=1024MiB (1074MB), run=9035-9035msec

Disk stats (read/write):
  vde: ios=0/1003, merge=0/0, ticks=0/546503, in_queue=544356, util=98.31%
```

### SSD

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/ssd# fio -direct=1 -iodepth=64 -rw=write -ioengine=libaio -bs=1024k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Write_PPS_Testing  
Write_PPS_Testing: (g=0): rw=write, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=64
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [W(1)][100.0%][w=160MiB/s][w=160 IOPS][eta 00m:00s]
Write_PPS_Testing: (groupid=0, jobs=1): err= 0: pid=46578: Sun Jun 12 21:30:56 2022
  write: IOPS=192, BW=193MiB/s (202MB/s)(1024MiB/5314msec); 0 zone resets
    slat (usec): min=40, max=141, avg=104.56, stdev=16.47
    clat (msec): min=7, max=1010, avg=331.46, stdev=233.77
     lat (msec): min=7, max=1010, avg=331.56, stdev=233.77
    clat percentiles (msec):
     |  1.00th=[   11],  5.00th=[   43], 10.00th=[   61], 20.00th=[   72],
     | 30.00th=[  103], 40.00th=[  190], 50.00th=[  330], 60.00th=[  481],
     | 70.00th=[  531], 80.00th=[  558], 90.00th=[  600], 95.00th=[  642],
     | 99.00th=[  877], 99.50th=[  944], 99.90th=[ 1003], 99.95th=[ 1011],
     | 99.99th=[ 1011]
   bw (  KiB/s): min=137216, max=518144, per=99.74%, avg=196812.80, stdev=113225.78, samples=10
   iops        : min=  134, max=  506, avg=192.20, stdev=110.57, samples=10
  lat (msec)   : 10=0.78%, 20=1.37%, 50=4.69%, 100=22.36%, 250=15.04%
  lat (msec)   : 500=17.68%, 750=35.84%, 1000=2.05%, 2000=0.20%
  cpu          : usr=1.83%, sys=0.51%, ctx=906, majf=0, minf=11
  IO depths    : 1=0.1%, 2=0.2%, 4=0.4%, 8=0.8%, 16=1.6%, 32=3.1%, >=64=93.8%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.9%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=0,1024,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: bw=193MiB/s (202MB/s), 193MiB/s-193MiB/s (202MB/s-202MB/s), io=1024MiB (1074MB), run=5314-5314msec

Disk stats (read/write):
  vdd: ios=0/989, merge=0/0, ticks=0/310721, in_queue=308744, util=97.12%
```

### Bcache

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/bcache# fio -direct=1 -iodepth=64 -rw=write -ioengine=libaio -bs=1024k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Write_PPS_Testing  
Write_PPS_Testing: (g=0): rw=write, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=64
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [W(1)][100.0%][w=248MiB/s][w=248 IOPS][eta 00m:00s]
Write_PPS_Testing: (groupid=0, jobs=1): err= 0: pid=31595: Sun Jun 12 20:38:19 2022
  write: IOPS=227, BW=227MiB/s (238MB/s)(1024MiB/4506msec); 0 zone resets
    slat (usec): min=34, max=58672, avg=411.96, stdev=2338.14
    clat (usec): min=1800, max=1162.6k, avg=276781.27, stdev=293484.97
     lat (usec): min=1853, max=1162.7k, avg=277193.46, stdev=293299.34
    clat percentiles (msec):
     |  1.00th=[    3],  5.00th=[    3], 10.00th=[    4], 20.00th=[    8],
     | 30.00th=[   16], 40.00th=[   75], 50.00th=[   96], 60.00th=[  326],
     | 70.00th=[  514], 80.00th=[  592], 90.00th=[  684], 95.00th=[  785],
     | 99.00th=[  927], 99.50th=[ 1099], 99.90th=[ 1133], 99.95th=[ 1167],
     | 99.99th=[ 1167]
   bw (  KiB/s): min=112640, max=382976, per=100.00%, avg=246016.00, stdev=83988.96, samples=8
   iops        : min=  110, max=  374, avg=240.25, stdev=82.02, samples=8
  lat (msec)   : 2=0.68%, 4=9.86%, 10=13.77%, 20=9.28%, 50=2.73%
  lat (msec)   : 100=14.36%, 250=4.88%, 500=13.38%, 750=24.71%, 1000=5.37%
  lat (msec)   : 2000=0.98%
  cpu          : usr=1.98%, sys=0.71%, ctx=1195, majf=0, minf=13
  IO depths    : 1=0.1%, 2=0.2%, 4=0.4%, 8=0.8%, 16=1.6%, 32=3.1%, >=64=93.8%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.9%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=0,1024,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
  WRITE: bw=227MiB/s (238MB/s), 227MiB/s-227MiB/s (238MB/s-238MB/s), io=1024MiB (1074MB), run=4506-4506msec

Disk stats (read/write):
    bcache0: ios=0/1024, merge=0/0, ticks=0/241568, in_queue=241568, util=96.40%, aggrios=2/803, aggrmerge=0/15, aggrticks=13/128964, aggrin_queue=127310, aggrutil=87.01%
  vdb: ios=4/1117, merge=0/31, ticks=26/8336, in_queue=6008, util=18.33%
  vdc: ios=0/489, merge=0/0, ticks=0/249593, in_queue=248612, util=87.01%
```


## Sequential read throughput (read bandwidth) (1024 KB for single I/O):

### HDD

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/hdd# fio -direct=1 -iodepth=64 -rw=read -ioengine=libaio -bs=1024k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Read_PPS_Testing  
Read_PPS_Testing: (g=0): rw=read, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=64
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [R(1)][100.0%][r=63.1MiB/s][r=63 IOPS][eta 00m:00s]
Read_PPS_Testing: (groupid=0, jobs=1): err= 0: pid=43829: Sun Jun 12 21:20:58 2022
  read: IOPS=113, BW=114MiB/s (119MB/s)(1024MiB/9010msec)
    slat (usec): min=19, max=543, avg=58.05, stdev=99.67
    clat (msec): min=20, max=1291, avg=561.59, stdev=177.89
     lat (msec): min=21, max=1291, avg=561.65, stdev=177.83
    clat percentiles (msec):
     |  1.00th=[   24],  5.00th=[  292], 10.00th=[  397], 20.00th=[  401],
     | 30.00th=[  506], 40.00th=[  592], 50.00th=[  600], 60.00th=[  600],
     | 70.00th=[  609], 80.00th=[  693], 90.00th=[  701], 95.00th=[  793],
     | 99.00th=[ 1183], 99.50th=[ 1200], 99.90th=[ 1200], 99.95th=[ 1284],
     | 99.99th=[ 1284]
   bw (  KiB/s): min=106496, max=141312, per=99.48%, avg=115772.24, stdev=6873.69, samples=17
   iops        : min=  104, max=  138, avg=113.06, stdev= 6.71, samples=17
  lat (msec)   : 50=2.34%, 100=0.10%, 250=2.05%, 500=20.51%, 750=67.09%
  lat (msec)   : 1000=6.64%, 2000=1.27%
  cpu          : usr=0.00%, sys=0.87%, ctx=1008, majf=0, minf=16396
  IO depths    : 1=0.1%, 2=0.2%, 4=0.4%, 8=0.8%, 16=1.6%, 32=3.1%, >=64=93.8%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.9%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=1024,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=114MiB/s (119MB/s), 114MiB/s-114MiB/s (119MB/s-119MB/s), io=1024MiB (1074MB), run=9010-9010msec

Disk stats (read/write):
  vde: ios=1010/1, merge=0/0, ticks=547986/2, in_queue=545948, util=97.15%
```

### SSD

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/ssd# fio -direct=1 -iodepth=64 -rw=read -ioengine=libaio -bs=1024k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Read_PPS_Testing  
Read_PPS_Testing: (g=0): rw=read, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=64
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [R(1)][100.0%][r=159MiB/s][r=159 IOPS][eta 00m:00s]
Read_PPS_Testing: (groupid=0, jobs=1): err= 0: pid=46775: Sun Jun 12 21:31:37 2022
  read: IOPS=193, BW=193MiB/s (202MB/s)(1024MiB/5303msec)
    slat (usec): min=19, max=494, avg=53.43, stdev=100.29
    clat (msec): min=7, max=1001, avg=330.10, stdev=219.07
     lat (msec): min=7, max=1001, avg=330.16, stdev=219.03
    clat percentiles (msec):
     |  1.00th=[   17],  5.00th=[   25], 10.00th=[   36], 20.00th=[   61],
     | 30.00th=[  140], 40.00th=[  271], 50.00th=[  363], 60.00th=[  443],
     | 70.00th=[  510], 80.00th=[  542], 90.00th=[  567], 95.00th=[  600],
     | 99.00th=[  802], 99.50th=[  877], 99.90th=[  995], 99.95th=[ 1003],
     | 99.99th=[ 1003]
   bw (  KiB/s): min=135168, max=522240, per=99.54%, avg=196812.80, stdev=114697.96, samples=10
   iops        : min=  132, max=  510, avg=192.20, stdev=112.01, samples=10
  lat (msec)   : 10=0.29%, 20=2.54%, 50=13.57%, 100=9.96%, 250=12.30%
  lat (msec)   : 500=29.39%, 750=29.98%, 1000=1.86%, 2000=0.10%
  cpu          : usr=0.15%, sys=1.21%, ctx=992, majf=0, minf=16396
  IO depths    : 1=0.1%, 2=0.2%, 4=0.4%, 8=0.8%, 16=1.6%, 32=3.1%, >=64=93.8%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.9%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=1024,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=193MiB/s (202MB/s), 193MiB/s-193MiB/s (202MB/s-202MB/s), io=1024MiB (1074MB), run=5303-5303msec

Disk stats (read/write):
  vdd: ios=998/1, merge=0/0, ticks=312292/1221, in_queue=311528, util=98.06%
```

### Bcache

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/bcache# fio -direct=1 -iodepth=64 -rw=read -ioengine=libaio -bs=1024k -size=1G -numjobs=1 -runtime=1000 -group_reporting -filename=iotest -name=Read_PPS_Testing  
Read_PPS_Testing: (g=0): rw=read, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=64
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [R(1)][100.0%][r=224MiB/s][r=224 IOPS][eta 00m:00s]
Read_PPS_Testing: (groupid=0, jobs=1): err= 0: pid=32395: Sun Jun 12 20:41:11 2022
  read: IOPS=242, BW=243MiB/s (254MB/s)(1024MiB/4221msec)
    slat (usec): min=27, max=514, avg=121.84, stdev=121.42
    clat (usec): min=1466, max=1295.1k, avg=262159.07, stdev=299364.60
     lat (usec): min=1513, max=1295.2k, avg=262281.04, stdev=299397.16
    clat percentiles (usec):
     |  1.00th=[   1958],  5.00th=[   3294], 10.00th=[   5276],
     | 20.00th=[   8979], 30.00th=[  14091], 40.00th=[  29754],
     | 50.00th=[  66323], 60.00th=[ 287310], 70.00th=[ 501220],
     | 80.00th=[ 599786], 90.00th=[ 608175], 95.00th=[ 792724],
     | 99.00th=[1199571], 99.50th=[1199571], 99.90th=[1300235],
     | 99.95th=[1300235], 99.99th=[1300235]
   bw (  KiB/s): min=40960, max=481280, per=99.03%, avg=246016.00, stdev=170532.79, samples=8
   iops        : min=   40, max=  470, avg=240.25, stdev=166.54, samples=8
  lat (msec)   : 2=1.17%, 4=5.57%, 10=16.31%, 20=11.62%, 50=9.77%
  lat (msec)   : 100=9.47%, 250=5.18%, 500=11.13%, 750=24.12%, 1000=3.81%
  lat (msec)   : 2000=1.86%
  cpu          : usr=0.00%, sys=3.32%, ctx=969, majf=0, minf=16395
  IO depths    : 1=0.1%, 2=0.2%, 4=0.4%, 8=0.8%, 16=1.6%, 32=3.1%, >=64=93.8%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.9%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.1%, >=64=0.0%
     issued rwts: total=1024,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=64

Run status group 0 (all jobs):
   READ: bw=243MiB/s (254MB/s), 243MiB/s-243MiB/s (254MB/s-254MB/s), io=1024MiB (1074MB), run=4221-4221msec

Disk stats (read/write):
    bcache0: ios=1024/0, merge=0/0, ticks=246204/0, in_queue=246204, util=97.18%, aggrios=771/4, aggrmerge=27/0, aggrticks=131197/129, aggrin_queue=129770, aggrutil=87.49%
  vdb: ios=1069/7, merge=42/0, ticks=27769/4, in_queue=25584, util=21.23%
  vdc: ios=474/1, merge=12/0, ticks=234626/254, in_queue=233956, util=87.49%
```

## Random write latency (4 KB for single I/O):

### HDD
```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/hdd# fio -direct=1 -iodepth=1 -rw=randwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Write_Latency_Testing  
Rand_Write_Latency_Testing: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [w(1)][100.0%][w=9872KiB/s][w=2468 IOPS][eta 00m:00s]
Rand_Write_Latency_Testing: (groupid=0, jobs=1): err= 0: pid=43963: Sun Jun 12 21:23:04 2022
  write: IOPS=2460, BW=9844KiB/s (10.1MB/s)(1024MiB/106521msec); 0 zone resets
    slat (usec): min=5, max=151, avg= 8.81, stdev= 1.73
    clat (usec): min=224, max=17297, avg=396.30, stdev=285.22
     lat (usec): min=233, max=17305, avg=405.22, stdev=285.24
    clat percentiles (usec):
     |  1.00th=[  355],  5.00th=[  359], 10.00th=[  359], 20.00th=[  359],
     | 30.00th=[  363], 40.00th=[  363], 50.00th=[  363], 60.00th=[  367],
     | 70.00th=[  367], 80.00th=[  371], 90.00th=[  400], 95.00th=[  469],
     | 99.00th=[  922], 99.50th=[ 1532], 99.90th=[ 5276], 99.95th=[ 5997],
     | 99.99th=[ 7046]
   bw (  KiB/s): min= 8072, max=10376, per=100.00%, avg=9843.79, stdev=166.17, samples=213
   iops        : min= 2018, max= 2594, avg=2460.95, stdev=41.54, samples=213
  lat (usec)   : 250=0.01%, 500=96.87%, 750=1.97%, 1000=0.22%
  lat (msec)   : 2=0.55%, 4=0.16%, 10=0.22%, 20=0.01%
  cpu          : usr=1.10%, sys=4.69%, ctx=262178, majf=0, minf=11
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,262144,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
  WRITE: bw=9844KiB/s (10.1MB/s), 9844KiB/s-9844KiB/s (10.1MB/s-10.1MB/s), io=1024MiB (1074MB), run=106521-106521msec

Disk stats (read/write):
  vde: ios=0/261829, merge=0/0, ticks=0/100681, in_queue=2444, util=99.95%
```

### SSD
```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/ssd# fio -direct=1 -iodepth=1 -rw=randwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Write_Latency_Testing  
Rand_Write_Latency_Testing: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [w(1)][100.0%][w=22.7MiB/s][w=5804 IOPS][eta 00m:00s]
Rand_Write_Latency_Testing: (groupid=0, jobs=1): err= 0: pid=46918: Sun Jun 12 21:32:47 2022
  write: IOPS=5942, BW=23.2MiB/s (24.3MB/s)(1024MiB/44114msec); 0 zone resets
    slat (usec): min=3, max=140, avg= 5.03, stdev= 1.10
    clat (usec): min=91, max=19153, avg=162.13, stdev=312.44
     lat (usec): min=102, max=19159, avg=167.28, stdev=312.45
    clat percentiles (usec):
     |  1.00th=[  105],  5.00th=[  109], 10.00th=[  110], 20.00th=[  112],
     | 30.00th=[  114], 40.00th=[  116], 50.00th=[  118], 60.00th=[  121],
     | 70.00th=[  125], 80.00th=[  131], 90.00th=[  145], 95.00th=[  174],
     | 99.00th=[ 2507], 99.50th=[ 2802], 99.90th=[ 3064], 99.95th=[ 3163],
     | 99.99th=[ 3752]
   bw (  KiB/s): min=23064, max=31712, per=100.00%, avg=23770.82, stdev=1972.48, samples=88
   iops        : min= 5766, max= 7928, avg=5942.70, stdev=493.12, samples=88
  lat (usec)   : 100=0.01%, 250=97.56%, 500=0.77%, 750=0.09%, 1000=0.04%
  lat (msec)   : 2=0.16%, 4=1.36%, 10=0.01%, 20=0.01%
  cpu          : usr=2.77%, sys=8.62%, ctx=262160, majf=0, minf=10
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,262144,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
  WRITE: bw=23.2MiB/s (24.3MB/s), 23.2MiB/s-23.2MiB/s (24.3MB/s-24.3MB/s), io=1024MiB (1074MB), run=44114-44114msec

Disk stats (read/write):
  vdd: ios=0/260897, merge=0/0, ticks=0/38521, in_queue=96, util=99.81%
```

### Bcache

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/bcache# fio -direct=1 -iodepth=1 -rw=randwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Write_Latency_Testing  
Rand_Write_Latency_Testing: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
fio-3.16
Starting 1 process
Jobs: 1 (f=1): [w(1)][100.0%][w=10.8MiB/s][w=2775 IOPS][eta 00m:00s]
Rand_Write_Latency_Testing: (groupid=0, jobs=1): err= 0: pid=34735: Sun Jun 12 20:51:15 2022
  write: IOPS=2800, BW=10.9MiB/s (11.5MB/s)(1024MiB/93599msec); 0 zone resets
    slat (usec): min=5, max=6167, avg= 7.47, stdev=12.88
    clat (nsec): min=1881, max=28412k, avg=348379.63, stdev=1162452.56
     lat (usec): min=105, max=28419, avg=355.97, stdev=1162.47
    clat percentiles (usec):
     |  1.00th=[  106],  5.00th=[  109], 10.00th=[  111], 20.00th=[  113],
     | 30.00th=[  115], 40.00th=[  117], 50.00th=[  119], 60.00th=[  122],
     | 70.00th=[  126], 80.00th=[  133], 90.00th=[  153], 95.00th=[  231],
     | 99.00th=[ 6587], 99.50th=[ 6652], 99.90th=[ 6783], 99.95th=[ 6849],
     | 99.99th=[ 7504]
   bw (  KiB/s): min=10728, max=28582, per=100.00%, avg=11201.99, stdev=1359.72, samples=187
   iops        : min= 2682, max= 7145, avg=2800.49, stdev=339.90, samples=187
  lat (usec)   : 2=0.01%, 100=0.01%, 250=95.29%, 500=0.96%, 750=0.09%
  lat (usec)   : 1000=0.04%
  lat (msec)   : 2=0.05%, 4=0.04%, 10=3.52%, 20=0.01%, 50=0.01%
  cpu          : usr=1.23%, sys=4.89%, ctx=262172, majf=0, minf=12
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,262144,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
  WRITE: bw=10.9MiB/s (11.5MB/s), 10.9MiB/s-10.9MiB/s (11.5MB/s-11.5MB/s), io=1024MiB (1074MB), run=93599-93599msec

Disk stats (read/write):
    bcache0: ios=0/261570, merge=0/0, ticks=0/89268, in_queue=89268, util=99.93%, aggrios=35/132554, aggrmerge=0/0, aggrticks=85/45471, aggrin_queue=19554, aggrutil=99.72%
  vdb: ios=70/265033, merge=0/0, ticks=171/90911, in_queue=39108, util=99.72%
  vdc: ios=0/76, merge=0/0, ticks=0/32, in_queue=0, util=0.22%
```

## Random read latency (4KB for single I/O):

### HDD

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/hdd# fio -direct=1 -iodepth=1 -rw=randread -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Read_Latency_Testingrandwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Write_Latency_Testing  
Rand_Read_Latency_Testingrandwrite: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
Rand_Write_Latency_Testing: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
fio-3.16
Starting 2 processes
Jobs: 2 (f=3): [r(2)][99.5%][r=9865KiB/s][r=2466 IOPS][eta 00m:01s]
Rand_Read_Latency_Testingrandwrite: (groupid=0, jobs=2): err= 0: pid=44684: Sun Jun 12 21:27:29 2022
  read: IOPS=2463, BW=9854KiB/s (10.1MB/s)(2048MiB/212817msec)
    slat (usec): min=4, max=664, avg= 9.15, stdev= 3.37
    clat (nsec): min=1902, max=77096k, avg=800489.27, stdev=5591447.93
     lat (usec): min=94, max=77104, avg=809.78, stdev=5591.43
    clat percentiles (usec):
     |  1.00th=[  212],  5.00th=[  223], 10.00th=[  229], 20.00th=[  235],
     | 30.00th=[  241], 40.00th=[  245], 50.00th=[  249], 60.00th=[  255],
     | 70.00th=[  265], 80.00th=[  273], 90.00th=[  310], 95.00th=[  478],
     | 99.00th=[ 2507], 99.50th=[62129], 99.90th=[65799], 99.95th=[66323],
     | 99.99th=[67634]
   bw (  KiB/s): min= 8400, max=11568, per=100.00%, avg=9855.77, stdev=152.54, samples=849
   iops        : min= 2100, max= 2892, avg=2463.94, stdev=38.13, samples=849
  lat (usec)   : 2=0.01%, 4=0.01%, 100=0.05%, 250=50.96%, 500=44.28%
  lat (usec)   : 750=1.35%, 1000=0.53%
  lat (msec)   : 2=1.34%, 4=0.65%, 10=0.01%, 20=0.02%, 50=0.01%
  lat (msec)   : 100=0.80%
  cpu          : usr=0.53%, sys=2.25%, ctx=524435, majf=0, minf=30
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=524288,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=9854KiB/s (10.1MB/s), 9854KiB/s-9854KiB/s (10.1MB/s-10.1MB/s), io=2048MiB (2147MB), run=212817-212817msec

Disk stats (read/write):
  vde: ios=523878/6, merge=0/0, ticks=418484/103, in_queue=258060, util=99.99%
```

### SSD

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/ssd# fio -direct=1 -iodepth=1 -rw=randread -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Read_Latency_Testingrandwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Write_Latency_Testing  
Rand_Read_Latency_Testingrandwrite: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
Rand_Write_Latency_Testing: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
fio-3.16
Starting 2 processes
Jobs: 2 (f=3): [r(2)][100.0%][r=22.6MiB/s][r=5790 IOPS][eta 00m:00s]
Rand_Read_Latency_Testingrandwrite: (groupid=0, jobs=2): err= 0: pid=47204: Sun Jun 12 21:34:33 2022
  read: IOPS=5869, BW=22.9MiB/s (24.0MB/s)(2048MiB/89324msec)
    slat (usec): min=3, max=556, avg= 5.68, stdev= 1.88
    clat (usec): min=26, max=15148, avg=333.61, stdev=645.73
     lat (usec): min=61, max=15158, avg=339.41, stdev=645.71
    clat percentiles (usec):
     |  1.00th=[  151],  5.00th=[  159], 10.00th=[  167], 20.00th=[  176],
     | 30.00th=[  184], 40.00th=[  194], 50.00th=[  206], 60.00th=[  215],
     | 70.00th=[  225], 80.00th=[  241], 90.00th=[  289], 95.00th=[  461],
     | 99.00th=[ 4015], 99.50th=[ 4178], 99.90th=[ 4424], 99.95th=[ 4555],
     | 99.99th=[ 5800]
   bw (  KiB/s): min=21280, max=33592, per=100.00%, avg=23481.21, stdev=829.00, samples=356
   iops        : min= 5320, max= 8398, avg=5870.30, stdev=207.25, samples=356
  lat (usec)   : 50=0.01%, 100=0.26%, 250=83.00%, 500=12.11%, 750=0.99%
  lat (usec)   : 1000=0.21%
  lat (msec)   : 2=0.17%, 4=2.20%, 10=1.07%, 20=0.01%
  cpu          : usr=1.33%, sys=4.24%, ctx=524385, majf=0, minf=31
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=524288,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=22.9MiB/s (24.0MB/s), 22.9MiB/s-22.9MiB/s (24.0MB/s-24.0MB/s), io=2048MiB (2147MB), run=89324-89324msec

Disk stats (read/write):
  vdd: ios=523312/4, merge=0/0, ticks=171968/2, in_queue=21980, util=99.93%
```

### Bcache

```
root@iZk1afu8yjxaqjmtrmahbnZ:/mnt/bcache# fio -direct=1 -iodepth=1 -rw=randread -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Read_Latency_Testingrandwrite -ioengine=libaio -bs=4k -size=1G -numjobs=1 -group_reporting -filename=iotest -name=Rand_Write_Latency_Testing  
Rand_Read_Latency_Testingrandwrite: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
Rand_Write_Latency_Testing: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
fio-3.16
Starting 2 processes
Jobs: 2 (f=3): [r(2)][100.0%][r=10.9MiB/s][r=2800 IOPS][eta 00m:00s]
Rand_Read_Latency_Testingrandwrite: (groupid=0, jobs=2): err= 0: pid=37565: Sun Jun 12 21:02:55 2022
  read: IOPS=2816, BW=11.0MiB/s (11.5MB/s)(2048MiB/186166msec)
    slat (usec): min=5, max=3104, avg= 9.05, stdev= 6.98
    clat (usec): min=2, max=21465, avg=699.65, stdev=1732.36
     lat (usec): min=69, max=21482, avg=708.85, stdev=1732.14
    clat percentiles (usec):
     |  1.00th=[  157],  5.00th=[  167], 10.00th=[  174], 20.00th=[  184],
     | 30.00th=[  192], 40.00th=[  204], 50.00th=[  215], 60.00th=[  223],
     | 70.00th=[  235], 80.00th=[  258], 90.00th=[  379], 95.00th=[ 6849],
     | 99.00th=[ 7177], 99.50th=[ 7308], 99.90th=[ 7439], 99.95th=[ 7635],
     | 99.99th=[12256]
   bw (  KiB/s): min= 9496, max=35544, per=100.00%, avg=11264.23, stdev=640.38, samples=744
   iops        : min= 2374, max= 8886, avg=2816.05, stdev=160.10, samples=744
  lat (usec)   : 4=0.01%, 100=0.03%, 250=78.01%, 500=13.47%, 750=1.09%
  lat (usec)   : 1000=0.21%
  lat (msec)   : 2=0.11%, 4=0.03%, 10=7.04%, 20=0.01%, 50=0.01%
  cpu          : usr=0.61%, sys=2.60%, ctx=524460, majf=0, minf=31
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=524288,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=11.0MiB/s (11.5MB/s), 11.0MiB/s-11.0MiB/s (11.5MB/s-11.5MB/s), io=2048MiB (2147MB), run=186166-186166msec

Disk stats (read/write):
    bcache0: ios=524216/6, merge=0/0, ticks=361164/64, in_queue=361228, util=99.99%, aggrios=262146/16, aggrmerge=0/0, aggrticks=182129/30, aggrin_queue=74574, aggrutil=99.96%
  vdb: ios=524293/20, merge=0/0, ticks=364259/56, in_queue=149148, util=99.96%
  vdc: ios=0/12, merge=0/0, ticks=0/4, in_queue=0, util=0.02%
```

## Conclusion
- In some case, Bcache performance is almost the same as ssd (Random write/read) because the cache device only have (2800 IOPS) meanwhile the ssd have (5800 IOPS) so the bcache performance dependent on the cache device
- Bcache has better performance at Sequential write/read throughput
- Bcache performance in Random write/read latency was dependent on cache device, just like point 1
- Bcache can reduce half cost of disk usage, as example, if you want to create 100GB partition with high throughput & high IOPS you can create 100GB ultra disk ($3.070) and then create around 25GB ssd ($3.230) that will cost = $6.3/month rather than create 100GB ssd will cost you $12.9/month