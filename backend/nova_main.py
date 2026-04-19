from flask import Flask, request, jsonify
from flask_cors import CORS
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from datetime import date as date_cls
import requests
import nova_init as initParm


app = Flask(__name__)
CORS(app)

# 重試用 session：遇到 502/503/504 自動退避重試
_retry = Retry(
    total=2,
    backoff_factor=1,
    status_forcelist=[502, 503, 504],
    allowed_methods=["GET"],
)
_session = requests.Session()
_session.mount("https://", HTTPAdapter(max_retries=_retry))

# APOD 快取：key 為日期字串，避免同日期重複打 API
_apod_cache: dict[str, dict] = {}


# -------- functions --------

def fetch_apod(date: str | None = None) -> dict:
    cache_key = date or date_cls.today().isoformat()
    if cache_key in _apod_cache:
        print(f"[cache hit] {cache_key}")
        return _apod_cache[cache_key]

    params = {"api_key": initParm.NASA_API_KEY}
    if date:
        params["date"] = date
    url = initParm.NASA_BASE_URL + initParm.APOD_PATH
    r = _session.get(url, params=params, timeout=30)
    r.raise_for_status()
    data = r.json()
    _apod_cache[cache_key] = data
    print(f"[cache store] {cache_key}")
    return data


# -------- api --------

# 首頁：列出可用端點
@app.route("/", methods=["GET"])
def index():
    return """
    <h1>NASA Cosmos Messenger API</h1>
    <ul>
      <li><a href="/apod">GET /apod</a> — 今日 APOD</li>
      <li><a href="/apod?date=1995-06-20">GET /apod?date=YYYY-MM-DD</a> — 指定日期 APOD</li>
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
    return jsonify(fake_date)

    try:
        data = fetch_apod(date)
        return jsonify(data)
    except requests.HTTPError as e:
        return jsonify({"error": f"NASA API error: {e.response.status_code}"}), 502
    except requests.RequestException as e:
        return jsonify({"error": f"Request failed: {str(e)}"}), 500


# -------- main --------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
