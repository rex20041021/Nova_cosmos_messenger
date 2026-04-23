# Nova Cosmos Messenger


A Flutter chat app where you can talk to **Nova**, an astronomy-focused AI assistant, browse NASA's Astronomy Picture of the Day (APOD), and collect your favourite skies.

DEMO: https://youtu.be/DjMtMbplITE

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                Flutter App (Dart)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │ chat_room    │  │ home / APOD  │  │ favorites │  │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘  │
│         │                 │                │        │
│  ┌──────▼─────────────────▼────────────────▼──────┐ │
│  │         Local SQLite  (sqflite)                │ │
│  │   chat.db (rooms + messages)                   │ │
│  │   favorites.db (saved APODs)                   │ │
│  └────────────────────────────────────────────────┘ │
│         │ HTTP (http package)                       │
└─────────┼───────────────────────────────────────────┘
          │
┌─────────▼───────────────────────────────────────────┐
│              Flask Backend (Python)                 │
│                                                     │
│  POST /chat ──► Groq API (llama-3.3-70b)  [Agent]   │
│                 │                                   │
│                 ├── tool: fetch_apod                │
│                 │       └──► NASA APOD API          │
│                 │                                   │
│                 └── tool: search_wikipedia          │
│                         └──► Wikipedia REST API     │
│                                                     │
│  GET /apod      ──►  NASA APOD API                  │
│  GET /apod/card ──►  Pillow + Google Fonts CDN      │
└─────────────────────────────────────────────────────┘
```

### Tech stack

| Layer | Technology | Version |
|---|---|---|
| Mobile UI | Flutter / Dart | SDK ^3.10.4 |
| Backend API | Flask + Flask-CORS | Python 3.x |
| Local DB | sqflite (SQLite) | ^2.3.3 |
| AI Model | Groq API — llama-3.3-70b-versatile | — |
| Astronomy data | NASA APOD API | public |
| Encyclopedia | Wikipedia REST API | public |
| Image generation | Pillow (PIL) | Python |
| Fonts (UI) | Google Fonts — Instrument Serif, DM Mono | ^6.2.1 |
| Share | share_plus | ^10.1.2 |
| URL open | url_launcher | ^6.3.1 |

### Why this stack

**Flutter** was chosen for its expressive widget system and single codebase that runs on both Android and iOS. The Material 3 theming layer is fully overridden with a custom dark palette so the app looks nothing like a default scaffold.

**Flask** keeps the backend minimal. The only reason a backend exists at all is to proxy API secrets (NASA key, Groq key) away from the client, and to run the server-side card-image composer (Pillow) that cannot run on-device. Everything else stays local.

**NASA APOD API** has a 30 requests/day quota and is occasionally unreliable. Two layers of defence are in place: 1. a server-side in-memory cache (`_apod_cache`, keyed by date string) so the same date never hits the API twice; 2. `requests.HTTPAdapter` with `Retry(total=3, backoff_factor=1, status_forcelist=[502, 503, 504])` so transient network errors back off and retry automatically instead of surfacing a failure to the user.

**sqflite (SQLite)** provides zero-dependency local persistence. Chat history and favourites survive app restarts without any remote account or network. Schema migrations are handled with `onUpgrade` callbacks — v2 added `wiki_json` via `ALTER TABLE`.

**Wikipedia REST API** provides free, structured encyclopedic content with no authentication required. The `/api/rest_v1/page/summary/{title}` endpoint returns a clean JSON payload (title, description, extract, thumbnail URL, page URL) that maps directly to the wiki card rendered in chat — no scraping or HTML parsing needed.

**Groq / llama-3.3-70b-versatile** gives OpenAI-compatible function calling at zero cost during prototyping. Nova runs as a **tool-use agent**: the model decides on its own whether to call `fetch_apod` or `search_wikipedia`, with what arguments, and the backend loop (`_run_chat_loop`) iterates up to 3 rounds so the model can chain tool results into a final answer — the classic ReAct (Reason + Act) pattern.

---

## Features

### Basic

| # | Requirement | Implementation |
|---|---|---|
| 1 | Input field summons keyboard and sends messages | `TextField` in `_InputBar` — `autofocus: true`, `TextInputAction.send` submits on keyboard action key |
| 2 | Messages ordered newest at bottom | `ListView.builder` with messages stored and retrieved by `created_at ASC`; `ScrollController` auto-scrolls to bottom after every new message |
| 3 | Scrollable message list | `ListView.builder` inside `Expanded` — scrolls freely when content overflows |
| 4 | Fixed input bar at bottom | `Column` → `Expanded(ListView)` + fixed `_InputBar`; bar stays anchored when soft keyboard appears via `resizeToAvoidBottomInset: true` |

---

### Bonus

#### 1 · Local database persistence (sqflite)

All data lives on-device in SQLite — no account required, no network needed for history.

- **`chat.db`** — `rooms` table (id, name, timestamps) + `messages` table (id, room_id, text, apod_json, wiki_json, from_user, created_at). Schema versioned: v2 added `wiki_json` via an `ALTER TABLE` migration in `onUpgrade`.
- **`favorites.db`** — `favorites` table stores full APOD metadata (date, title, explanation, url, hdurl, media_type, copyright, saved_at).
- On every app launch all rooms, messages, and favourites are rehydrated from disk automatically.

#### 2 · AI chat — Groq API (llama-3.3-70b-versatile)

Nova is an astronomy-focused AI assistant with **OpenAI-compatible function calling**. Two tools are registered:

- `fetch_apod(date?)` — pulls NASA APOD for any date back to 1995-06-16; results are server-cached to avoid burning the 30 req/day quota. Accepted date formats:
  - Explicit: `2004-10-21`, `2004/10/21`
  - Natural language (resolved by the model): "今天的 APOD", "昨天", "兩天前", "give me the picture from October 10, 2000"
- `search_wikipedia(query)` — searches English Wikipedia and returns a structured summary; the system prompt instructs the model to translate Chinese terms to English before querying (e.g. 蟹狀星雲 → Crab Nebula).

**Multi-turn history** — the full room message history is sent on every `/chat` request, giving the model conversation memory within a session.

**Multiple chat rooms** — users can create, rename, and delete independently named rooms; each room keeps its own conversation history in the local DB.

#### 3 · Additional features

**APOD Explorer**

- Browse today's APOD or pick any historical date via `DatePickerDialog` (range: 1995-06-16 → today).
- **Random APOD** — uses NASA's `count=1` API parameter (mutually exclusive with `date`) to pull a random picture from the 30-year archive.
- Full-screen detail page with pinch-to-zoom (`InteractiveViewer`), copyright attribution, and scrollable explanation.

**Favourites collection**

- Star any APOD from its detail page; the star icon updates immediately and persists across sessions via `FavoritesDB`.
- Dedicated Favourites page with a 2-column image grid. Each card shows a gradient overlay, a sequential index badge, and a VIDEO badge for video APODs.
- Video APODs open in an external browser (`url_launcher`); image APODs push to the detail page.

**APOD Share Card**

- Tapping the share icon in the detail page calls `GET /apod/card` on the backend.
- The backend downloads the HD image, resizes it to 1080 px wide (max 1440 px tall), and composites a 295 px info bar below it: a warm cream accent line, the title in **Playfair Display Bold Italic** (auto-downloaded from Google Fonts on first use and cached in `backend/fonts/`), date in monospace, photographer credit, and a NASA attribution string.
- A preview bottom sheet (`DraggableScrollableSheet`) shows the card via `Image.memory` + `InteractiveViewer` before the user confirms sharing. On confirm the bytes are written to a temp file and passed to `share_plus`.

**Wikipedia cards in chat**

- When Nova calls `search_wikipedia`, the result renders as a rich card inline in the chat: full-width thumbnail, Instrument Serif italic title, DM Mono extract, and a tappable URL row that opens the Wikipedia page in the browser.

**Polished dark UI**

- Palette: `#050505` background · `#F6F2EA` foreground · `#D9C5A7` warm cream accent · `#E94B2A` signal red.
- Typography: Instrument Serif (italic display headings) + DM Mono (body / metadata).
- Home page hero has a **Ken Burns animation** (24 s scale + pan loop, `ClipRect` to prevent overflow) over today's APOD.
- Animated pulse dot in the nav; 3-dot staggered opacity loading indicator in chat; press-state `AnimatedContainer` animations on every interactive element.

---

## Project structure

```
nova_cosmos_messenger/
├── backend/
│   ├── nova_init.py         # env vars & API constants
│   ├── nova_main.py         # Flask app — routes, AI loop, card generator
│   └── fonts/               # auto-downloaded Google Fonts TTFs (git-ignored)
└── lib/
    ├── main.dart             # app entry point, dark ThemeData
    ├── config/
    │   └── api_config.dart   # baseUrl constant
    ├── models/
    │   ├── apod_data.dart
    │   ├── chat_message.dart
    │   ├── chat_room.dart
    │   └── wiki_info.dart
    ├── services/
    │   ├── apod_service.dart      # GET /apod HTTP wrapper
    │   ├── chat_service.dart      # POST /chat HTTP wrapper
    │   ├── chat_db.dart           # sqflite — rooms + messages
    │   └── favorites_db.dart      # sqflite — favourites
    └── route/
        ├── home_page.dart          # Ken Burns hero + nav
        ├── chat_history_page.dart  # room list
        ├── chat_room_page.dart     # AI chat + APOD/wiki cards
        ├── apod_detail_page.dart   # detail view + share preview sheet
        └── favorites_page.dart     # saved APOD grid
```

---

## Setup

### Backend

```bash
cd backend
pip install flask flask-cors requests pillow python-dotenv
```

Create `backend/.env`:
```
NASA_API_KEY=your_nasa_api_key
GROQ_API_KEY=your_groq_api_key
```

```bash
python nova_main.py
# Server starts on 0.0.0.0:5000
```

### Flutter

```bash
flutter pub get
# Edit lib/config/api_config.dart → set baseUrl to your machine's LAN IP
flutter run
```

> On the first share-card request the backend downloads Playfair Display Bold Italic (~60 KB) from Google Fonts and caches it to `backend/fonts/PlayfairDisplay-BoldItalic.ttf`. Subsequent requests use the cached file.
