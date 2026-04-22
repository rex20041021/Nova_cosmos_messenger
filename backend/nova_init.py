import os
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

NASA_API_KEY = os.getenv("NASA_API_KEY")
NASA_BASE_URL = "https://api.nasa.gov"
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "llama-3.3-70b-versatile"


APOD_PATH = "/planetary/apod"

if not NASA_API_KEY:
    raise RuntimeError("NASA_API_KEY 未設定，請檢查 backend/.env")
if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY 未設定，請檢查 backend/.env")