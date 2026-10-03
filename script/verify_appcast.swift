#!/usr/bin/env swift
import CryptoKit
import Foundation

// The public key embedded in Chameo's release bundles.
let chameoPublicKey = "/DO+T5vBJ5T0Z1DGBe97MTDbOqGNGpzS8vXuLIFNHEU="

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

guard CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3 else {
    fail("usage: verify_appcast.swift APPCAST [PUBLIC_ED_KEY]")
}

do {
    let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let prefix = Data("<!-- sparkle-signatures:\n".utf8)
    guard let start = data.range(of: prefix, options: .backwards),
          let end = data.range(of: Data("-->".utf8), in: start.upperBound..<data.endIndex),
          let block = String(data: data[start.upperBound..<end.lowerBound], encoding: .utf8) else {
        fail("appcast is missing its Sparkle feed signature")
    }
    let fields = block.split(separator: "\n").compactMap { line -> (String, String)? in
        let parts = line.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), parts[1].trimmingCharacters(in: .whitespaces))
    }
    guard fields.filter({ $0.0 == "edSignature" }).count == 1,
          fields.filter({ $0.0 == "length" }).count == 1,
          let signatureField = fields.first(where: { $0.0 == "edSignature" }),
          let lengthField = fields.first(where: { $0.0 == "length" }),
          let signature = Data(base64Encoded: signatureField.1),
          signature.count == 64,
          let length = UInt64(lengthField.1) else {
        fail("appcast has malformed Sparkle signing metadata")
    }
    let content = data[..<start.lowerBound]
    guard UInt64(content.count) == length else {
        fail("appcast signed length does not match its content")
    }
    let keyString = CommandLine.arguments.count == 3 ? CommandLine.arguments[2] : chameoPublicKey
    guard let keyData = Data(base64Encoded: keyString) else { fail("invalid public key") }
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
    guard key.isValidSignature(signature, for: content) else {
        fail("appcast signature does not match the public key and content")
    }
    print("appcast_signature=verified")
} catch {
    fail(error.localizedDescription)
}
