import SwiftUI

// Dropdowns instead of typing. Free text is only left for notes and for "Other…" names.

/// Pick several options from one dropdown; it stays open while you tick.
struct MultiSelectMenu<Option: Hashable>: View {
    let title: String
    let options: [Option]
    @Binding var selection: Set<Option>
    let label: (Option) -> String
    var emptyText = "None"

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Toggle(label(option), isOn: Binding(
                    get: { selection.contains(option) },
                    set: { on in if on { selection.insert(option) } else { selection.remove(option) } }))
            }
        } label: {
            DropdownLabel(title: title, value: summary)
        }
        .menuActionDismissBehavior(.disabled)
        .accessibilityLabel(title)
        .accessibilityValue(summary)
    }

    private var summary: String {
        let picked = options.filter(selection.contains).map(label)
        return picked.isEmpty ? emptyText : picked.joined(separator: ", ")
    }
}

/// A number from a list (or none), shown as "3 sets ⌄".
struct NumberMenu: View {
    let field: ExerciseField
    @Binding var value: Double?
    var accessibilityName: String

    var body: some View {
        Menu {
            Picker(field.title, selection: $value) {
                Text("No \(field.title.lowercased())").tag(Double?.none)
                ForEach(field.options(including: value), id: \.self) { Text(field.format($0)).tag(Double?.some($0)) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(value.map(field.format) ?? field.title).foregroundStyle(value == nil ? Palette.secondary : Palette.text)
                Image(systemName: "chevron.down").font(.caption2).foregroundStyle(Palette.secondary)
            }
            .font(.subheadline.monospacedDigit())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.track, in: .capsule)
        }
        .accessibilityLabel("\(accessibilityName) \(field.title.lowercased())")
        .accessibilityValue(value.map(field.format) ?? "not set")
    }
}

/// A dropdown of names in groups, plus "Other…" to type a new one.
struct NameMenu<Label: View>: View {
    let title: String
    let groups: [(title: String, names: [String])]
    let pick: (String) -> Void
    @ViewBuilder var label: Label

    @State private var typing = false
    @State private var typed = ""

    var body: some View {
        Menu {
            ForEach(groups.filter { !$0.names.isEmpty }, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.names, id: \.self) { name in Button(name) { pick(name) } }
                }
            }
            Section {
                Button("Other…", systemImage: "keyboard") { typing = true }
            }
        } label: {
            // The whole row opens the menu, not just the words.
            label.frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
        }
        .alert(title, isPresented: $typing) {
            TextField("Name", text: $typed)
            Button("Add") {
                let name = typed.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { pick(name) }
                typed = ""
            }
            Button("Cancel", role: .cancel) { typed = "" }
        }
    }
}

/// "Title ........ value ⌄" — how every dropdown row reads in a form.
struct DropdownLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).foregroundStyle(Palette.text)
            Spacer(minLength: 12)
            Text(value).foregroundStyle(Palette.secondary).lineLimit(1).multilineTextAlignment(.trailing)
            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Palette.secondary)
        }
        .contentShape(.rect)
    }
}

/// Removes duplicates (ignoring case) while keeping the first spelling and order.
func uniqueNames(_ names: [String]) -> [String] {
    var seen = Set<String>()
    return names.filter { seen.insert($0.lowercased()).inserted }
}
