// File: workouttrackerUITests/Support/UITestSupport.swift
import XCTest
import UIKit

enum UITestLaunch {
    static func app(
        start: String,
        reset: Bool = true,
        seed: Bool = false,
        preferredContentSizeCategory: UIContentSizeCategory? = nil,
        disableAnimations: Bool = true,
        extraEnv: [String: String] = [:],
        extraArgs: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extraArgs

        if let preferredContentSizeCategory {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                preferredContentSizeCategory.rawValue
            ]
        }

        var env = app.launchEnvironment
        env["UITESTS"] = "1"
        env["UITESTS_START"] = start
        env["UITESTS_RESET"] = reset ? "1" : "0"
        env["UITESTS_SEED"] = seed ? "1" : "0"
        env["UITESTS_DISABLE_ANIMATIONS"] = disableAnimations ? "1" : "0"
        for (k, v) in extraEnv { env[k] = v }
        app.launchEnvironment = env
        return app
    }
}

extension XCUIApplication {
    func el(_ id: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: id).firstMatch
    }
}

extension XCTestCase {
    func attachUITestDebug(_ app: XCUIApplication,
                           name: String,
                           file: StaticString = #filePath,
                           line: UInt = #line) {
        let shot = XCUIScreen.main.screenshot()
        let a1 = XCTAttachment(screenshot: shot)
        a1.name = "\(name) screenshot"
        a1.lifetime = .keepAlways
        add(a1)

        let a2 = XCTAttachment(string: app.debugDescription)
        a2.name = "\(name) hierarchy"
        a2.lifetime = .keepAlways
        add(a2)
    }
}

@discardableResult
func tapNewActivityButton(_ app: XCUIApplication, timeout: TimeInterval = 6.0) -> Bool {
    let byId = app.descendants(matching: .any).matching(identifier: "timeline.newActivityButton").firstMatch
    if byId.waitForExistence(timeout: timeout) {
        if byId.isHittable { byId.tap() }
        else { byId.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        return true
    }

    let byLabel = app.descendants(matching: .any)
        .matching(NSPredicate(format: "label CONTAINS[c] %@", "New activity"))
        .firstMatch

    if byLabel.waitForExistence(timeout: 2.0) {
        byLabel.tap()
        return true
    }

    return false
}

func assertApproximatelyVerticallyCentered(
    _ element: XCUIElement,
    in app: XCUIApplication,
    tolerance: CGFloat = 140,
    debugName: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(
        element.waitForExistence(timeout: 6),
        "Expected element '\(debugName)' to exist before checking centering.",
        file: file,
        line: line
    )

    let window = app.windows.firstMatch
    XCTAssertTrue(
        window.waitForExistence(timeout: 2),
        "Expected app window for centering check.",
        file: file,
        line: line
    )

    let deadline = Date().addingTimeInterval(4.0)
    var delta = abs(element.frame.midY - window.frame.midY)

    while delta > tolerance && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        delta = abs(element.frame.midY - window.frame.midY)
    }

    if delta > tolerance {
        let shot = XCUIScreen.main.screenshot()
        let screenshotAttachment = XCTAttachment(screenshot: shot)
        screenshotAttachment.name = "\(debugName) not centered screenshot"
        screenshotAttachment.lifetime = .keepAlways

        let hierarchyAttachment = XCTAttachment(string: app.debugDescription)
        hierarchyAttachment.name = "\(debugName) hierarchy"
        hierarchyAttachment.lifetime = .keepAlways

        XCTContext.runActivity(named: "Centering failure debug") { activity in
            activity.add(screenshotAttachment)
            activity.add(hierarchyAttachment)
        }
    }

    XCTAssertLessThanOrEqual(
        delta,
        tolerance,
        "Expected '\(debugName)' to be vertically near the middle of the screen. delta=\(delta), tolerance=\(tolerance)",
        file: file,
        line: line
    )
}



func assertActionableRowVisibleInWorkingArea(
    _ element: XCUIElement,
    in app: XCUIApplication,
    preferredTopFraction: CGFloat = 0.18,
    preferredBottomFraction: CGFloat = 0.66,
    topInset: CGFloat = 60,
    bottomInset: CGFloat = 120,
    debugName: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(
        element.waitForExistence(timeout: 6),
        "Expected element '\(debugName)' to exist before checking visibility.",
        file: file,
        line: line
    )

    let window = app.windows.firstMatch
    XCTAssertTrue(
        window.waitForExistence(timeout: 2),
        "Expected app window for visibility check.",
        file: file,
        line: line
    )

    func isInWorkingArea(_ elementFrame: CGRect, _ windowFrame: CGRect) -> Bool {
        guard !elementFrame.isEmpty, !windowFrame.isEmpty else { return false }
        let visibleMinY = windowFrame.minY + topInset
        let visibleMaxY = windowFrame.maxY - bottomInset
        guard elementFrame.maxY > visibleMinY, elementFrame.minY < visibleMaxY else {
            return false
        }

        let preferredMinY = max(visibleMinY, windowFrame.minY + (windowFrame.height * preferredTopFraction))
        let preferredMaxY = min(visibleMaxY, windowFrame.minY + (windowFrame.height * preferredBottomFraction))
        return elementFrame.midY >= preferredMinY && elementFrame.midY <= preferredMaxY
    }

    let deadline = Date().addingTimeInterval(4.0)
    var elementFrame = element.frame
    var windowFrame = window.frame
    var delta = abs(elementFrame.midY - windowFrame.midY)
    var success = isInWorkingArea(elementFrame, windowFrame)

    while !success && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        elementFrame = element.frame
        windowFrame = window.frame
        delta = abs(elementFrame.midY - windowFrame.midY)
        success = isInWorkingArea(elementFrame, windowFrame)
    }

    if !success {
        let shot = XCUIScreen.main.screenshot()
        let screenshotAttachment = XCTAttachment(screenshot: shot)
        screenshotAttachment.name = "\(debugName) not in working area screenshot"
        screenshotAttachment.lifetime = .keepAlways

        let hierarchyAttachment = XCTAttachment(string: app.debugDescription)
        hierarchyAttachment.name = "\(debugName) hierarchy"
        hierarchyAttachment.lifetime = .keepAlways

        XCTContext.runActivity(named: "Actionable-row position failure debug") { activity in
            activity.add(screenshotAttachment)
            activity.add(hierarchyAttachment)
        }
    }

    XCTAssertTrue(
        success,
        "Expected '\(debugName)' to be visible inside the usable upper/middle working area. frame=\(NSCoder.string(for: elementFrame))), window=\(NSCoder.string(for: windowFrame)), delta=\(delta)",
        file: file,
        line: line
    )
}
