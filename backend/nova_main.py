from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from datetime import date as date_cls
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont
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

# Nova 人格（system prompt）。之後 Step 3 會在這裡追加今天日期、tool 使用說明。
NOVA_SYSTEM_PROMPT = (
    "你是 Nova，一位熱愛天文的 AI 夥伴。"
    "你的任務是陪使用者聊天、介紹天文知識、協助他們探索 NASA 每日天文圖 (APOD)。"
    "請一律用繁體中文回覆，語氣輕鬆親切，避免過長的教科書式說明。"
    "如果使用者只是閒聊，就自然地聊；如果問到天文主題，給出準確、簡潔的解釋。"
)


# -------- functions --------

def call_groq(messages: list[dict], temperature: float = 0.7) -> dict:
    headers = {
        "Authorization": f"Bearer {initParm.GROQ_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": initParm.GROQ_MODEL,
        "messages": messages,
        "temperature": temperature,
    }
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


# Nova 對話：支援多輪歷史，目前只純 LLM，Step 3 會加 APOD / Wikipedia tools
@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json(silent=True) or {}
    user_text = (data.get("text") or "").strip()
    history = data.get("history") or []

    if not user_text:
        return jsonify({"error": "text is required"}), 400

    messages: list[dict] = [{"role": "system", "content": NOVA_SYSTEM_PROMPT}]
    for msg in history:
        role = "user" if msg.get("role") == "user" else "assistant"
        text = (msg.get("text") or "").strip()
        if text:
            messages.append({"role": role, "content": text})
    messages.append({"role": "user", "content": user_text})

    try:
        resp = call_groq(messages)
    except requests.HTTPError as e:
        return jsonify({"error": f"Groq API error: {e.response.status_code}"}), 502
    except requests.RequestException as e:
        return jsonify({"error": f"Request failed: {str(e)}"}), 500

    choice = (resp.get("choices") or [{}])[0]
    ai_text = ((choice.get("message") or {}).get("content") or "").strip()
    return jsonify({"text": ai_text})


# -------- main --------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
