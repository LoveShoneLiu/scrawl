import SwiftUI

struct ParentSettingsView: View {
    @EnvironmentObject private var world: WorldStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                Toggle("Sound", isOn: $world.soundEnabled)

                if world.lastSaveFailed {
                    Text("Last save failed. Storage may be full. Try emptying the pond, then save again.")
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    confirmClear = true
                } label: {
                    Text("Empty the pond")
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
                Text("The drawing paper is not affected. This cannot be undone.")
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(false)
    }
}
