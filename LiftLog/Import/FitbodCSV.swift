import Foundation

/// One set from a Fitbod export, with the text already turned into numbers.
struct FitbodRow: Sendable, Equatable {
    var date: Date
    var exercise: String
    var reps: Int
    var weightKg: Double
    var durationSeconds: Double
    var distanceMeters: Double
    var isWarmup: Bool
    var note: String
    var multiplier: Double
}

struct FitbodParseResult: Sendable {
    var rows: [FitbodRow]
    /// Lines that couldn't be understood, such as a missing date or exercise.
    var skippedLines: Int
}

enum FitbodCSVError: LocalizedError, Equatable {
    case empty
    case missingColumns([String])

    var errorDescription: String? {
        switch self {
        case .empty:
            "The file is empty."
        case .missingColumns(let columns):
            "This doesn't look like a Fitbod export. Missing columns: \(columns.joined(separator: ", "))."
        }
    }
}

/// Reads the CSV file that Fitbod exports. See docs/fitbod-import.md.
enum FitbodCSV {
    static let requiredColumns = ["Date", "Exercise", "Reps", "Weight(kg)"]

    static func parse(_ text: String) throws -> FitbodParseResult {
        // "\r\n" counts as a single newline character in Swift, so Windows line endings work too.
        let lines = text.split(whereSeparator: \.isNewline)
        guard let headerLine = lines.first else { throw FitbodCSVError.empty }

        let header = splitFields(String(headerLine)).map {
            $0.replacingOccurrences(of: "\u{FEFF}", with: "").trimmingCharacters(in: .whitespaces)
        }
        let columnIndex = Dictionary(header.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let missing = requiredColumns.filter { columnIndex[$0] == nil }
        guard missing.isEmpty else { throw FitbodCSVError.missingColumns(missing) }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        var rows: [FitbodRow] = []
        rows.reserveCapacity(lines.count)
        var skipped = 0

        for line in lines.dropFirst() {
            var fields = splitFields(String(line))

            // A note with a comma in it (and no quotes) splits into extra fields.
            // Glue them back together so the columns after the note line up.
            if fields.count > header.count, let noteIndex = columnIndex["Note"] {
                let noteRange = noteIndex...(noteIndex + fields.count - header.count)
                fields.replaceSubrange(noteRange, with: [fields[noteRange].joined(separator: ",")])
            }

            guard fields.count == header.count,
                  let row = makeRow(fields, columnIndex: columnIndex, dateFormatter: dateFormatter)
            else {
                skipped += 1
                continue
            }
            rows.append(row)
        }

        return FitbodParseResult(rows: rows, skippedLines: skipped)
    }

    private static func makeRow(
        _ fields: [String],
        columnIndex: [String: Int],
        dateFormatter: DateFormatter
    ) -> FitbodRow? {
        func text(_ column: String) -> String? {
            columnIndex[column].map { fields[$0].trimmingCharacters(in: .whitespaces) }
        }
        func number(_ column: String) -> Double? {
            guard let value = text(column).flatMap(Double.init), value.isFinite else { return nil }
            return value
        }

        guard let date = text("Date").flatMap(dateFormatter.date(from:)),
              let exercise = text("Exercise"), !exercise.isEmpty
        else { return nil }

        return FitbodRow(
            date: date,
            exercise: exercise,
            reps: Int(exactly: (number("Reps") ?? 0).rounded()) ?? 0,
            weightKg: number("Weight(kg)") ?? 0,
            durationSeconds: number("Duration(s)") ?? 0,
            distanceMeters: number("Distance(m)") ?? 0,
            isWarmup: text("isWarmup")?.lowercased() == "true",
            note: text("Note") ?? "",
            multiplier: number("multiplier") ?? 1
        )
    }

    /// Splits one line into fields. Handles "quoted, fields" and "" inside quotes.
    /// A `"` in the middle of a field is kept as an ordinary character, and a line
    /// whose quotes never close falls back to a plain split on commas.
    static func splitFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var atFieldStart = true
        let characters = Array(line)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        current.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(character)
                }
                atFieldStart = false
            } else if character == "," {
                fields.append(current)
                current = ""
                atFieldStart = true
            } else if character == "\"" && atFieldStart {
                inQuotes = true
                atFieldStart = false
            } else {
                current.append(character)
                atFieldStart = false
            }
            index += 1
        }

        if inQuotes {
            return line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        }
        fields.append(current)
        return fields
    }
}
