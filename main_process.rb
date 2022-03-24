# main
def main()
    # WebDriverの生成
    driver = create_webdriver()

    # ログイン
    login_social_park(driver)

    # 一覧ページに遷移
    move_to_the_list(driver)

    # 一覧を1ページずつめくっていく
    index = 1
    loop do
        # 取得範囲の終端を迎えたら終了
        if index > $traverse_end_index
            break
        end

        # 進捗の表示
        print_log("【INFO】ListIndex: " + index.to_s + "/" + $traverse_end_index.to_s)

        # 取得範囲の先端を迎えていたら、
        # 表示されているリンクを一通り踏んでデータを取得する
        if index >= $traverse_start_index
            traverse(driver)
        end

        # 次のページがあれば遷移し、なければ終了
        index += 1
        sleep_time = $default_sleep_time
        begin
            nextElement = driver.find_element(:class, 'next')
            nextElement.find_element(:tag_name, 'a').click
            on_open_new_page(driver)
        rescue
            # sleepが128秒を超えるようになったら終了させる
            # この時点で合計4分以上はsleepしている
            if sleep_time > 128
                print_log("【WARN】 次のページがありません")
                break
            end

            # スリープ時間を更新してスリープ
            sleep sleep_time
            sleep_time *= 2
            retry
        end
    end

    # 終了
    print_log("【INFO】正常に終了しました")
    driver.quit
end
