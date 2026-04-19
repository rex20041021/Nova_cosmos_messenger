import os
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

NASA_API_KEY = os.getenv("NASA_API_KEY")
NASA_BASE_URL = "https://api.nasa.gov"

APOD_PATH = "/planetary/apod"

if not NASA_API_KEY:
    raise RuntimeError("NASA_API_KEY 未設定，請檢查 backend/.env")
