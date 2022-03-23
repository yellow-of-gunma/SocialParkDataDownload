require 'nokogiri'
require "csv"
require "./common_logic.rb"

# ページのhtmlを解析してデータ化する
def parse_html(doc)
    data = {}

    # 本文領域
    center = doc.css('#Center')[0]
    data[:is_event] = center.css('.topicDetailBox')[0].nil?
    topic_detail_box = data[:is_event] ? center.css('.eventDetailBox')[0].css('.parts') : center.css('.topicDetailBox')[0].css('.parts')
    topic_main = topic_detail_box.css('dl')[0]

    # コミュニティ
    data[:community] = {
        id: doc.css('#cLocalNav_1')[0].css('a')[0][:href].split('target_c_commu_id=')[1],
        title: topic_detail_box.css('.partsHeading')[0].css('h3')[0].content.split('] イベント')[0].split('] トピック')[0].split('[')[1]
    }

    # 投稿者
    topic_dd = topic_main.css('dd')[0]
    event_table = topic_dd.css('table')[0]
    data[:user] = data[:is_event] ? event_table.css('td')[1].content : topic_dd.css('.name')[0].content.slice(1..-2)

    # 投稿日時
    data[:date] = parse_datetime_text(topic_main.css('dt')[0].content)
    data[:last_date] = data[:date]

    # タイトル
    data[:title] = data[:is_event] ? event_table.css('td')[0].content : topic_dd.css('.title')[0].content.slice(1..-2)

    # 添付画像
    photo = data[:is_event] ? topic_dd.css('.photo')[0] : topic_dd.css('.body')[0].css('.photo')[0]
    data[:photo] = []
    if !(photo.nil?)
        photo.css('li').each do |ph|
            data[:photo].push(ph.css('img')[0][:src].slice(2..-1).split('&')[0])
        end
    end

    # 本文
    data[:body] = data[:is_event] ? event_table.css('td')[5].content : topic_dd.css('.body')[0].content.slice((data[:photo].size + 2)..-3)
    
    # イベント情報
    data[:event_detail] = {
        date: data[:is_event] ? event_table.css('td')[2].content.delete('&nbsp;') : '',
        venue: data[:is_event] ? event_table.css('td')[3].content : '',
        application_period: data[:is_event] ? event_table.css('td')[6].content : '',
        recruitment_numbers: data[:is_event] ? event_table.css('td')[7].content : '',
        member_nubers: data[:is_event] ? event_table.css('td')[8].content.split("人")[0] : '',
    }

    # コメント
    data[:comment] = []
    comment_list = center.css('.commentList')[0]
    if !(comment_list.nil?)
        comment_list.css('.parts')[0].css('dl').each do |comm|
            comment_data = {}

            # ID
            comment_heading = comm.css('dd')[0].css('.title')[0].css('.heading')[0]
            comment_data[:id] = comment_heading.content.split("\n")[0].slice(0..-2)

            # 投稿者
            comment_data[:user] = comment_heading.content.split("\n")[1].slice(1..-1)

            # 投稿日時
            comment_data[:date] = parse_datetime_text(comm.css('dt')[0].content)
            data[:last_date] = comment_data[:date]


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
    community_id = data[:community][:id]
    topic_id = data[:id]
    date = data[:last_date][:year] + '年' + data[:last_date][:month] + '月' + data[:last_date][:day] + '日'
    page = data[:page]
    title = data[:title]
    num = data[:comment].length
    community_title = data[:community][:title]
    base_filename = 'c' + community_id + '_t' + topic_id + '_' + page.to_s + '_' + date + '_' + title + '(' + num.to_s + ')_' + community_title

    # ファイルに使用できない文字を削る
    filename = base_filename.gsub(/[\\\/:\*\?"<>\|]/, "")
    return (filename.nil?) ? "" : filename
end

# 表示されているページの情報を保存
def save_data(driver)
    # ページの情報を解析
    doc = Nokogiri::HTML(driver.page_source.toutf8, nil, 'utf-8')
    data = parse_html(doc)
    data[:id] = Hash[URI::decode_www_form((URI::parse(driver.current_url)).query)]["target_c_commu_topic_id"]
    page = Hash[URI::decode_www_form((URI::parse(driver.current_url)).query)]["page"]
    data[:page] = (page.nil?) ? 1 : page

    # ファイル名の決定
    filename = get_filename(data)
    print_log("【INFO】file: " + filename)

    # CSV化したデータを出力
    CSV.open('topic/csv/' + filename + '.csv','w', :encoding => "utf-8") do |writter|
        # 最初にヘッダー部分を直書き
        writter.puts([
            "number", 
            "date",
            "time", 
            "user", 
            "title", 
            "body",
            "photo0", 
            "photo1", 
            "photo2", 
            "event_date",
            "event_venue",
            "event_application_period",
            "event_recruitment_numbers",
            "event_member_numbers",
        ])

        # 本文
        topic_data = []
        topic_data.push(0) #number
        topic_data.push(data[:date][:year] + '/' + data[:date][:month] + '/' + data[:date][:day]) #date
        topic_data.push(data[:date][:hour] + ':' + data[:date][:minute]) #time
        topic_data.push(data[:user]) #user
        topic_data.push(data[:title]) #title
        topic_data.push(data[:body]) #body_text
        for i in 0..2 do
            topic_data.push(data[:photo].length > i ? data[:photo][i] : "") #photo
        end
        topic_data.push(data[:event_detail][:date]) #event_date
        topic_data.push(data[:event_detail][:venue]) #event_venue
        topic_data.push(data[:event_detail][:application_period]) #event_application_period
        topic_data.push(data[:event_detail][:recruitment_numbers]) #event_recruitment_numbers
        topic_data.push(data[:event_detail][:member_nubers]) #event_member_nubers

        writter.puts(topic_data)

        # コメント
        data[:comment].each do |comm|
            comment_data = []
            comment_data.push(comm[:id]) #number
            comment_data.push(comm[:date][:year] + '/' + comm[:date][:month] + '/' + comm[:date][:day]) #date
            comment_data.push(comm[:date][:hour] + ':' + comm[:date][:minute]) #time
            comment_data.push(comm[:user]) #user
            comment_data.push("") #title
            comment_data.push(comm[:body]) #body_text
            for i in 0..2 do
                comment_data.push(comm[:photo].length > i ? comm[:photo][i] : "") #photo
            end
            for i in 0..4 do
                comment_data.push("") #event
            end
            writter.puts(comment_data)
        end
    end

    # スクリーンショットを保存
    driver.save_screenshot('topic/screenshot/' + filename + '.png')

    # 添付画像を保存
    asset_base_filename = 'topic/asset/' + filename + '_'
    data[:photo].each do |url|
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
    # 表示されているトピックのリンクの数の半分の値を計算
    # 1つのトピックに対してリンクが2つ存在するため
    link_size = driver.find_elements(:xpath, "//a[contains(@href,'target_c_commu_topic_id=')]").size() / 2

    # リンクの数だけループ
    for i in 0..link_size-1
        # 2回目以降のループ処理の際にドライバがなくなってるので、再度ドライバ指定
        events_in_loop = driver.find_elements(:xpath, "//a[contains(@href,'target_c_commu_topic_id=')]")

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
    driver.find_element(:xpath, "//a[contains(@href,'a=page_h_com_topic_find_all')]").click
    on_open_new_page(driver)
end