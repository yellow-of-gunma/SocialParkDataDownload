

// ページ解析開始
function run(event) {
    event.preventDefault();
    const pageType = document.getElementById("page_type").value;
    console.log(pageType)

    // 各変数・画面要素の初期化
    const messageDoc = document.getElementById("message");
    messageDoc.style.color = "red";
    //messageDoc.innerText = pageType;

    // 今回データのHTMLを解析
    const domparser = new window.DOMParser();
    const pageSourceDoc = document.getElementById("page_source");
    const doc = domparser.parseFromString(pageSourceDoc.value, 'text/html');
    const centerDoc = doc.getElementById('Center');
    const diaryDetailBox = centerDoc.getElementsByClassName("dparts diaryDetailBox")[0].getElementsByClassName("parts")[0]
    const commentList = centerDoc
        .getElementsByClassName("dparts commentList")[0]
        .getElementsByClassName("parts")[0]
        .getElementsByTagName("form")[0]
        .getElementsByTagName("dl")
    console.log(diaryDetailBox)
    for(let i = 0; i < commentList.length; i ++){
        console.log(commentList[i])
        const dateTime = commentList[i].getElementsByTagName("dt")[0].innerText;
        const title = commentList[i]
            .getElementsByTagName("dd")[0]
            .getElementsByClassName("title")[0]
            .getElementsByClassName("heading")[0]
            .innerText
            .split('\n')[1]
            .slice(1);
        const body = commentList[i]
            .getElementsByTagName("dd")[0]
            .getElementsByClassName("body")[0]
            .getElementsByClassName("text")[0].innerText;

        console.log(dateTime)
        console.log(title)
        console.log(body)
    }
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
}