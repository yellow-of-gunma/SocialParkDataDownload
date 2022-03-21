require 'mechanize'
require 'open-uri'
require 'nokogiri'
require 'kconv'
require "rubygems"
require "csv"

agent = Mechanize.new

member_id_list = [
    [],
    [],
    []
]

#ログイン情報
#print "mail > "
mail = ''
#print "password > "
pass = ''

agent.max_history = 2
agent.user_agent_alias = 'Windows Chrome'
agent.conditional_requests = false

#ログインページ
login_page = agent.get('http://mckees.sns-park.com/?m=portal&a=page_user_top')
login_form = login_page.forms[0]

#ログインのための情報を入力して送信
login_form.field_with(name: 'username').value = mail
login_form.field_with(name: 'password').value = pass
top_page = login_form.submit

#メンバー検索のページに遷移
user_search_page = top_page.link_with(href: '?m=pc&a=page_h_search').click
user_search_form = user_search_page.forms[0]

#メンバー検索の結果ページに遷移
user_search_result_page = user_search_form.submit

#ユーザページに遷移
user_id = 109
user_page = user_search_result_page.link_with(:href => /target_c_member_id=#{user_id}/).click
doc = Nokogiri::HTML(user_page.body.toutf8, nil, 'utf-8')

#メンバー検索の結果の次ページに遷移
#user_search_result_2_page = user_search_result_page.link_with(text: '次を表示').click
#doc = Nokogiri::HTML(user_search_result_2_page.body.toutf8, nil, 'utf-8')

#ページタイトル表示
p doc.title
File.open('diary/' + doc.title + '.html','w', :encoding => "utf-8") do |poke|
    poke.puts(doc)
end