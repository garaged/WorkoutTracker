import SwiftUI

struct EquipmentPickerScreen: View {
    @AppStorage("profile.equipment.selected.v1") private var selectedJSON: String = "[]"
    @AppStorage("profile.equipment.custom.v1") private var customJSON: String = "[]" // stores labels

    @State private var selected: Set<String> = []   // canonical tags
    @State private var custom: [String] = []        // labels

    @State private var showAddCustom = false
    @State private var newCustom = ""

    var body: some View {
        List {
            Section {
                Text("\(selected.count) selected")
                    .foregroundStyle(.secondary)
            }

            Section("Common") {
                ForEach(EquipmentCatalog.common) { item in
                    row(tag: item.id, label: item.label, symbol: item.symbol)
                }
            }

            Section("Custom") {
                if custom.isEmpty {
                    ContentUnavailableView(
                        "No Custom Equipment",
                        systemImage: "plus",
                        description: Text("Add items you have at home or at your gym.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(custom, id: \.self) { label in
                        let tag = EquipmentCatalog.slugify(label)
                        row(tag: tag, label: label, symbol: EquipmentCatalog.symbol(for: tag))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeCustom(label: label)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }

                Button {
                    newCustom = ""
                    showAddCustom = true
                } label: {
                    Label("Add Custom Equipment", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Equipment")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newCustom = ""
                    showAddCustom = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            selected = Set(decode(selectedJSON) as [String])
            custom = decode(customJSON)
            custom.sort()
        }
        .onChange(of: selected) { _, v in
            selectedJSON = encode(Array(v).sorted())
        }
        .onChange(of: custom) { _, v in
            customJSON = encode(v.sorted())
        }
        .sheet(isPresented: $showAddCustom) {
            NavigationStack {
                Form {
                    Section("Name") {
                        TextField("e.g. Dip Station", text: $newCustom)
                    }
                }
                .navigationTitle("Add Equipment")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showAddCustom = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Add") {
                            addCustom(label: newCustom)
                            showAddCustom = false
                        }
                        .disabled(newCustom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func row(tag: String, label: String, symbol: String) -> some View {
        let isOn = selected.contains(tag)
        return Button {
            toggle(tag)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 22)

                Text(label)

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ tag: String) {
        if selected.contains(tag) { selected.remove(tag) }
        else { selected.insert(tag) }
    }

    private func addCustom(label raw: String) {
        let label = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }

        if !custom.contains(where: { $0.caseInsensitiveCompare(label) == .orderedSame }) {
            custom.append(label)
        }

        // auto-select custom equipment slug
        selected.insert(EquipmentCatalog.slugify(label))
    }

    private func removeCustom(label: String) {
        custom.removeAll { $0 == label }
        selected.remove(EquipmentCatalog.slugify(label))
    }

    // JSON helpers
    private func decode<T: Decodable>(_ s: String) -> T {
        guard let data = s.data(using: .utf8) else {
            return (try! JSONDecoder().decode(T.self, from: Data("[]".utf8)))
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { return (try! JSONDecoder().decode(T.self, from: Data("[]".utf8))) }
    }

    private func encode<T: Encodable>(_ v: T) -> String {
        do {
            let data = try JSONEncoder().encode(v)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
}
