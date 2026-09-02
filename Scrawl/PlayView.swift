import SwiftUI

struct PlayView: View {
    @EnvironmentObject private var world: WorldStore
    @EnvironmentObject private var drawing: DrawingSession
    @EnvironmentObject private var sound: SoundPlayer

    @State private var shake: CGFloat = 0
    @State private var showSettings = false
    @State private var ignoreNextSoundTap = false
    @State private var flashingSkill: CreatureSkill?
    @State private var saveFlash = false
    @State private var saveShake: CGFloat = 0
    @State private var showLibrary = false

    private let accent = Color(red: 0.18, green: 0.55, blue: 0.62)
    private let ink = Color(red: 0.28, green: 0.32, blue: 0.36)

    var body: some View {
        GeometryReader { geo in
            let layout = PlayLayout(size: geo.size)
            ZStack(alignment: .bottom) {
                Palette.desk.ignoresSafeArea()

                VStack(spacing: 0) {
                    railsPaper(layout: layout)
                    PondView()
                        .frame(height: layout.pondHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                putInButton(size: layout.dropSize)
                    .padding(.bottom, layout.pondHeight - 4)
                    .modifier(ShakeEffect(shakes: shake))
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .clipped()
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSettings) {
            ParentSettingsView()
        }
        .sheet(isPresented: $showLibrary) {
            PondLibraryView()
        }
    }

    private func railsPaper(layout: PlayLayout) -> some View {
        HStack(alignment: .top, spacing: layout.railGap) {
            leftRail(layout: layout)
            paperSheet
            rightRail(layout: layout)
        }
        .padding(.horizontal, layout.sidePad)
        .padding(.top, layout.topPad)
        .padding(.bottom, layout.dropReserve)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }

    private func leftRail(layout: PlayLayout) -> some View {
        toolTray(layout: layout) {
            soundButton(size: layout.tool)
            trayDivider
            twoColumn(spacing: layout.grid) {
                ForEach(Array(Palette.swatches.enumerated()), id: \.offset) { _, color in
                    colorDot(color, size: layout.tool)
                }
            }
            twoColumn(spacing: layout.grid) {
                ForEach(StampKind.allCases) { kind in
                    stampButton(kind, size: layout.tool)
                }
            }
        }
    }

    private func rightRail(layout: PlayLayout) -> some View {
        toolTray(layout: layout) {
            HStack(spacing: layout.grid) {
                ForEach([BrushKind.crayon, .sketch], id: \.id) { kind in
                    brushButton(kind, size: layout.tool)
                }
            }
            HStack(spacing: layout.grid) {
                ForEach([InkWidth.medium, .thick]) { width in
                    widthDot(width, hit: layout.tool)
                }
            }
            trayDivider
            twoColumn(spacing: layout.grid) {
                ForEach(CreatureSkill.allCases.filter(\.isKidPlay)) { skill in
                    skillButton(skill, size: layout.tool)
                }
            }
            trayDivider
            HStack(spacing: layout.grid) {
                roundTool(systemName: "arrow.uturn.backward", size: layout.tool) {
                    drawing.undoLastStroke()
                }
                roundTool(systemName: "doc", size: layout.tool) {
                    drawing.clearPaper()
                }
            }
            HStack(spacing: layout.grid) {
                saveButton(size: layout.tool)
                libraryButton(size: layout.tool)
            }
        }
    }

    private func toolTray<Content: View>(layout: PlayLayout, @ViewBuilder content: () -> Content) -> some View {
        let stack = VStack(spacing: layout.traySpacing, content: content)
            .padding(.horizontal, layout.trayPadH)
            .padding(.vertical, layout.trayPadV)
            .frame(width: layout.trayWidth)
        let chrome = RoundedRectangle(cornerRadius: 32, style: .continuous)
        return Group {
            if layout.fitsWithoutScroll {
                stack
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    stack
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .background(
            chrome
                .fill(Palette.tray)
                .shadow(color: Color.black.opacity(0.10), radius: 12, y: 5)
        )
        .overlay(chrome.stroke(Palette.trayLine, lineWidth: 1.5))
        .clipShape(chrome)
    }

    private var trayDivider: some View {
        Rectangle()
            .fill(Palette.trayLine)
            .frame(height: 1)
            .padding(.horizontal, 4)
    }

    private func twoColumn<Content: View>(spacing: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ],
            spacing: spacing,
            content: content
        )
    }

    private var paperSheet: some View {
        paperCanvas
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Palette.paperEdge.opacity(0.8), lineWidth: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                    .padding(7)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 14, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var paperCanvas: some View {
        ZStack {
            DrawingCanvas(
                inkColor: drawing.inkColor,
                brushKind: drawing.brushKind,
                inkWidth: drawing.inkWidth,
                revision: drawing.revision,
                session: drawing
            )
            GeometryReader { geo in
                ForEach(drawing.stamps) { stamp in
                    StampGlyph(stamp: stamp)
                        .position(
                            x: stamp.normalizedPoint.x * geo.size.width,
                            y: stamp.normalizedPoint.y * geo.size.height
                        )
                }
            }
            .allowsHitTesting(false)
        }
        .background(Palette.paper)
    }

    private func soundButton(size: CGFloat) -> some View {
        Button {
            if ignoreNextSoundTap {
                ignoreNextSoundTap = false
                return
            }
            world.soundEnabled.toggle()
            sound.hapticLight()
        } label: {
            Image(systemName: world.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(world.soundEnabled ? accent : Color(red: 0.55, green: 0.42, blue: 0.40))
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(Palette.trayLine, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.2)
                .onEnded { _ in
                    ignoreNextSoundTap = true
                    showSettings = true
                }
        )
    }

    private func colorDot(_ color: UIColor, size: CGFloat) -> some View {
        Button {
            drawing.inkColor = color
        } label: {
            Circle()
                .fill(Color(color))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: drawing.inkColor == color ? 5 : 1)
                )
                .overlay(
                    Circle()
                        .stroke(drawing.inkColor == color ? accent : Color.clear, lineWidth: 3)
                        .padding(-3)
                )
        }
        .buttonStyle(.plain)
    }

    private func widthDot(_ width: InkWidth, hit: CGFloat) -> some View {
        let on = drawing.inkWidth == width
        return Button {
            drawing.inkWidth = width
        } label: {
            ZStack {
                Circle()
                    .fill(on ? accent : Color.white)
                Circle()
                    .fill(on ? Color.white : ink.opacity(0.45))
                    .frame(width: width.dotSize, height: width.dotSize)
            }
            .frame(width: hit, height: hit)
            .overlay(
                Circle().stroke(on ? accent : Palette.trayLine, lineWidth: on ? 4 : 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func stampButton(_ kind: StampKind, size: CGFloat) -> some View {
        Button {
            drawing.addStamp(kind)
            sound.hapticLight()
        } label: {
            Image(uiImage: kind.iconImage(side: size * 2))
                .resizable()
                .interpolation(.high)
                .frame(width: size * 0.72, height: size * 0.72)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(Palette.trayLine, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func saveButton(size: CGFloat) -> some View {
        Button(action: savePond) {
            Image(systemName: saveFlash ? "checkmark" : "square.and.arrow.down")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(saveFlash ? Color.white : ink)
                .frame(width: size, height: size)
                .background(Circle().fill(saveFlash ? accent : Color.white))
                .overlay(Circle().stroke(saveFlash ? Color.clear : Palette.trayLine, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .modifier(ShakeEffect(shakes: saveShake))
    }

    private func libraryButton(size: CGFloat) -> some View {
        Button {
            showLibrary = true
            sound.hapticLight()
        } label: {
            Image(systemName: "square.stack")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(world.snapshots.isEmpty ? ink.opacity(0.7) : accent)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(world.snapshots.isEmpty ? Palette.trayLine : accent, lineWidth: world.snapshots.isEmpty ? 1.5 : 3))
        }
        .buttonStyle(.plain)
    }

    private func savePond() {
        guard world.canSavePond else {
            saveShake += 1
            sound.play(.empty)
            return
        }
        world.saveSnapshot()
        if world.lastSaveFailed {
            saveShake += 1
            sound.play(.empty)
            return
        }
        saveFlash = true
        sound.play(.drop)
        sound.hapticLight()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            saveFlash = false
        }
    }

    private func skillButton(_ skill: CreatureSkill, size: CGFloat) -> some View {
        let on = skill == .fish ? world.isFishing : flashingSkill == skill
        return Button {
            if skill != .fish {
                flashingSkill = skill
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    if flashingSkill == skill {
                        flashingSkill = nil
                    }
                }
            }
            world.playSkill(skill, color: drawing.inkColor)
            sound.hapticLight()
        } label: {
            Image(systemName: skill.symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(on ? Color.white : skill.tint)
                .frame(width: size, height: size)
                .background(Circle().fill(on ? skill.tint : Color.white))
                .overlay(Circle().stroke(skill.tint, lineWidth: on ? 0 : 3))
        }
        .buttonStyle(.plain)
    }

    private func brushButton(_ kind: BrushKind, size: CGFloat) -> some View {
        Button {
            drawing.brushKind = kind
        } label: {
            Image(systemName: kind.symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(drawing.brushKind == kind ? Color.white : ink)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(drawing.brushKind == kind ? accent : Color.white)
                )
                .overlay(
                    Circle().stroke(drawing.brushKind == kind ? Color.clear : Palette.trayLine, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func roundTool(systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(Palette.trayLine, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private func putInButton(size: CGFloat) -> some View {
        Button(action: putIn) {
            ZStack {
                Circle()
                    .fill(drawing.hasMarks ? accent : Color(white: 0.78))
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(Color.white, lineWidth: 5))
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: size * 0.67))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size + 12, height: size + 12)
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private func putIn() {
        let drops = drawing.makeDrops()
        guard drops.isEmpty == false else {
            withAnimation(.default) { shake += 1 }
            sound.play(.empty)
            return
        }
        drawing.clearPaper()
        for drop in drops {
            world.add(image: drop.image, kind: drop.kind, hunts: drop.hunts, skills: drop.skills)
        }
        sound.play(.drop)
        sound.hapticLight()
    }
}

private struct PlayLayout {
    let tool: CGFloat
    let traySpacing: CGFloat
    let grid: CGFloat
    let trayPadH: CGFloat
    let trayPadV: CGFloat
    let topPad: CGFloat
    let sidePad: CGFloat
    let railGap: CGFloat
    let dropReserve: CGFloat
    let dropSize: CGFloat
    let pondHeight: CGFloat
    let fitsWithoutScroll: Bool

    var trayWidth: CGFloat { tool * 2 + 36 }

    init(size: CGSize) {
        let portrait = size.height > size.width
        if portrait {
            tool = size.width >= 980 ? 56 : 48
            traySpacing = 14
            grid = 10
            trayPadH = 12
            trayPadV = 14
            topPad = 14
            sidePad = 16
            railGap = 14
            dropReserve = 88
            dropSize = 84
            pondHeight = size.height * 0.32
            fitsWithoutScroll = true
            return
        }

        topPad = 8
        sidePad = 12
        railGap = 10
        dropSize = size.height < 780 ? 68 : 76
        dropReserve = dropSize + 8

        var pond = min(size.height * 0.24, 240)
        let minDrawing: CGFloat = 360
        if size.height - pond < minDrawing {
            pond = max(132, size.height - minDrawing)
        }
        pondHeight = pond

        let available = max(120, size.height - pond - topPad - dropReserve)
        var nextTool: CGFloat = min(size.width, size.height) >= 900 ? 50 : 42
        var nextSpacing: CGFloat = 10
        var nextGrid: CGFloat = 8
        var nextPadV: CGFloat = 10
        while Self.leftRailHeight(tool: nextTool, spacing: nextSpacing, grid: nextGrid, padV: nextPadV) > available && nextTool > 28 {
            nextTool -= 1
            if nextTool < 38 {
                nextSpacing = 7
                nextGrid = 6
                nextPadV = 8
            }
        }
        tool = nextTool
        traySpacing = nextSpacing
        grid = nextGrid
        trayPadH = 10
        trayPadV = nextPadV
        fitsWithoutScroll = Self.leftRailHeight(tool: nextTool, spacing: nextSpacing, grid: nextGrid, padV: nextPadV) <= available
    }

    /// Sound + divider + 4 color rows + 3 stamp rows.
    private static func leftRailHeight(tool: CGFloat, spacing: CGFloat, grid: CGFloat, padV: CGFloat) -> CGFloat {
        padV * 2 + spacing * 2 + 1 + grid * 5 + tool * 8
    }
}

private struct StampGlyph: View {
    let stamp: PaperStamp

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: stamp.size, height: stamp.size)
            .rotationEffect(.radians(Double(stamp.rotation)))
    }

    private var image: UIImage {
        let side = stamp.size * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            stamp.kind.draw(in: CGRect(origin: .zero, size: CGSize(width: side, height: side)), color: stamp.color)
        }
    }
}

private extension CreatureSkill {
    var tint: Color {
        switch self {
        case .dash: return Color(red: 0.96, green: 0.55, blue: 0.12)
        case .jump: return Color(red: 0.22, green: 0.62, blue: 0.48)
        case .glow: return Color(red: 0.92, green: 0.72, blue: 0.12)
        case .bubbles: return Color(red: 0.28, green: 0.58, blue: 0.92)
        case .fish: return Color(red: 0.96, green: 0.42, blue: 0.58)
        case .eat: return Color(red: 0.86, green: 0.28, blue: 0.22)
        case .shield: return Color(red: 0.42, green: 0.52, blue: 0.78)
        case .scare: return Color(red: 0.62, green: 0.38, blue: 0.82)
        }
    }
}
