//
//  OpsPulseTests.swift
//  OpsPulseTests
//
//  Created by Randall Ridley on 7/1/26.
//

@testable import OpsPulse
import SwiftData
import XCTest

final class OpsPulseTests: XCTestCase {
    private final class URLProtocolStub: URLProtocol {
        static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    private func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            AssetEntity.self,
            EventEntity.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        URLProtocolStub.requestHandler = nil
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        URLProtocolStub.requestHandler = nil
    }

    func testEventEntity_isAcknowledged() throws {
        let e1 = EventEntity(id: "e1", assetId: "a1", timestamp: Date(), severity: "low", message: "m")
        XCTAssertFalse(e1.isAcknowledged)

        e1.acknowledgedAt = Date()
        XCTAssertTrue(e1.isAcknowledged)
    }

    func testAssetEntity_upsert_insertsWhenMissing() throws {
        let container = makeModelContainer()
        let context = ModelContext(container)

        AssetEntity.upsert(
            from: AssetDTO(id: "A-1", name: "Well 1", type: "well", location: "Permian", status: "online"),
            in: context
        )
        try context.save()

        let descriptor = FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.id == "A-1" })
        let assets = try context.fetch(descriptor)
        XCTAssertEqual(assets.count, 1)
        XCTAssertEqual(assets.first?.name, "Well 1")
    }

    func testAssetEntity_upsert_updatesWhenExisting() throws {
        let container = makeModelContainer()
        let context = ModelContext(container)
        context.insert(AssetEntity(id: "A-1", name: "Old", type: "well", location: "X", status: "offline", updatedAt: Date(timeIntervalSince1970: 1)))
        try context.save()

        AssetEntity.upsert(
            from: AssetDTO(id: "A-1", name: "New", type: "compressor", location: "Y", status: "online"),
            in: context
        )
        try context.save()

        let descriptor = FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.id == "A-1" })
        let assets = try context.fetch(descriptor)
        XCTAssertEqual(assets.count, 1)
        XCTAssertEqual(assets.first?.name, "New")
        XCTAssertEqual(assets.first?.type, "compressor")
        XCTAssertEqual(assets.first?.location, "Y")
        XCTAssertEqual(assets.first?.status, "online")
    }

    func testAPIClient_fetchAssets_decodesResponse() async throws {
        let expectedURL = URL(string: "https://example.com/api/assets")!
        let json = #"[{"id":"A-1","name":"Well 1","type":"well","location":"Permian","status":"online"}]"#
        let data = Data(json.utf8)

        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url, expectedURL)
            XCTAssertEqual(request.httpMethod, "GET")
            let response = HTTPURLResponse(url: expectedURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let client = APIClient(
            baseURL: URL(string: "https://example.com")!,
            urlSession: makeURLSession(),
            keychain: KeychainStore(service: "OpsPulseTests"),
            authTokenKey: "ops_pulse_tests_token"
        )
        let assets = try await client.fetchAssets()

        XCTAssertEqual(assets.count, 1)
        XCTAssertEqual(assets.first?.id, "A-1")
        XCTAssertEqual(assets.first?.name, "Well 1")
    }

    func testAPIClient_fetchAssets_throwsOnHttpError() async throws {
        let expectedURL = URL(string: "https://example.com/api/assets")!
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url, expectedURL)
            let response = HTTPURLResponse(url: expectedURL, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let client = APIClient(
            baseURL: URL(string: "https://example.com")!,
            urlSession: makeURLSession(),
            keychain: KeychainStore(service: "OpsPulseTests"),
            authTokenKey: "ops_pulse_tests_token"
        )

        do {
            _ = try await client.fetchAssets()
            XCTFail("Expected error")
        } catch let error as APIError {
            switch error {
            case .httpStatus(let code):
                XCTAssertEqual(code, 500)
            default:
                XCTFail("Unexpected APIError: \(error)")
            }
        }
    }
}
