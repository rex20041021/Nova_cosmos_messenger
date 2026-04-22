import requests
from urllib.parse import quote


BASE_URL = "https://api.nasa.gov/planetary/apod"
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
WIKI_UA = "NovaCosmosMessenger/0.1 (test script)"


def fetch_apod(date: str | None = None) -> dict:
    params = {"api_key": API_KEY}
    if date:
        params["date"] = date
    r = requests.get(BASE_URL, params=params, timeout=30)
    r.raise_for_status()
    return r.json()


def fetch_groq_chat(
    prompt: str,
    model: str = "llama-3.3-70b-versatile",
    system: str | None = None,
    temperature: float = 0.7,
) -> dict:
    headers = {
        "Authorization": f"Bearer {GROQ_API}",
        "Content-Type": "application/json",
    }
    messages: list[dict] = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    payload = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
    }
    r = requests.post(GROQ_URL, headers=headers, json=payload, timeout=30)
    r.raise_for_status()
    return r.json()


def search_wikipedia(query: str, lang: str = "zh") -> dict | None:
    base = f"https://{lang}.wikipedia.org"
    headers = {"User-Agent": WIKI_UA}

    # 1. opensearch 找最接近的條目標題
    r = requests.get(
        f"{base}/w/api.php",
        headers=headers,
        params={
            "action": "opensearch",
            "search": query,
            "limit": 1,
            "namespace": 0,
            "format": "json",
        },
        timeout=10,
    )
    r.raise_for_status()
    data = r.json()
    titles = data[1] if len(data) > 1 else []
    if not titles:
        return None
    title = titles[0]

    # 2. 取該條目摘要
    r2 = requests.get(
        f"{base}/api/rest_v1/page/summary/{quote(title)}",
        headers=headers,
        timeout=10,
    )
    r2.raise_for_status()
    s = r2.json()
    return {
        "title": s.get("title"),
        "description": s.get("description"),
        "extract": s.get("extract"),
        "url": s.get("content_urls", {}).get("desktop", {}).get("page"),
        "thumbnail": (s.get("thumbnail") or {}).get("source"),
    }


if __name__ == "__main__":
    # today = fetch_apod()
    # print("=== Today's APOD ===")
    # print(f"title:      {today.get('title')}")
    # print(f"date:       {today.get('date')}")
    # print(f"media_type: {today.get('media_type')}")
    # print(f"url:        {today.get('url')}")
    # print(f"explanation: {today.get('explanation', '')[:120]}...")

    # print()

    # sample = fetch_apod("1995-06-20")
    # print("=== 1995-06-20 APOD ===")
    # print(f"title:      {sample.get('title')}")
    # print(f"date:       {sample.get('date')}")
    # print(f"media_type: {sample.get('media_type')}")
    # print(f"url:        {sample.get('url')}")

    # resp = fetch_groq_chat(
    #     prompt="用一句話介紹哈伯太空望遠鏡。",
    #     system="你是 Nova，一個熱愛天文的助手，請用繁體中文回覆。",
    # )
    # print("=== Groq Chat ===")
    # print(f"model:   {resp.get('model')}")
    # print(f"usage:   {resp.get('usage')}")
    # choice = resp.get("choices", [{}])[0]
    # print(f"content: {choice.get('message', {}).get('content')}")
    # print(f"finish:  {choice.get('finish_reason')}")

    # --- Wikipedia test ---
    cases = [
        # 驗證：中文 query 直接打 en.wikipedia.org 會怎樣
        ("en", "蟹狀星雲"),
        ("en", "哈伯太空望遠鏡"),
        ("en", "獵戶座大星雲"),
        ("en", "黑洞"),
        # 對照組：英文 query 打 en 才是正解
        ("en", "Crab Nebula"),
        ("en", "Hubble Space Telescope"),
    ]
    for lang, query in cases:
        print(f"=== Wikipedia ({lang}) / query={query!r} ===")
        try:
            res = search_wikipedia(query, lang=lang)
        except Exception as e:
            print(f"ERROR: {e}")
            print()
            continue
        if res is None:
            print("no match")
        else:
            extract = res.get("extract") or ""
            print(f"title:       {res.get('title')}")
            print(f"description: {res.get('description')}")
            print(f"extract[:300]: {extract[:300]}")
            print(f"extract_len: {len(extract)}")
            print(f"url:         {res.get('url')}")
            print(f"thumbnail:   {res.get('thumbnail')}")
        print()
