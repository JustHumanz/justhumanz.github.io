---
layout: post
title:  "Playing with kctf,secure and scalable infrastructure for ctf competition 1"
categories: security ctf infrastructure
img_path: ../../assets/img/kctf/
---

kctf atau singkatan dari kubernetes-ctf adalah sebuah tools orchestration untuk ctf infrastruktur,kctf sendiri di rintis oleh [google project](https://github.com/google/kctf)  

kegunaan kctf sendiri sangat lengkap,mulai dari securty,availability, dan scalability selain itu cara kerja kctf yang menggunakkan `sanbox` yang berfungsi untuk `mengisolasi` setiap pemain dan chall yang ada


#### Sanbox
Kctf menggunakkan sanbox untuk setiap chall yang disetup,sanbox yang digunnakan untuk mengisolasi setiap challnya adalah [nsjail](https://github.com/google/nsjail) secara singkatnya nsjail yang bertugas buat [isolasi](https://github.com/google/nsjail#what-forms-of-isolation-does-it-provide) linux yang berisi chall

"terus apa bedanya sama docker yang sama sama `ngisolasi`?"

Kerennya disini bray,si kctf ini bakal ngebagi biar 1 chall cuman buat 1 orang,karena kctf bakal ngebuat `sanbox` baru setiap ada tcp koneksi baru  
misal nih ada chall A yang gak sengaja di rusak sama si bebek,nah pas orang lain mau akses challnya challnya bakal ok ok aja,gak ada yang rusak karena yang dirusak sama si bebek itu sanboxnya punya dia,jadi setiap tcp koneksi bakal punya challnya sendiri jadi misalkan challnya rusak atau pesertanya mau ganggu peserta lain bakal bisa terhindar


### Deployment
Kctf walaupun berbasis kubernetes tapi gak butuh pengalaman kubernetes,kctf sudah didesign untuk umum,commandnya sudah build-in jadi tidak perlu cek dokumentasi kubernetes setiap mau deploy  
tapi jika kamu memang  kubernetes professional kctf juga bisa di operasikan seperti kubernetes pada umumnya,misalnya menggunakkan manifest untuk deploymen servicenya


### Challenge support
Kctf support untuk pwd,web, dan xss kalau dari pengalaman saya baru coba yang web  
untuk web kctf bisa di setting untuk web app(apache+php) atau web service(golang,nodejs)

### PoC
untuk PoC berbentuk video sudah pernah saya buat di [fb](https://web.facebook.com/kaitothethief/videos/346369657014412) saya,tapi untuk lebih jelasnya saya jabarkan disini saja  

1. pertama enable umask  
    `umask a+rx`  

2. terus install dependencies,dependenciesnya ada
    ```
    xxd
    wget
    curl
    netcat
    docker
    ```
    sesuaikan sama distro yang dipakai,kalau sudah install skip aja

3. enable user namespace
    `echo 'kernel.unprivileged_userns_clone=1' | sudo tee -a /etc/sysctl.d/00-local-userns.conf`  
    terus restart procpsnya `sudo service procps restart`

4. install kctf
    ```
    mkdir ctf-directory && cd ctf-directory
    curl -sSL https://kctf.dev/sdk | tar xz
    source kctf/activate
    ```

5. buat local `cluster`
    ```kctf cluster create local-cluster --start --type kind```

6. buat test chall
    ```
    kctf chal create chall-test --template web`
    cd chall-test
    ```
    disana ada `challenge.yaml` sebagai manifestnya  
    ```
    apiVersion: kctf.dev/v1
    kind: Challenge
    metadata:
    name: chall-test
    spec:
    deployed: true
    powDifficultySeconds: 0
    network:
        public: false
        ports:
        - protocol: "HTTPS"
            targetPort: 1337
    healthcheck:
        # TIP: disable the healthcheck during development
        enabled: true    
    ```  
    bisa dilihat untuk manifestnya,seperti nama challnya lalu port yang dituju,lanjut start challnya
    ``kctf chal start``  
    tunggu beberapa menit,karena kctf sedang membuild image,kalau sudah forward portnya biar bisa diakses
    ```kctf chal debug port-forward --local-port 2525```  
    langsung buka ae port 2525 di lokal  
    ![1.png](1.png)     
    disana kelihatan kalau kerenel yang dipake adalah `NSJAIL`

7. check kctf
    ```cd challenge```  
    terus buka vscode disana dan mulai oprek oprek sendiri
         


Ref: https://google.github.io/kctf/         