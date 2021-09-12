---
layout: post
title:  "Setup gitlab runner secara manual di k8s"
categories: cicd,gitlab,k8s,devops
---
## Setup gitlab runner secara manual di k8s
<p align="center">
  <img src="https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/Humanz/Nyanpasuu.jpg"/>
  Nyanpasuu
</p>
Setup gitlab runner secara manual di k8s,seperti judulnya kali ini saya akan membahas cara setup runner secara manual,tapi kenapa manual? 
seperti yang terlampir di [sysadmin survival guide](https://techbeacon.com/devops/how-stay-relevant-devops-era-sysadmins-survival-guide) 
`You cannot automate what you can’t understand` so kita langsung ke pembahasan saja  

pertama cari gitlab token dan register urlnya yang terletak di `repo > settings > CI/CD > Runners`  
![token_register](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/runner/token-url.png)  
harap sesuaikan token dan gitlab urlnya   
lalu download default value untuk gitlab runnernya  `wget https://gitlab.com/gitlab-org/charts/gitlab-runner/-/raw/master/values.yaml`  
![download_val](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/runner/download-val.png)  
jika sudah silahkan buka dan masukan token dan gitlab urlnya  
![set_token](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/runner/set-token-url.png)  
lalu scroll kebawah sampai ketemu `rbac` dan set valuenya seperti ini   
![val_conf](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/runner/val-conf.png)  

selanjutnya adalah membuat `service account` dengan command `kubectl create serviceaccount gitlab-runner`  
![create_acc](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/runner/create-account-service.png)  

nah lalu install gitlab runner via `helm` dengan value yang sudah di save tersebut `helm install gitlab-runner -f ./values.yaml gitlab/gitlab-runner`  
![install_runner](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/runner/install%20via%20helm.png)  

jika sudah kita bisa verifikasi apakah runner sudah jalan atau belum,kita bisa lihat di `repo > settings > CI/CD > Runners` dan sedikt scroll kebawah  
![done_runner](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/runner/done-one.png)  
dan bingo,runner sudah terpasang   

#### Optional

jika ingin menambahkan `tags` di runner bisa edit value.yaml dan lalukan `upgrade` via helm,
pertama tambahkan `tags` yang diinginkan,contohnya seperti ini   
![done_runner](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/runner/add-tags.png)  
lalu lakukan `upgrade` dengan command `helm upgrade gitlab-runner -f ./values.yaml gitlab/gitlab-runner` kemudian cek kembali di gitlab runners  
![done_tags](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/runner/after-upgrade.png)  