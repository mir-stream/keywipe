import SwiftUI
import KeyWipeCore

private enum Palette {
    static let ink = Color(red: 0.12, green: 0.19, blue: 0.18)
    static let muted = Color(red: 0.42, green: 0.48, blue: 0.46)
    static let paper = Color(red: 0.97, green: 0.97, blue: 0.94)
    static let green = Color(red: 0.22, green: 0.41, blue: 0.34)
    static let mint = Color(red: 0.57, green: 0.91, blue: 0.79)
}

struct HomeView: View {
    @ObservedObject var controller: CleaningController
    private var trackpad: Bool { controller.mode == .trackpad }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "keyboard")
                    .font(.system(size: 21, weight: .medium))
                Text("KeyWipe").font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
                Text("A LITTLE RESET")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.7).foregroundStyle(Palette.muted)
            }
            .padding(.bottom, 22)

            HStack(spacing: 4) {
                modeButton(.keyboard, title: "키보드 청소", symbol: "keyboard")
                modeButton(.trackpad, title: "트랙패드 청소", symbol: "hand.draw")
            }
            .padding(4)
            .background(Palette.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
            .padding(.bottom, 18)

            Text(trackpad ? "트랙패드도, 가볍게." : "키보드에 잠깐의 쉼표.")
                .font(.system(size: 32, weight: .bold))
                .tracking(-1.3)
                .padding(.bottom, 8)
            Text(trackpad ? "트랙패드와 주변 키를 함께 막아요.\n청소가 끝나면 Esc를 3초간 누르세요."
                         : "닦는 동안 키 입력은 잠시 멈추고,\n트랙패드는 그대로 사용할 수 있어요.")
                .font(.system(size: 14)).lineSpacing(5)
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)

            Group {
                if trackpad { TrackpadIllustration(dark: false) }
                else { KeyboardIllustration(dark: false) }
            }
            .frame(width: 376, height: 150)
            .padding(.top, 12)
            .padding(.bottom, 14)

            HStack(spacing: 8) {
                Image(systemName: controller.hasPermission ? "checkmark.circle.fill" : "lock.circle")
                Text(controller.hasPermission ? "시작할 준비가 됐어요" : "처음 한 번, 손쉬운 사용 권한이 필요해요")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.green)
            .padding(.bottom, 12)

            Button(action: {
                if controller.hasPermission { controller.startCleaning() }
                else { controller.openPermissionSettings() }
            }) {
                HStack(spacing: 9) {
                    Image(systemName: controller.hasPermission ? "sparkles" : "arrow.up.forward.app")
                    Text(controller.hasPermission ? "청소 시작하기" : "권한 설정 열기")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 55)
                .background(Palette.green, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            if !controller.hasPermission {
                Text("시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용\nKeyWipe를 켜고 이 창으로 돌아오세요.")
                    .font(.system(size: 11)).lineSpacing(4)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }

            if let notice = controller.notice {
                Text(notice)
                    .font(.system(size: 12)).lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.green)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 15)

            HStack(spacing: 6) {
                Image(systemName: trackpad ? "escape" : "cursorarrow.click")
                Text(trackpad ? "해제는 Esc 키를 3초간 누르기" : "해제는 트랙패드로 버튼을 2초간 누르기")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.ink)
            .padding(.bottom, 16)

            Rectangle().fill(Palette.ink.opacity(0.1)).frame(height: 1)
                .padding(.bottom, 12)
            Text(trackpad ? "트랙패드·마우스·키보드 차단 · 전원 및 Touch ID 제외"
                          : "내장·외장 키보드 모두 차단 · 전원 및 Touch ID 제외")
                .font(.system(size: 10)).foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 42)
        .padding(.top, 30)
        .padding(.bottom, 22)
        .frame(width: 540, height: 660)
        .foregroundStyle(Palette.ink)
        .background(Palette.paper)
        .environment(\.colorScheme, .light)
    }

    private func modeButton(_ mode: CleaningMode, title: String, symbol: String) -> some View {
        Button { controller.mode = mode; controller.notice = nil } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .foregroundStyle(controller.mode == mode ? .white : Palette.muted)
                .background(controller.mode == mode ? Palette.green : .clear,
                            in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(controller.mode == mode ? .isSelected : [])
    }
}

struct CleaningView: View {
    @ObservedObject var controller: CleaningController
    var preview = false
    private var trackpad: Bool { controller.mode == .trackpad }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.055, green: 0.075, blue: 0.085)
                RadialGradient(colors: [Palette.mint.opacity(0.08), .clear],
                    center: .center, startRadius: 30, endRadius: 570)

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Circle().fill(Palette.mint).frame(width: 6, height: 6)
                        Text(preview ? "화면 미리보기 · 실제 차단 안 됨"
                             : (trackpad ? "트랙패드 청소 중" : "키보드 청소 중"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Palette.mint)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Palette.mint.opacity(0.08), in: Capsule())
                    .padding(.bottom, 28)

                    Text(controller.isFinishing ? "이제 손을 떼주세요." : "편하게 닦으세요.")
                        .font(.system(size: 40, weight: .bold)).tracking(-1.4)
                        .foregroundStyle(Color.white.opacity(0.95))
                        .padding(.bottom, 14)
                    Text(controller.isFinishing
                         ? (trackpad ? "Esc와 트랙패드에서 손을 떼면 입력이 다시 켜져요."
                                     : "눌린 키가 모두 놓이면 청소 모드가 끝나요.")
                         : (trackpad ? "트랙패드와 키보드 입력을 모두 막고 있어요."
                                     : "모든 키보드 입력을 막고 있어요."))
                        .font(.system(size: 15)).foregroundStyle(Color.white.opacity(0.5))

                    Group {
                        if trackpad { TrackpadIllustration(dark: true) }
                        else { KeyboardIllustration(dark: true) }
                    }
                    .frame(width: 376, height: 150)
                    .padding(.vertical, 36)

                    Text(String(format: "%02d:%02d", controller.elapsedSeconds / 60,
                                controller.elapsedSeconds % 60))
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.bottom, 30)

                    if controller.isFinishing {
                        ProgressView().controlSize(.small).tint(Palette.mint)
                            .frame(width: 280, height: 58)
                    } else if trackpad {
                        EscapeHoldIndicator(progress: controller.escapeProgress)
                            .frame(width: 280, height: 58)
                    } else {
                        HoldToFinishButton { controller.requestFinish() }
                            .frame(width: 280, height: 58)
                    }

                    Text(trackpad ? "Esc 키를 3초간 누른 뒤 놓으세요"
                                  : "트랙패드로 2초간 누른 뒤 놓으세요")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.top, 12)
                }
                .scaleEffect(min(1, (geometry.size.height - 100) / 570))

                VStack {
                    HStack {
                        Text("KeyWipe").font(.system(size: 15, weight: .semibold, design: .rounded))
                        Spacer()
                        Image(systemName: "lock.fill").font(.system(size: 13))
                    }
                    Spacer()
                    Text(trackpad ? "트랙패드·마우스·키보드 입력 차단 · 전원 및 Touch ID 제외"
                                  : "트랙패드와 마우스는 사용할 수 있어요. 전원 및 Touch ID는 차단되지 않아요.")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.white.opacity(0.3))
                .padding(32)
                .allowsHitTesting(false)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

struct EscapeHoldIndicator: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color(white: 0.12)
                Palette.mint.opacity(0.22).frame(width: geometry.size.width * progress)
                HStack(spacing: 14) {
                    Text("esc").font(.system(size: 13, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.35)))
                    Text(progress > 0 ? "계속 누르고 계세요" : "3초간 누르면 해제")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(progress > 0 ? Palette.mint : .white)
                .frame(maxWidth: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.2)))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Esc 키를 3초간 누르면 청소 모드 해제")
        .accessibilityValue("\(Int(progress * 100))퍼센트")
    }
}

struct TrackpadIllustration: View {
    let dark: Bool

    var body: some View {
        Canvas { context, size in
            let outer = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            let body = Path(roundedRect: outer, cornerRadius: 16)
            context.fill(body, with: .color(dark ? Color(white: 0.12) : Color(white: 0.89)))
            context.stroke(body, with: .color(dark ? .white.opacity(0.1) : .black.opacity(0.1)), lineWidth: 1)
            for col in 0..<12 {
                let rect = CGRect(x: 14 + CGFloat(col) * 29, y: 12, width: 25, height: 19)
                context.fill(Path(roundedRect: rect, cornerRadius: 4),
                             with: .color(dark ? Color(white: 0.19) : Color(white: 0.98)))
            }
            let pad = Path(roundedRect: CGRect(x: 68, y: 47, width: size.width - 136, height: 88),
                           cornerRadius: 8)
            context.fill(pad, with: .color(dark ? Color(white: 0.17) : Color(white: 0.95)))
            context.stroke(pad, with: .color(dark ? .white.opacity(0.18) : .black.opacity(0.15)), lineWidth: 1)
            let circle = CGRect(x: size.width / 2 - 22, y: 69, width: 44, height: 44)
            context.fill(Path(ellipseIn: circle), with: .color(dark ? Palette.mint : Palette.green))
            let icon = Text(Image(systemName: dark ? "lock.fill" : "sparkles"))
                .foregroundColor(dark ? Palette.ink : .white)
                .font(.system(size: 18, weight: .medium))
            context.draw(context.resolve(icon), at: CGPoint(x: size.width / 2, y: 91))
        }
        .accessibilityHidden(true)
    }
}

struct KeyboardIllustration: View {
    let dark: Bool

    var body: some View {
        Canvas { context, size in
            let outer = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
            let body = Path(roundedRect: outer, cornerRadius: 16)
            context.fill(body, with: .color(dark ? Color(white: 0.12) : Color(white: 0.89)))
            context.stroke(body, with: .color(dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1)), lineWidth: 1)
            let gap: CGFloat = 4
            let keyWidth = (size.width - 28 - gap * 13) / 14
            for row in 0..<5 {
                for col in 0..<14 {
                    if row == 4 && (3...9).contains(col) { continue }
                    let isSpace = row == 4 && col == 2
                    let rect = CGRect(x: 14 + CGFloat(col) * (keyWidth + gap),
                        y: 14 + CGFloat(row) * 25,
                        width: isSpace ? keyWidth * 8 + gap * 7 : keyWidth, height: 20)
                    let path = Path(roundedRect: rect, cornerRadius: 4)
                    context.fill(path, with: .color(dark ? Color(white: 0.19) : Color(white: 0.98)))
                    context.stroke(path, with: .color(dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)), lineWidth: 0.7)
                }
            }
            let circle = CGRect(x: size.width / 2 - 24, y: size.height / 2 - 24, width: 48, height: 48)
            context.fill(Path(ellipseIn: circle), with: .color(dark ? Palette.mint : Palette.green))
            let icon = Text(Image(systemName: dark ? "lock.fill" : "sparkles"))
                .foregroundColor(dark ? Palette.ink : .white)
                .font(.system(size: 19, weight: .medium))
            context.draw(context.resolve(icon),
                at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        .accessibilityHidden(true)
    }
}
