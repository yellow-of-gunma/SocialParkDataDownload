
// ページ解析開始
function run(event) {
    event.preventDefault();

    // ページタイプによって分岐
    const pageType = Number(document.getElementById("page_type").value);
    switch (pageType){
        case 0:
            parseDiary();
            break;
    }
}

// 黙示録の解析
function parseDiary(){
    const dialyData = {}
    
    const domparser = new window.DOMParser();
    const pageSourceDoc = document.getElementById("page_source");
    const doc = domparser.parseFromString(pageSourceDoc.value, 'text/html');
    const centerDom = doc.getElementById('Center');

    // 本文領域の解析
    const diaryDetailBox = centerDom
        .getElementsByClassName("dparts diaryDetailBox")[0]
        .getElementsByClassName("parts")[0];
    const dialyDom = diaryDetailBox.getElementsByTagName("dl")[0];

    // 投稿日時
    dialyData.date = parseDateTime(dialyDom.getElementsByTagName("dt")[0].innerText);

    // タイトル
    dialyData.title = getTitleTextByDLDom(dialyDom);

    // 添付画像
    const dBody = getBodyDomByDLDom(dialyDom);
    const photoDom = dBody.getElementsByClassName("photo")[0];
    const numOfPhoto = photoDom ? photoDom.getElementsByTagName("li").length : 0;

    // 本文
    const contentText = dBody.innerText.slice(numOfPhoto + 1);
    const contentHTML = photoDom ? dBody.innerHTML.split('</ul>')[1].slice(1) : dBody.innerHTML.slice(1);
    dialyData.content = {
        text: contentText,
        html: contentHTML
    }
    
    const likeList = diaryDetailBox.getElementsByClassName("body")[1].innerText.split('\n');
    dialyData.like = []
    for(let i = 1; i < likeList.length - 1; i++){
        dialyData.like.push(likeList[i])
    }

    // コメントの解析
    dialyData.comment = [];
    const commentList = centerDom
        .getElementsByClassName("dparts commentList")[0]
        .getElementsByClassName("parts")[0]
        .getElementsByTagName("form")[0]
        .getElementsByTagName("dl");
    for(let i = 0; i < commentList.length; i ++){
        // 投稿日時
        const cDateTime = parseDateTime(commentList[i].getElementsByTagName("dt")[0].innerText);

        // 投稿者
        const cTitle = getTitleTextByDLDom(commentList[i]).split('\n')[1].slice(1);

        // 内容
        const cBody = getBodyDomByDLDom(commentList[i]).getElementsByClassName("text")[0].innerText;

        // 解析データの格納
        dialyData.comment.push({
            date: cDateTime,
            poster: cTitle,
            content: cBody
        })
    }
    console.log(dialyData);
}

// 投稿日時解析の共通処理
function parseDateTime(text){
    const yearSplit = text.split('年');
    const monthSplit = yearSplit[1].split('月');
    const daySplit = monthSplit[1].split('日');
    const hourSplit = daySplit[1].split(':');
    return {
        year: yearSplit[0],
        month: monthSplit[0],
        day: daySplit[0],
        hour: hourSplit[0],
        minute: hourSplit[1]
    };
}

// <dl>タグのdomからTitleの文字列を取得する共通処理
function getTitleTextByDLDom(dlDom) {
    return dlDom
        .getElementsByTagName("dd")[0]
        .getElementsByClassName("title")[0]
        .getElementsByClassName("heading")[0]
        .innerText
}

// <dl>タグのdomからBodyのDomを取得する共通処理
function getBodyDomByDLDom(dlDom) {
    return dlDom
        .getElementsByTagName("dd")[0]
        .getElementsByClassName("body")[0]
}

// セレクトボックスの要素作成
function createOptionElement(key, value){
    const op = document.createElement("option");
    op.value = key;
    op.text = value;
    return op;
}

// 初期化処理
function init() {
    document.getElementById("page_type").appendChild(createOptionElement(0, "黙示録"));
    document.getElementById("page_type").appendChild(createOptionElement(1, "アキバ"));

    const messageDoc = document.getElementById("message");
    messageDoc.style.color = "red";
    //messageDoc.innerText = "";
}