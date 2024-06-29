import AppKit
import SwiftUI

class BorderWindowController: NSWindowController {
  var borderWindow: NSWindow!
  var appController: AppController?

  init() {
    super.init(window: nil)
    initializeBorderWindow()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenDidChange(_:)),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
  }

  @objc func screenDidChange(_ notification: Notification) {
    initializeBorderWindow()
  }

  private func initializeBorderWindow() {
    let screenFrame = NSScreen.main!.frame

    if borderWindow == nil {
      borderWindow = NSWindow(
        contentRect: screenFrame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false)
      borderWindow.isOpaque = false
      borderWindow.backgroundColor = .clear
      borderWindow.level = .screenSaver
      borderWindow.ignoresMouseEvents = true
      borderWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

      let borderView = BorderView(frame: screenFrame)
      borderWindow.contentView = borderView
    } else {
      borderWindow.setFrame(screenFrame, display: true)
      if let borderView = borderWindow.contentView as? BorderView {
        borderView.frame = screenFrame
        borderView.needsDisplay = true
      }
    }

    if let borderView = borderWindow.contentView as? BorderView {
      borderView.setNeedsDisplay(borderView.bounds)
    }

    self.window = borderWindow
  }

  func setAppController(appController: AppController) {
    self.appController = appController
    if let borderView = borderWindow.contentView as? BorderView {
      borderView.setAppController(appController: appController)
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func showBorder() {
    borderWindow.orderFrontRegardless()
    if let borderView = borderWindow.contentView as? BorderView {
      borderView.startAnimation()
    }
  }

  func hideBorder() {
    borderWindow.orderOut(nil)
    if let borderView = borderWindow.contentView as? BorderView {
      borderView.stopAnimation()
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

class BorderView: NSView {
  private var isAnimating = false
  private var borderWidth: CGFloat = 10.0
  private var animationTimer: Timer?
  private var animateOut = false
  private var appController: AppController?

  public func setAppController(appController: AppController) {
    self.appController = appController
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let borderColor = NSColor.systemPurple

    borderColor.set()

    let borderPath = NSBezierPath(
      rect: self.bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
    borderPath.lineWidth = borderWidth
    borderPath.stroke()
  }

  func startAnimation() {
    guard !isAnimating else { return }

    isAnimating = true
    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
      self?.animateBorder()
    }
  }

  func stopAnimation() {
    animationTimer?.invalidate()
    isAnimating = false
  }

  private func animateBorder() {
    if appController?.useAnimation == false {
      borderWidth = 10
      self.needsDisplay = true
      return
    }
    if animateOut {
      borderWidth -= 0.5
      if borderWidth < 1 {
        animateOut = false
      }

    } else {
      borderWidth += 0.5
      if borderWidth > 15 {
        animateOut = true
      }
    }
    self.needsDisplay = true
  }
}
