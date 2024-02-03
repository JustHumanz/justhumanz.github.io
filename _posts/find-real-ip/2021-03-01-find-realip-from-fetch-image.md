---
layout: post
title:  "Find real ip address from fetch image"
categories: tips security
---
## Find real ip address from fetch image
<p align="center">
  <img src="https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/Humanz/Nyanpasuu.jpg"/>
  Nyanpasuu
</p>
hallo kali ini saya akan memberikan sedikit `tips` untuk mencari real ip yang dihide oleh cloudflare,well seperti yang kita tahu bawa cloudflare akan menghide real ip address dan menggantinya dengan ip address milik cloudflare.  


Hal pertama yang harus ada adalah target memiliki fitur `fetch image` dan yang kedua harus memiliki `web service`,ok langsung ke contohnya  

Sebagai contoh disini saya akan memakain `danbooru.donmai.us` sebagai target.  
![danbooru.donmai.us using cloudflare](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/Humanz/danbooru-cloudflare.png)


Seperti hal biasanya,buat akun danbooru karena fitur fetch image hanya ada di user  
setelah membuat akun bisa langsung ke bagian [post](https://danbooru.donmai.us/uploads/new) lalu disana ada fitur `source` nah disini kita bisa memanfaatkannya untuk mendapatkan real ip address  
![danbooru.donmai.us source](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/Humanz/danbooru-source.png)  
nah disana kita masukan url dari web service kita,disini saya pakai `https://cdn.humanz.moe/kanowangyy.png` sebagai end point yang akan di request oleh danbooru dan menggunakkan grep di `web service` sebagai filternya  
![danbooru.donmai.us source](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/Humanz/danbooru-wangyy.png)  
tunggu beberapa saat,lalu coba baca lognya lagi  
![danbooru.donmai.us result](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/Humanz/danbooru-result.png)  
itu terlihat bahawa Danbooru melakukan http request ke `web service` saya,dan jika diperhatikan lagi ip tersebut berasal dari `147.135.10.29` yang dimana ip `147.135.10.29` adalah ip real dari website danbooru,untuk pengetesan saya akan langsung access danbooru by ip address  


![danbooru.donmai.us access by ip](https://raw.githubusercontent.com/JustHumanz/jekyll-klise/master/assets/img/Humanz/danbooru-byip.png)  
dan bingo,ip `147.135.10.29` adalah real ip dari danbooru.donmai.us



