import SwiftData
import SwiftUI

struct EventRow: View {
    @Environment(\.modelContext) private var modelContext

    let event: EventEntity

    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.severity.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(event.message)

            if event.isAcknowledged {
                Text("Acknowledged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let acknowledgedNote = event.acknowledgedNote, !acknowledgedNote.isEmpty {
                    Text(acknowledgedNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    TextField("Note", text: $note)
                        .textFieldStyle(.roundedBorder)

                    Button("Acknowledge") {
                        event.acknowledgedAt = Date()
                        event.acknowledgedNote = note
                        try? modelContext.save()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
