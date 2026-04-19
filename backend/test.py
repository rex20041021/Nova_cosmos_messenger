import requests

API_KEY = "FhfkS4BxazxJDbKhna8aoagO07SL49tFp9qdyrnh"
BASE_URL = "https://api.nasa.gov/planetary/apod"


def fetch_apod(date: str | None = None) -> dict:
    params = {"api_key": API_KEY}
    if date:
        params["date"] = date
    r = requests.get(BASE_URL, params=params, timeout=30)
    r.raise_for_status()
    return r.json()


if __name__ == "__main__":
    today = fetch_apod()
    print("=== Today's APOD ===")
    print(f"title:      {today.get('title')}")
    print(f"date:       {today.get('date')}")
    print(f"media_type: {today.get('media_type')}")
    print(f"url:        {today.get('url')}")
    print(f"explanation: {today.get('explanation', '')[:120]}...")

    print()

    sample = fetch_apod("1995-06-20")
    print("=== 1995-06-20 APOD ===")
    print(f"title:      {sample.get('title')}")
    print(f"date:       {sample.get('date')}")
    print(f"media_type: {sample.get('media_type')}")
    print(f"url:        {sample.get('url')}")
