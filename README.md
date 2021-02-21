# msfukui.page

msfukui's website by Hugo and Minimal.

## Setup

Install Hugo (https://gohugo.io/getting-started/installing/) for macOS.

```
$ sudo port install hugo
...
```

## Post a content

Example of posting xxx.md:

```
$ hugo new posts/xxx.md
/Users/msfukui/msfukui.page/content/posts/xxx.md created
$ cat content/posts/xxx.md
---
title: "Xxx"
date: 2021-02-20
tags: []
draft: true
---
```

And edit `content/posts/xxx.md`.

If you want to check the operation at local:

```
$ hugo server -D
```

And go to `http://localhost:1313`.

(`-D` is include content marked as draft.)

## Publish

...

## Reference

* Quick Start | Hugo

    https://gohugo.io/getting-started/quick-start/

* 静的サイトジェネレータ「Hugo」と技術文書公開向けテーマ「Docsy」でOSSサイトを作る | さくらのナレッジ

    https://knowledge.sakura.ad.jp/22908/

* ブログをGKEでの運用に移行した | tsub's blog

    https://blog.tsub.me/post/operate-blog-server-on-gke/

* Dockerを使用したNGINXとNGINX Plusのデプロイ | NGINX

    https://www.nginx.co.jp/blog/deploying-nginx-nginx-plus-docker/
