require 'nokogiri'
require "csv"
require "./common_logic.rb"

# ページのhtmlを解析してデータ化する
def parse_html(doc)
    data = {}

    # 画像
    data[:photo] = doc.css('.photo')[0].css('img')[0][:src].slice(2..-1).split('&')[0]

    # 本文領域
    center = doc.css('#Center')[0]
    center.css('tr').each do |row|
        if row.css('th').length <= 0
            next
        end
        th = row.css('th')[0].content
        td = row.css('td')[0].content.strip
        if th == "コミュニティ名"
            data[:name] = td
        elsif th == "開設日"
            data[:date] = parse_date_text(td)
        elsif th == "管理者"
            data[:manager] = td
        elsif th == "副管理者"
            data[:deputy_manager] = td
        elsif th == "カテゴリ"
            data[:category] = td
        elsif th == "メンバー数"
            data[:member_numbers] = td.split('人')[0]
        elsif th == "参加条件"
            data[:entry_condition] = td
        elsif th == "公開範囲"
            data[:share_with] = td
        elsif th == "トピック作成"
            data[:topic_auth] = td
        elsif th == "コメント作成"
            data[:comment_auth] = td
        elsif th.include? "説明文"
            data[:body] = td
        end
    end

    return data
end

# ファイル名の決定
def get_filename(data)
    id = data[:id]
    name = data[:name]
    base_filename = 'c' + id.to_s + '_' + name

    # ファイルに使用できない文字を削る
    filename = base_filename.gsub(/[\\\/:\*\?"<>\|]/, "")
    return (filename.nil?) ? "" : filename
end

# 表示されているページの情報を保存
def save_data(driver)
    # ページの情報を解析
    doc = Nokogiri::HTML(driver.page_source.toutf8, nil, 'utf-8')
    data = parse_html(doc)
    data[:id] = Hash[URI::decode_www_form((URI::parse(driver.current_url)).query)]["target_c_commu_id"]

    # ファイル名の決定
    filename = get_filename(data)
    print_log("【INFO】file: " + filename)

    # CSV化したデータを出力
    CSV.open('community/csv/' + filename + '.csv','w', :encoding => "utf-8") do |writter|
        # 最初にヘッダー部分を直書き
        writter.puts([
            "id", 
            "name",
            "date", 
            "manager",
            "deputy_manager",
            "category", 
            "member_numbers", 
            "entry_condition", 
            "share_with", 
            "topic_auth", 
            "comment_auth",
            "body",
        ])

        # 本文
        diary_data = []
        diary_data.push(data[:id]) #id
        diary_data.push(data[:name]) #name
        diary_data.push(data[:date][:year] + '/' + data[:date][:month] + '/' + data[:date][:day]) #date
        diary_data.push(data[:manager]) #manager
        diary_data.push((data[:deputy_manager].nil?) ? '' : data[:deputy_manager]) #deputy_manager
        diary_data.push(data[:category]) #category
        diary_data.push(data[:member_numbers]) #member_numbers
        diary_data.push(data[:entry_condition]) #entry_condition
        diary_data.push(data[:share_with]) #share_with
        diary_data.push(data[:topic_auth]) #topic_auth
        diary_data.push(data[:comment_auth]) #comment_auth
        diary_data.push(data[:body]) #body

        writter.puts(diary_data)
    end

    # スクリーンショットを保存
    driver.save_screenshot('community/screenshot/' + filename + '.png')

    # 添付画像を保存
    asset_base_filename = 'community/asset/' + filename + '_'
    download_image(asset_base_filename + data[:photo].split('=')[1],  $base_url + data[:photo])
end

# 表示されているページから目当てのリンクを一通り踏んでデータを取得する
def traverse(driver)
    # 表示されている日記のリンクの数の半分の値を計算
    # 1つの日記に対してリンクが2つ存在するため
    link_size = driver.find_elements(:xpath, "//a[contains(@href,'target_c_commu_id=')]").size() / 2

    # リンクの数だけループ
    for i in 0..link_size-1
        # 保存したいページに移動
        move_to_target_page(driver, i * 2, "//a[contains(@href,'target_c_commu_id=')]")

        # 保存
        save_data(driver)

        # 前のページに戻る
        driver.navigate.back
        on_open_new_page(driver)
    end
end

# 一覧ページに遷移する
def move_to_the_list(driver)
    driver.find_element(:xpath, "//a[contains(@href,'a=page_h_com_find_all')]").click
    on_open_new_page(driver)
end