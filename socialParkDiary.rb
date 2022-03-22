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

# 一覧の何ページ目から何ページ目までを取得するか
# (1-index, closed interval)
traverse_start_index = 1
traverse_end_index = 10000000

# 新しいページを開くたびにおこなうsleepの時間指定
default_sleep_time = 0.5

# windowリサイズ
# ページが読み込めているかの判定＆ページが読み込めるまでのwaitにも利用
def on_open_new_page(driver)
    sleepTime = default_sleep_time
    sleep sleepTime

    # 一旦Windowサイズを小さめに変更
    driver.manage.window.resize_to(100, 100)
    begin
        # 実際のページサイズを取得
        width  = driver.execute_script("return Math.max(document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth);")
        height = driver.execute_script("return Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight);")
    rescue
        # sleepが10分を超えるようになったら終了させる
        if sleepTime > 600
            puts "\n【ERROR】window_resizeのリトライを繰り返しましたが、成功しませんでした\n\n"
            raise
        end

        # スリープ時間を更新してスリープ
        sleepTime *= 2
        sleep sleepTime

        # リトライ
        retry        
    end
    # 取得サイズに若干の余白を持たせてWindowサイズを変更
    # 若干の余白を持たせることでスクロールバーの表示を無くすことができる
    driver.manage.window.resize_to(width + 100, height + 100)
end

# 表示されているページの情報を保存
def save_data(driver)
    # ページの情報を解析
    doc = Nokogiri::HTML(driver.page_source.toutf8, nil, 'utf-8')

    # ファイル名の指定
    filename = "hoge"

    # CSV化したデータを出力
    File.open('diary/csv/' + filename + '.html','w', :encoding => "utf-8") do |writter|
        writter.puts(doc)
    end

    # スクリーンショットを保存
    driver.save_screenshot('diary/screenshot/' + filename + '.png')
end

# 表示されているページから目当てのリンクを一通り踏んでデータを取得する
def traverse(driver)
    # 表示されている日記のリンクの数の半分の値を計算
    # 1つの日記に対してリンクが2つ存在するため
    link_size = driver.find_elements(:xpath, "//a[contains(@href,'target_c_diary_id=')]").size() / 2

    # リンクの数だけループ
    for i in 0..link_size-1
        # 2回目以降のループ処理の際にドライバがなくなってるので、再度ドライバ指定
        events_in_loop = driver.find_elements(:xpath, "//a[contains(@href,'target_c_diary_id=')]")

        # 保存したいページに移動
        events_in_loop[i*2].click
        on_open_new_page(driver)

        # 保存
        save_data(driver)

        # 前のページに戻る
        driver.navigate.back
        on_open_new_page(driver)
    end
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

# 最新日記一覧のページに移動
wd.find_element(:xpath, "//a[contains(@href,'a=page_h_diary_list_all')]").click
on_open_new_page(wd)

# 一覧を1ページずつめくっていく
index = 1
loop do
    # 取得範囲の終端を迎えたら終了
    if index > traverse_end_index
        break
    end

    # 進捗の表示
    puts "\n【INFO】ListIndex: " + index.to_s + "/" + traverse_end_index.to_s + "\n\n"

    # 取得範囲の先端を迎えていたら、
    # 表示されているリンクを一通り踏んでデータを取得する
    if index >= traverse_start_index
        traverse(wd)
    end

    # 次のページがあれば遷移し、なければ終了
    index += 1
    begin
        nextElement = wd.find_element(:class, 'next')
        nextElement.find_element(:tag_name, 'a').click
        on_open_new_page(wd)
    rescue
        break
    end
end

# 終了
wd.quit