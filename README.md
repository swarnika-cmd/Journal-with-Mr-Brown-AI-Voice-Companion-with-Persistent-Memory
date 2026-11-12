<div align="center">

<!-- Hero Banner -->
<img src=".github/assets/hero-banner.png" alt="Journal with Mr Brown" width="100%" />

<br />

# 📖 Journal with Mr Brown

### *A voice journal with searchable memory*

[![Live Demo](https://img.shields.io/badge/🚀_Live_Demo-Visit_App-8B2252?style=for-the-badge&logoColor=white)](https://mrbrown-frontend.onrender.com)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.4-3178C6?style=for-the-badge&logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![React](https://img.shields.io/badge/React-19-61DAFB?style=for-the-badge&logo=react&logoColor=black)](https://react.dev/)

---

*Some days you need a friend who just listens.*
*Mr Brown is that friend — except he keeps every entry and can find it again.*

</div>

---

## ✨ What is This?

**Journal with Mr Brown** is a voice-first AI journal where you speak your thoughts and receive warm, empathetic responses from **Mr Brown** — an AI companion that uses your recent entries for context, tracks your mood, and lets you search your past entries.

Unlike traditional text journals, you simply **press record and talk**. Mr Brown transcribes your words, responds in a warm tone, speaks his reply aloud, and stores each entry with a vector embedding so you can search it later.

> *"Hey Mr Brown, what have I said about my presentation at work?"*
>
> *"Ah, I remember — you were worried about the presentation at work. But you also mentioned it went better than expected the next day."*

Every entry is stored, and embedded with Gemini when `GEMINI_API_KEY` is set, so Mr Brown can retrieve it later by similarity when you ask. Search is vector similarity only; there is no date filter.

---

## 🏗️ Architecture

<div align="center">
  <img src=".github/assets/architecture.png" alt="Journal with Mr Brown Architecture" width="85%" />
</div>

---


## 🌟 Features

### 🎙️ Voice-First Journaling
Press the record button and speak freely. When you stop recording, the audio is uploaded to the backend as one file (up to 10 MB) and transcribed with **Deepgram's Nova-2**. This is not streaming transcription.

Each turn runs these stages one after another:

1. Upload the recording.
2. Speech-to-text (Deepgram).
3. LLM reply (see below).
4. Text-to-speech (ElevenLabs).
5. Mood analysis, database write and embedding.

The reply audio plays in the browser once the response arrives. The backend logs STT, LLM, TTS and total milliseconds per turn, keyed by an `X-Request-Id` response header. Total is server handler time, from upload received to response sent (it excludes upload transfer). The LLM stage includes fetching your last 5 entries from Postgres. [`scripts/measure_turn.sh`](scripts/measure_turn.sh) times 20 sequential turns against your own deployment and prints p50 and p95; see [Measuring turn time](#-measuring-turn-time). No turn-time figure is published here.

### 🤖 Mr Brown — Your AI Companion
Mr Brown isn't a generic chatbot. He is a persona defined by a system prompt: warm, empathetic, and conversational. Each reply is given your last 5 entries as context.

The reply model depends on which keys are set:
- If `OPENAI_API_KEY` is set, replies and mood analysis use OpenAI (`gpt-4o-mini`).
- Otherwise, if `GEMINI_API_KEY` is set, they use Gemini 2.5 Flash.
- If neither is set, or the chosen provider errors, the backend returns a short canned reply. It does not switch providers on error.

Embeddings, Ask Mr Brown answers and weekly insights always use Gemini, so `GEMINI_API_KEY` is needed for those.

### 🔊 Voice Responses
Each reply is converted to speech with **ElevenLabs** (`eleven_multilingual_v2`, MP3) and returned to the browser with the entry. If `ELEVENLABS_API_KEY` is missing or the call fails, the reply comes back as text only.

### 📊 Mood Tracking & Sentiment Analysis
Every journal entry is analyzed for emotional tone by an LLM. Your mood is scored on a 1-5 scale with a one-word label (for example *Happy*, *Anxious*, *Calm*, *Stressed*) and shown on a **mood heatmap calendar**. With no LLM key set, a keyword-based fallback assigns the score.

### 🔍 Ask Mr Brown (RAG Memory Search)
Ever wonder what you said three weeks ago about a particular topic? Ask Mr Brown. Using **pgvector** cosine-distance search over Gemini embeddings, it retrieves the most relevant past entries and has Gemini write an answer from them.

### 📈 Weekly Insights & Keepsakes
When you request it (it is not scheduled), Mr Brown generates a review of your last 7 days. It needs at least 3 entries in that window:
- **Summary** — A warm overview of your week
- **Themes** — Recurring topics and patterns
- **Mood Arc** — How your emotions evolved
- **Highlight** — Your brightest moment
- **Suggestion** — A gentle, non-preachy recommendation for next week

### 📅 Timeline View
Browse your past entries in a chronological timeline with mood indicators, and search them by text. Reply audio is not stored, so the timeline shows the text of each reply only.

---

## 📸 App Preview

<div align="center">
  <table style="border-collapse: collapse; border: none; background: transparent; width: 100%;">
    <tr>
      <td align="center" style="padding: 10px; border: none; width: 33%;">
        <strong>🎙️ Landing Page</strong><br/><br/>
        <img src=".github/assets/landing.png" width="100%" style="border-radius: 12px; border: 1px solid rgba(212, 131, 143, 0.3); box-shadow: 0 4px 12px rgba(0,0,0,0.15);" />
      </td>
      <td align="center" style="padding: 10px; border: none; width: 33%;">
        <strong>🔒 Retro Auth Cloud</strong><br/><br/>
        <img src=".github/assets/auth.png" width="100%" style="border-radius: 12px; border: 1px solid rgba(212, 131, 143, 0.3); box-shadow: 0 4px 12px rgba(0,0,0,0.15);" />
      </td>
      <td align="center" style="padding: 10px; border: none; width: 33%;">
        <strong>🏠 Interactive Dashboard</strong><br/><br/>
        <img src=".github/assets/dashboard.png" width="100%" style="border-radius: 12px; border: 1px solid rgba(212, 131, 143, 0.3); box-shadow: 0 4px 12px rgba(0,0,0,0.15);" />
      </td>
    </tr>
  </table>
</div>

---

## 🛠️ Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | React 19, TanStack Router, Tailwind CSS | Warm, glassmorphic UI with voice recording |
| **Backend** | Express.js, TypeScript | REST API with modular service architecture |
| **Database** | PostgreSQL + pgvector | Persistent storage with vector similarity search |
| **Cache / rate limits** | Redis (optional) | Caches entry lists, mood stats and the latest insight; backs per-IP rate limits. Without Redis the app queries the database directly and rate limits fall back to in-process memory |
| **ORM** | Prisma | Type-safe database access |
| **STT** | Deepgram Nova-2 | Speech-to-text on the uploaded recording |
| **LLM** | OpenAI `gpt-4o-mini` if `OPENAI_API_KEY` is set, else Gemini 2.5 Flash | Replies and mood analysis; Gemini is always used for Ask Mr Brown and insights |
| **TTS** | ElevenLabs | Natural voice synthesis for Mr Brown's replies |
| **Embeddings** | Gemini Embedding API | Vector representations for semantic memory search |
| **Local infra** | Docker Compose | Runs PostgreSQL (pgvector) and Redis only; the backend and frontend run on the host with npm |

---

## 🚀 Getting Started

### Prerequisites

- **Node.js** ≥ 18
- **Docker** & **Docker Compose** (for PostgreSQL + Redis)
- API keys for: **Deepgram**, **ElevenLabs**, **Google Gemini** (and/or OpenAI)

### 1. Clone the Repository

```bash
git clone https://github.com/swarnika-cmd/Journal-with-Mr-Brown-AI-Voice-Companion-with-Persistent-Memory.git
cd Journal-with-Mr-Brown-AI-Voice-Companion-with-Persistent-Memory
```

### 2. Set Up Environment Variables

```bash
cp .env.example backend/.env
```

The backend loads `backend/.env`. Edit it with your API keys:

```env
# Server
PORT=8001

# API Keys
DEEPGRAM_API_KEY=your_key_here
ELEVENLABS_API_KEY=your_key_here
GEMINI_API_KEY=your_key_here
# Optional. If set, replies and mood analysis use OpenAI instead of Gemini.
OPENAI_API_KEY=your_key_here

# Database
DATABASE_URL="postgresql://postgres:postgres@localhost:5436/clara_voice_journal"

# Auth
JWT_ACCESS_SECRET="your_random_secret"
JWT_REFRESH_SECRET="your_random_secret"
```

### 3. Start Infrastructure

```bash
docker-compose up -d
```

`docker-compose.yml` starts two containers (the backend and frontend are not containerized here):
- 🐘 **PostgreSQL 15** (`pgvector/pgvector:pg15`) on port `5436`
- 🔴 **Redis 7** (`redis:7-alpine`) on port `6379`

### 4. Set Up the Backend

```bash
cd backend
npm install
npx prisma generate
npx prisma db push
npm run dev
```

The backend server starts at `http://localhost:8001`.

### 5. Set Up the Frontend

```bash
cd clara-keeps-secrets
npm install
npm run dev
```

The frontend launches at `http://localhost:5173`.

### 6. Open & Enjoy

Navigate to `http://localhost:5173`, create an account, and start speaking. 🎙️

---

## 📁 Project Structure

```
Journal-with-Mr-Brown-AI-Voice-Companion-with-Persistent-Memory/
├── backend/                    # Express.js API server
│   ├── prisma/
│   │   └── schema.prisma       # Database schema (User, Entry, Insight)
│   └── src/
│       ├── server.ts           # Entry point
│       ├── routes/             # API route handlers
│       ├── services/
│       │   ├── llm.service.ts          # Mr Brown's personality & responses
│       │   ├── stt.service.ts          # Deepgram speech-to-text
│       │   ├── tts.service.ts          # ElevenLabs text-to-speech
│       │   ├── sentiment.service.ts    # AI mood analysis
│       │   ├── embedding.service.ts    # Vector embedding generation
│       │   ├── rag.service.ts          # Semantic memory search
│       │   └── insight.service.ts      # Weekly emotional insights
│       ├── middleware/         # Auth middleware (JWT)
│       └── lib/                # Prisma client & Redis
│
├── clara-keeps-secrets/        # React frontend (TanStack Start)
│   └── src/
│       ├── routes/             # Page routes
│       ├── components/
│       │   ├── mrbrown/        # Mr Brown UI components
│       │   │   ├── Landing.tsx         # Landing page
│       │   │   ├── AuthCloud.tsx       # Auth form
│       │   │   ├── RecordView.tsx      # Voice recording interface
│       │   │   ├── TimelineView.tsx    # Entry timeline
│       │   │   ├── AskView.tsx         # RAG query interface
│       │   │   ├── InsightsView.tsx    # Weekly insights display
│       │   │   ├── MoodCalendar.tsx    # Mood heatmap
│       │   │   └── FloatingHearts.tsx  # Ambient animations
│       │   └── ui/             # Reusable UI components (shadcn)
│       ├── hooks/              # Auth & state hooks
│       └── lib/                # API client utilities
│
├── scripts/                    # measure_turn.sh, make_sample_wav.py
├── docker-compose.yml          # PostgreSQL + Redis containers
├── .env.example                # Environment template
└── README.md                   # You are here ✨
```

---

## ⏱️ Measuring turn time

`scripts/measure_turn.sh` posts a recording to `/api/entries/voice` 20 times in sequence (paced to stay under the 20-requests-per-minute-per-IP limit) and prints per-turn client-side time (curl `time_total`) plus p50 and p95 using the nearest-rank method.

```bash
TOKEN=<access token> scripts/measure_turn.sh http://localhost:8001 my_recording.webm
```

- Run it against a backend with real Deepgram, ElevenLabs and OpenAI or Gemini keys, using a recording of speech. Audio without speech skips the LLM and TTS stages.
- `python3 scripts/make_sample_wav.py` writes a short tone WAV for smoke-testing the endpoint only.
- The server returns 200 even when the LLM or TTS provider fails (canned reply, no audio). The response carries a `degraded` flag; the script excludes degraded turns from p50/p95, prints how many there were, and exits non-zero if any occurred.
- Each turn creates a journal entry for that user, so use a test account.
- Per-stage server timings are in the backend log as one JSON `voice_turn` line per turn, with the same request id as the `X-Request-Id` response header.

---

## 🎨 Design Philosophy

The UI is intentionally **warm, nostalgic, and intimate** — designed to feel like opening a well-loved journal rather than using a tech product.

- **Cream & dusty rose palette** — Soft, comforting colors that reduce screen anxiety
- **Glassmorphism cards** — Frosted glass overlays with subtle blur effects
- **Floating heart animations** — Ambient particles that make the space feel alive
- **Lace-strip borders** — Decorative elements inspired by vintage stationery
- **Script typography** — Mr Brown's name rendered in elegant cursive to feel personal

Every design decision serves the same goal: *make the user feel safe enough to be honest.*

---

## ⚠️ Known limitations

- Without `GEMINI_API_KEY`, entries are saved with a zero vector, so Ask Mr Brown cannot retrieve them. Add the key before journaling, since existing entries are not re-embedded.
- Provider failures in the LLM or TTS stage do not fail the request: the user gets a canned reply or no audio, and the response has `degraded: true`.
- Reply audio is not stored; it plays once.

---

## 🔮 Roadmap

- [ ] 🌙 **Dark mode** — A midnight variant for late-night journaling
- [ ] 📱 **PWA support** — Install as a native app on mobile
- [ ] 🎵 **Ambient sounds** — Optional background music while recording
- [ ] 🔗 **Export & share** — Download entries as PDF keepsakes
- [ ] 🌐 **Multi-language** — Mr Brown speaks your language
- [ ] 👥 **Shared journals** — Couples & family memory spaces
- [ ] 🧩 **Plugin system** — Custom integrations (Spotify mood, weather context)

---

## 🤝 Contributing

Contributions are welcome! Whether it's fixing a bug, improving documentation, or proposing a new feature — open an issue or submit a PR.

```bash
# Fork the repo, create your branch
git checkout -b feature/amazing-feature

# Make your changes, then
git commit -m "Add amazing feature"
git push origin feature/amazing-feature
```

---

<div align="center">

### 💌

*Built with late nights, warm tea, and the belief that*
*everyone deserves a friend who listens.*

**Made with ❤️ by [Swarnika](https://github.com/swarnika-cmd)**

<br />

<sub>Mr Brown is listening.</sub>

</div>
