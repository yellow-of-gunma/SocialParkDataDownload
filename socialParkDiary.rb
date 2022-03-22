require 'open-uri'
require 'nokogiri'
require 'uri'
require 'kconv'
require "rubygems"
require "csv"
require 'selenium-webdriver'

# ログイン情報
$login_mail = 'ここにメールアドレスを入力'
$login_pass = 'ここにパスワードを入力'
$base_url = 'http://ここにドメインを入力.sns-park.com/'

# 一覧の何ページ目から何ページ目までを取得するか
# (1-index, closed interval)
traverse_start_index = 1
traverse_end_index = 1000000000

# 状況出力
def print_log(text)
    puts "\n" + text + "\n\n"
end

# windowリサイズ
# ページが読み込めているかの判定＆ページが読み込めるまでのwaitにも利用
def on_open_new_page(driver)
    sleepTime = 0.5
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
            print_log("【ERROR】window_resizeのリトライを繰り返しましたが、成功しませんでした")
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

# 投稿日時を解析する
def parse_datetime_text(datetime)
    yearSplit = datetime.split('年')
    monthSplit = yearSplit[1].split('月')
    daySplit = monthSplit[1].split('日')
    hourSplit = daySplit[1].split(':')
    return {
        year: yearSplit[0],
        month: monthSplit[0],
        day: daySplit[0],
        hour: hourSplit[0],
        minute: hourSplit[1]
    }
end

# ページのhtmlを解析してデータ化する
def parse_html(doc, current_url)
    data = {}

    # ID
    data[:id] = Hash[URI::decode_www_form((URI::parse(current_url)).query)]["target_c_diary_id"]

    # 本文領域
    center = doc.css('#Center')[0]
    diary_detail_box = center.css('.diaryDetailBox')[0].css('.parts')
    diary_main = diary_detail_box.css('dl')[0]

    # 投稿者
    data[:user] = diary_detail_box.css('.partsHeading')[0].css('h3')[0].content.split('さんの黙示録')[0].split('の黙示録')[0]

    # 投稿日時
    data[:date] = parse_datetime_text(diary_main.css('dt')[0].content)

    # タイトル
    data[:title] = diary_main.css('dd')[0].css('.title')[0].css('.heading')[0].content

    # 添付画像
    d_body = diary_main.css('dd')[0].css('.body')[0]
    photo = d_body.css('.photo')[0]
    data[:photo] = []
    if !(photo.nil?)
        photo.css('li').each do |ph|
            data[:photo].push(ph.css('img')[0][:src].slice(2..-1).split('&')[0])
        end
    end

    # 本文
    data[:body] = {
        text: d_body.content.slice((data[:photo].size + 1)..-2),
        html: data[:photo].size == 0 ? d_body.inner_html.slice(1..-2) : d_body.inner_html.split('</ul>')[1].slice(1..-2)
    }

    # アルバム
    data[:album] = data[:body][:html].scan(/img\.php\?filename=a_[\d|_]+\.jpg/)

    # いいね！
    data[:like] = []
    diary_detail_box.css('.body')[1].content.split("\n").each do |lik|
        if !lik.empty?
            data[:like].push(lik)
        end
    end

    # コメント
    data[:comment] = []
    comment_list = center.css('#commentList')[0]
    if !(comment_list.nil?)
        comment_list.css('.parts')[0].css('form')[0].css('dl').each do |comm|
            comment_data = {}

            # ID
            comment_heading = comm.css('dd')[0].css('.title')[0].css('.heading')[0]
            comment_data[:id] = comment_heading.content.split("\n")[0].slice(0..-2)

            # 投稿者
            comment_data[:user] = comment_heading.content.split("\n")[1].slice(1..-1)

            # 投稿日時
            comment_data[:date] = parse_datetime_text(comm.css('dt')[0].content)

            # 添付画像
            c_body = comm.css('dd')[0].css('.body')[0]
            c_photo = c_body.css('.photo')[0]
            comment_data[:photo] = []
            if !(c_photo.nil?)
                c_photo.css('li').each do |ph|
                    comment_data[:photo].push(ph.css('img')[0][:src].slice(2..-1).split('&')[0])
                end
            end

            # 内容
            comment_data[:body] = c_body.css('.text')[0].content

            data[:comment].push(comment_data)
        end
    end

    return data
end

# ファイル名の決定
def get_filename(data)
    id = data[:id]
    date = data[:date][:year] + '年' + data[:date][:month] + '月' + data[:date][:day] + '日'
    title = data[:title]
    num = data[:comment].length
    user = data[:user]
    base_filename = id + '_' + date + '_' + title + '(' + num.to_s + ')_' + user

    # ファイルに使用できない文字を削る
    filename = base_filename.gsub(/[\\\/:\*\?"<>\|]/, "")
    return (filename.nil?) ? "" : filename
end

# 画像のダウンロード
def download_image(filename, url)
    File.open(filename, "wb") do |file|
        URI.open(url) do |img|
            file.puts img.read
        end
    end
end

# 表示されているページの情報を保存
def save_data(driver)
    # ページの情報を解析
    doc = Nokogiri::HTML(driver.page_source.toutf8, nil, 'utf-8')
    data = parse_html(doc, driver.current_url)

    # ファイル名の決定
    filename = get_filename(data)
    print_log("【INFO】file: " + filename)

    # CSV化したデータを出力
    CSV.open('diary/csv/' + filename + '.csv','w', :force_quotes => true, :encoding => "utf-8") do |writter|
        # 最初にヘッダー部分を直書き
        writter.puts([
            "number", 
            "date",
            "time", 
            "user", 
            "title", 
            "body_text", 
            "body_html", 
            "photo0", 
            "photo1", 
            "photo2", 
            "like0", 
            "like1", 
            "like2", 
            "like3", 
            "like4", 
            "like5", 
            "like6", 
            "like7", 
            "like8", 
            "like9", 
            "like_over"
        ])

        # 本文
        diary_data = []
        diary_data.push(0) #number
        diary_data.push(data[:date][:year] + '/' + data[:date][:month] + '/' + data[:date][:day]) #date
        diary_data.push(data[:date][:hour] + ':' + data[:date][:minute]) #time
        diary_data.push(data[:user].gsub(",", "")) #user
        diary_data.push(data[:title].gsub(",", "")) #title
        diary_data.push(data[:body][:text].gsub(",", "")) #body_text
        diary_data.push(data[:body][:html].gsub(",", "")) #body_html
        for i in 0..2 do
            diary_data.push(data[:photo].length > i ? data[:photo][i] : "") #photo
        end
        for i in 0..9 do
            diary_data.push(data[:like].length > i ? data[:like][i].gsub(",", "") : "") #like
        end
        diary_data.push(data[:like].length > 10) #like_over
        writter.puts(diary_data)

        # コメント
        data[:comment].each do |comm|
            comment_data = []
            comment_data.push(comm[:id]) #number
            comment_data.push(comm[:date][:year] + '/' + comm[:date][:month] + '/' + comm[:date][:day]) #date
            comment_data.push(comm[:date][:hour] + ':' + comm[:date][:minute]) #time
            comment_data.push(comm[:user].gsub(",", "")) #user
            comment_data.push("") #title
            comment_data.push(comm[:body].gsub(",", "")) #body_text
            comment_data.push("") #body_html
            for i in 0..2 do
                comment_data.push(comm[:photo].length > i ? comm[:photo][i] : "") #photo
            end
            for i in 0..9 do
                comment_data.push("") #like
            end
            comment_data.push(false) #like_over
            writter.puts(comment_data)
        end
    end

    # スクリーンショットを保存
    driver.save_screenshot('diary/screenshot/' + filename + '.png')

    # 添付画像を保存
    asset_base_filename = 'diary/asset/' + filename + '_'
    data[:photo].each do |url|
        download_image(asset_base_filename + url.split('=')[1],  $base_url + url)
    end
    data[:album].each do |url|
        download_image(asset_base_filename + url.split('=')[1],  $base_url + url)
    end
    data[:comment].each do |comm|
        comm[:photo].each do |url|
            download_image(asset_base_filename + url.split('=')[1],  $base_url + url)
        end
    end
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
wd.get ($base_url + '?m=portal&a=page_user_top')

# ログイン
wd.find_element(:id, 'username').send_keys $login_mail
wd.find_element(:id, 'password').send_keys $login_pass
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
    print_log("【INFO】ListIndex: " + index.to_s + "/" + traverse_end_index.to_s)

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