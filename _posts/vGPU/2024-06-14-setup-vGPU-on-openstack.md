---
layout: post
title:  "Setup Nvidia vGPU on Openstack"
categories: nvidia vGPU openstack
image: https://storage.humanz.moe/humanz-blog/75c40aa35d0ff6191170655459f89a92bd42eea3_s2_n3_y1.png
img_path: ../../assets/img/vgpu
---


hello folks, it's very loooooooong time since I wrote article.

this time i'll write about how setup Nvidia vGPU on openstack the motivation why I'm writing about this one is because there are not many blogs or walkthroughs that write setup vgpu in OpenStack with the proper way, ok let's beguin 


first, you need to know if your GPU support vgpu or not you can check it on nvidia developer page [grid-vgpu-17.0](https://docs.nvidia.com/grid/17.0/grid-vgpu-release-notes-generic-linux-kvm/index.html)

<details>
  <summary>A little tip</summary>
  
    if you only have desktop gpu you can try https://gitlab.com/polloloco/vgpu-proxmox or if you already have datacenter gpu but not in grid-vgpu list try to change ge grid-vgpu version, nvidia sometimes drop the vgpu support in newer version (in my case nvidia A30 was drop the vgpu support on grid 16.0)
    
</details>

if you already sure if your gpu was support vgpu then you need to download the driver, you can get the driver from [here](https://nvid.nvidia.com/login) 

![nvidia-dashboard](1.png)

if you use ubuntu you can filter it but if you use another OS you can download the Linux KVM and make sure the product version was same with the grid-vgpu.

download it and copy on the host, from that file you will get **Guest_Drivers** and **Host_Drivers**

![nvidia-driver](2.png)

next you can install it with dpkg

![install-nvidia-driver](3.png)

if the `nvidia-smi` was working next is enabeling **iommu**, to enable **iommu** you need edit the grub config on linux and bios

go to `/etc/default/grub` and then add `amd_iommu=on` in `GRUB_CMDLINE_LINUX_DEFAULT` if you use intel processor then use `intel_iommu=on`

![iommu-grub](4.png)

enabling iommu from bios was dependent on vendor hardware in my case I use supermirco and here are the [steps](https://www.supermicro.com/support/faqs/faq.cfm?faq=31883)

![iommu-bios](5.png)

then reboot it.


to verify if the iommu already enable or not you can check from kernel message

![iommu-msg](6.png)

now the iommu was running and next is config the nvidia vgpu and the last is config nova.

secound, you need to enable nvidia SR-IOV.

![nvidia-pci](7.png)

get the nvidia PCI address and make sure the kernel driver in use is nvidia (you can disable nouveau)

![nvidia-sr-iov](8.png)

enable the VF on that PCI address.

you can check if the VF already created or not by see the kernel message `dmesg | grep iommu` or `lspci | grep NVIDIA`

now let's check the nvidia profile

![mdevctl](9.png)

that was the example if nvidia mdev profile very gpu type should have different profile (mine is nvidia A30), let me explain little bit.

on that pic bus id `0000:41:00.4` was have 9 type but the **Available instances: 1** only upon type **nvidia-688** that mean the nvidia type **nvidia-689/690/691** was not supported on this gpu (maybe cuz the driver? i'm not very know about this one) 

The important thing is that one GPU can only support one type.


and the last part is config the nova, let's add the nova config on gpu compute

```bash
nano /etc/kolla/config/nova/jk1osgpu01/nova.conf

[devices]
enabled_mdev_types = nvidia-688

[mdev_nvidia-688]
device_addresses = 0000:41:00.4,0000:81:00.4
mdev_class = CUSTOM_VGPU_24G
```
you can create more than one type if you have two gpu, here the example
```
[devices]
enabled_mdev_types = nvidia-688, nvidia-687

[mdev_nvidia-688]
device_addresses = 0000:41:00.4
mdev_class = CUSTOM_VGPU_24G

[mdev_nvidia-687]
device_addresses = 0000:81:00.4,0000:81:00.5
mdev_class = CUSTOM_VGPU_12G

```


after that reconfig with kolla ansible

```
kolla-ansible -i multinode deploy --limit jk1osgpu01 -t nova
```

and the last part is create a flavor for vgpu vm

![flavor](10.png)


let's create vm and install the nvidia driver

![create vm](11.png)


![install nvidia](12.png)

for the nvidia driver you should use the installer from **Guest_Drivers** also the VM driver version is should same with host