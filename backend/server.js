import express from 'express';
import cors from 'cors';
import { WebSocketServer } from 'ws';
import http from 'http';

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;

const app = express();
app.use(cors());
app.use(express.json());

const assets = [
  { id: 'WELL-101', name: 'Well 101', type: 'well', location: 'Pad A', status: 'online' },
  { id: 'WELL-102', name: 'Well 102', type: 'well', location: 'Pad A', status: 'online' },
  { id: 'COMP-201', name: 'Compressor 201', type: 'compressor', location: 'Station 2', status: 'online' },
  { id: 'TANK-301', name: 'Tank 301', type: 'tank', location: 'Battery 3', status: 'offline' }
];

app.get('/health', (_req, res) => res.json({ ok: true }));

app.get('/api/assets', (_req, res) => res.json(assets));

app.get('/api/assets/:id', (req, res) => {
  const asset = assets.find(a => a.id === req.params.id);
  if (!asset) return res.status(404).json({ error: 'not_found' });
  res.json(asset);
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/ws' });

function buildFrame(command, headers = {}, body = '') {
  const headerLines = Object.entries(headers)
    .map(([k, v]) => `${k}:${v}`)
    .join('\n');
  return `${command}\n${headerLines}\n\n${body}\0`;
}

function parseFrames(buffer) {
  const text = buffer.toString('utf8');
  const frames = [];

  // STOMP frames can be concatenated; each ends with \0
  const parts = text.split('\0');
  for (const part of parts) {
    const trimmed = part.replace(/^\n+/, '');
    if (!trimmed.trim()) continue;

    const [head, ...bodyParts] = trimmed.split('\n\n');
    const lines = head.split('\n');
    const command = lines[0].trim();
    const headers = {};
    for (const line of lines.slice(1)) {
      const idx = line.indexOf(':');
      if (idx > 0) headers[line.slice(0, idx)] = line.slice(idx + 1);
    }
    const body = bodyParts.join('\n\n');
    frames.push({ command, headers, body });
  }
  return frames;
}

let nextMessageId = 1;

function nowIso() {
  return new Date().toISOString();
}

function makeTelemetry(assetId) {
  // deterministic-ish values for a nicer demo
  const t = Date.now() / 1000;
  const base = assetId.includes('WELL') ? 1200 : assetId.includes('COMP') ? 500 : 40;
  const pressure = base + Math.sin(t / 3) * (base * 0.04);
  const flow = (assetId.includes('TANK') ? 0 : 250) + Math.cos(t / 5) * 12;
  const temperature = 60 + Math.sin(t / 7) * 3;

  return {
    assetId,
    timestamp: nowIso(),
    pressure: Number(pressure.toFixed(2)),
    flow: Number(flow.toFixed(2)),
    temperature: Number(temperature.toFixed(2))
  };
}

function maybeEvent(assetId) {
  // low probability event generation
  if (Math.random() > 0.92) {
    return {
      id: `EVT-${Math.floor(Math.random() * 900000 + 100000)}`,
      assetId,
      timestamp: nowIso(),
      severity: ['info', 'warning', 'critical'][Math.floor(Math.random() * 3)],
      message: `Auto event for ${assetId}`
    };
  }
  return null;
}

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.subscriptions = new Map(); // destination -> subscriptionId

  ws.on('pong', () => (ws.isAlive = true));

  ws.on('message', (data) => {
    const frames = parseFrames(data);
    for (const frame of frames) {
      if (frame.command === 'CONNECT') {
        const resp = buildFrame('CONNECTED', {
          version: '1.2',
          'heart-beat': '10000,10000'
        });
        ws.send(resp);
      } else if (frame.command === 'SUBSCRIBE') {
        const destination = frame.headers.destination;
        const id = frame.headers.id;
        if (destination && id) ws.subscriptions.set(destination, id);
      } else if (frame.command === 'UNSUBSCRIBE') {
        // optional
        const id = frame.headers.id;
        if (id) {
          for (const [dest, subId] of ws.subscriptions.entries()) {
            if (subId === id) ws.subscriptions.delete(dest);
          }
        }
      } else if (frame.command === 'SEND') {
        // app-level send (e.g. acknowledgements)
        // In a real broker we'd route this; for demo we just no-op.
      } else if (frame.command === 'DISCONNECT') {
        ws.close();
      }
    }
  });

  ws.on('close', () => {
    ws.subscriptions?.clear?.();
  });
});

setInterval(() => {
  for (const client of wss.clients) {
    if (client.readyState !== 1) continue;
    if (!client.subscriptions) continue;

    for (const asset of assets) {
      const telemetryDest = `/topic/telemetry.${asset.id}`;
      const subId = client.subscriptions.get(telemetryDest);
      if (subId) {
        const payload = JSON.stringify(makeTelemetry(asset.id));
        client.send(buildFrame('MESSAGE', {
          subscription: subId,
          destination: telemetryDest,
          'message-id': String(nextMessageId++),
          'content-type': 'application/json'
        }, payload));
      }

      const eventDest = `/topic/events.${asset.id}`;
      const eventSubId = client.subscriptions.get(eventDest);
      if (eventSubId) {
        const evt = maybeEvent(asset.id);
        if (evt) {
          client.send(buildFrame('MESSAGE', {
            subscription: eventSubId,
            destination: eventDest,
            'message-id': String(nextMessageId++),
            'content-type': 'application/json'
          }, JSON.stringify(evt)));
        }
      }
    }
  }
}, 1000);

// Heartbeat / liveness
setInterval(() => {
  for (const ws of wss.clients) {
    if (ws.isAlive === false) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  }
}, 30000);

server.listen(PORT, () => {
  console.log(`OpsPulse backend running on http://localhost:${PORT}`);
  console.log(`REST: /api/assets  |  WS (STOMP): ws://localhost:${PORT}/ws`);
});
