//
//  OpsPulseApp.swift
//  OpsPulse
//
//  Created by Randall Ridley on 7/1/26.
//

import Foundation

// Minimal representation of a STOMP frame.
//
// STOMP frames are text-based and look like:
//   COMMAND\n
//   header1:value1\n
//   header2:value2\n
//   \n
//   <optional body bytes>
//   \0
//
// `command` is the first line, headers are key/value pairs, and the frame is terminated by a NULL byte (\0).
struct STOMPFrame {
    let command: String
    let headers: [String: String]
    let body: Data
}

enum STOMPClientError: Error {
    case notConnected
    case invalidFrame
}

final class STOMPClient {
    typealias MessageHandler = (String, Data) -> Void

    private let wsURL: URL
    private let urlSession: URLSession

    // Backing WebSocket for all STOMP traffic.
    private var webSocketTask: URLSessionWebSocketTask?

    // Subscription handlers keyed by STOMP destination.
    // NOTE: This implementation keeps one handler per destination.
    // If you need multiple handlers per destination, change the value type to an array.
    private var subscriptions: [String: MessageHandler] = [:]

    // Incrementing ID used for the STOMP `id` header on SUBSCRIBE frames.
    private var nextSubId = 1

    init(wsURL: URL = BackendConfig.wsURL, urlSession: URLSession = .shared) {
        self.wsURL = wsURL
        self.urlSession = urlSession
    }

    func connect() {
        // Prevent duplicate connects.
        if webSocketTask != nil { return }

        let task = urlSession.webSocketTask(with: wsURL)
        webSocketTask = task
        task.resume()

        // STOMP requires a CONNECT frame after the WebSocket is established.
        //
        // `accept-version`: STOMP protocol version(s) the client supports.
        // `heart-beat`: desired heartbeat intervals (client->server, server->client) in ms.
        //              This asks for 10s heartbeats in both directions.
        sendFrame(command: "CONNECT", headers: [
            "accept-version": "1.2",
            "heart-beat": "10000,10000"
        ])

        // Begin receiving frames and dispatching to subscription handlers.
        receiveLoop()
    }

    func disconnect() {
        // Politely tell the server we're disconnecting, then close the WebSocket.
        sendFrame(command: "DISCONNECT", headers: [:])
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        subscriptions.removeAll()
    }

    func subscribe(destination: String, handler: @escaping MessageHandler) throws {
        // You must connect() before subscribing.
        guard webSocketTask != nil else { throw STOMPClientError.notConnected }

        // STOMP subscriptions have an `id` header that is used to identify them.
        // We generate a unique ID locally.
        let subId = "sub-\(nextSubId)"
        nextSubId += 1

        // Store the handler so incoming MESSAGE frames can be routed by destination.
        subscriptions[destination] = handler

        // SUBSCRIBE registers interest in a destination (topic/queue).
        sendFrame(command: "SUBSCRIBE", headers: [
            "id": subId,
            "destination": destination
        ])
    }

    private func receiveLoop() {
        // URLSessionWebSocketTask delivers one message at a time.
        // We call receive() again after each message to create a continuous loop.
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure:
                // Any receive error tears down the connection and clears subscriptions.
                self.disconnect()
            case .success(let message):
                switch message {
                case .data(let data):
                    // Most STOMP servers send frames as bytes.
                    self.handleIncoming(data)
                case .string(let string):
                    // Some servers send text messages; treat them equivalently.
                    self.handleIncoming(Data(string.utf8))
                @unknown default:
                    break
                }

                // Keep listening for the next WebSocket message.
                self.receiveLoop()
            }
        }
    }

    private func handleIncoming(_ data: Data) {
        // A single WebSocket message can contain one or multiple STOMP frames.
        let frames = parseFrames(data)
        for frame in frames {
            // We only route MESSAGE frames to destination handlers.
            if frame.command == "MESSAGE", let destination = frame.headers["destination"], let handler = subscriptions[destination] {
                handler(destination, frame.body)
            }
        }
    }

    private func parseFrames(_ data: Data) -> [STOMPFrame] {
        // This implementation treats incoming frames as UTF-8 text.
        // That works for typical JSON bodies and header blocks, but binary payloads
        // would require a more exact implementation (e.g. content-length parsing).
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        // STOMP frames are null-byte terminated. Multiple frames may be concatenated.
        let parts = text.split(separator: "\0", omittingEmptySubsequences: true)
        var frames: [STOMPFrame] = []

        for part in parts {
            // Some servers send heartbeats as a leading newline, or separate frames
            // with blank lines. Drop leading newlines so parsing remains stable.
            let normalized = part.hasPrefix("\n") ? part.drop(while: { $0 == "\n" }) : Substring(part)

            // Headers end with a blank line ("\n\n"). Everything after that is the body.
            guard let headRange = normalized.range(of: "\n\n") else { continue }

            let headerBlock = normalized[..<headRange.lowerBound]
            let bodyBlock = normalized[headRange.upperBound...]

            // Header block is line-delimited:
            // - First line: command
            // - Remaining lines: key:value
            let lines = headerBlock.split(separator: "\n", omittingEmptySubsequences: false)
            guard let command = lines.first.map(String.init) else { continue }

            var headers: [String: String] = [:]
            for line in lines.dropFirst() {
                guard let idx = line.firstIndex(of: ":") else { continue }
                let key = String(line[..<idx])
                let value = String(line[line.index(after: idx)...])
                headers[key] = value
            }

            // Body is treated as UTF-8 bytes.
            frames.append(STOMPFrame(command: command, headers: headers, body: Data(bodyBlock.utf8)))
        }

        return frames
    }

    private func sendFrame(command: String, headers: [String: String], body: Data? = nil) {
        // If not connected, drop outbound frames.
        guard let webSocketTask else { return }

        // Build the STOMP frame header section.
        var frame = "\(command)\n"
        for (k, v) in headers {
            frame += "\(k):\(v)\n"
        }
        frame += "\n"

        // Assemble as bytes:
        // header block (UTF-8), optional body, then a null terminator.
        var data = Data(frame.utf8)
        if let body {
            data.append(body)
        }
        data.append(0)

        // Fire-and-forget send. Errors are ignored in this demo client.
        webSocketTask.send(.data(data)) { _ in }
    }
}
