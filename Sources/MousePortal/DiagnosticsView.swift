import AppKit
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("System status")
                            .font(.system(size: 17, weight: .semibold))
                        Label(state.engineState.label, systemImage: state.engineState == .running ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(state.engineState == .running ? .green : .orange)
                        Label(
                            state.accessibilityGranted ? "Accessibility permission granted" : "Accessibility permission not granted",
                            systemImage: state.accessibilityGranted ? "hand.raised.fill" : "hand.raised.slash.fill"
                        )
                        .foregroundStyle(state.accessibilityGranted ? Color.secondary : Color.orange)
                    }
                    Spacer()
                    Button("Refresh") {
                        state.refreshDisplays()
                        state.start()
                    }
                    Button("Copy Report") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(state.diagnosticsText(), forType: .string)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Displays")
                        .font(.system(size: 15, weight: .semibold))
                    ForEach(state.displays) { display in
                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 5) {
                            GridRow {
                                Text(display.name).fontWeight(.medium)
                                Text(display.isMain ? "Main display" : "Connected")
                                    .foregroundStyle(.secondary)
                            }
                            GridRow {
                                Text("UUID").foregroundStyle(.secondary)
                                Text(display.uuid).textSelection(.enabled)
                            }
                            GridRow {
                                Text("Coordinates").foregroundStyle(.secondary)
                                Text("\(Int(display.frame.x)), \(Int(display.frame.y))")
                            }
                            GridRow {
                                Text("Resolution").foregroundStyle(.secondary)
                                Text("\(Int(display.frame.width)) × \(Int(display.frame.height))")
                            }
                            GridRow {
                                Text("Rotation").foregroundStyle(.secondary)
                                Text("\(Int(display.rotation))°")
                            }
                        }
                        .font(.system(size: 12))
                        .padding(.bottom, 10)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(32)
        }
    }
}
