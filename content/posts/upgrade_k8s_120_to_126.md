---
title: "おうち Kubernetes クラスターを v1.20 から v1.26 に上げる"
date: 2023-02-04
tags: [kubernetes]
draft: false
---

## この記事は?

先週末(1/29)に, このブログ?をホストしている自宅の Kubernetes クラスターを v1.20 から v1.26 に上げました.

この記事はその作業で引っかかったことの備忘録, 自分メモです.

## 承前

このブログ?をホストしている環境ですが, 2020 年 12 月頃に購入した Raspberry Pie 4 (8GB) 3台のおうち Kubernetes クラスター上で稼働しています.

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">おうちでk8sが流行っているみたいなので、冬休みの自由工作用にraspberry-pi買ってみた。届くの楽しみ。自作PCみたいな感覚で楽しそうだなー。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1340605827430797313?ref_src=twsrc%5Etfw">December 20, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

稼働している構成は HW, SW とも普通の環境なのですが, セットアップ後 1 年半ほど放置していたので, いろいろかなり置いていかれています.

幸い HW は問題なく動作している様なので, SW だけでも最新まで更新するべく, 重い腰を上げて対処することにしました. (きっと仕事に絶望して現実逃避したくなったのでしょう)

## 更新を進める

### 更新の考え方を決める

まず方針として, 新しいバージョンの環境を別に準備して移行するのではなく, 現在のクラスターのバージョンを上げて対処する選択としました.

理由はいくつかありますが, 購入/割り当てしているグローバルIPアドレスが1つしかなくこれ以上増やすことができないことと, この仕組みが停止しても誰も困らないことが大きいです.

アップグレードの方法は公式ページに基本従うことになるみたいです. 流し読みします.

https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/

Kubernetes クラスターはメジャーバージョンはまとめてあげることはできず, ひとつずつ上げていく必要があります.

今回は v1.20 → v.1.26 まで上げるので, v1.20 → v1.21 → v1.22 → v1.23 → v1.24 → v1.25 → v1.26 と上げていきます.

マイナーバージョンは, メジャーバージョンのアップグレード時にまとめて上げられる限り最新まで上げて, 次にメジャーバージョンを上げる前にそのバージョンの latest まで上げてから次に行くことにしました.

(この方針は結果としてうまく行きませんでした. 理由は後述.)

### 更新の手順を整理する

公式ページに書いてある通りですが, おおよその流れはこんな感じになります.

* 事前に全 node の OS, MW 周りをアップグレードしておく

    Ubuntu 20.04 LTS 64bit なので `sudo apt update -y && sudo apt dist-upgrade -y && sudo apt autoremove -y && sudo apt autoclean` しました.

    kubeadm, kubelet, kubectl, docker-ce, docker-cli は hold しているので, ここではまだあがりません.

まずは control-plne で作業します.

* kubeadm を一つ上げる

    以下の様に kubeadm の hold を解除してバージョン指定で一つ上に上げて hold し直します. 

    一気に最新にするとだめなことに注意.

    ```bash
    $ sudo apt-mark unhold kubeadm && \
    sudo apt update -y && sudo apt install -y kubeadm=1.21.15-00 && \
    sudo apt-mark hold kubeadm
    ```

    kubelet, kubectl の hold はこの時点ではそのままで.

    上げる先のバージョンは `apt-cache madison kubeadm` で眺めつつ決めます.

    上がった後は `sudo kubeadm version` してバージョン確認します.

* `sudo kubeadm upgrade plan` でチェックする

    いろいろ出てくるので内容を見て対処します.

* `sudo kubeadm upgrade apply` でアップグレードする

    祈ります. 問題あれば対処します.

* kubectl, kubelet を一つ上げる

    ```bash
    $ sudo apt-mark unhold kubelet kubectl && \
    sudo apt-get update && sudo apt-get install -y kubelet=1.21.15-00 kubectl=1.21.15-00 && \
    sudo apt-mark hold kubelet kubectl
    ```

    上がった後は `sudo kubelet --version`, `sudo kubectl version` でそれぞれバージョン確認します.

* kubelet を再起動

    ```bash
    $ sudo systemctl daemon-reload
    $ sudo systemctl restart kubelet
    ```

* kubectl でバージョン確認と稼働確認

    `sudo kubectl get nodes -o wide` で control-plane のみバージョン上がっていることを確認します.

    `sudo kubectl get pods -o wide --all-namespaces`, `sudo kubectl get svc -o wide --all-namespaces` で pod と service の様子を確認します.

    CrashBackoff などのステータスになっていたら対処します.

現在の自分のおうちクラスターには複数の control-plane はないので, ここまでで control-plane のアップグレードは終了です.

次に各 worker node で1台ずつ以下作業します.

* kubeadm を一つ上げる

    実施方法は control-plane と同じです. 上げる先は control-plane と揃えます.

    上げた後のバージョン確認も忘れずに.

* `kubeadm upgrade node` でアップグレード

* kubectl, kubelet を一つ上げる

    実施方法は control-plane と同じです. 上げる先は control-plane と揃えます.

    上げた後のバージョン確認も忘れずに.

* kubelet を再起動

    ```bash
    $ sudo systemctl daemon-reload
    $ sudo systemctl restart kubelet
    ```

全台終わったら最後にまとめて動作確認します.

* control-plane で改めて kubectl でバージョン確認と稼働確認

    各 node もバージョンが上がっていることを確認します. pod, service も動作を合わせて確認します.

これを各メジャーバージョンのアップグレードバージョン毎に繰り返す感じになります.

### 作業で発生した問題, 注意事項など

#### v1.20 → v1.21, v1.21 → v1.22

バージョン上げすぎ問題を発生させてしまいましたが, 特に問題はなく作業は順調に進んでいます.

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">ああ、あげすぎた。。 `sudo apt upgrade -y kubeadm=1.21.14-00 kubectl=1.21.14-00 kubelet=1.21.14-00 --allow-change-held-packages --allow-downgrades` する。。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619221015443427333?ref_src=twsrc%5Etfw">January 28, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

#### v1.22 → v1.23

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">ハバネロスナック食べながらv1.22.17に上げられた。ここからコンテナランタイムを差し替えないと。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619231302766690304?ref_src=twsrc%5Etfw">January 28, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

v1.23 から Kubernetes のコンテナランタイムについて docker のサポートが公式では deprecate されるため, 先に docker-ce, docker-cli を削除して containerd.io に差し替えます. が..

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">あ、containerd に差し替えたらお亡くなりになった。。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619236643613057024?ref_src=twsrc%5Etfw">January 28, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">pod まで通信が来ていないっぽいなー。もうちょっと見てみなきゃだけど時間切れ。。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619239860241563650?ref_src=twsrc%5Etfw">January 28, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">むー、metallb が機能していないっぽいな。バージョン上げてみようと思ったけれど設定が configmap 経由じゃなくなっているのか。itamae のレシピも書き直しだなー。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619297094413742080?ref_src=twsrc%5Etfw">January 28, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">うーん、 ingress-nginx controller もお亡くなるになっていた。もうちょっと眺めなければ。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619312814392479744?ref_src=twsrc%5Etfw">January 28, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">おお、ingress-nginx controller を新しいmanifest で deploy したら復旧した。以前の様にLBのTypeとIPを明示的に設定しなくても metallb で払い出されたIPに紐付けされてる。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619318343185633280?ref_src=twsrc%5Etfw">January 28, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">etcd と api-server が crashbackoff してるみたいだ。ログ見るとポートが重複しているみたい。 master を再起動してみるかな。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619319580136210434?ref_src=twsrc%5Etfw">January 28, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">うん、全部 running に復帰した。よかったー。さてここからさらに 1.26 まで上げるかなー。でも明日にしよう。。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619321082686902272?ref_src=twsrc%5Etfw">January 28, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

ということで, MetalLb と ingress-nginx controller のバージョンを上げて control-plane を再起動することで復旧できました.

Kubernetes で稼働しているとバージョン上げる場合は基本 `sudo kubectl apply -f [ファイル名]` とするだけなので, こういう時は楽でいいなーって思います.

一点注意として ingress-nginx contoller の適用する manifest は, metallb で LB を稼働させているので baremetal ではなく cloud の方を選択する必要があります.

前までは公式に提供されている manifest ファイルに少し手を入れていたのですが, 不要になったのは本当に良いなあと思いました.

#### v1.23 → v1.24

kubelet と containerd がちゃんと動いていないっぽくて, 調べたらまだ unix socket の指定が定義に残っていたみたいで修正して復旧.

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">なるほど。 node の定義にはまだ含まれているのか。書き換えれば行けそう。 <a href="https://t.co/484wcnp3qg">https://t.co/484wcnp3qg</a></p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619519546158886914?ref_src=twsrc%5Etfw">January 29, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">`kubectl annotate node [node name] --overwrite <a href="https://t.co/mco8ReUg37">https://t.co/mco8ReUg37</a>` して明示的に書き換えた後で upgrade apply したら行けたっぽい。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619521643096989696?ref_src=twsrc%5Etfw">January 29, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

`kubectl get nodes -o wide` したら `master` の名称が表示されなくなってて, あれ? って思ったらこんな話が.

リリースノートをちゃんと見ていないことの弊害が. よくないですね. これ以降はざっとでも一通り目を通すことにしました.

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">v1.24 から master の label はなくなって control-plain のみになったのか。 <a href="https://t.co/1XYXz1P6ZR">https://t.co/1XYXz1P6ZR</a> <a href="https://t.co/fYNG6h36VJ">https://t.co/fYNG6h36VJ</a></p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619526395071442947?ref_src=twsrc%5Etfw">January 29, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

kubelet がバージョンを上げた後の restart で起動に失敗する様になって, なんで..と思ったらこんな変更が入っていました. 対処して復旧.

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">/var/lib/kubelet/kubeadm-flags.env を編集して --network-plugin オプションを削除しないと kubelet がエラー吐いて起動しなかった。指定されていても無視していればよかったのになぜにエラーにしたかな。 <a href="https://t.co/GzJVTXIdc3">https://t.co/GzJVTXIdc3</a></p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619537881730797568?ref_src=twsrc%5Etfw">January 29, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

flannel が Crash する様になったのでバージョン上げ下げしました.

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">flannel が 1 pod だけ起動に失敗し続けていたので、一旦 v0.20.2 から v.0.16.3 に切り戻してみた。うまく動いていそうだけれど、理由がよくわからないな。この辺り関係するかなって思っていろいろやってみたけれどよくわからなかった。 <a href="https://t.co/MJJ10YtlZQ">https://t.co/MJJ10YtlZQ</a></p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619552725611708417?ref_src=twsrc%5Etfw">January 29, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

#### v1.24 → v1.25, v1.25 → v1.26

後は特に問題なく上げることができた.

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">とりあえず v1.26 まで上げた。一応提供しているページは表示されていて pod にエラーがないことは確認した。itamae のレシピも一通り書き換えたので、しばらくはこれで様子をみることにしよう。よかったよかった。別途ブログにでもメモしておく様にしよう。。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619676995859939340?ref_src=twsrc%5Etfw">2023年1月29日</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

ここで書いている Itamae の recipes は, このクラスター環境の構築用に初期に作って使っていたもの. その後 OS の環境を一から作り直す際にも何度か使っているものです.

#### その他

作業の開始前にこんなことがあってちょっと調べてみたりもしました.

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">あれ、 <a href="https://t.co/rNU1E4N11L">https://t.co/rNU1E4N11L</a> にアクセスできない。お亡くなりになってる..?</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619197394478075904?ref_src=twsrc%5Etfw">January 28, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

あと原因はわからないのですが apt で kubeadm を上げようとすると, Ubuntu の場合 v1.23 以降は最後のマイナーバージョンが最新から一つ古いものしかない状態でした.

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">v1.22.17 -&gt; v1.23.16 にあげようとしたら kubeadm が v1.23.15 までしかなくてだめっぽいな。</p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1619492321120391168?ref_src=twsrc%5Etfw">January 29, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

そういうものなのかな, と思い, 気にせず一つ古いマイナーバージョンまででアップグレードは止めて, そのまま次のメジャーバージョンのアップグレードに進むことにしました.

## まとめ

この作業, 定期で自動化する方法はないかな..という気持ちになるのでちょっと考えてみよう.

そういえばそもそも現在の環境についてまとめていなかったので, 現在こんな感じですが, 別途別記事でまとめておくことにしておけるといいなあ..

<blockquote class="twitter-tweet"><p lang="ja" dir="ltr">とりあえず組み上げできた。手持ちのカードリーダーがsdxcに対応してなさそうなので、ちょっと買い物をしてくるかな。。 <a href="https://t.co/kzbin92mVU">pic.twitter.com/kzbin92mVU</a></p>&mdash; ふくい（ま） (@msfukui) <a href="https://twitter.com/msfukui/status/1343068250502955008?ref_src=twsrc%5Etfw">December 27, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

外で何か大変なことがあっても, 自宅に自分専用のオンプレ Kubernetes クラスターがあると思うと, なんとか頑張れる気がしますね.
