require 'nokogiri'
require "csv"
require "./common_logic.rb"

# ページのhtmlを解析してデータ化する(本文)
def parse_main_html(doc)
    data = {}

    # point
    data[:point] = doc.css('.point')[0].content.split(' Point')[0]

    # rank
    data[:rank] = doc.css('.rank')[0].css('img')[0][:alt]

    # 本文領域
    center = doc.css('#Center')[0]
    center.css('tr').each do |row|
        th = row.css('th')[0].content
        td0 = row.css('td')[0].content
        td = td0.strip!
        if th == "ニックネーム"
            data[:user] = td0 #なぜかstrip!するとnilになってしまうので回避
        elsif th == "年齢"
            data[:age] = td
        elsif th == "誕生日"
            data[:birthday] = td
        elsif th == "性別"
            data[:gender] = td
        elsif th == "血液型"
            data[:blood] = td
        elsif th == "現住所"
            data[:address] = td
        elsif th == "出身地"
            data[:birthplace] = td
        elsif th == "自己紹介"
            data[:body] = td
        end
    end
    return data
end

# ページのhtmlを解析してデータ化する(紹介文)
def parse_intro_html(doc)
    data = {}
    data[:intro] = []
    center = doc.css('#Center')[0]
    center.css('tr').each do |row|
        data[:intro].push({
            user: row.css('th')[0].content,
            body: row.css('td')[0].content.strip!
        })
    end
    return data
end

# ページのhtmlを解析してデータ化する(画像)
def parse_image_html(doc)
    data = {}
    data[:photo] = []
    center = doc.css('#Center')[0]
    center.css('td').each do |ph|
        data[:photo].push(ph.css('img')[0][:src].slice(2..-1).split('&')[0])
    end
    return data
end

# ファイル名の決定
def get_filename(data)
    user_id = data[:id]
    user_name = data[:user]
    base_filename = user_id.to_s + '_' + user_name

    # ファイルに使用できない文字を削る
    filename = base_filename.gsub(/[\\\/:\*\?"<>\|]/, "")
    return (filename.nil?) ? "" : filename
end

# 表示されているページの情報を保存(本文)
def save_main(driver)
    # ページの情報を解析
    doc = Nokogiri::HTML(driver.page_source.toutf8, nil, 'utf-8')
    data = parse_main_html(doc)
    data[:id] = Hash[URI::decode_www_form((URI::parse(driver.current_url)).query)]["target_c_member_id"]

    # ファイル名の決定
    filename = get_filename(data)
    print_log("【INFO】[main] file: " + filename)

    # CSV化したデータを出力
    CSV.open('member/csv/' + filename + '.csv','w', :encoding => "utf-8") do |writter|
        # 最初にヘッダー部分を直書き
        writter.puts([
            "id", 
            "user",
            "point",
            "rank",
            "age", 
            "birthday", 
            "gender", 
            "blood",
            "address", 
            "birthplace", 
            "body"
        ])

        # 本文
        user_data = []
        user_data.push(data[:id]) #id
        user_data.push(data[:user]) #user
        user_data.push((data[:point].nil?) ? '' : data[:point]) #point
        user_data.push(data[:rank]) #rank
        user_data.push((data[:age].nil?) ? '' : data[:age]) #age
        user_data.push((data[:birthday].nil?) ? '' : data[:birthday]) #birthday
        user_data.push((data[:gender].nil?) ? '' : data[:gender]) #gender
        user_data.push((data[:blood].nil?) ? '' : data[:blood]) #blood
        user_data.push((data[:address].nil?) ? '' : data[:address]) #address
        user_data.push((data[:birthplace].nil?) ? '' : data[:birthplace]) #birthplace
        user_data.push((data[:body].nil?) ? '' : data[:body]) #body

        writter.puts(user_data)
    end

    # スクリーンショットを保存
    driver.save_screenshot('member/screenshot/' + filename + '.png')

    # ユーザ名を返す
    return data[:user]
end

# 表示されているページの情報を保存(紹介文)
def save_intro(driver, user)
    # ページの情報を解析
    doc = Nokogiri::HTML(driver.page_source.toutf8, nil, 'utf-8')
    data = parse_intro_html(doc)
    data[:id] = Hash[URI::decode_www_form((URI::parse(driver.current_url)).query)]["target_c_member_id"]
    data[:user] = user

    # ファイル名の決定
    filename = get_filename(data)
    print_log("【INFO】[intro] file: " + filename)

    # CSV化したデータを出力
    CSV.open('member/csv/' + filename + '_紹介文.csv','w', :encoding => "utf-8") do |writter|
        # 最初にヘッダー部分を直書き
        writter.puts([
            "user",
            "body"
        ])

        # 本文
        data[:intro].each do |row|
            intro_data = []
            intro_data.push(row[:user]) #user
            intro_data.push(row[:body]) #body
            writter.puts(intro_data)
        end
    end

    # スクリーンショットを保存
    driver.save_screenshot('member/screenshot/' + filename + '_紹介文.png')
end

# 表示されているページの情報を保存(紹介文)
def save_image(driver, user)
    # ページの情報を解析
    doc = Nokogiri::HTML(driver.page_source.toutf8, nil, 'utf-8')
    data = parse_image_html(doc)
    data[:id] = Hash[URI::decode_www_form((URI::parse(driver.current_url)).query)]["target_c_member_id"]
    data[:user] = user

    # ファイル名の決定
    filename = get_filename(data)
    print_log("【INFO】[image] file: " + filename)

    # 添付画像を保存
    asset_base_filename = 'member/asset/' + filename + '_'
    data[:photo].each do |url|
        download_image(asset_base_filename + url.split('=')[1],  $base_url + url)
    end
end

# 表示されているページから目当てのリンクを一通り踏んでデータを取得する
def traverse(driver)
    # 表示されているトピックのリンクの数の半分の値を計算
    # 1つのトピックに対してリンクが2つ存在するため
    link_size = driver.find_elements(:xpath, "//a[contains(@href,'target_c_member_id=')]").size() / 2

    # リンクの数だけループ
    for i in 0..link_size-1
        # 保存したいページに移動
        move_to_target_page(driver, i * 2, "//a[contains(@href,'target_c_member_id=')]")

        # 自分自身だったらホーム画面に飛ばされるので、それ以外の場合
        if driver.current_url != "http://mckees.sns-park.com/?m=pc&a=page_h_home"
            # 保存
            username = save_main(driver)

            # 紹介文
            begin
                driver.find_element(:xpath, "//a[contains(@href,'a=page_fh_intro')]")
                intro = true
            rescue
                intro = false
            end
            if intro
                driver.find_element(:xpath, "//a[contains(@href,'a=page_fh_intro')]").click
                on_open_new_page(driver)

                # 保存
                save_intro(driver, username)

                driver.navigate.back
                on_open_new_page(driver)
            end

            # 画像
            begin
                driver.find_element(:xpath, "//a[contains(@href,'a=page_f_show_image')]")
                image = true
            rescue
                image = false
            end
            if image
                driver.find_element(:xpath, "//a[contains(@href,'a=page_f_show_image')]").click
                on_open_new_page(driver)

                # 保存
                save_image(driver, username)

                driver.navigate.back
                on_open_new_page(driver)
            end
        end

        driver.navigate.back
        on_open_new_page(driver)
    end
end

# 一覧ページに遷移する
def move_to_the_list(driver)
    driver.find_element(:xpath, "//a[contains(@href,'a=page_h_search')]").click
    on_open_new_page(driver)
    driver.find_element(:class, 'input_submit').click
    on_open_new_page(driver)
end