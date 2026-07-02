# STOMP in OpsPulse (Beginner Guide)

This document explains what STOMP is, why OpsPulse uses it, and how the app’s `STOMPClient` works.

## What is STOMP?

**STOMP** (Simple/Streaming Text Oriented Messaging Protocol) is a lightweight messaging protocol.

- It’s often used over **WebSockets** so an app can maintain a single, long-lived connection.
- The server can then **push messages to the client in real time** (instead of the client constantly polling).

In OpsPulse, STOMP is used for:

- **Live telemetry** updates (to drive the charts)
- **Live events** updates (to drive the event feed)

## The basic idea (mental model)

- **WebSocket** = a persistent pipe between the app and the server
- **STOMP** = a way to send structured “frames” through that pipe

The app:

- connects to the backend WebSocket
- sends a STOMP `CONNECT` frame
- sends STOMP `SUBSCRIBE` frames to topics
- waits for STOMP `MESSAGE` frames

## STOMP frames (what actually travels over the wire)

A STOMP frame is:

- a **command** line
- followed by **headers** (`key:value`) lines
- followed by a blank line
- followed by an optional **body**
- terminated by a **null byte** (`\0`)

Example (conceptual):

```text
MESSAGE
destination:/topic/telemetry.A-100
content-type:application/json

{"timestamp":"2026-01-01T00:00:00Z","pressure":123.4,"flow":10.2,"temperature":85.0}
\0
```

## Where the WebSocket URL is configured

In the iOS app, the WebSocket endpoint comes from:

- `OpsPulse/BackendConfig.swift`

The STOMP client defaults to:

- `BackendConfig.wsURL`

## Topics (destinations) OpsPulse subscribes to

OpsPulse subscribes to destinations of the form:

- `"/topic/telemetry.<ASSET_ID>"`
- `"/topic/events.<ASSET_ID>"`

For example:

- `/topic/telemetry.A-100`
- `/topic/events.A-100`

When a STOMP `MESSAGE` arrives, it includes a `destination` header. OpsPulse uses that header to decide which subscription handler should run.

## What the iOS app does with incoming messages

At a high level:

- **Telemetry messages**:
  - decoded from JSON into a telemetry DTO
  - converted into app-friendly points (for Swift Charts)
  - appended to an in-memory list so the graph updates

- **Event messages**:
  - decoded from JSON into an event DTO
  - inserted into SwiftData (so the UI updates)

Important: the **server** is the source of truth for “live” updates.

- The app does not generate telemetry/events by itself.
- The only exception is SwiftUI previews, which may use local sample data.

## How `STOMPClient` works (mapped to its methods)

### `connect()`

- Creates and resumes a `URLSessionWebSocketTask`
- Sends a STOMP `CONNECT` frame with:
  - `accept-version: 1.2`
  - `heart-beat: 10000,10000`
- Starts `receiveLoop()`

### `subscribe(destination:handler:)`

- Stores your handler in a dictionary keyed by `destination`
- Sends a STOMP `SUBSCRIBE` frame with:
  - `id: sub-<N>`
  - `destination: <destination>`

Note: the current implementation stores **one handler per destination**.

### `receiveLoop()`

- Calls `webSocketTask.receive(...)`
- On success:
  - normalizes `.data` or `.string` into `Data`
  - calls `handleIncoming(...)`
  - calls `receiveLoop()` again (to keep listening)
- On failure:
  - disconnects and clears subscriptions

### `parseFrames(_:)`

- Splits incoming data on the STOMP frame terminator (`\0`)
- Splits headers vs body on `\n\n`
- Parses:
  - first line as the command
  - remaining lines as headers

## Troubleshooting

### "Nothing is updating"

- Confirm the backend is running and reachable
- Confirm the app is using the correct `wsURL`
- Confirm you are subscribing to the correct destination (`/topic/telemetry.<id>`)

### "I see a WebSocket connection but no messages"

Common causes:

- the server is not publishing messages to that topic
- asset id mismatch (subscribed to `A-100` but server publishes `A-1`)
- server expects authentication headers (not implemented in this demo client)

### Heartbeats

The client requests heartbeats via the `heart-beat` header, but it does not actively send periodic heartbeat frames on its own. Some servers are fine with this; others may require additional heartbeat handling.

## Related files

- `OpsPulse/Clients/STOMPClient.swift` (STOMP over WebSocket implementation)
- `OpsPulse/BackendConfig.swift` (backend REST + WebSocket endpoints)
