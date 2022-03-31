# SocialParkDataDownload
- 2022/3/31にそーしゃるぱーくがサービスを終了するので作りました

## 概要
- そーしゃるぱーくのSNS上から、日記とトピックとメンバー自己紹介とコミュニティ説明文のデータを全部ローカルに保存します
  - 対象ページ1つにつき以下の3つがローカルに生成されます
    - csv化されたデータ
    - 画面のスクリーンショット
    - 添付されている画像すべて
- 非公式です
  - このプログラムについて公式に問い合わせたりしないでください

## 環境構築手順
- Chromeが入っていなければインストール
- Rubyの実行環境を整える
  - 以下のページなどを参照のこと
    - https://prog-8.com/docs/ruby-env-win
- ChromeのWebDriverを以下からダウンロード＆展開し、ruby.exeと同じディレクトリに置く
  - https://sites.google.com/chromium.org/driver/downloads
  - 自分のパソコンに入っているChromeのバージョンと同じバージョンのものをダウンロードすること
  - ruby.exeの場所は、コマンドプロンプトで以下のコマンドを打てば分かる
    - [windowsの場合] `where.exe ruby`
    - [maxの場合] `which ruby`
- コマンドプロンプトで以下の3つを実行し、ライブラリをインストール
  - `gem install nokogiri`
  - `gem install selenium-webdriver`
  - `gem install ffi`
- このプロジェクトのディレクトリに`diary` `topic` `member` `community`の4つのフォルダを作成
- `diary` `topic` `member` `community`の各フォルダの下にそれぞれ`asset` `csv` `screenshot`の3つのフォルダを作成

## そーしゃるぱーく上での準備
- マイホームに「全体の最新コミュニティ書き込み」が表示されていることを確認
  - 表示されていない場合、設定変更 > マイホーム最新情報表示変更 から「表示する」を選択して設定変更
- 誰にもアク禁にされていないことを確認
  - アク禁にされている場合、メンバの情報取得が途中でエラーになると思われる

## 実行手順
- const.rbをテキストエディタで開き、以下の3箇所を適切に設定
  - `$login_mail`
  - `$login_pass`
  - `$base_url`
- 必要であれば、const.rbの以下も項目も変更
  - `$traverse_start_index`
  - `$traverse_end_index`
    - 保存範囲の設定
    - 「最新日記一覧」「トピック一覧」「メンバー検索結果一覧」のページ数を表している
      - 最初のページが1
      - それ以降はurl上に出る`page=`の数値
  - `$default_sleep_time`
    - サーバに高負荷をかけないように、ページ遷移のたびにスリープします
- このプロジェクトのディレクトリをコマンドプトンプトで開き、以下のコマンドを実行
  - [日記を取得する場合] `ruby social_park_diary.rb`
  - [トピックを取得する場合] `ruby social_park_topic.rb`
  - [自己紹介を取得する場合] `ruby social_park_member.rb`
  - [コミュニティ紹介文を取得する場合] `ruby social_park_community.rb`
    - 自己紹介はサイトによって項目名・項目内容が異なるため、以下のメソッドを要編集のこと
      - member_logic.rb#parse_main_html
      - member_logic.rb#save_main

## ありがとうそーしゃるぱーく