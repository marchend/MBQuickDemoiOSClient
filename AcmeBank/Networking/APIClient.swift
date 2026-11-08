import Foundation

/// Errors surfaced by `APIClient` for any request it performs.
enum APIError: Error, Equatable {
    /// The server responded `401 Unauthorized`.
    case unauthorized
    /// The server responded with any other non-2xx status code.
    case server(Int)
    /// The request could not reach the server at all (offline, DNS, etc.),
    /// or the app's configuration is invalid.
    case transport(String)
    /// The response body could not be decoded as the expected type.
    case decoding(String)
}

/// Thin async/await wrapper around `URLSession` for JSON POST requests
/// against the Mock Backend.
///
/// The base URL is read lazily from the app's Info.plist (`API_BASE_URL`,
/// itself baked from the `Config/Base.xcconfig` build setting) — it is never
/// hardcoded in Swift, and a missing/invalid value is surfaced as a regular
/// thrown error rather than crashing the app at launch or on first use.
struct APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    /// POSTs `body` as JSON to `path` (relative to the configured base URL)
    /// and decodes a successful (2xx) response as `Response`.
    func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body
    ) async throws -> Response {
        let baseURL = try resolveBaseURL()

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.transport("Response was not an HTTP response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw APIError.decoding(error.localizedDescription)
            }
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.server(httpResponse.statusCode)
        }
    }

    private func resolveBaseURL() throws -> URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: raw)
        else {
            throw APIError.transport("API_BASE_URL is missing or invalid in Info.plist")
        }
        return url
    }
}
