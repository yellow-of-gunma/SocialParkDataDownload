require 'open-uri'
require 'nokogiri'
require 'kconv'
require "rubygems"
require "csv"
require 'selenium-webdriver'

# ログイン情報
mail = 'ここにメールアドレスを入力'
pass = 'ここにパスワードを入力'
login_page_url = 'http://mckees.sns-park.com/?m=portal&a=page_user_top'

# windowリサイズ
# ページが読み込めているかの判定＆ページが読み込めるまでのwaitにも利用
def window_resize(driver)
    sleepTime = 1
    driver.manage.window.resize_to(100, 100)
    begin
        # 実際のページサイズを取得
        width  = driver.execute_script("return Math.max(document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth);")
        height = driver.execute_script("return Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight);")
    rescue
        # 10分を超えるようになったら終了させる
        if sleepTime > 600
            p "【ERROR】window_resizeのリトライを繰り返しましたが、成功しませんでした"
            raise
        end

        # スリープ
        p "sleepTime:" + sleepTime.to_s
        sleep sleepTime

        # 次回のスリープ時間を更新しリトライ
        sleepTime *= 2
        retry        
    end
    # 取得サイズに若干の余白を持たせてWindowをサイズを変更
    # 若干の余白を持たせることでスクロールバーの表示を無くすことができる
    driver.manage.window.resize_to(width+100, height+100)
end

# WebDriverの生成
# Chromeをヘッドレス起動
options = Selenium::WebDriver::Chrome::Options.new(
  args: ["--headless", "--disable-gpu", "window-size=1280x800"],
)
wd = Selenium::WebDriver.for :chrome, options: options

# ログインページを開く
wd.get login_page_url

# ログイン
wd.find_element(:id, 'username').send_keys mail
wd.find_element(:id, 'password').send_keys pass
wd.find_element(:id, 'buttonLogin').click

# 最新日記のページに移動
wd.find_element(:xpath, "//a[contains(@href,'a=page_h_diary_list_all')]").click
window_resize(wd)

# 表示されている日記リンクの数の半分の値を計算
# 1つの日記に対してリンクが2つ存在するため
diary_size = wd.find_elements(:xpath, "//a[contains(@href,'target_c_diary_id=')]").size() / 2

# リンクの数だけループ
for i in 0..diary_size-1
    # 2回目以降のループ処理の際にドライバがなくなってるので、再度ドライバ指定
    events_in_loop = wd.find_elements(:xpath, "//a[contains(@href,'target_c_diary_id=')]")

    # 日記に移動し情報を解析
    events_in_loop[i*2].click()
    window_resize(wd)

    p "index:" + i.to_s

    doc = Nokogiri::HTML(wd.page_source.toutf8, nil, 'utf-8')

    # ファイル名の指定
    filename = "hoge" + i.to_s

    # CSV化したデータを出力
    File.open('diary/csv/' + filename + '.html','w', :encoding => "utf-8") do |writter|
        writter.puts(doc)
    end

    # スクリーンショットを保存
    wd.save_screenshot('diary/screenshot/' + filename + '.png')

    # 前のページに戻る
    wd.navigate.back
    window_resize(wd)
end

# 終了
wd.quit