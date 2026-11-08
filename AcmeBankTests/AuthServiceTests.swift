import XCTest
@testable import AcmeBank

/// Exercises `AuthService.login` through the real `APIClient` decode path
/// (a `URLProtocol` stub replaces the network, nothing else is faked), so
/// these cover both the status-code → `AuthError` mapping and the JSON keys
/// the hand-written `LoginResponse` DTO actually reads.
///
/// Scope caveat, per the PR review: the payload below is the documented
/// `POST /api/login` shape, NOT a fixture captured from the Mock Backend,
/// and `Generated/acme-mock-backend-login-v1/` is not committed at this
/// head. So this is a regression guard against *our* side drifting — it
/// cannot detect the published contract moving first. It should be replaced
/// by the generated types plus a captured fixture once that tree lands.
final class AuthServiceTests: XCTestCase {

    override func tearDown() {
        StubURLProtocol.responder = nil
        super.tearDown()
    }

    func test_login_on200_decodesPayloadIntoLoginResult() async throws {
        StubURLProtocol.responder = { _ in
            (200, Data(#"{"token":"tok-1","customerId":"cust-1","firstName":"Taylor"}"#.utf8))
        }

        let result = try await makeAuthService().login(
            username: "bankuser.one@acmebank.com",
            password: "Password123"
        )

        XCTAssertEqual(
            result,
            LoginResult(token: "tok-1", customerId: "cust-1", firstName: "Taylor")
        )
    }

    func test_login_sendsUsernameAndPasswordAsJSONBody() async throws {
        let sentBody = UncheckedBox<[String: String]?>(nil)
        StubURLProtocol.responder = { request in
            if let data = request.bodyData {
                sentBody.value = try? JSONDecoder().decode([String: String].self, from: data)
            }
            return (200, Data(#"{"token":"t","customerId":"c","firstName":"f"}"#.utf8))
        }

        _ = try await makeAuthService().login(
            username: "bankuser.one@acmebank.com",
            password: "Password123"
        )

        XCTAssertEqual(
            sentBody.value,
            ["username": "bankuser.one@acmebank.com", "password": "Password123"]
        )
    }

    /// The mapping `LoginViewModel` depends on for its "Incorrect username
    /// or password" message — it silently breaks if `APIClient`'s 401
    /// handling changes.
    func test_login_on401_mapsToInvalidCredentials() async {
        StubURLProtocol.responder = { _ in (401, Data(#"{"error":"unauthorized"}"#.utf8)) }

        await assertLoginThrows(.invalidCredentials)
    }

    func test_login_on500_mapsToServerError() async {
        StubURLProtocol.responder = { _ in (500, Data()) }

        await assertLoginThrows(.server)
    }

    /// A 200 whose body does not match the expected keys must surface as a
    /// coarse server error, not crash or decode into garbage.
    func test_login_onUndecodableSuccessBody_mapsToServerError() async {
        StubURLProtocol.responder = { _ in (200, Data(#"{"tokenz":"t"}"#.utf8)) }

        await assertLoginThrows(.server)
    }

    // MARK: - Helpers

    private func makeAuthService() -> AuthService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return AuthService(apiClient: APIClient(session: URLSession(configuration: configuration)))
    }

    private func assertLoginThrows(
        _ expected: AuthError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await makeAuthService().login(username: "u", password: "p")
            XCTFail("expected login to throw \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? AuthError, expected, file: file, line: line)
        }
    }
}

/// Answers every request from a canned `(statusCode, body)` pair so the
/// networking stack can be exercised without a server.
private final class StubURLProtocol: URLProtocol {
    static var responder: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard
            let responder = StubURLProtocol.responder,
            let url = request.url
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let (statusCode, body) = responder(request)
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension URLRequest {
    /// `URLProtocol` strips `httpBody` for stream-backed requests, so fall
    /// back to draining `httpBodyStream`.
    var bodyData: Data? {
        if let httpBody {
            return httpBody
        }
        guard let stream = httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// Mutable capture box for values written from the stub's closure.
private final class UncheckedBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
