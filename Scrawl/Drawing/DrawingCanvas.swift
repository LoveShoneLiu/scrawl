import PencilKit
import SwiftUI

final class PaperCanvasView: PKCanvasView {
    var preferredTool: PKTool?
    private let hiddenPicker = PKToolPicker()
    private var isRestoringTool = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        hideSystemPicker()
        becomeFirstResponder()
        restorePreferredTool()
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        hideSystemPicker()
        restorePreferredTool()
        return ok
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        restorePreferredTool()
        super.touchesBegan(touches, with: event)
    }

    func hideSystemPicker() {
        hiddenPicker.setVisible(false, forFirstResponder: self)
        hiddenPicker.addObserver(self)
    }

    func restorePreferredTool() {
        guard isRestoringTool == false, let preferredTool else { return }
        isRestoringTool = true
        tool = preferredTool
        hiddenPicker.selectedTool = preferredTool
        hiddenPicker.setVisible(false, forFirstResponder: self)
        isRestoringTool = false
    }

    override func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
        guard isRestoringTool == false else { return }
        restorePreferredTool()
    }

    override func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
        guard isRestoringTool == false else { return }
        toolPicker.setVisible(false, forFirstResponder: self)
        restorePreferredTool()
    }
}

struct DrawingCanvas: UIViewRepresentable {
    let inkColor: UIColor
    let brushKind: BrushKind
    let inkWidth: InkWidth
    let revision: UInt
    var session: DrawingSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> PaperCanvasView {
        let canvas = PaperCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = Palette.paperUI
        canvas.isOpaque = true
        canvas.overrideUserInterfaceStyle = .light
        canvas.isScrollEnabled = false
        canvas.bounces = false
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.isRulerActive = false
        canvas.drawing = session.drawing
        applyTool(to: canvas, context: context, force: true)
        context.coordinator.appliedRevision = revision
        session.canvasView = canvas
        return canvas
    }

    func updateUIView(_ canvas: PaperCanvasView, context: Context) {
        context.coordinator.session = session
        applyTool(to: canvas, context: context, force: false)
        canvas.hideSystemPicker()
        canvas.restorePreferredTool()
        if context.coordinator.appliedRevision != revision {
            context.coordinator.isApplyingProgrammaticChange = true
            canvas.drawing = session.drawing
            canvas.undoManager?.removeAllActions()
            context.coordinator.isApplyingProgrammaticChange = false
            context.coordinator.appliedRevision = revision
        }
        session.canvasView = canvas
    }

    private func applyTool(to canvas: PaperCanvasView, context: Context, force: Bool) {
        let changed = force
            || context.coordinator.lastBrush != brushKind
            || context.coordinator.lastWidth != inkWidth
            || Self.colorsDiffer(context.coordinator.lastInkColor, inkColor)
        guard changed else { return }
        let next = brushKind.makeTool(color: inkColor, width: inkWidth)
        canvas.preferredTool = next
        canvas.tool = next
        context.coordinator.lastInkColor = inkColor
        context.coordinator.lastBrush = brushKind
        context.coordinator.lastWidth = inkWidth
    }

    private static func colorsDiffer(_ lhs: UIColor?, _ rhs: UIColor) -> Bool {
        guard let lhs else { return true }
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        return abs(lr - rr) > 0.01 || abs(lg - rg) > 0.01 || abs(lb - rb) > 0.01 || abs(la - ra) > 0.01
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var session: DrawingSession
        var appliedRevision: UInt = 0
        var lastInkColor: UIColor?
        var lastBrush: BrushKind?
        var lastWidth: InkWidth?
        var isApplyingProgrammaticChange = false

        init(session: DrawingSession) {
            self.session = session
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard isApplyingProgrammaticChange == false else { return }
            session.drawing = canvasView.drawing
            session.noteUserDrew()
        }
    }
}
