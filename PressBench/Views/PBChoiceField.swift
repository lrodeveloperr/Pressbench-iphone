import SwiftUI

/// A form row that keeps the approved editor layout while replacing avoidable
/// typing with a short, explicit selection list. Existing and new custom values
/// remain editable through the Other path.
struct PBChoiceField: View {
    let title: String
    @Binding var selection: String
    let choices: [String]
    let identifier: String
    let tapToSelectTitle: String
    let otherTitle: String
    let cancelTitle: String

    @State private var showingChoices = false
    @State private var customMode = false
    @State private var choosingOther = false

    var body: some View {
        Group {
            if choices.isEmpty {
                TextField(title, text: $selection)
                    .accessibilityIdentifier(identifier)
            } else if customMode {
                HStack(spacing: 10) {
                    TextField(title, text: $selection)
                    Button { showingChoices = true } label: {
                        Image(systemName: "list.bullet")
                            .frame(width: PBTheme.minimumTarget, height: PBTheme.minimumTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tapToSelectTitle)
                    .accessibilityIdentifier(identifier)
                }
            } else {
                Button { showingChoices = true } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title).font(.caption).foregroundStyle(PBTheme.secondary)
                            Text(selection.isEmpty ? tapToSelectTitle : selection)
                                .foregroundStyle(selection.isEmpty ? PBTheme.secondary : PBTheme.text)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.up.chevron.down").foregroundStyle(PBTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: PBTheme.minimumTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier)
            }
        }
        .onAppear { customMode = !selection.isEmpty && !choices.contains(selection) }
        .onChange(of: selection) { _, newValue in
            if choosingOther {
                choosingOther = false
                customMode = true
            } else {
                customMode = !newValue.isEmpty && !choices.contains(newValue)
            }
        }
        .sheet(isPresented: $showingChoices) {
            PBChoicePickerSheet(
                title: title,
                selection: selection,
                choices: choices,
                identifier: identifier,
                isPresented: $showingChoices,
                otherTitle: otherTitle,
                cancelTitle: cancelTitle,
                choose: { value in
                    selection = value
                    customMode = false
                },
                chooseOther: {
                    customMode = true
                    if choices.contains(selection) {
                        choosingOther = true
                        selection = ""
                    } else {
                        choosingOther = false
                    }
                }
            )
        }
    }
}

private struct PBChoicePickerSheet: View {
    let title: String
    let selection: String
    let choices: [String]
    let identifier: String
    @Binding var isPresented: Bool
    let otherTitle: String
    let cancelTitle: String
    let choose: (String) -> Void
    let chooseOther: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(choices, id: \.self) { value in
                    Button {
                        isPresented = false
                        choose(value)
                    } label: {
                        HStack {
                            Text(value).foregroundStyle(PBTheme.text)
                            Spacer()
                            if selection == value {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(PBTheme.primaryStrong)
                            }
                        }
                        .frame(minHeight: PBTheme.minimumTarget)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    isPresented = false
                    chooseOther()
                } label: {
                    HStack {
                        Text(otherTitle).foregroundStyle(PBTheme.text)
                        Spacer()
                        Image(systemName: "pencil").foregroundStyle(PBTheme.primary)
                    }
                    .frame(minHeight: PBTheme.minimumTarget)
                }
                .buttonStyle(.plain)
            }
            .accessibilityIdentifier("\(identifier).sheet")
            .environment(\.defaultMinListRowHeight, PBTheme.minimumTarget)
            .scrollContentBackground(.hidden)
            .background(PBTheme.canvasGradient)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) { isPresented = false }
                        .accessibilityIdentifier("\(identifier).cancel")
                }
            }
        }
        .pbEditorSheetStyle()
    }
}
