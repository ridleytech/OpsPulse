# OpsPulse Backend

## Run

1. Install deps:

```bash
npm install
```

2. Start server:

```bash
npm run dev
```

## Endpoints

- `GET /health`
- `GET /api/assets`
- `GET /api/assets/:id`

## WebSocket (STOMP)

- URL: `ws://localhost:3000/ws`
- Destinations:
  - `/topic/telemetry.<ASSET_ID>`
  - `/topic/events.<ASSET_ID>`
