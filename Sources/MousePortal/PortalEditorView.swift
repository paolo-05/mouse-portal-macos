import AppKit
import MousePortalCore
import SwiftUI

private enum EditorSection: String, CaseIterable, Identifiable {
    case portals = "Portals"
    case settings = "Settings"
    case diagnostics = "Diagnostics"

    var id: String { rawValue }
}

struct PortalEditorView: View {
    @ObservedObject var state: AppState
    @State private var section: EditorSection = .portals
    @State private var selectedPortalID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !state.accessibilityGranted {
                permissionBanner
                Divider()
            }

            switch section {
            case .portals:
                portalEditor
            case .settings:
                SettingsView(state: state)
            case .diagnostics:
                DiagnosticsView(state: state)
            }
        }
        .frame(minWidth: 920, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(
            "MousePortal",
            isPresented: Binding(
                get: { state.errorMessage != nil },
                set: { if !$0 { state.errorMessage = nil } }
            )
        ) {
            Button("OK") { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "Unknown error")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MousePortal")
                    .font(.system(size: 20, weight: .semibold))
                Text(state.displayStatusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Section", selection: $section) {
                ForEach(EditorSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 310)

            Spacer()

            Toggle(
                "Enabled",
                isOn: Binding(
                    get: { state.configuration.preferences.isGloballyEnabled },
                    set: state.setGlobalEnabled
                )
            )
            .toggleStyle(.switch)
            .help("Enable or disable all portals")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility permission is required")
                    .font(.system(size: 13, weight: .semibold))
                Text("MousePortal uses it only to observe and reposition the pointer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Request Permission") { state.requestAccessibilityPermission() }
            Button("Open Settings") { state.openAccessibilitySettings() }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
    }

    private var portalEditor: some View {
        HSplitView {
            PortalSidebar(
                portals: state.activePortals,
                selection: $selectedPortalID,
                onToggle: state.setPortalEnabled
            )
            .frame(minWidth: 185, idealWidth: 215, maxWidth: 250)

            PortalCanvasView(
                displays: state.displays,
                portals: state.activePortals,
                selectedPortalID: $selectedPortalID,
                onCreate: { source, destination in
                    state.addPortal(source: source, destination: destination)
                    selectedPortalID = state.activePortals.last?.id
                },
                onUpdate: state.updatePortal
            )
            .frame(minWidth: 430)

            inspector
                .frame(minWidth: 230, idealWidth: 250, maxWidth: 290)
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if let selectedPortalID,
           let portal = state.activePortals.first(where: { $0.id == selectedPortalID }) {
            PortalInspector(
                portal: portal,
                displays: state.displays,
                onUpdate: state.updatePortal,
                onDelete: {
                    state.deletePortal(portal.id)
                    self.selectedPortalID = nil
                }
            )
        } else {
            VStack(spacing: 9) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                Text("Select a portal")
                    .font(.headline)
                Text("Its direction, name, color, and edge segments will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 190)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private struct PortalSidebar: View {
    var portals: [Portal]
    @Binding var selection: UUID?
    var onToggle: (UUID, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PORTALS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            if portals.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("No portals yet")
                        .font(.system(size: 13, weight: .medium))
                    Text("Create one by dragging between two display edges.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                Spacer()
            } else {
                List(portals, selection: $selection) { portal in
                    HStack(spacing: 9) {
                        Circle()
                            .fill(portal.color.swiftUIColor)
                            .frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(portal.name)
                                .lineLimit(1)
                            Text(portal.direction.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { portal.isEnabled },
                                set: { onToggle(portal.id, $0) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                    }
                    .tag(portal.id)
                    .accessibilityElement(children: .combine)
                }
                .listStyle(.sidebar)
            }

            Divider()
            Text("Use the global shortcut to toggle all portals")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(12)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

private struct PortalInspector: View {
    var portal: Portal
    var displays: [DisplayDescriptor]
    var onUpdate: (Portal) -> Void
    var onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    inspectorLabel("NAME")
                    TextField("Portal name", text: binding(\.name))
                }

                VStack(alignment: .leading, spacing: 9) {
                    inspectorLabel("BEHAVIOR")
                    Toggle("Enabled", isOn: binding(\.isEnabled))
                    Picker("Direction", selection: binding(\.direction)) {
                        ForEach(PortalDirection.allCases, id: \.self) { direction in
                            Text(direction.label).tag(direction)
                        }
                    }
                    Picker("Color", selection: binding(\.color)) {
                        ForEach(PortalColor.allCases, id: \.self) { color in
                            HStack {
                                Circle().fill(color.swiftUIColor).frame(width: 8, height: 8)
                                Text(color.label)
                            }
                            .tag(color)
                        }
                    }
                }

                endpointSection(title: "SOURCE", segment: binding(\.source))
                endpointSection(title: "DESTINATION", segment: binding(\.destination))

                Divider()
                Button("Delete Portal", role: .destructive, action: onDelete)
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func endpointSection(title: String, segment: Binding<EdgeSegment>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            inspectorLabel(title)
            Text(displayName(for: segment.wrappedValue.displayUUID))
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Picker("Edge", selection: segment.edge) {
                ForEach(DisplayEdge.allCases, id: \.self) { edge in
                    Text(edge.label).tag(edge)
                }
            }
            HStack {
                Text("Start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: segment.start, in: 0...max(0, segment.wrappedValue.end - 0.03))
            }
            HStack {
                Text("End")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: segment.end, in: min(1, segment.wrappedValue.start + 0.03)...1)
            }
        }
    }

    private func inspectorLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func displayName(for uuid: String) -> String {
        displays.first(where: { $0.uuid == uuid })?.name ?? "Disconnected display"
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Portal, Value>) -> Binding<Value> {
        Binding(
            get: { portal[keyPath: keyPath] },
            set: { value in
                var updated = portal
                updated[keyPath: keyPath] = value
                onUpdate(updated)
            }
        )
    }
}

private extension Binding where Value == EdgeSegment {
    var edge: Binding<DisplayEdge> {
        Binding<DisplayEdge>(
            get: { wrappedValue.edge },
            set: { wrappedValue.edge = $0 }
        )
    }

    var start: Binding<Double> {
        Binding<Double>(
            get: { wrappedValue.start },
            set: { wrappedValue.start = $0 }
        )
    }

    var end: Binding<Double> {
        Binding<Double>(
            get: { wrappedValue.end },
            set: { wrappedValue.end = $0 }
        )
    }
}
