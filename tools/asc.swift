// asc — the smallest possible App Store Connect API client, for the ops
// steps that would otherwise be clicks in the developer portal: register
// the App ID, turn on a capability, create a certificate, generate a
// profile. Apple's tools all the way down: CryptoKit signs the token,
// URLSession makes the call. No third-party code (CLAUDE.md).
//
// Usage:
//   swiftc -O tools/asc.swift -o asc
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=… asc GET  /v1/certificates
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=… asc POST /v1/bundleIds body.json
//
// The key file is read by this program only; nothing prints it. Output is
// the response body; the exit status is non-zero for HTTP 4xx/5xx.

import CryptoKit
import Foundation

func base64url(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("asc: \(message)\n".utf8))
    exit(2)
}

func token() throws -> String {
    let env = ProcessInfo.processInfo.environment
    guard let keyID = env["ASC_KEY_ID"], let issuer = env["ASC_ISSUER_ID"], let path = env["ASC_KEY_PATH"]
    else { fail("set ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH") }
    let pem = try String(contentsOfFile: path, encoding: .utf8)
    let key = try P256.Signing.PrivateKey(pemRepresentation: pem)

    let now = Int(Date().timeIntervalSince1970)
    let header = try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": keyID, "typ": "JWT"])
    // Team keys carry an issuer; individual keys carry `sub: "user"` instead
    // and have no issuer at all. ASC_ISSUER_ID=user selects the latter.
    var claims: [String: Any] = ["iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"]
    if issuer == "user" { claims["sub"] = "user" } else { claims["iss"] = issuer }
    let payload = try JSONSerialization.data(withJSONObject: claims)
    let signingInput = "\(base64url(header)).\(base64url(payload))"
    let signature = try key.signature(for: Data(signingInput.utf8))
    return "\(signingInput).\(base64url(signature.rawRepresentation))"
}

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count >= 2 else { fail("usage: asc GET|POST|PATCH|DELETE /v1/path [body.json]") }
let method = arguments[arguments.startIndex]
let path = arguments[arguments.startIndex + 1]
let bodyPath = arguments.count >= 3 ? arguments[arguments.startIndex + 2] : nil

var request = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com\(path)")!)
request.httpMethod = method
request.setValue("Bearer \(try token())", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
if let bodyPath { request.httpBody = try Data(contentsOf: URL(fileURLWithPath: bodyPath)) }

let done = DispatchSemaphore(value: 0)
var status = 0
var body = Data()
let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let error { fail(error.localizedDescription) }
    status = (response as? HTTPURLResponse)?.statusCode ?? 0
    body = data ?? Data()
    done.signal()
}
task.resume()
done.wait()

FileHandle.standardOutput.write(body)
if !body.isEmpty { FileHandle.standardOutput.write(Data("\n".utf8)) }
FileHandle.standardError.write(Data("asc: HTTP \(status) \(method) \(path)\n".utf8))
exit(status >= 400 ? 1 : 0)
