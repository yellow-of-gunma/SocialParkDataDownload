# SocialParkDataDownload

## 概要
- そーしゃるぱーくのSNS上にあがっている日記のデータを全部ダウンロードします
  - 対象ページ1つにつき以下の3つがローカルに生成されます
    - csv化されたデータ
    - 画面のスクリーンショット
    - 添付されている画像すべて
- 非公式です
  - このプログラムについて公式に問い合わせたりしないでください

## 環境構築手順
1. Rubyの実行環境を整える
  - 以下のページなどを参照のこと
    - https://prog-8.com/docs/ruby-env-win
2. ChromeのWebDriverを以下からダウンロード＆展開し、ruby.exeと同じディレクトリに置く
  - https://sites.google.com/chromium.org/driver/downloads
  - 自分のパソコンに入っているChromeのバージョンと同じバージョンのものをダウンロードすること
  - ruby.exeの場所は、コマンドプロンプト(ターミナル)で以下のコマンドを打てば分かる
    - [windowsの場合] where.exe ruby
    - [maxの場合] which ruby
3. コマンドプロンプト(ターミナル)で以下の3つを実行し、ライブラリをインストール
  - gem install nokogiri
  - gem install selenium-webdriver
  - gem install ffi
4. socialParkDiary.rbがあるディレクトリに、「diary」フォルダを作成
5. 「diary」フォルダの下に「asset」「csv」「screenshot」の3つのフォルダを作成

## 実行手順
1. socialParkDiary.rbをテキストエディタで開き、以下の3箇所を適切に設定
  - $login_mail
  - $login_pass
  - $base_url
2. socialParkDiary.rbがあるディレクトリをコマンドプトンプト(ターミナル)で開き、以下のコマンドを実行
  - ruby socialParkDiary.rb

## ありがとうそーしゃるぱーく
- 10年以上の長きに渡って、本当にお世話になりました