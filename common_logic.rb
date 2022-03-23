require 'open-uri'
require 'uri'
require 'kconv'
require "rubygems"
require 'selenium-webdriver'
require "./const.rb"

# 状況出力
def print_log(text)
    puts "\n" + text + "\n\n"
end

# ページ遷移したらおこなう処理
def on_open_new_page(driver)
    # まずSleep
    sleep_time = $default_sleep_time
    sleep sleep_time

    # 一旦Windowサイズを小さめに変更
    driver.manage.window.resize_to(100, 100)
    begin
        # 実際のページサイズを取得
        width  = driver.execute_script("return Math.max(document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth);")
        height = driver.execute_script("return Math.max(document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight);")
    rescue
        # sleepが10分を超えるようになったら終了させる
        if sleep_time > 600
            print_log("【ERROR】window_resizeのリトライを繰り返しましたが、成功しませんでした")
            raise
        end

        # スリープ時間を更新してスリープ
        sleep_time *= 2
        sleep sleep_time

        # リトライ
        retry        
    end
    # 取得サイズに若干の余白を持たせてWindowサイズを変更
    # 若干の余白を持たせることでスクロールバーの表示を無くすことができる
    driver.manage.window.resize_to(width + 100, height + 100)
end

# 投稿日時を解析する
def parse_datetime_text(datetime)
    year_split = datetime.split('年')
    month_split = year_split[1].split('月')
    day_split = month_split[1].split('日')
    hour_split = day_split[1].split(':')
    return {
        year: year_split[0],
        month: month_split[0],
        day: day_split[0],
        hour: hour_split[0],
        minute: hour_split[1]
    }
end

# 画像のダウンロード
def download_image(filename, url)
    File.open(filename, "wb") do |file|
        URI.open(url) do |img|
            file.puts img.read
        end
    end
end

# WebDriverの生成
def create_webdriver()
    # Chromeをヘッドレス起動
    options = Selenium::WebDriver::Chrome::Options.new(
        args: ["--headless", "--disable-gpu", "window-size=1280x800"],
    )
    wd = Selenium::WebDriver.for :chrome, options: options
    return wd
end

# ログイン
def login_social_park(driver)
    # ログインページを開く
    driver.get ($base_url + '?m=portal&a=page_user_top')

    # ログイン
    driver.find_element(:id, 'username').send_keys $login_mail
    driver.find_element(:id, 'password').send_keys $login_pass
    driver.find_element(:id, 'buttonLogin').click

    on_open_new_page(driver)
end
