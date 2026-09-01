import Foundation

enum MDBlock {
    case heading(String, Int)
    case bullet(String)
    case numbered(String, String)
    case quote(String)
    case code(String)
    case paragraph(String)
    case blank
}

enum Markdown {
    /// Notes are split into presentation sections by lines containing only `---`.
    static func sections(of text: String) -> [String] {
        var groups: [[String]] = [[]]
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                groups.append([])
            } else {
                groups[groups.count - 1].append(line)
            }
        }
        let sections = groups
            .map { $0.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return sections.isEmpty ? [text] : sections
    }

    static func blocks(of text: String) -> [MDBlock] {
        var result: [MDBlock] = []
        var codeLines: [String]? = nil
        for raw in text.components(separatedBy: "\n") {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if let lines = codeLines {
                    result.append(.code(lines.joined(separator: "\n")))
                    codeLines = nil
                } else {
                    codeLines = []
                }
                continue
            }
            if codeLines != nil {
                codeLines!.append(raw)
                continue
            }
            if trimmed.isEmpty { result.append(.blank); continue }
            if trimmed.hasPrefix("### ") { result.append(.heading(String(trimmed.dropFirst(4)), 3)); continue }
            if trimmed.hasPrefix("## ") { result.append(.heading(String(trimmed.dropFirst(3)), 2)); continue }
            if trimmed.hasPrefix("# ") { result.append(.heading(String(trimmed.dropFirst(2)), 1)); continue }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") { result.append(.bullet(String(trimmed.dropFirst(2)))); continue }
            if trimmed.hasPrefix("> ") { result.append(.quote(String(trimmed.dropFirst(2)))); continue }
            if let dot = trimmed.firstIndex(of: "."),
               !trimmed.hasPrefix("."),
               trimmed[..<dot].allSatisfy(\.isNumber),
               trimmed.index(after: dot) < trimmed.endIndex,
               trimmed[trimmed.index(after: dot)] == " " {
                result.append(.numbered(String(trimmed[trimmed.index(dot, offsetBy: 2)...]), String(trimmed[..<dot])))
                continue
            }
            result.append(.paragraph(trimmed))
        }
        if let lines = codeLines, !lines.isEmpty { result.append(.code(lines.joined(separator: "\n"))) }
        return result
    }

    static func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}
