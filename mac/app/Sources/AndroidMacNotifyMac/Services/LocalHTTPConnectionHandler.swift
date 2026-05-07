import Foundation
import Network

struct LocalHTTPConnectionHandler: Sendable {
    private static let receiveChunkMaximumLength = 256 * 1024
    private static let maxHeaderBytes = 32 * 1024
    private static let headerSeparator = Data("\r\n\r\n".utf8)

    func receiveRequestHead(on connection: NWConnection) async throws -> HTTPRequestHead {
        var buffer = Data()

        while true {
            let chunk = try await receiveChunk(on: connection)
            if !chunk.data.isEmpty {
                buffer.append(chunk.data)
            }

            if let head = try parseRequestHead(from: buffer) {
                return head
            }

            if buffer.count > Self.maxHeaderBytes,
               buffer.range(of: Self.headerSeparator) == nil {
                throw LocalServerError.malformedRequest
            }

            if chunk.isComplete {
                throw LocalServerError.malformedRequest
            }
        }
    }

    func receiveBufferedRequest(_ head: HTTPRequestHead, on connection: NWConnection) async throws -> HTTPRequest {
        var body = head.initialBody
        while body.count < head.contentLength {
            let chunk = try await receiveChunk(on: connection)
            if !chunk.data.isEmpty {
                body.append(chunk.data)
            }

            if chunk.isComplete {
                break
            }
        }

        guard body.count >= head.contentLength else {
            throw LocalServerError.malformedRequest
        }

        return HTTPRequest(
            method: head.method,
            target: head.target,
            path: head.path,
            queryItems: head.queryItems,
            headers: head.headers,
            body: Data(body.prefix(head.contentLength))
        )
    }

    func receiveChunk(on connection: NWConnection) async throws -> (data: Data, isComplete: Bool) {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: Self.receiveChunkMaximumLength) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (data ?? Data(), isComplete))
            }
        }
    }

    func send(_ response: HTTPResponse, on connection: NWConnection) async {
        let data = serialize(response: response)
        await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { _ in
                continuation.resume()
            })
        }
    }

    private func parseRequestHead(from data: Data) throws -> HTTPRequestHead? {
        guard let headerRange = data.range(of: Self.headerSeparator) else {
            return nil
        }

        let headerData = data[..<headerRange.lowerBound]
        let bodyStartIndex = headerRange.upperBound

        guard let headerText = String(data: headerData, encoding: .utf8) else {
            throw LocalServerError.malformedRequest
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw LocalServerError.malformedRequest
        }

        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count >= 2 else {
            throw LocalServerError.malformedRequest
        }

        let method = String(requestParts[0]).uppercased()
        let target = String(requestParts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = line[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }

        guard let contentLength = Int(headers["content-length"] ?? "0"),
              contentLength >= 0
        else {
            throw LocalServerError.malformedRequest
        }
        guard bodyStartIndex <= Int.max - contentLength else {
            throw LocalServerError.malformedRequest
        }

        let components = URLComponents(string: "http://localhost\(target)")
        let path = components?.path ?? target
        let queryItems = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        return HTTPRequestHead(
            method: method,
            target: target,
            path: path,
            queryItems: queryItems,
            headers: headers,
            contentLength: contentLength,
            initialBody: Data(data[bodyStartIndex..<data.endIndex])
        )
    }

    private func serialize(response: HTTPResponse) -> Data {
        var responseString = "HTTP/1.1 \(response.statusCode) \(response.reasonPhrase)\r\n"
        for (key, value) in response.headers {
            responseString += "\(key): \(value)\r\n"
        }
        responseString += "\r\n"

        var data = Data(responseString.utf8)
        data.append(response.body)
        return data
    }
}
