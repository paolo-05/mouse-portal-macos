import AppKit
import MousePortalCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var isConfirmingReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                settingsGroup(
                    title: "Pointer behavior",
                    description: "Conservative defaults prevent a portal from immediately triggering again after arrival."
                ) {
                    valueSlider(
                        "Arrival inset",
                        value: preference(\.destinationInset),
                        range: 2...24,
                        valueLabel: "\(Int(state.configuration.preferences.destinationInset)) pt"
                    )
                    valueSlider(
                        "Edge threshold",
                        value: preference(\.edgeThreshold),
                        range: 1...10,
                        valueLabel: "\(Int(state.configuration.preferences.edgeThreshold)) pt"
                    )
                    valueSlider(
                        "Anti-bounce delay",
                        value: preference(\.cooldownSeconds),
                        range: 0.05...0.5,
                        valueLabel: String(format: "%.2f s", state.configuration.preferences.cooldownSeconds)
                    )
                    valueSlider(
                        "Minimum velocity",
                        value: preference(\.minimumVelocity),
                        range: 0...2500,
                        valueLabel: state.configuration.preferences.minimumVelocity == 0
                            ? "Off"
                            : "\(Int(state.configuration.preferences.minimumVelocity)) pt/s"
                    )
                    valueSlider(
                        "Momentum carry",
                        value: preference(\.momentumTransfer),
                        range: 0...1.5,
                        valueLabel: "\(Int(state.configuration.preferences.momentumTransfer * 100))%"
                    )
                    Picker("Hold to suspend portals", selection: preference(\.suspendModifier)) {
                        ForEach(SuspendModifier.allCases, id: \.self) { modifier in
                            Text(modifier.label).tag(modifier)
                        }
                    }
                    .frame(maxWidth: 360)
                }

                settingsGroup(
                    title: "Global shortcut",
                    description: "Choose a single letter and one or more modifiers. The shortcut works while MousePortal is running."
                ) {
                    HStack(spacing: 12) {
                        TextField("Key", text: shortcutKey)
                            .frame(width: 52)
                            .multilineTextAlignment(.center)
                        ForEach(ShortcutModifier.allCases, id: \.self) { modifier in
                            Toggle(modifier.label, isOn: shortcutModifier(modifier))
                                .toggleStyle(.checkbox)
                        }
                    }
                    Text("Current shortcut: \(state.configuration.preferences.toggleShortcut.displayLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                settingsGroup(
                    title: "Feedback and startup",
                    description: "The arrival indicator appears briefly where the pointer enters the destination display."
                ) {
                    Toggle("Show arrival indicator", isOn: preference(\.showsArrivalIndicator))
                    Toggle(
                        "Launch MousePortal at login",
                        isOn: Binding(
                            get: { state.configuration.preferences.launchAtLogin },
                            set: state.setLaunchAtLogin
                        )
                    )
                }

                settingsGroup(
                    title: "Configuration",
                    description: "Profiles remain stored locally. Export a JSON backup before experimenting with a complex layout."
                ) {
                    HStack {
                        Button("Import…", action: importConfiguration)
                        Button("Export…", action: exportConfiguration)
                    }

                    Divider()

                    if isConfirmingReset {
                        HStack(spacing: 10) {
                            Text("Reset app settings to their defaults?")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Cancel") {
                                isConfirmingReset = false
                            }
                            Button("Reset", role: .destructive) {
                                state.resetPreferencesToDefaults()
                                isConfirmingReset = false
                            }
                        }
                    } else {
                        HStack {
                            Button("Reset Settings…") {
                                isConfirmingReset = true
                            }
                            Spacer()
                            Text("Portals and display profiles are kept.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: 650, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
    }

    private func settingsGroup<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    private func valueSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueLabel: String
    ) -> some View {
        HStack {
            Text(title)
                .frame(width: 145, alignment: .leading)
            Slider(value: value, in: range)
                .frame(maxWidth: 300)
            Text(valueLabel)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .trailing)
        }
    }

    private func preference<Value>(_ keyPath: WritableKeyPath<PortalPreferences, Value>) -> Binding<Value> {
        Binding(
            get: { state.configuration.preferences[keyPath: keyPath] },
            set: { value in
                state.updatePreferences { preferences in
                    preferences[keyPath: keyPath] = value
                }
            }
        )
    }

    private var shortcutKey: Binding<String> {
        Binding(
            get: { state.configuration.preferences.toggleShortcut.key.uppercased() },
            set: { value in
                let normalized = value.lowercased().filter { $0.isLetter || $0.isNumber }
                guard let key = normalized.last else { return }
                state.updatePreferences { $0.toggleShortcut.key = String(key) }
            }
        )
    }

    private func shortcutModifier(_ modifier: ShortcutModifier) -> Binding<Bool> {
        Binding(
            get: { state.configuration.preferences.toggleShortcut.modifiers.contains(modifier) },
            set: { enabled in
                state.updatePreferences { preferences in
                    var modifiers = preferences.toggleShortcut.modifiers
                    if enabled {
                        if !modifiers.contains(modifier) { modifiers.append(modifier) }
                    } else if modifiers.count > 1 {
                        modifiers.removeAll(where: { $0 == modifier })
                    }
                    preferences.toggleShortcut.modifiers = modifiers
                }
            }
        )
    }

    private func exportConfiguration() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MousePortal Configuration.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.exportConfiguration(to: url)
    }

    private func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.importConfiguration(from: url)
    }
}
