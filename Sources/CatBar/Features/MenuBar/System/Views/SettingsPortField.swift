import AppKit
import SwiftUI

/// A port text field that does **not** automatically become first responder
/// when the view appears. The user must explicitly click to start editing.
///
/// On macOS the first `TextField` in the hierarchy steals focus when the
/// popover / panel appears. This wrapper uses `NSTextField` directly so
/// we can override the initial-responder behaviour without affecting
/// typing once the user clicks in.
struct SettingsPortTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let onChange: () -> Void
    let onSubmit: () -> Void
    @Environment(\.isEnabled) var isEnabled

    init(placeholder: String, text: Binding<String>, onChange: @escaping () -> Void, onSubmit: @escaping () -> Void) {
        self.placeholder = placeholder
        self._text = text
        self.onChange = onChange
        self.onSubmit = onSubmit
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NoAutoFocusTextField {
        let field = NoAutoFocusTextField()
        field.placeholderString = placeholder
        field.stringValue = text
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.alignment = .right
        field.font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize(for: .regular),
            weight: .regular)
        field.lineBreakMode = .byTruncatingTail
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // Refuse initial first-responder status.
        field.refusesFirstResponder = true
        return field
    }

    func updateNSView(_ nsView: NoAutoFocusTextField, context: Context) {
        nsView.isEnabled = isEnabled
        // Only push the binding value when the user is not actively editing.
        if nsView.currentEditor() == nil, nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SettingsPortTextField

        init(parent: SettingsPortTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
            parent.onChange()
        }

        func control(
            _ control: NSControl,
            textView _: NSTextView,
            doCommandBy commandSelector: Selector) -> Bool
        {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                // Resign focus after submitting.
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}

/// A text field subclass that refuses first-responder status on the
/// **first** responder-chain query (panel open / tab switch) but
/// accepts clicks normally afterward.
final class NoAutoFocusTextField: NSTextField {
    /// Once the user explicitly clicks inside, allow normal focus.
    private var userDidClick = false

    override var acceptsFirstResponder: Bool {
        if userDidClick { return true }
        return false
    }

    override func mouseDown(with event: NSEvent) {
        userDidClick = true
        // Temporarily allow responding so that the regular
        // mouseDown → becomeFirstResponder path works.
        super.mouseDown(with: event)
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            // Reset so the next panel-open cycle doesn't auto-focus.
            userDidClick = false
        }
        return resigned
    }
}
