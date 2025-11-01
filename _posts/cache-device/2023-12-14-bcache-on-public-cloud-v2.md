---
layout: post
title:  "Improving IOPS in public cloud and reduce cost with bcache V2"
categories: tips storage infrastructure public_cloud
image: https://storage.humanz.moe/humanz-blog/GffkM_hboAAlsVm.jpeg
img_path: ../../assets/img/Public_cloud
---
Actually i'm already created this post in past but at that post i admit it if i didn't explain it clearly just showing some config then fio test also i didn't show the result of Cost optimization, so yeah at this time i will retest it and explain it more details.


my main motive to create this was because of this [paper](https://ieeexplore.ieee.org/abstract/document/9644017)

![paper](Aws/EBS/1.png)

in that abstract its was writen **"technique outperforms Linux bcache by up to 3.35 times within specified cost constraints"** but sadly i didn't have the full pdf of paper.

First let's talk about Bcache or Caching device.....

tl;dr it's was idea when the SSD was not very common thing and mainly servers use HDD for thier storage and some people want achive SSD peformance but with cheap price and large size so they create a cache device and bcache was one of them, maybe you already hear about intel Optane? yeah that is one example of Caching device from intel. for more you can read it in bcache [homepage](https://bcache.evilpiepirate.org)


So Caching device was invented because of pricy of SSD(or fast device). so the situation was pretty same like cloud nowdays where the price of fast device is kinda scary if you not aware of it.


### Setup
In this lab i will use AWS for testing, here the specification

owh wait.. just let me greb the terraform file.

```
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "eu-north-1"
}

variable "cache_dev_size" {
        description = "Size of cache device"
        default = 32
}

variable "backing_dev_size" {
        description = "Size of backing device"
        default = 1000
}

locals {
  bcache_setup = templatefile("${path.module}/bcache.sh", {
    cache_size = "${var.cache_dev_size}"
    back_size = "${var.backing_dev_size}"
  })
}


resource "aws_instance" "bcache" {
  ami = "ami-0fe8bec493a81c7da"
  instance_type = "t3.medium"
  key_name = "humanz"
  user_data = local.bcache_setup #"${file("bcache.sh")}"
  root_block_device {
    delete_on_termination = true
    volume_size = 8
    volume_type = "gp3"
  }

  ebs_block_device {
    device_name = "/dev/sdb"
    iops = 16000
    throughput = 1000
    delete_on_termination = true
    volume_size = var.cache_dev_size
    volume_type = "gp3"
  }


  ebs_block_device {
    device_name = "/dev/sdc"
    delete_on_termination = true
    volume_size = var.backing_dev_size
    volume_type = "st1"
  }

}
```
If you are already experienced with terraform stuff you should know what type of instance I have created, but i thing is AWS have storage tier like SSD, Faster SSD, More faster SSD

a quick brief, AWS have four fast device type
- gp2
- gp3
- io
- io2 Block Express

And for the slow device is
- st
- hdd

i don't want to explain it one by one but gp2 was like the old one and they still use burst performance for thier IOPS&throughput meanwhile the gp3 was more newest and not use burst performance, gp3 only use baseline performance, io devices is pricy af so i skip it 

### Cache Device
i choice gp3 because gp3 have simple rule :
- maximum IOPS is 16000k
- maximum throughput 1000MiB/s
- every 1GiB size you can increase 500 IOPS

from that rule i just need to create a gp3 volume with 32 GiB size where 32 is come from (MAX IOPS / IOPS every 1GiB)

### Backing Device
for this one i use st, but st was not like gp3 st more like gp2 who still using burst performance for thier IOPS&Throughput

the rule kinda complex, volume with 1TiB size have 40MiB/s baseline and have 250MiB/s burst throughput, burst throughput it's self have limit or more like burst throughput have credit for earch IOPS each volume have 1TiB burst throughput credit after the burst throughput credit was 0 the performance back using baseline throughput which is 40MiB/s. little bit confusing but let me make it more easy to undetstand

1 TiB st volume have burst throughput which is make the throughput performance will reach 250MiB/s but if the burst throughput credit empty the throughput performance will reduce to 40MiB/s.


### Bcache
Time to setup

- `apt install bca--wait wait wait`  
why i'm keep doing this, just read the cloud-init [user-script](https://github.com/JustHumanz/public-cloud-dojo/blob/master/block_storage/vm/bcache.sh) 

the important thing maybe is :
- i use writeback as cache_mode
- i disabled sequential_cutoff 


### Testing
In here i'll test with two method
- Random Read
- Random Write

First let's collect the IOPS baseline for cache&back dev


Ah btw here the fio command:

Random Write : 

```
sudo fio --name=write_iops --directory=/dev/<device dir> --size=10G --time_based --runtime=60s --ramp_time=2s --ioengine=libaio --direct=1 --verify=0 --bs=4K --iodepth=256 --rw=randwrite --group_reporting=1  --iodepth_batch_submit=256  --iodepth_batch_complete_max=256
```

Random Read : 

```
sudo fio --name=read_iops --directory=/dev/<device dir> --size=10G --time_based --runtime=60s --ramp_time=2s --ioengine=libaio --direct=1 --verify=0 --bs=4K --iodepth=256 --rw=randread --group_reporting=1  --iodepth_batch_submit=256  --iodepth_batch_complete_max=256
```

a little explanation:
- `--directory=/dev/<device dir>` the device directory # **DON'T RUN LIKE THIS IN PROD OR DEVICE WHO ALREADY HAVE FILESYSTEM**, i'm running it whitout any filesystem so the result was pure 
- `--size=10G` it's will create a byte buffer with 10G size
- `--direct=1` the IO operation will ignore any OS cache(i.e: diry pages)
- `--bs=4K` i use 4K or 4Kib for block size since 4K bs is general in linux filesystem


### Result

IOPS  
![IOPS](Aws/EBS/chart.png)  
*More higher more better*

Throughput  
![throughput](Aws/EBS/chart%20(1).png)  
*More higher more better*

Latency  
![lat](Aws/EBS/chart%20(2).png)  
*More lower more better*

And the result was bcache really can improve the Random Write IOPS(?) tbh i don't expect about this one, bcache won even against the cache device it's self, well yeah the read was not really improve since we use `writeback`

for full result you can see it on [this link](https://docs.google.com/spreadsheets/d/1LB04A1-HCSbQ23IZIEyDr3eumjrkMN8O-znvCmJosOw/edit?usp=sharing)

### Cost Optimization
Just like i said early cost optimization is one of my goal for this test, now let's we calc it.

|Storage Type|Size|IOPS|Throughput|Price|
|---|---|---|---|---|
|Backing Storage(st)|1 TiB|250|250 MiB/s|$48.64|
|Cache Storage(gp3)|36GiB|16000|1000 MiB/s|$107.19|

$48.64 + $107.19 = **$155.83**

So from 1TiB Bcache we got **$155.83** now let's try to create storage with gp3 type and 1TiB size

|Storage Type|Size|IOPS|Throughput|Price|
|---|---|---|---|---|
|Cache Storage(gp3)|36GiB|16000|1000 MiB/s|$189.79|

And 1TiB gp3 is **$189.79**

so $189.79 - $155.83 = **$33.96**

Yep, I just cut a cost around $30/month, wait wait wait this only if i create 1TiB how if i create let say 5TiB

1TiB gp3 is $189.79 so $189.79*5 = **$948.94**

1TiB st is $48.64 so $48.64*5 = **$243.2** then add the cache $243.2+$107.19 = **$350.39**

and now $948.94 - $350.39 = **$598.55**

So i just save around $600/month for 5TiB volume.

for full result you can see it on [this link](https://docs.google.com/spreadsheets/d/1LB04A1-HCSbQ23IZIEyDr3eumjrkMN8O-znvCmJosOw/edit?usp=sharing)


### Cons
I admit it, bcache have some problem

Especially in resize the backing device, when you are using bcache you cannot just increase trough the aws panel after that run the growpart because the bcache doesn't update thier block sector after growpart the way to update block sector is to attach/dettach the bcache state or reboot the instance, in another world yes you need down time when resize the bcache size 

Idk but look like LVM cache can solve this issues

## Summary
Bcache really can improve the IOPS meanwhile make the cost more lower but not on all scoop, only some scoop like write operation 

Bcache was hard and not beginner friendly especially someone who doesn't understand or newbie in linux, so if you want to implement this one you need a solid team or at least rich experience in linux