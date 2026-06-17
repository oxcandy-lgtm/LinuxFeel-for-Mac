import AppKit
import Foundation

private let appDelegate = LinuxFeelControlCenterAppDelegate()

@main
enum LinuxFeelControlCenterMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = appDelegate
        app.run()
    }
}

final class LinuxFeelControlCenterAppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: LinuxFeelControlCenterWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = LinuxFeelControlCenterWindowController()
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

final class LinuxFeelControlCenterWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LinuxFeel Control Center"
        window.minSize = NSSize(width: 860, height: 620)
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = LinuxFeelControlCenterViewController()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class LinuxFeelControlCenterViewController: NSViewController {
    override func loadView() {
        let rootView = NSView(frame: .zero)
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
    }

    private func buildInterface() {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let contentView = NSView(frame: .zero)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .fill
        stackView.spacing = 18

        contentView.addSubview(stackView)
        scrollView.documentView = contentView

        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])

        stackView.addArrangedSubview(makeIntroCard())

        for helper in HelperSection.all {
            stackView.addArrangedSubview(HelperCardView(helper: helper))
        }
    }

    private func makeIntroCard() -> CardView {
        let card = CardView()

        let title = makeLabel(
            "LinuxFeel Control Center",
            font: .systemFont(ofSize: 24, weight: .semibold),
            textColor: .labelColor
        )

        let subtitle = makeLabel(
            "Manual launch only. This surface copies commands and opens docs for the existing helpers.",
            font: .systemFont(ofSize: 14, weight: .regular),
            textColor: .secondaryLabelColor
        )

        let limitation = makeLabel(
            "It does not move or replace the native macOS menu bar, and it does not start or stop helpers.",
            font: .systemFont(ofSize: 13, weight: .regular),
            textColor: .tertiaryLabelColor
        )

        let stack = makeVerticalStack(spacing: 8)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(limitation)

        card.setContentView(stack)
        return card
    }
}

final class HelperCardView: CardView {
    private let helper: HelperSection

    init(helper: HelperSection) {
        self.helper = helper
        super.init(frame: .zero)
        buildCard()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildCard() {
        let rootStack = makeVerticalStack(spacing: 14)

        let title = makeLabel(
            helper.name,
            font: .systemFont(ofSize: 19, weight: .semibold),
            textColor: .labelColor
        )

        let summary = makeLabel(
            helper.summary,
            font: .systemFont(ofSize: 14, weight: .regular),
            textColor: .secondaryLabelColor
        )

        rootStack.addArrangedSubview(title)
        rootStack.addArrangedSubview(summary)

        rootStack.addArrangedSubview(
            InfoBlockView(
                title: "Status note",
                value: helper.statusNote,
                monospaced: false
            )
        )

        rootStack.addArrangedSubview(
            InfoBlockView(
                title: "Build output",
                value: helper.binaryPath,
                monospaced: true
            )
        )

        for row in helper.commandRows {
            rootStack.addArrangedSubview(
                CommandRowView(
                    title: row.title,
                    command: row.command
                )
            )
        }

        rootStack.addArrangedSubview(
            InfoBlockView(
                title: "Permission note",
                value: helper.permissionNote,
                monospaced: false
            )
        )

        let footerRow = NSStackView()
        footerRow.translatesAutoresizingMaskIntoConstraints = false
        footerRow.orientation = .horizontal
        footerRow.alignment = .centerY

        let spacer = NSView(frame: .zero)
        spacer.translatesAutoresizingMaskIntoConstraints = false

        let openReadmeButton = ActionButton(title: "Open README")
        openReadmeButton.onClick = { [helper] in
            let url = RepositoryLocator.rootURL.appendingPathComponent(helper.readmeRelativePath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                NSBeep()
                return
            }
            NSWorkspace.shared.open(url)
        }

        footerRow.addArrangedSubview(spacer)
        footerRow.addArrangedSubview(openReadmeButton)

        rootStack.addArrangedSubview(footerRow)
        setContentView(rootStack)
    }
}

private struct HelperSection {
    let name: String
    let summary: String
    let statusNote: String
    let binaryPath: String
    let commandRows: [CommandRow]
    let permissionNote: String
    let readmeRelativePath: String

    static let all: [HelperSection] = [
        HelperSection(
            name: "mouse-selection",
            summary: "Middle-click paste and drag-to-copy helper.",
            statusNote: "Swallows the middle-click event so paste wins over the app's own middle-click action.",
            binaryPath: "mouse-selection/.build/release/selection-paste",
            commandRows: [
                CommandRow(title: "Build", command: "./mouse-selection/build.sh"),
                CommandRow(title: "Install", command: "./mouse-selection/install-launch-agent.sh"),
                CommandRow(title: "Uninstall", command: "./mouse-selection/uninstall-launch-agent.sh"),
                CommandRow(
                    title: "Inspect",
                    command: """
                    launchctl print "gui/$(id -u)/org.linuxfeel.selection-paste"
                    tail -n 50 "$HOME/Library/Logs/selection-paste.log"
                    tail -n 50 "$HOME/Library/Logs/selection-paste.err"
                    """
                )
            ],
            permissionNote: "Requires Accessibility permission. Some macOS versions may also require Input Monitoring.",
            readmeRelativePath: "mouse-selection/README.md"
        ),
        HelperSection(
            name: "focus",
            summary: "Experimental focus-follows-mouse helper.",
            statusNote: "Focus changes happen after a short delay. Auto-raise is not implemented yet.",
            binaryPath: "focus/.build/release/focus-follows-mouse",
            commandRows: [
                CommandRow(title: "Build", command: "./focus/build.sh"),
                CommandRow(title: "Install", command: "./focus/install-launch-agent.sh"),
                CommandRow(title: "Uninstall", command: "./focus/uninstall-launch-agent.sh"),
                CommandRow(
                    title: "Inspect",
                    command: """
                    launchctl print "gui/$(id -u)/org.linuxfeel.focus-follows-mouse"
                    tail -n 50 "$HOME/Library/Logs/focus-follows-mouse.log"
                    tail -n 50 "$HOME/Library/Logs/focus-follows-mouse.err"
                    """
                )
            ],
            permissionNote: "Requires Accessibility permission. Does not implement auto-raise yet.",
            readmeRelativePath: "focus/README.md"
        ),
        HelperSection(
            name: "battery",
            summary: "Experimental battery charge-limit helper.",
            statusNote: "Desk mode keeps the limit at 80%. Home mode is CHLS-only on supported hardware.",
            binaryPath: "battery/.build/release/mac-charge-limiter",
            commandRows: [
                CommandRow(title: "Build", command: "./battery/build.sh"),
                CommandRow(title: "Install (desk)", command: "sudo ./battery/install-home-daemon.sh"),
                CommandRow(title: "Install (home)", command: "sudo ./battery/install-home-daemon.sh home"),
                CommandRow(title: "Uninstall", command: "sudo ./battery/uninstall-daemon.sh"),
                CommandRow(
                    title: "Status",
                    command: """
                    ./battery/.build/release/mac-charge-limiter status
                    ./battery/.build/release/mac-charge-limiter read-key CHLS
                    """
                )
            ],
            permissionNote: "Battery helper requires administrator privileges for persistent daemon install and SMC writes. The UI does not run these commands automatically.",
            readmeRelativePath: "battery/README.md"
        )
    ]
}

private struct CommandRow {
    let title: String
    let command: String
}

private enum RepositoryLocator {
    static var rootURL: URL {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard bundleURL.pathExtension == "app" else {
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }

        return bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

final class CardView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContentView(_ contentView: NSView) {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            contentView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
    }
}

final class InfoBlockView: NSView {
    init(title: String, value: String, monospaced: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = makeLabel(
            title,
            font: .systemFont(ofSize: 12, weight: .semibold),
            textColor: .tertiaryLabelColor
        )

        let valueLabel = makeLabel(
            value,
            font: monospaced ? .monospacedSystemFont(ofSize: 12, weight: .regular) : .systemFont(ofSize: 13, weight: .regular),
            textColor: .labelColor
        )

        let stack = makeVerticalStack(spacing: 4)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(valueLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class CommandRowView: NSView {
    init(title: String, command: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let headerRow = NSStackView()
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 10

        let titleLabel = makeLabel(
            title,
            font: .systemFont(ofSize: 12, weight: .semibold),
            textColor: .tertiaryLabelColor
        )

        let spacer = NSView(frame: .zero)
        spacer.translatesAutoresizingMaskIntoConstraints = false

        let copyButton = ActionButton(title: "Copy")
        copyButton.onClick = {
            copyText(command)
        }

        headerRow.addArrangedSubview(titleLabel)
        headerRow.addArrangedSubview(spacer)
        headerRow.addArrangedSubview(copyButton)

        let commandLabel = makeLabel(
            command,
            font: .monospacedSystemFont(ofSize: 12, weight: .regular),
            textColor: .labelColor
        )
        commandLabel.isSelectable = true

        let stack = makeVerticalStack(spacing: 6)
        stack.addArrangedSubview(headerRow)
        stack.addArrangedSubview(commandLabel)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ActionButton: NSButton {
    var onClick: (() -> Void)?

    init(title: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.title = title
        bezelStyle = .rounded
        controlSize = .small
        font = .systemFont(ofSize: 12, weight: .medium)
        target = self
        action = #selector(handleClick)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleClick() {
        onClick?()
    }
}

private func makeVerticalStack(spacing: CGFloat) -> NSStackView {
    let stack = NSStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .vertical
    stack.alignment = .fill
    stack.spacing = spacing
    return stack
}

private func makeLabel(
    _ text: String,
    font: NSFont,
    textColor: NSColor,
    selectable: Bool = false
) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = font
    label.textColor = textColor
    label.isSelectable = selectable
    label.maximumNumberOfLines = 0
    label.cell?.lineBreakMode = .byWordWrapping
    label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return label
}

private func copyText(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}
