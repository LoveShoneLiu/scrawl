import SwiftUI

struct ParentSettingsView: View {
    @EnvironmentObject private var world: WorldStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false
    @State private var pendingLoad: PondSnapshot?
    @State private var pendingDelete: PondSnapshot?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Sound", isOn: $world.soundEnabled)
                }

                Section {
                    Button("Save this pond") {
                        world.saveSnapshot()
                    }
                    .disabled(world.canSavePond == false)

                    if world.lastSnapshotSavedAt != nil {
                        Text("Saved. You can open it next time from this list.")
                            .foregroundStyle(.secondary)
                    }
                    if world.lastSaveFailed {
                        Text("Last save failed. Storage may be full. Delete an old pond, then try again.")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Each time the app opens, the pond starts empty. Save here if you want this pond back later.")
                }

                Section("Saved ponds") {
                    if world.snapshots.isEmpty {
                        Text("None yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(world.snapshots) { snapshot in
                            Button {
                                choose(snapshot)
                            } label: {
                                snapshotRow(snapshot)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    pendingDelete = snapshot
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmClear = true
                    } label: {
                        Text("Empty the pond")
                    }
                    .disabled(world.pondHasLife == false)
                }
            }
            .navigationTitle("Parent settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Remove every doodle from the pond?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Empty", role: .destructive) {
                    world.clearWorld()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The drawing paper is not affected. This does not delete saved ponds.")
            }
            .confirmationDialog("Open this saved pond?", isPresented: loadConfirm, titleVisibility: .visible) {
                Button("Open") {
                    if let pendingLoad {
                        world.loadSnapshot(id: pendingLoad.id)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingLoad = nil
                }
            } message: {
                Text("The current pond will be replaced. Save first if you want to keep it.")
            }
            .confirmationDialog("Delete this saved pond?", isPresented: deleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let pendingDelete {
                        world.deleteSnapshot(id: pendingDelete.id)
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(false)
    }

    private var loadConfirm: Binding<Bool> {
        Binding(
            get: { pendingLoad != nil },
            set: { if $0 == false { pendingLoad = nil } }
        )
    }

    private var deleteConfirm: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if $0 == false { pendingDelete = nil } }
        )
    }

    private func choose(_ snapshot: PondSnapshot) {
                if world.pondHasLife == false {
            world.loadSnapshot(id: snapshot.id)
            dismiss()
            return
        }
        pendingLoad = snapshot
    }

    private func snapshotRow(_ snapshot: PondSnapshot) -> some View {
        HStack(spacing: 14) {
            Group {
                if let thumb = world.snapshotThumbs[snapshot.id] {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(red: 0.18, green: 0.52, blue: 0.56)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateText.string(from: snapshot.savedAt))
                    .foregroundStyle(.primary)
                Text(snapshotSummary(snapshot))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func snapshotSummary(_ snapshot: PondSnapshot) -> String {
        let doodles = snapshot.creatureCount == 1 ? "1 doodle" : "\(snapshot.creatureCount) doodles"
        if snapshot.fishCount == 0 {
            return doodles
        }
        let fish = snapshot.fishCount == 1 ? "1 fish" : "\(snapshot.fishCount) fish"
        return "\(doodles) · \(fish)"
    }

    private static let dateText: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
