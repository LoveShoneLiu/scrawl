import Combine
import PencilKit
import UIKit

@MainActor
final class DrawingSession: ObservableObject {
    @Published var drawing = PKDrawing()
    @Published var inkColor: UIColor = Palette.swatches[0]
    @Published var brushKind: BrushKind = .crayon
    @Published var inkWidth: InkWidth = .medium
    @Published var stamps: [PaperStamp] = []
    @Published private(set) var revision: UInt = 0

    weak var canvasView: PKCanvasView?
    private var lastActionWasStamp = false

    var hasMarks: Bool {
        drawing.strokes.isEmpty == false || stamps.isEmpty == false
    }

    func clearPaper() {
        drawing = PKDrawing()
        stamps = []
        lastActionWasStamp = false
        revision += 1
    }

    func undoLastStroke() {
        if lastActionWasStamp, stamps.isEmpty == false {
            stamps.removeLast()
            lastActionWasStamp = stamps.isEmpty == false
            return
        }
        lastActionWasStamp = false
        canvasView?.undoManager?.undo()
    }

    func addStamp(_ kind: StampKind) {
        let stamp = PaperStamp(
            id: UUID(),
            kind: kind,
            color: kind.placedColor(),
            normalizedPoint: CGPoint(
                x: CGFloat.random(in: 0.22...0.78),
                y: CGFloat.random(in: 0.2...0.78)
            ),
            rotation: CGFloat.random(in: -0.28...0.28),
            size: CGFloat.random(in: kind.paperSize)
        )
        stamps.append(stamp)
        lastActionWasStamp = true
    }

    func noteUserDrew() {
        lastActionWasStamp = false
    }

    func makeDrops() -> [PondDrop] {
        guard hasMarks else { return [] }
        guard let image = renderImage(includeStrokes: true, stamps: stamps) else { return [] }
        return [PondDrop(image: image, kind: .doodle, hunts: false, skills: [])]
    }

    private func renderImage(includeStrokes: Bool, stamps: [PaperStamp]) -> UIImage? {
        let canvasBounds = canvasView?.bounds ?? CGRect(x: 0, y: 0, width: 900, height: 560)
        let source = canvasView?.drawing ?? drawing

        var union = CGRect.null
        if includeStrokes, source.strokes.isEmpty == false {
            var bounds = source.bounds.insetBy(dx: -24, dy: -24)
            if bounds.width < 8 { bounds.size.width = 8 }
            if bounds.height < 8 { bounds.size.height = 8 }
            union = bounds
        }
        for stamp in stamps {
            let center = CGPoint(
                x: stamp.normalizedPoint.x * canvasBounds.width,
                y: stamp.normalizedPoint.y * canvasBounds.height
            )
            let stampRect = CGRect(x: center.x - stamp.size / 2, y: center.y - stamp.size / 2, width: stamp.size, height: stamp.size)
            union = union.isNull ? stampRect : union.union(stampRect)
        }
        guard union.isNull == false, union.width.isFinite, union.height.isFinite else { return nil }
        union = union.insetBy(dx: -16, dy: -16)

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: union.size, format: format)
        return renderer.image { _ in
            if includeStrokes, source.strokes.isEmpty == false {
                source.image(from: union, scale: format.scale).draw(at: .zero)
            }
            for stamp in stamps {
                let center = CGPoint(
                    x: stamp.normalizedPoint.x * canvasBounds.width - union.origin.x,
                    y: stamp.normalizedPoint.y * canvasBounds.height - union.origin.y
                )
                let rect = CGRect(x: center.x - stamp.size / 2, y: center.y - stamp.size / 2, width: stamp.size, height: stamp.size)
                guard let ctx = UIGraphicsGetCurrentContext() else { continue }
                ctx.saveGState()
                ctx.translateBy(x: rect.midX, y: rect.midY)
                ctx.rotate(by: stamp.rotation)
                ctx.translateBy(x: -rect.midX, y: -rect.midY)
                stamp.kind.draw(in: rect, color: stamp.color)
                ctx.restoreGState()
            }
        }
    }
}
