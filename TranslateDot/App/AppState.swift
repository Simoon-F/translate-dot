import AppKit
import os

@MainActor
final class AppState {
    let permissionManager: AccessibilityPermissionManager
    let screenCapturePermissionManager: ScreenCapturePermissionManager

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "Workflow")
    private let selectedTextProvider: AXSelectedTextProvider
    private let clipboardSelectedTextProvider: ClipboardSelectedTextProvider
    private let screenshotSelectionController: ScreenshotSelectionController
    private let screenCaptureProvider: ScreenCaptureProvider
    private let textRecognizer: VisionTextRecognizer
    private let settings: AppSettings
    private let viewModel: TranslationViewModel
    private let coordinator: TranslationCoordinator
    private let panelController: TranslationPanelController
    private var lastExternalApplicationPID: pid_t?
    private var selectionTask: Task<Void, Never>?
    private var screenshotTask: Task<Void, Never>?

    init(
        permissionManager: AccessibilityPermissionManager = AccessibilityPermissionManager(),
        screenCapturePermissionManager: ScreenCapturePermissionManager = ScreenCapturePermissionManager(),
        selectedTextProvider: AXSelectedTextProvider = AXSelectedTextProvider(),
        clipboardSelectedTextProvider: ClipboardSelectedTextProvider = ClipboardSelectedTextProvider(),
        screenshotSelectionController: ScreenshotSelectionController = ScreenshotSelectionController(),
        screenCaptureProvider: ScreenCaptureProvider = ScreenCaptureProvider(),
        textRecognizer: VisionTextRecognizer = VisionTextRecognizer(),
        settings: AppSettings = .shared
    ) {
        self.permissionManager = permissionManager
        self.screenCapturePermissionManager = screenCapturePermissionManager
        self.selectedTextProvider = selectedTextProvider
        self.clipboardSelectedTextProvider = clipboardSelectedTextProvider
        self.screenshotSelectionController = screenshotSelectionController
        self.screenCaptureProvider = screenCaptureProvider
        self.textRecognizer = textRecognizer
        self.settings = settings

        let viewModel = TranslationViewModel()
        let coordinator = TranslationCoordinator(viewModel: viewModel, settings: settings)
        self.viewModel = viewModel
        self.coordinator = coordinator
        self.panelController = TranslationPanelController(
            viewModel: viewModel,
            coordinator: coordinator,
            settings: settings
        )

        viewModel.onOpenAccessibilitySettings = { [weak permissionManager] in
            permissionManager?.openSystemSettings()
        }
        viewModel.onRetryAccessibility = { [weak self] in
            self?.retryAccessibilityPermission()
        }
        viewModel.onOpenScreenCaptureSettings = { [weak screenCapturePermissionManager] in
            screenCapturePermissionManager?.openSystemSettings()
        }
        viewModel.onRetryScreenCapture = { [weak self] in
            self?.retryScreenCapturePermission()
        }
        viewModel.onDismiss = { [weak panelController] in
            panelController?.hide()
        }
    }

    func translateScreenshot() {
        selectionTask?.cancel()
        screenshotTask?.cancel()
        screenshotSelectionController.cancel(notify: false)
        panelController.hide()

        guard screenCapturePermissionManager.requestAccessIfNeeded() else {
            logger.info("Screenshot request requires Screen Recording permission")
            viewModel.showScreenCapturePermissionRequired()
            panelController.show(anchor: nil)
            return
        }

        screenshotSelectionController.beginSelection { [weak self] selection in
            guard let self, let selection else { return }
            self.screenshotTask = Task { @MainActor [weak self] in
                await self?.performScreenshotTranslation(selection)
            }
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

    private func performScreenshotTranslation(_ selection: ScreenshotSelection) async {
        viewModel.showRecognizingScreenshot()
        panelController.show(anchor: selection.bounds)

        do {
            let image = try await screenCaptureProvider.capture(
                selectionBounds: selection.bounds,
                on: selection.screen
            )
            try Task.checkCancellation()
            let sourceLanguage = settings.sourceLanguageIdentifier.isEmpty
                ? nil
                : settings.sourceLanguageIdentifier
            let text = try await textRecognizer.recognizeText(
                in: image,
                sourceLanguageIdentifier: sourceLanguage
            )
            try Task.checkCancellation()

            let request = TranslationRequest(text: text, selectionBounds: selection.bounds)
            viewModel.showLoading(for: request)
            coordinator.submit(request)
        } catch is CancellationError {
            logger.debug("Screenshot translation cancelled")
        } catch let error as LocalizedError {
            logger.error("Screenshot translation failed: \(String(describing: error), privacy: .public)")
            viewModel.showFailure(error.errorDescription ?? L10n.string(
                "error.screenshot_failed",
                defaultValue: "Screenshot translation failed. Try again."
            ))
        } catch {
            logger.error("Screenshot translation failed: \(String(describing: error), privacy: .public)")
            viewModel.showFailure(L10n.string(
                "error.screenshot_failed",
                defaultValue: "Screenshot translation failed. Try again."
            ))
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

    private func retryScreenCapturePermission() {
        if screenCapturePermissionManager.isAuthorized {
            translateScreenshot()
        } else {
            viewModel.showScreenCapturePermissionRequired()
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
