import AppKit
import os

@MainActor
final class AppState {
    let permissionManager: AccessibilityPermissionManager

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "Workflow")
    private let selectedTextProvider: AXSelectedTextProvider
    private let clipboardSelectedTextProvider: ClipboardSelectedTextProvider
    private let viewModel: TranslationViewModel
    private let coordinator: TranslationCoordinator
    private let panelController: TranslationPanelController
    private var lastExternalApplicationPID: pid_t?
    private var selectionTask: Task<Void, Never>?

    init(
        permissionManager: AccessibilityPermissionManager = AccessibilityPermissionManager(),
        selectedTextProvider: AXSelectedTextProvider = AXSelectedTextProvider(),
        clipboardSelectedTextProvider: ClipboardSelectedTextProvider = ClipboardSelectedTextProvider()
    ) {
        self.permissionManager = permissionManager
        self.selectedTextProvider = selectedTextProvider
        self.clipboardSelectedTextProvider = clipboardSelectedTextProvider

        let viewModel = TranslationViewModel()
        let coordinator = TranslationCoordinator(viewModel: viewModel)
        self.viewModel = viewModel
        self.coordinator = coordinator
        self.panelController = TranslationPanelController(viewModel: viewModel, coordinator: coordinator)

        viewModel.onOpenAccessibilitySettings = { [weak permissionManager] in
            permissionManager?.openSystemSettings()
        }
        viewModel.onRetryAccessibility = { [weak self] in
            self?.retryAccessibilityPermission()
        }
        viewModel.onDismiss = { [weak panelController] in
            panelController?.hide()
        }
    }

    func translateSelection() {
        // Accessibility must be queried before any TranslateDot UI is shown.
        let sourceApplication = NSWorkspace.shared.frontmostApplication
        if let sourceApplication,
           sourceApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            lastExternalApplicationPID = sourceApplication.processIdentifier
        }
        let sourceApplicationPID = lastExternalApplicationPID
        logger.info(
            "Selection requested sourcePID=\(sourceApplicationPID ?? -1, privacy: .public) bundle=\(sourceApplication?.bundleIdentifier ?? "unknown", privacy: .public)"
        )

        guard permissionManager.requestAccessIfNeeded() else {
            logger.info("Translation request requires Accessibility permission")
            viewModel.showPermissionRequired()
            panelController.show(anchor: nil)
            monitorAccessibilityAuthorization()
            return
        }

        selectionTask?.cancel()
        selectionTask = Task { @MainActor [weak self] in
            await self?.performSelectionLookup(sourceApplicationPID: sourceApplicationPID)
        }
    }

    private func performSelectionLookup(sourceApplicationPID: pid_t?) async {
        let accessibilityResult = selectedTextProvider.readSelection(
            frontmostApplicationPID: sourceApplicationPID
        )
        let selection: Result<SelectedTextResult, SelectedTextError>

        switch accessibilityResult {
        case .success, .failure(.permissionRequired), .failure(.selectionTooLong):
            selection = accessibilityResult
        case .failure(let accessibilityError):
            logger.info("Trying clipboard fallback after \(accessibilityError.logDescription, privacy: .public)")
            selection = await clipboardSelectedTextProvider.readSelection(from: sourceApplicationPID)
        }

        guard !Task.isCancelled else { return }
        switch selection {
        case .success(let result):
            let request = TranslationRequest(text: result.text, selectionBounds: result.bounds)
            viewModel.showLoading(for: request)
            panelController.show(anchor: result.bounds)
            coordinator.submit(request)

        case .failure(let error):
            logger.error("Selection lookup failed: \(error.logDescription, privacy: .public)")
            viewModel.showSelectionError(error)
            panelController.show(anchor: nil)
        }
    }

    func showHotKeyFailure(_ message: String) {
        viewModel.showFailure(message)
        panelController.show(anchor: nil)
    }

    private func retryAccessibilityPermission() {
        if permissionManager.check() {
            viewModel.showNoSelection(message: L10n.string(
                "permission.granted",
                defaultValue: "Permission granted. Select text in another app, then press ⌥D."
            ))
        } else {
            viewModel.showPermissionRequired()
            monitorAccessibilityAuthorization()
        }
    }

    private func monitorAccessibilityAuthorization() {
        permissionManager.monitorUntilGranted { [weak self] in
            self?.viewModel.showNoSelection(message: L10n.string(
                "permission.activated",
                defaultValue: "Permission is active. Return to the original app, select the text again, then press ⌥D."
            ))
        }
    }
}
