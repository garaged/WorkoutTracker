import Foundation

/// Redacts sensitive-ish substrings before writing to the *shareable* on-disk log file.
///
/// Why this exists:
/// - The app can export logs; exported files routinely get attached to issues / shared around.
/// - It's easy to accidentally log something you didn't intend (tokens, Authorization headers, etc.).
/// - Redaction is a safety net. It should be conservative and fast.
///
/// Design goals:
/// - **Never break the log format** (keep timestamps/categories/levels intact).
/// - **Mask values, not keys** so the log remains useful.
/// - **Be conservative**: we redact likely secrets (Bearer tokens, "token=...", api keys, etc.).
enum LogRedactor {

    // Precompiled regexes for performance.
    private static let bearerRegex = try! NSRegularExpression(
        pattern: #"(?i)(authorization\s*:\s*bearer\s+)([A-Za-z0-9\-\._~\+/]+=*)"#,
        options: []
    )

    private static let kvSecretRegex = try! NSRegularExpression(
        // Examples:
        // token=abc, token: abc, api_key: abc, password=abc
        pattern: #"(?i)\b(token|access_token|refresh_token|apikey|api_key|secret|password|authorization)\b\s*[:=]\s*([^\s,;]+)"#,
        options: []
    )

    private static let ocidRegex = try! NSRegularExpression(
        // OCI identifiers often start with ocid1...
        pattern: #"\b(ocid1\.[A-Za-z0-9\.\-_]+)\b"#,
        options: []
    )

    private static let emailRegex = try! NSRegularExpression(
        pattern: #"\b([A-Z0-9._%+-]+)@([A-Z0-9.-]+\.[A-Z]{2,})\b"#,
        options: [.caseInsensitive]
    )

    /// Returns a version of `input` with sensitive values masked.
    static func redact(_ input: String) -> String {
        var s = input

        // 1) Authorization: Bearer <token> -> Authorization: Bearer <redacted>
        s = replace(using: bearerRegex, in: s) { match, original in
            let prefix = original.substring(with: match.range(at: 1))
            return prefix + "<redacted>"
        }

        // 2) token=..., api_key:..., password=... -> keep key, mask value
        s = replace(using: kvSecretRegex, in: s) { match, original in
            let key = original.substring(with: match.range(at: 1))
            return key + "=<redacted>"
        }

        // 3) ocid1.... -> keep prefix + suffix to preserve traceability without leaking full id
        s = replace(using: ocidRegex, in: s) { match, original in
            let ocid = original.substring(with: match.range(at: 1))
            return maskMiddle(ocid, keepPrefix: 10, keepSuffix: 6)
        }

        // 4) email -> keep first char of local-part
        s = replace(using: emailRegex, in: s) { match, original in
            let local = original.substring(with: match.range(at: 1))
            let domain = original.substring(with: match.range(at: 2))
            let maskedLocal: String
            if local.count <= 1 {
                maskedLocal = "*"
            } else {
                maskedLocal = local.prefix(1) + String(repeating: "*", count: max(1, local.count - 1))
            }
            return maskedLocal + "@" + domain
        }

        // 5) Generic “very long” strings (often tokens) — optional light masking
        // We keep this conservative to avoid destroying legitimate numbers/ids.
        s = maskVeryLongRuns(s)

        return s
    }

    // MARK: - Helpers

    private static func replace(using regex: NSRegularExpression, in input: String, builder: (NSTextCheckingResult, NSString) -> String) -> String {
        let ns = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return input }

        // Build from the end so ranges remain valid.
        var out = input as NSString
        for m in matches.reversed() {
            let replacement = builder(m, out)
            out = out.replacingCharacters(in: m.range, with: replacement) as NSString
        }
        return out as String
    }

    private static func maskMiddle(_ s: String, keepPrefix: Int, keepSuffix: Int) -> String {
        guard s.count > keepPrefix + keepSuffix + 3 else { return s }
        let prefix = s.prefix(keepPrefix)
        let suffix = s.suffix(keepSuffix)
        return prefix + "…<redacted>…" + suffix
    }

    private static func maskVeryLongRuns(_ input: String) -> String {
        // Mask long contiguous runs of URL-safe/base64-ish characters.
        // Example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...."
        // We keep first/last bits so it's still useful for correlating logs.
        let pattern = #"\b([A-Za-z0-9\-\._~\+/]{28,})\b"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        return replace(using: regex, in: input) { match, original in
            let token = original.substring(with: match.range(at: 1))
            return maskMiddle(token, keepPrefix: 6, keepSuffix: 6)
        }
    }
}

private extension NSString {
    func substring(with range: NSRange) -> String {
        guard range.location != NSNotFound, range.length > 0 else { return "" }
        return self.substring(with: range)
    }
}
