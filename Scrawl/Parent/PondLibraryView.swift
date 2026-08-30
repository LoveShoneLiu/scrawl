import SwiftUI

struct PondLibraryView: View {
    @EnvironmentObject private var world: WorldStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingLoad: PondSnapshot?
    @State private var pendingDelete: PondSnapshot?

    var body: some View {
        NavigationStack {
            Group {
                if world.snapshots.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.stack")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(Color(red: 0.18, green: 0.55, blue: 0.62))
                        Text("No saved ponds yet")
                            .font(.title3.weight(.semibold))
                        Text("Tap the download button after you put doodles in the pond.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 18),
                                GridItem(.flexible(), spacing: 18)
                            ],
                            spacing: 18
                        ) {
                            ForEach(world.snapshots) { snapshot in
                                card(snapshot)
                            }
                        }
                        .padding(22)
                    }
                }
            }
            .background(Color(red: 0.988, green: 0.965, blue: 0.918))
            .navigationTitle("Saved ponds")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
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
            } message: {
                Text("This pond will be gone. The current pond is not affected.")
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
        }
        .presentationDetents([.medium, .large])
    }

    private var deleteConfirm: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if $0 == false { pendingDelete = nil } }
        )
    }

    private var loadConfirm: Binding<Bool> {
        Binding(
            get: { pendingLoad != nil },
            set: { if $0 == false { pendingLoad = nil } }
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

    private func card(_ snapshot: PondSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Button {
                    choose(snapshot)
                } label: {
                    Group {
                        if let thumb = world.snapshotThumbs[snapshot.id] {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color(red: 0.18, green: 0.52, blue: 0.56)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    pendingDelete = snapshot
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(red: 0.86, green: 0.28, blue: 0.28)))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }

            Button {
                choose(snapshot)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.dateText.string(from: snapshot.savedAt))
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.28, green: 0.32, blue: 0.36))
                    Text(summary(snapshot))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
        )
    }

    private func summary(_ snapshot: PondSnapshot) -> String {
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
