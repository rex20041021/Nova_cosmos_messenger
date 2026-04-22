from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from datetime import date as date_cls
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont
from urllib.parse import quote
import json
import requests
import nova_init as initParm


app = Flask(__name__)
CORS(app)

# 重試用 session：遇到 502/503/504 自動退避重試
_retry = Retry(
    total=3,
    backoff_factor=1,
    status_forcelist=[502, 503, 504],
    allowed_methods=["GET"],
)
_session = requests.Session()
_session.mount("https://", HTTPAdapter(max_retries=_retry))

# APOD 快取：key 為日期字串，避免同日期重複打 API
_apod_cache: dict[str, dict] = {}

# Nova 人格（system prompt）。每次呼叫時會動態追加今天日期。
NOVA_SYSTEM_PROMPT_BASE = (
    "你是 Nova，一位熱愛天文的 AI 夥伴。"
    "你的任務是陪使用者聊天、介紹天文知識、協助他們探索 NASA 每日天文圖 (APOD)。"
    "請一律用繁體中文回覆，語氣輕鬆親切，避免過長的教科書式說明。"
    "如果使用者只是閒聊，就自然地聊；如果問到天文主題，給出準確、簡潔的解釋。\n"
    "當使用者想看某一天的 APOD（例如『給我看2000年10月10日的照片』、"
    "『今天的 APOD』、『昨天的那張』），請呼叫 fetch_apod 工具。"
    "日期格式必須為 YYYY-MM-DD；若使用者說『今天』就省略 date 參數。"
    "拿到工具結果後，用繁中簡短介紹這張圖的主題，不要把英文原文完整貼上來。\n"
    "當使用者詢問特定天體、天文現象、太空任務或儀器的深入知識（例如『蟹狀星雲是什麼？』、"
    "『詹姆斯·韋伯望遠鏡的特色？』、『黑洞的事件視界』），請呼叫 search_wikipedia 工具查詢。"
    "呼叫時 query 必須翻成英文（如：蟹狀星雲→Crab Nebula、黑洞→Black hole）。"
    "工具結果是英文摘要，請轉述成繁中並融入你的回答，不要整段貼英文原文。"
    "閒聊或使用者問題本身就很模糊時不必呼叫 wikipedia。"
)

WIKI_UA = "NovaCosmosMessenger/0.1 (https://github.com/)"

# APOD tool 定義（OpenAI-compatible function calling）
FETCH_APOD_TOOL = {
    "type": "function",
    "function": {
        "name": "fetch_apod",
        "description": (
            "Fetch NASA Astronomy Picture of the Day (APOD) for a given date. "
            "Use when the user asks to see the APOD for a specific date, or 'today'. "
            "Valid date range: 1995-06-16 to today."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "date": {
                    "type": "string",
                    "description": "Date in YYYY-MM-DD format. Omit for today's APOD.",
                },
            },
            "required": [],
        },
    },
}

SEARCH_WIKIPEDIA_TOOL = {
    "type": "function",
    "function": {
        "name": "search_wikipedia",
        "description": (
            "Search English Wikipedia for astronomical knowledge: celestial objects, "
            "missions, instruments, phenomena, astronomers. Use when the user wants "
            "encyclopedic information. Do NOT use for casual chat."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": (
                        "English search term. Translate Chinese terms first "
                        "(蟹狀星雲→Crab Nebula, 哈伯太空望遠鏡→Hubble Space Telescope, "
                        "黑洞→Black hole)."
                    ),
                },
            },
            "required": ["query"],
        },
    },
}

# APOD 起始日（由 NASA 官方）
_APOD_MIN_DATE = date_cls(1995, 6, 16)


def _valid_apod_date(date_str: str) -> bool:
    try:
        d = date_cls.fromisoformat(date_str)
    except ValueError:
        return False
    return _APOD_MIN_DATE <= d <= date_cls.today()


# -------- functions --------

def call_groq(
    messages: list[dict],
    tools: list[dict] | None = None,
    temperature: float = 0.7,
) -> dict:
    headers = {
        "Authorization": f"Bearer {initParm.GROQ_API_KEY}",
        "Content-Type": "application/json",
    }
    payload: dict = {
        "model": initParm.GROQ_MODEL,
        "messages": messages,
        "temperature": temperature,
    }
    if tools:
        payload["tools"] = tools
    r = requests.post(initParm.GROQ_URL, headers=headers, json=payload, timeout=30)
    r.raise_for_status()
    return r.json()


def fetch_apod(date: str | None = None) -> dict:
    cache_key = date or date_cls.today().isoformat()
    if cache_key in _apod_cache:
        print(f"[cache hit] {cache_key}")
        return _apod_cache[cache_key]

    params = {"api_key": initParm.NASA_API_KEY}
    if date:
        params["date"] = date
    url = initParm.NASA_BASE_URL + initParm.APOD_PATH
    r = _session.get(url, params=params, timeout=15)
    r.raise_for_status()
    data = r.json()
    _apod_cache[cache_key] = data
    print(f"[cache store] {cache_key}")
    return data


def search_wikipedia(query: str) -> dict | None:
    base = "https://en.wikipedia.org"
    headers = {"User-Agent": WIKI_UA}

    # opensearch 找最接近的條目標題
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

    # 取條目摘要
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
        "url": (s.get("content_urls") or {}).get("desktop", {}).get("page"),
        "thumbnail": (s.get("thumbnail") or {}).get("source"),
    }


# -------- image card --------

_CARD_WIDTH = 1080
_PADDING = 48


def _load_font(size: int):
    candidates = [
        "C:/Windows/Fonts/arialbd.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def _wrap_text(text: str, font, max_width: int, draw) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current: list[str] = []
    for word in words:
        test = " ".join(current + [word])
        bbox = draw.textbbox((0, 0), test, font=font)
        if (bbox[2] - bbox[0]) <= max_width or not current:
            current.append(word)
        else:
            lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))
    return lines


def compose_card(image_bytes: bytes, title: str, date: str) -> BytesIO:
    img = Image.open(BytesIO(image_bytes)).convert("RGB")
    ratio = _CARD_WIDTH / img.width
    new_h = int(img.height * ratio)
    img = img.resize((_CARD_WIDTH, new_h), Image.LANCZOS).convert("RGBA")

    # 上方深色漸層（讓白字可讀）
    top_h = 300
    top_overlay = Image.new("RGBA", (_CARD_WIDTH, top_h), (0, 0, 0, 0))
    top_draw = ImageDraw.Draw(top_overlay)
    for y in range(top_h):
        alpha = int(210 * (1 - y / top_h))
        top_draw.line([(0, y), (_CARD_WIDTH, y)], fill=(0, 0, 0, alpha))
    img.paste(top_overlay, (0, 0), top_overlay)

    # 下方薄漸層
    bottom_h = 90
    bottom_overlay = Image.new("RGBA", (_CARD_WIDTH, bottom_h), (0, 0, 0, 0))
    bottom_draw = ImageDraw.Draw(bottom_overlay)
    for y in range(bottom_h):
        alpha = int(170 * (y / bottom_h))
        bottom_draw.line([(0, y), (_CARD_WIDTH, y)], fill=(0, 0, 0, alpha))
    img.paste(bottom_overlay, (0, img.height - bottom_h), bottom_overlay)

    draw = ImageDraw.Draw(img)

    title_font = _load_font(56)
    date_font = _load_font(34)
    attr_font = _load_font(24)

    # 標題（最多 2 行）
    title_lines = _wrap_text(title, title_font, _CARD_WIDTH - 2 * _PADDING, draw)[:2]
    y = _PADDING
    for line in title_lines:
        draw.text((_PADDING, y), line, font=title_font, fill=(255, 255, 255))
        bbox = draw.textbbox((0, 0), line, font=title_font)
        y += (bbox[3] - bbox[1]) + 12

    # 日期
    draw.text((_PADDING, y + 8), date, font=date_font, fill=(220, 220, 220))

    # 右下角署名
    attr = "NASA Astronomy Picture of the Day"
    bbox = draw.textbbox((0, 0), attr, font=attr_font)
    attr_w = bbox[2] - bbox[0]
    draw.text(
        (_CARD_WIDTH - _PADDING - attr_w, img.height - 55),
        attr,
        font=attr_font,
        fill=(230, 230, 230),
    )

    # 扁平化成 RGB 輸出 JPEG
    flat = Image.new("RGB", img.size, (0, 0, 0))
    flat.paste(img, (0, 0), img)
    buf = BytesIO()
    flat.save(buf, format="JPEG", quality=90)
    buf.seek(0)
    return buf


# -------- api --------

# 首頁：列出可用端點
@app.route("/", methods=["GET"])
def index():
    return """
    <h1>NASA Cosmos Messenger API</h1>
    <ul>
      <li><a href="/apod">GET /apod</a> — 今日 APOD</li>
      <li><a href="/apod?date=1995-06-20">GET /apod?date=YYYY-MM-DD</a> — 指定日期 APOD</li>
      <li><a href="/apod/card?date=1995-06-20">GET /apod/card?date=YYYY-MM-DD</a> — 產生分享卡片圖</li>
      <li>POST /chat — Nova 對話（body: {"text": "...", "history": [{"role": "user"|"ai", "text": "..."}]}）</li>
    </ul>
    """


# 取得 APOD (今日或指定日期)
@app.route("/apod", methods=["GET"])
def apod():
    date = request.args.get("date")
    fake_date = {
        "copyright": "Miguel Claro\n(TWAN,\nDark Sky Alqueva)",
        "date": "2026-04-19",
        "explanation": "Have you ever had stars in your eyes? It appears that the eye on the left does, and moreover, it appears to be gazing at even more stars. The featured 27-frame mosaic was taken in 2019 from Ojas de Salar in the Atacama Desert of Chile.  The eye is actually a small lagoon captured reflecting the dark night sky as the Milky Way Galaxy arched overhead. The seemingly smooth band of the Milky Way is really composed of billions of stars, but decorated with filaments of light-absorbing dust and red-glowing nebulas. Additionally, both Jupiter (slightly left the galactic arch) and Saturn (slightly to the right) are visible.  The lights of small towns dot the unusual vertical horizon.  The rocky terrain around the lagoon appears to some more like the surface of Mars than our Earth.   Sky Surprise: What picture did APOD feature on your birthday? (after 1995)",
        "hdurl": "https://apod.nasa.gov/apod/image/2604/EyeOnMW_Claro_1380.jpg",
        "media_type": "image",
        "service_version": "v1",
        "title": "Eye on the Milky Way",
        "url": "https://apod.nasa.gov/apod/image/2604/EyeOnMW_Claro_960.jpg",
    }
    # return jsonify(fake_date)

    try:
        data = fetch_apod(date)
        print(data)
        return jsonify(data)
    except requests.HTTPError as e:
        return jsonify({"error": f"NASA API error: {e.response.status_code}"}), 502
    except requests.RequestException as e:
        return jsonify({"error": f"Request failed: {str(e)}"}), 500


# 產生合成分享卡片（背景圖 + 標題 + 日期）
@app.route("/apod/card", methods=["GET"])
def apod_card():
    date = request.args.get("date")
    try:
        data = fetch_apod(date)
        if data.get("media_type") == "video":
            return jsonify({"error": "video APOD has no image"}), 400
        img_url = data.get("hdurl") or data.get("url")
        r = _session.get(img_url, timeout=30)
        r.raise_for_status()
        buf = compose_card(r.content, data.get("title", ""), data.get("date", ""))
        return send_file(
            buf,
            mimetype="image/jpeg",
            download_name=f"apod_{data.get('date', 'card')}.jpg",
        )
    except requests.HTTPError as e:
        return jsonify({"error": f"NASA API error: {e.response.status_code}"}), 502
    except requests.RequestException as e:
        return jsonify({"error": f"Request failed: {str(e)}"}), 500
    except Exception as e:
        return jsonify({"error": f"Card generation failed: {str(e)}"}), 500


# -------- chat helpers --------

def _build_chat_messages(history: list, user_text: str) -> list[dict]:
    system_prompt = (
        NOVA_SYSTEM_PROMPT_BASE
        + f"\n今天的日期是 {date_cls.today().isoformat()}。"
    )
    messages: list[dict] = [{"role": "system", "content": system_prompt}]
    for msg in history:
        role = "user" if msg.get("role") == "user" else "assistant"
        text = (msg.get("text") or "").strip()
        if text:
            messages.append({"role": role, "content": text})
    messages.append({"role": "user", "content": user_text})
    return messages


def _execute_tool_call(tc: dict) -> tuple[dict, dict]:
    """執行一個 tool call。回傳 (給 LLM 的結果, 併入最終回應的 extras)。"""
    fn = tc.get("function") or {}
    name = fn.get("name")
    try:
        args = json.loads(fn.get("arguments") or "{}")
    except json.JSONDecodeError:
        args = {}
    if not isinstance(args, dict):
        args = {}

    if name == "fetch_apod":
        date_arg = args.get("date")
        if date_arg and not _valid_apod_date(date_arg):
            return (
                {"error": f"Invalid date: {date_arg}. Must be YYYY-MM-DD between 1995-06-16 and today."},
                {},
            )
        try:
            full = fetch_apod(date_arg)
        except Exception as e:
            return ({"error": str(e)}, {})
        for_llm = {
            "title": full.get("title"),
            "date": full.get("date"),
            "explanation": full.get("explanation"),
            "media_type": full.get("media_type"),
            "copyright": full.get("copyright"),
        }
        return (for_llm, {"apod": full})

    if name == "search_wikipedia":
        query = (args.get("query") or "").strip()
        if not query:
            return ({"error": "query is required"}, {})
        try:
            result = search_wikipedia(query)
        except Exception as e:
            return ({"error": str(e)}, {})
        if result is None:
            return ({"error": f"No Wikipedia article found for: {query}"}, {})
        # LLM 只需要 title / description / extract，縮圖和 URL 給前端用
        for_llm = {
            "title": result.get("title"),
            "description": result.get("description"),
            "extract": result.get("extract"),
        }
        return (for_llm, {"wiki": result})

    return ({"error": f"Unknown tool: {name}"}, {})


def _run_chat_loop(
    messages: list[dict],
    tools: list[dict],
    max_iter: int = 3,
) -> dict:
    extras: dict = {}
    for _ in range(max_iter):
        resp = call_groq(messages, tools=tools)
        msg = ((resp.get("choices") or [{}])[0]).get("message") or {}
        tool_calls = msg.get("tool_calls") or []

        if not tool_calls:
            return {"text": (msg.get("content") or "").strip(), **extras}

        messages.append({
            "role": "assistant",
            "content": msg.get("content") or "",
            "tool_calls": tool_calls,
        })
        for tc in tool_calls:
            for_llm, for_fe = _execute_tool_call(tc)
            extras.update(for_fe)
            messages.append({
                "role": "tool",
                "tool_call_id": tc.get("id"),
                "content": json.dumps(for_llm, ensure_ascii=False),
            })

    return {"text": "（抱歉，剛剛想太久迷路了，再問我一次？）", **extras}


# Nova 對話：支援多輪歷史 + APOD tool-calling。Wikipedia tool 之後加入。
@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json(silent=True) or {}
    user_text = (data.get("text") or "").strip()
    history = data.get("history") or []

    if not user_text:
        return jsonify({"error": "text is required"}), 400

    messages = _build_chat_messages(history, user_text)
    try:
        return jsonify(_run_chat_loop(
            messages,
            tools=[FETCH_APOD_TOOL, SEARCH_WIKIPEDIA_TOOL],
        ))
    except requests.HTTPError as e:
        return jsonify({"error": f"Groq API error: {e.response.status_code}"}), 502
    except requests.RequestException as e:
        return jsonify({"error": f"Request failed: {str(e)}"}), 500


# -------- main --------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
