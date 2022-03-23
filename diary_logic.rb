require 'nokogiri'
require "csv"
require "./common_logic.rb"

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
    base_filename = 'd' + id + '_' + date + '_' + title + '(' + num.to_s + ')_' + user

    # ファイルに使用できない文字を削る
    filename = base_filename.gsub(/[\\\/:\*\?"<>\|]/, "")
    return (filename.nil?) ? "" : filename
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
    CSV.open('diary/csv/' + filename + '.csv','w', :encoding => "utf-8") do |writter|
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

# 一覧ページに遷移する
def move_to_the_list(driver)
    driver.find_element(:xpath, "//a[contains(@href,'a=page_h_diary_list_all')]").click
    on_open_new_page(driver)
end