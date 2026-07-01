import Foundation

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

    private var webSocketTask: URLSessionWebSocketTask?
    private var subscriptions: [String: MessageHandler] = [:]
    private var nextSubId = 1

    init(wsURL: URL = BackendConfig.wsURL, urlSession: URLSession = .shared) {
        self.wsURL = wsURL
        self.urlSession = urlSession
    }

    func connect() {
        if webSocketTask != nil { return }

        let task = urlSession.webSocketTask(with: wsURL)
        webSocketTask = task
        task.resume()

        sendFrame(command: "CONNECT", headers: [
            "accept-version": "1.2",
            "heart-beat": "10000,10000"
        ])

        receiveLoop()
    }

    func disconnect() {
        sendFrame(command: "DISCONNECT", headers: [:])
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        subscriptions.removeAll()
    }

    func subscribe(destination: String, handler: @escaping MessageHandler) throws {
        guard webSocketTask != nil else { throw STOMPClientError.notConnected }
        let subId = "sub-\(nextSubId)"
        nextSubId += 1
        subscriptions[destination] = handler
        sendFrame(command: "SUBSCRIBE", headers: [
            "id": subId,
            "destination": destination
        ])
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure:
                self.disconnect()
            case .success(let message):
                switch message {
                case .data(let data):
                    self.handleIncoming(data)
                case .string(let string):
                    self.handleIncoming(Data(string.utf8))
                @unknown default:
                    break
                }
                self.receiveLoop()
            }
        }
    }

    private func handleIncoming(_ data: Data) {
        let frames = parseFrames(data)
        for frame in frames {
            if frame.command == "MESSAGE", let destination = frame.headers["destination"], let handler = subscriptions[destination] {
                handler(destination, frame.body)
            }
        }
    }

    private func parseFrames(_ data: Data) -> [STOMPFrame] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let parts = text.split(separator: "\0", omittingEmptySubsequences: true)
        var frames: [STOMPFrame] = []

        for part in parts {
            let normalized = part.hasPrefix("\n") ? part.drop(while: { $0 == "\n" }) : Substring(part)
            guard let headRange = normalized.range(of: "\n\n") else { continue }

            let headerBlock = normalized[..<headRange.lowerBound]
            let bodyBlock = normalized[headRange.upperBound...]

            let lines = headerBlock.split(separator: "\n", omittingEmptySubsequences: false)
            guard let command = lines.first.map(String.init) else { continue }

            var headers: [String: String] = [:]
            for line in lines.dropFirst() {
                guard let idx = line.firstIndex(of: ":") else { continue }
                let key = String(line[..<idx])
                let value = String(line[line.index(after: idx)...])
                headers[key] = value
            }

            frames.append(STOMPFrame(command: command, headers: headers, body: Data(bodyBlock.utf8)))
        }

        return frames
    }

    private func sendFrame(command: String, headers: [String: String], body: Data? = nil) {
        guard let webSocketTask else { return }

        var frame = "\(command)\n"
        for (k, v) in headers {
            frame += "\(k):\(v)\n"
        }
        frame += "\n"

        var data = Data(frame.utf8)
        if let body {
            data.append(body)
        }
        data.append(0)

        webSocketTask.send(.data(data)) { _ in }
    }
}
