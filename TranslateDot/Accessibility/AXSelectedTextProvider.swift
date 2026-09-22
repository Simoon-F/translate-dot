import AppKit
import ApplicationServices
import os

struct AXSelectedTextProvider {
    static let maximumCharacterCount = 10_000

    private enum ElementLookup {
        case success(AXUIElement)
        case failure(AXError)
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "AXSelection")

    func readSelection(frontmostApplicationPID: pid_t? = nil) -> Result<SelectedTextResult, SelectedTextError> {
        guard AXIsProcessTrusted() else {
            return .failure(.permissionRequired)
        }

        let focusedResult = focusedElement(frontmostApplicationPID: frontmostApplicationPID)
        guard case .success(let focusedElement) = focusedResult else {
            let focusedError: AXError
            if case .failure(let error) = focusedResult {
                focusedError = error
            } else {
                focusedError = .failure
            }
            logger.error("Focused element AXError=\(focusedError.rawValue, privacy: .public)")
            return .failure(.focusedElementUnavailable(focusedError))
        }

        let selectionResult = selectedText(from: focusedElement)
        guard case .success(let selection) = selectionResult else {
            if case .failure(let error) = selectionResult {
                return .failure(error)
            }
            return .failure(.noSelection)
        }
        let selectedText = selection.text

        let trimmed = selectedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.noSelection)
        }
        guard selectedText.count <= Self.maximumCharacterCount else {
            return .failure(.selectionTooLong(limit: Self.maximumCharacterCount))
        }

        let bounds = selectedBounds(for: selection.element).map(AccessibilityCoordinateConverter.toAppKit)
        return .success(SelectedTextResult(text: selectedText, bounds: bounds))
    }

    private func focusedElement(frontmostApplicationPID: pid_t?) -> ElementLookup {
        let systemWide = AXUIElementCreateSystemWide()
        let systemWideResult = elementAttribute(kAXFocusedUIElementAttribute, from: systemWide)
        if case .success = systemWideResult {
            return systemWideResult
        }

        let focusedApplicationResult = elementAttribute(kAXFocusedApplicationAttribute, from: systemWide)
        if case .success(let focusedApplication) = focusedApplicationResult {
            let applicationFocusResult = elementAttribute(kAXFocusedUIElementAttribute, from: focusedApplication)
            if case .success = applicationFocusResult {
                logger.debug("Resolved focus through the system-wide focused application")
                return applicationFocusResult
            }
        }

        guard let frontmostApplicationPID,
              frontmostApplicationPID != ProcessInfo.processInfo.processIdentifier else {
            if case .failure(let error) = systemWideResult { return .failure(error) }
            return .failure(.noValue)
        }

        logger.debug("System-wide focus unavailable; retrying application PID=\(frontmostApplicationPID, privacy: .public)")
        let application = AXUIElementCreateApplication(frontmostApplicationPID)
        return elementAttribute(kAXFocusedUIElementAttribute, from: application)
    }

    private func selectedText(from focusedElement: AXUIElement) -> Result<(text: String, element: AXUIElement), SelectedTextError> {
        var currentElement: AXUIElement? = focusedElement
        var lastError: AXError = .attributeUnsupported
        var foundEmptySelection = false

        // Some web and cross-platform controls expose the selection on an ancestor of the
        // focused leaf. Keep the search tight so text cannot leak from unrelated UI elements.
        for _ in 0..<5 {
            guard let element = currentElement else { break }
            var textValue: CFTypeRef?
            let textError = AXUIElementCopyAttributeValue(
                element,
                kAXSelectedTextAttribute as CFString,
                &textValue
            )
            lastError = textError
            foundEmptySelection = foundEmptySelection || textError == .noValue

            if textError == .success {
                guard let selectedText = textValue as? String else {
                    return .failure(.noSelection)
                }
                return .success((selectedText, element))
            }
            if textError != .attributeUnsupported && textError != .noValue {
                logger.error("Selected text AXError=\(textError.rawValue, privacy: .public)")
                return .failure(.accessibilityFailure(textError))
            }

            currentElement = parent(of: element)
        }

        logger.error("Selected text AXError=\(lastError.rawValue, privacy: .public)")
        return foundEmptySelection ? .failure(.noSelection) : .failure(.selectedTextUnsupported)
    }

    private func elementAttribute(_ attribute: String, from element: AXUIElement) -> ElementLookup {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return .failure(error == .success ? .illegalArgument : error)
        }
        // Core Foundation has no conditional cast for opaque AX types; the type ID guard makes
        // this downcast safe without assuming the runtime value's concrete Swift type.
        return .success(unsafeDowncast(value, to: AXUIElement.self))
    }

    private func parent(of element: AXUIElement) -> AXUIElement? {
        guard case .success(let parent) = elementAttribute(kAXParentAttribute, from: element) else {
            return nil
        }
        return parent
    }

    private func selectedBounds(for element: AXUIElement) -> CGRect? {
        var rangeValue: CFTypeRef?
        let rangeError = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )
        guard rangeError == .success,
              let rangeValue,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            logger.debug("Selected range unavailable AXError=\(rangeError.rawValue, privacy: .public)")
            return nil
        }

        let axRange = unsafeDowncast(rangeValue, to: AXValue.self)
        guard AXValueGetType(axRange) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axRange, .cfRange, &range) else { return nil }

        var boundsValue: CFTypeRef?
        let boundsError = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            axRange,
            &boundsValue
        )
        guard boundsError == .success,
              let boundsValue,
              CFGetTypeID(boundsValue) == AXValueGetTypeID() else {
            logger.debug("Selection bounds unavailable AXError=\(boundsError.rawValue, privacy: .public)")
            return nil
        }

        let axBounds = unsafeDowncast(boundsValue, to: AXValue.self)
        guard AXValueGetType(axBounds) == .cgRect else { return nil }
        var bounds = CGRect.zero
        guard AXValueGetValue(axBounds, .cgRect, &bounds), bounds.isFinite else { return nil }
        return bounds
    }
}

enum AccessibilityCoordinateConverter {
    /// Accessibility uses a top-left global origin while AppKit uses the lower-left of the main display.
    static func toAppKit(_ accessibilityRect: CGRect) -> CGRect {
        guard let mainScreen = NSScreen.screens.first else { return accessibilityRect }
        return CGRect(
            x: accessibilityRect.minX,
            y: mainScreen.frame.maxY - accessibilityRect.maxY,
            width: accessibilityRect.width,
            height: accessibilityRect.height
        )
    }
}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite && origin.y.isFinite && width.isFinite && height.isFinite
    }
}
