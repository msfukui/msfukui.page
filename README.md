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

Build the content, build the container image, push and deploy.

### Build the content

```
$ hugo
Start building sites …

                   | EN
-------------------+-----
  Pages            | 16
  Paginator pages  |  0
  Non-page files   |  0
  Static files     |  2
  Processed images |  0
  Aliases          |  5
  Sitemaps         |  1
  Cleaned          |  0

Total in 23 ms
```

### Build the container image

#### Login to container registry (ghcr.io)

You need to install docker and issue a github token for accessing the repository in advance.

Assuming the access token is stored at the end of `.netrc`:

```
$ tail -1 ~/.netrc | awk '{ print $2; }' | docker login ghcr.io -u msfukui --password-stdin
Login Succeeded
```

#### Setup to cross-build the image

To run on a cluster of ras-pi with linux/arm64 architecture, use `docker buildx` to do a cross build on macos.

```
$ docker buildx ls
NAME/NODE DRIVER/ENDPOINT STATUS  PLATFORMS
default * docker
  default default         running linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6
$ docker buildx create --name pitanetes_builder
pitanetes_builder
$ docker buildx use pitanetes_builder
$ docker buildx inspect --bootstrap
[+] Building 15.7s (1/1) FINISHED
 => [internal] booting buildkit                                 15.7s
 => => pulling image moby/buildkit:buildx-stable-1              15.0s
 => => creating container buildx_buildkit_pitanetes_builder0     0.7s
Name:   pitanetes_builder
Driver: docker-container

Nodes:
Name:      pitanetes_builder0
Endpoint:  unix:///var/run/docker.sock
Status:    running
Platforms: linux/amd64, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/arm/v7, linux/arm/v6
```

#### Build & Push

```
$ docker buildx use pitanetes_builder
$ docker buildx build --platform linux/arm64 -t ghcr.io/msfukui/msfukui.page . --push
[+] Building 12.7s (12/12) FINISHED
 => [internal] load build definition from Dockerfile                               0.0s
 => => transferring dockerfile: 32B                                                0.0s
 => [internal] load .dockerignore                                                  0.0s
 => => transferring context: 2B                                                    0.0s
 => [internal] load metadata for docker.io/library/nginx:latest                    1.7s
 => [1/6] FROM docker.io/library/nginx@sha256:b0********79                         0.0s
 => => resolve docker.io/library/nginx@sha256:b0********79                         0.0s
 => [internal] load build context                                                  0.0s
 => => transferring context: 2.12kB                                                0.0s
 => CACHED [2/6] RUN rm /etc/nginx/nginx.conf /etc/nginx/conf.d/default.conf       0.0s
 => CACHED [3/6] COPY public /usr/share/nginx/html                                 0.0s
 => CACHED [4/6] COPY docker/nginx/conf /etc/nginx                                 0.0s
 => CACHED [5/6] RUN find /usr/share/nginx/html -type d -exec chmod o+rx {} +      0.0s
 => CACHED [6/6] RUN find /usr/share/nginx/html -type f -exec chmod o+r  {} +      0.0s
 => exporting to image                                                            10.8s
 => => exporting layers                                                            0.6s
 => => exporting manifest sha256:f4********48                                      0.0s
 => => exporting config sha256:c2********bc                                        0.0s
 => => pushing layers                                                              8.6s
 => => pushing manifest for ghcr.io/msfukui/msfukui.page:latest                    1.5s
 => [auth] msfukui/msfukui.page:pull,push user/image:pull token for ghcr.io        0.0s
```

#### Clean up (logout)

```
$ docker logout ghcr.io
Removing login credentials for ghcr.io
```

### Deploy

Register the read-only access token of ghcr.io as a secret in the container registry in advance.

```
$ kubectl create secret docker-registry msfukui-ghcr-secret-token --docker-server=ghcr.io --docker-username=msfukui --docker-password=[access-token] --docker-email=[sample@example.com]
secret/msfukui-ghcr-secret-token created
```

Deploy pods:

```
$ kubectl apply -f manifests/deployment.yml
deployment.apps/msfukui-page-deployment created
$ kubectl get pods
```

Deploy a service:

```
$ kubectl apply -f manifests/service.yml
service/msfukui-page-service configured
```

Since the ingress and TLS certificates are managed on the cluster side, they are omitted in this section.

## Futures

* Build the image and deploy to the k8s cluster with github actions.

## Reference

* Quick Start | Hugo

    https://gohugo.io/getting-started/quick-start/

* 静的サイトジェネレータ「Hugo」と技術文書公開向けテーマ「Docsy」でOSSサイトを作る | さくらのナレッジ

    https://knowledge.sakura.ad.jp/22908/

* ブログをGKEでの運用に移行した | tsub's blog

    https://blog.tsub.me/post/operate-blog-server-on-gke/

* Dockerを使用したNGINXとNGINX Plusのデプロイ | NGINX

    https://www.nginx.co.jp/blog/deploying-nginx-nginx-plus-docker/

* Images | Kubernetes -> Using a private registry

    https://kubernetes.io/docs/concepts/containers/images/#using-a-private-registry

* docker buildx build

    https://docs.docker.com/engine/reference/commandline/buildx_build/
