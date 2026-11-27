import SwiftUI
import UIKit

public struct Deck52GridView: View {
    @ObservedObject var viewModel: GameViewModel
    
    // 4 Suits in logical display order
    let suits: [Suit] = [.hearts, .diamonds, .clubs, .spades]
    let ranks: [Rank] = Rank.allCases // 2 to Ace
    
    public var body: some View {
        if viewModel.isRankOnlyActive {
            RankOnlyGridView(viewModel: viewModel)
        } else {
            VStack(spacing: 4) {
                VStack(spacing: 3) {
                    ForEach(suits) { suit in
                        HStack(spacing: 3) {
                            // 13 ranks for this suit (no suit header to maximize card width)
                            ForEach(ranks) { rank in
                                let card = Card(rank: rank, suit: suit)
                                let owner = viewModel.cardOwner(card)
                                
                                CardButton(card: card, owner: owner) {
                                    viewModel.onCardTapped(card)
                                }
                            }
                        }
                    }
                }
                
                // Công tắc nhỏ chuyển nhanh sang bàn phím A->K (áp dụng cho tất cả các trò)
                HStack(spacing: 8) {
                    CompactMiniSwitch(
                        title: "Bàn phím A➔K",
                        isOn: $viewModel.isRankOnlyMode,
                        activeColor: .blue
                    )
                    Spacer()
                    Text("Bật A➔K để giữ phím vuốt chọn ♥ ♦ ♣ ♠")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }
            .padding(4)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

// MARK: - Shared Deterministic Geometry for 3-Row A->K Keypad & 4-Suit Popup
private enum RankKeypadGeometry {
    static let rows: [[Rank]] = [
        [.ace, .two, .three, .four, .five],
        [.six, .seven, .eight, .nine, .ten],
        [.jack, .queen, .king]
    ]
    static let popupSuits: [Suit] = [.hearts, .diamonds, .clubs, .spades]
    static let spacing: CGFloat = 6
    static let popupHeight: CGFloat = 60
    static let popupGapAboveKey: CGFloat = 10
    
    static func keyRect(rowIndex: Int, colIndex: Int, colCount: Int, in gridSize: CGSize) -> CGRect {
        let totalRows = CGFloat(rows.count)
        let rowHeight = max(1, (gridSize.height - spacing * (totalRows - 1)) / totalRows)
        let cols = CGFloat(colCount)
        let colWidth = max(1, (gridSize.width - spacing * (cols - 1)) / cols)
        let x = CGFloat(colIndex) * (colWidth + spacing)
        let y = CGFloat(rowIndex) * (rowHeight + spacing)
        return CGRect(x: x, y: y, width: colWidth, height: rowHeight)
    }
    
    static func hitTest(point: CGPoint, in gridSize: CGSize) -> (Rank, CGRect)? {
        guard gridSize.width > 0, gridSize.height > 0 else { return nil }
        // 1. Exact hit first
        for (rIdx, row) in rows.enumerated() {
            for (cIdx, rank) in row.enumerated() {
                let rect = keyRect(rowIndex: rIdx, colIndex: cIdx, colCount: row.count, in: gridSize)
                if rect.contains(point) {
                    return (rank, rect)
                }
            }
        }
        // 2. Fallback: nearest key if finger landed on the 6pt gap between buttons
        var best: (Rank, CGRect, CGFloat)? = nil
        for (rIdx, row) in rows.enumerated() {
            for (cIdx, rank) in row.enumerated() {
                let rect = keyRect(rowIndex: rIdx, colIndex: cIdx, colCount: row.count, in: gridSize)
                let expanded = rect.insetBy(dx: -spacing, dy: -spacing)
                if expanded.contains(point) {
                    let dx = point.x - rect.midX
                    let dy = point.y - rect.midY
                    let distSq = dx * dx + dy * dy
                    if best == nil || distSq < best!.2 {
                        best = (rank, rect, distSq)
                    }
                }
            }
        }
        return best.map { ($0.0, $0.1) }
    }
    
    static func popupRect(for keyRect: CGRect, gridWidth: CGFloat) -> CGRect {
        let effectiveWidth = gridWidth > 0 ? gridWidth : 348
        let width: CGFloat = min(236, max(196, effectiveWidth))
        let minX: CGFloat = 0
        let maxX: CGFloat = max(minX, effectiveWidth - width)
        let originX = min(max(minX, keyRect.midX - width / 2), maxX)
        let originY = keyRect.minY - popupHeight - popupGapAboveKey
        return CGRect(x: originX, y: originY, width: width, height: popupHeight)
    }
}

// MARK: - Native UIKit 0ms Touch Surface (Eliminates SwiftUI DragGesture & Edge Gate Lag)
private struct RankKeypadTouchOverlay: UIViewRepresentable {
    let isSwipeSuitEnabled: Bool
    let isCardUsed: (Rank, Suit) -> Bool
    let onPressChanged: (Rank, CGRect, CGFloat) -> Void
    let onPopupOpened: (Rank, CGRect, CGFloat, Suit?) -> Void
    let onHoverSuitChanged: (Suit?) -> Void
    let onCommitRankOnly: (Rank) -> Void
    let onCommitSuit: (Rank, Suit) -> Void
    let onReset: () -> Void
    
    func makeUIView(context: Context) -> RankKeypadTouchView {
        let view = RankKeypadTouchView()
        updateCallbacks(on: view)
        return view
    }
    
    func updateUIView(_ uiView: RankKeypadTouchView, context: Context) {
        updateCallbacks(on: uiView)
    }
    
    private func updateCallbacks(on view: RankKeypadTouchView) {
        view.isSwipeSuitEnabled = isSwipeSuitEnabled
        view.isCardUsed = isCardUsed
        view.onPressChanged = onPressChanged
        view.onPopupOpened = onPopupOpened
        view.onHoverSuitChanged = onHoverSuitChanged
        view.onCommitRankOnly = onCommitRankOnly
        view.onCommitSuit = onCommitSuit
        view.onReset = onReset
    }
}

private final class RankKeypadTouchView: UIView {
    var isSwipeSuitEnabled: Bool = true
    var isCardUsed: ((Rank, Suit) -> Bool)?
    var onPressChanged: ((Rank, CGRect, CGFloat) -> Void)?
    var onPopupOpened: ((Rank, CGRect, CGFloat, Suit?) -> Void)?
    var onHoverSuitChanged: ((Suit?) -> Void)?
    var onCommitRankOnly: ((Rank) -> Void)?
    var onCommitSuit: ((Rank, Suit) -> Void)?
    var onReset: (() -> Void)?
    
    private let holdDelay: TimeInterval = 0.11
    private let instantSwipeUpThreshold: CGFloat = 10
    
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let selectionHaptic = UISelectionFeedbackGenerator()
    
    private weak var activeTouch: UITouch?
    private var pressedRank: Rank?
    private var pressedKeyRect: CGRect = .zero
    private var startPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var isPopupOpen: Bool = false
    private var hoveredSuit: Suit?
    private var holdWorkItem: DispatchWorkItem?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
        isExclusiveTouch = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        let pt = touch.location(in: self)
        guard let (rank, rect) = RankKeypadGeometry.hitTest(point: pt, in: bounds.size) else { return }
        
        activeTouch = touch
        pressedRank = rank
        pressedKeyRect = rect
        startPoint = pt
        currentPoint = pt
        isPopupOpen = false
        hoveredSuit = nil
        
        lightHaptic.prepare()
        selectionHaptic.prepare()
        onPressChanged?(rank, rect, bounds.width)
        
        if isSwipeSuitEnabled {
            holdWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, self.pressedRank == rank, !self.isPopupOpen else { return }
                self.openPopup()
            }
            holdWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay, execute: item)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = activeTouch, touches.contains(active), let rank = pressedRank else { return }
        let pt = active.location(in: self)
        currentPoint = pt
        
        if isSwipeSuitEnabled && !isPopupOpen {
            let dy = pt.y - startPoint.y
            if dy <= -instantSwipeUpThreshold {
                // Vuốt hướng lên >= 10pt -> bung popup 4 chất ngay lập tức không cần chờ hết 0.11s
                holdWorkItem?.cancel()
                holdWorkItem = nil
                openPopup()
                return
            } else if !pressedKeyRect.insetBy(dx: -36, dy: -36).contains(pt) {
                // Chỉ hủy giữ khi kéo trượt hẳn ra ngoài mặt phím
                holdWorkItem?.cancel()
                holdWorkItem = nil
            }
        }
        
        if isPopupOpen {
            let newSuit = suitAt(point: pt, for: rank)
            if newSuit != hoveredSuit {
                hoveredSuit = newSuit
                if newSuit != nil {
                    selectionHaptic.selectionChanged()
                    selectionHaptic.prepare()
                }
                onHoverSuitChanged?(newSuit)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = activeTouch, touches.contains(active), let rank = pressedRank else { return }
        let endPt = active.location(in: self)
        holdWorkItem?.cancel()
        holdWorkItem = nil
        
        if isPopupOpen {
            if let suit = suitAt(point: endPt, for: rank) {
                mediumHaptic.impactOccurred()
                onCommitSuit?(rank, suit)
            }
        } else {
            // Chạm nhả nhanh bình thường -> nhập số không chất
            if pressedKeyRect.insetBy(dx: -20, dy: -20).contains(endPt) {
                onCommitRankOnly?(rank)
            }
        }
        
        clearTouchState()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = activeTouch, touches.contains(active) else { return }
        clearTouchState()
    }
    
    private func openPopup() {
        guard let rank = pressedRank else { return }
        isPopupOpen = true
        lightHaptic.impactOccurred()
        mediumHaptic.prepare()
        let initialSuit = suitAt(point: currentPoint, for: rank)
        hoveredSuit = initialSuit
        onPopupOpened?(rank, pressedKeyRect, bounds.width, initialSuit)
    }
    
    private func suitAt(point: CGPoint, for rank: Rank) -> Suit? {
        let rect = RankKeypadGeometry.popupRect(for: pressedKeyRect, gridWidth: bounds.width)
        // Còn nằm trong thân phím (chưa vuốt lên hướng popup) -> chưa chọn chất (thả tay = hủy an toàn)
        guard point.y <= pressedKeyRect.minY + 4 else { return nil }
        guard point.y >= rect.minY - 48 else { return nil }
        guard point.x >= rect.minX - 24 && point.x <= rect.maxX + 24 else { return nil }
        
        let suits = RankKeypadGeometry.popupSuits
        let slotWidth = rect.width / CGFloat(suits.count)
        let rawIndex = Int(floor((point.x - rect.minX) / slotWidth))
        let clampedIndex = min(max(0, rawIndex), suits.count - 1)
        let suit = suits[clampedIndex]
        
        if isCardUsed?(rank, suit) == true {
            return nil
        }
        return suit
    }
    
    private func clearTouchState() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        activeTouch = nil
        pressedRank = nil
        pressedKeyRect = .zero
        isPopupOpen = false
        hoveredSuit = nil
        onReset?()
    }
}

// MARK: - Compact Mini Toggle Switch (Nút công tắc nhỏ gọn đặt dưới bàn phím)
private struct CompactMiniSwitch: View {
    let title: String
    @Binding var isOn: Bool
    var activeColor: Color = .blue
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.16)) {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 6) {
                // Mini pill switch track + thumb
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? activeColor : Color.gray.opacity(0.35))
                        .frame(width: 28, height: 16)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 0.5)
                        .padding(2)
                }
                
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isOn ? activeColor : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isOn ? activeColor.opacity(0.12) : Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn ? activeColor.opacity(0.45) : Color.gray.opacity(0.25), lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Rank-Only Keypad (A -> K for ALL games, with 0ms UIKit Press-Hold + Swipe Suit Picker ♥ ♦ ♣ ♠)
public struct RankOnlyGridView: View {
    @ObservedObject var viewModel: GameViewModel
    @AppStorage("server1_rank_swipe_suit_enabled") private var isSwipeSuitEnabled: Bool = true
    
    let row1: [Rank] = [.ace, .two, .three, .four, .five]
    let row2: [Rank] = [.six, .seven, .eight, .nine, .ten]
    let row3: [Rank] = [.jack, .queen, .king]
    
    @State private var pressedRank: Rank? = nil
    @State private var activePopupRank: Rank? = nil
    @State private var activeKeyRect: CGRect = .zero
    @State private var activeGridWidth: CGFloat = 0
    @State private var hoveredSuit: Suit? = nil
    
    public var body: some View {
        VStack(spacing: 6) {
            // 3 hàng phím A -> K phủ 1 lớp cảm ứng UIKit 0ms thống nhất (không bị delay ở 6-9 và J-K)
            VStack(spacing: RankKeypadGeometry.spacing) {
                // Row 1: A, 2, 3, 4, 5
                HStack(spacing: RankKeypadGeometry.spacing) {
                    ForEach(row1) { rank in
                        RankButtonVisual(
                            rank: rank,
                            isPressed: pressedRank == rank,
                            isPopupOpen: activePopupRank == rank,
                            showSwipeHint: isSwipeSuitEnabled
                        )
                    }
                }
                
                // Row 2: 6, 7, 8, 9, 10
                HStack(spacing: RankKeypadGeometry.spacing) {
                    ForEach(row2) { rank in
                        RankButtonVisual(
                            rank: rank,
                            isPressed: pressedRank == rank,
                            isPopupOpen: activePopupRank == rank,
                            showSwipeHint: isSwipeSuitEnabled
                        )
                    }
                }
                
                // Row 3: J, Q, K
                HStack(spacing: RankKeypadGeometry.spacing) {
                    ForEach(row3) { rank in
                        RankButtonVisual(
                            rank: rank,
                            isPressed: pressedRank == rank,
                            isPopupOpen: activePopupRank == rank,
                            showSwipeHint: isSwipeSuitEnabled
                        )
                    }
                }
            }
            .overlay(
                RankKeypadTouchOverlay(
                    isSwipeSuitEnabled: isSwipeSuitEnabled,
                    isCardUsed: { rank, suit in
                        viewModel.cardOwner(Card(rank: rank, suit: suit)) != nil
                    },
                    onPressChanged: { rank, rect, gridWidth in
                        pressedRank = rank
                        activeKeyRect = rect
                        activeGridWidth = gridWidth
                    },
                    onPopupOpened: { rank, rect, gridWidth, initialSuit in
                        activeKeyRect = rect
                        activeGridWidth = gridWidth
                        hoveredSuit = initialSuit
                        withAnimation(.spring(response: 0.14, dampingFraction: 0.84)) {
                            activePopupRank = rank
                        }
                    },
                    onHoverSuitChanged: { suit in
                        hoveredSuit = suit
                    },
                    onCommitRankOnly: { rank in
                        viewModel.onRankTapped(rank)
                    },
                    onCommitSuit: { rank, suit in
                        viewModel.onCardTapped(Card(rank: rank, suit: suit))
                    },
                    onReset: {
                        pressedRank = nil
                        hoveredSuit = nil
                        withAnimation(.easeOut(duration: 0.10)) {
                            activePopupRank = nil
                        }
                    }
                )
            )
            .overlay(alignment: .topLeading) {
                if let popupRank = activePopupRank {
                    let rect = RankKeypadGeometry.popupRect(for: activeKeyRect, gridWidth: activeGridWidth)
                    SuitSwipePopupView(
                        rank: popupRank,
                        suits: RankKeypadGeometry.popupSuits,
                        hoveredSuit: hoveredSuit,
                        ownerLookup: { suit in
                            viewModel.cardOwner(Card(rank: popupRank, suit: suit))
                        }
                    )
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                }
            }
            .zIndex(activePopupRank != nil ? 100 : 10)
            
            // Hàng công tắc nhỏ đặt ngay dưới A -> K (áp dụng cho tất cả các trò)
            HStack(spacing: 6) {
                CompactMiniSwitch(
                    title: "A➔K",
                    isOn: $viewModel.isRankOnlyMode,
                    activeColor: .blue
                )
                
                CompactMiniSwitch(
                    title: "Giữ vuốt ♥ ♦ ♣ ♠",
                    isOn: $isSwipeSuitEnabled,
                    activeColor: .purple
                )
                
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .zIndex(activePopupRank != nil ? 100 : 10)
    }
}

// MARK: - Floating 4-Suit Popup View (♥ ♦ ♣ ♠)
private struct SuitSwipePopupView: View {
    let rank: Rank
    let suits: [Suit]
    let hoveredSuit: Suit?
    let ownerLookup: (Suit) -> String?
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(suits) { suit in
                let owner = ownerLookup(suit)
                let isUsed = (owner != nil)
                let isSelected = (hoveredSuit == suit && !isUsed)
                
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        Text(rank.displaySymbol)
                            .font(.system(size: isSelected ? 14 : 12, weight: .black))
                            .foregroundColor(
                                isSelected ? .white : (suit.isRed ? .red : .primary)
                            )
                        Text(suit.rawValue)
                            .font(.system(size: isSelected ? 24 : 21, weight: .bold))
                            .foregroundColor(
                                isSelected ? .white : (suit.isRed ? .red : .primary)
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        isSelected
                        ? (suit.isRed ? Color.red : Color.blue)
                        : (isUsed ? Color.gray.opacity(0.18) : Color(.secondarySystemBackground))
                    )
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected ? Color.white.opacity(0.9) : Color.gray.opacity(0.25),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .scaleEffect(isSelected ? 1.12 : 1.0)
                    .offset(y: isSelected ? -4 : 0)
                    .opacity(isUsed ? 0.42 : 1.0)
                    .animation(.spring(response: 0.14, dampingFraction: 0.78), value: isSelected)
                    
                    if let owner = owner {
                        Text(shortOwnerBadge(owner))
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.gray)
                            .clipShape(Capsule())
                            .offset(x: 2, y: -3)
                    }
                }
            }
        }
        .padding(5)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.purple.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.24), radius: 10, x: 0, y: 4)
    }
    
    private func shortOwnerBadge(_ name: String) -> String {
        if name.contains("Tụ ") { return name.replacingOccurrences(of: "Tụ ", with: "") }
        if name.contains("Nhóm ") { return name.replacingOccurrences(of: "Nhóm ", with: "") }
        if name == "Bài chung" { return "BC" }
        return String(name.prefix(2))
    }
}

// MARK: - Visual Style of A->K Key
private struct RankButtonVisual: View {
    let rank: Rank
    let isPressed: Bool
    let isPopupOpen: Bool
    let showSwipeHint: Bool
    
    var textColor: Color {
        if rank == .ace { return .red }
        if rank == .jack || rank == .queen || rank == .king { return .blue }
        return .primary
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(rank.displaySymbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isPopupOpen ? .purple : textColor)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    isPopupOpen
                    ? Color.purple.opacity(0.14)
                    : (isPressed ? Color.blue.opacity(0.10) : Color(.systemBackground))
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isPopupOpen ? Color.purple : (isPressed ? Color.blue.opacity(0.6) : Color.gray.opacity(0.3)),
                            lineWidth: (isPopupOpen || isPressed) ? 2 : 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
                .scaleEffect(isPressed && !isPopupOpen ? 0.96 : 1.0)
                .animation(.easeOut(duration: 0.08), value: isPressed)
            
            if showSwipeHint {
                Text("♥♠")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.55))
                    .padding(.top, 3)
                    .padding(.trailing, 4)
            }
        }
    }
}

struct CardButton: View {
    let card: Card
    let owner: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 1) {
                    Text(card.rank.displaySymbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(card.suit.isRed ? .red : .black)
                    
                    Text(card.suit.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(card.suit.isRed ? .red : .black)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(owner != nil ? Color.gray.opacity(0.2) : Color.white)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(owner != nil ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: owner != nil ? 1.5 : 1)
                )
                .opacity(owner != nil ? 0.6 : 1.0)
                
                // Badge of current owner (Tụ 1, Tụ 2, Bài chung...)
                if let owner = owner {
                    Text(shortOwner(owner))
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .offset(x: 2, y: -4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(owner != nil) // Locked when already chosen! Tap card on mat to remove
    }
    
    private func shortOwner(_ name: String) -> String {
        if name.contains("Tụ ") {
            return name.replacingOccurrences(of: "Tụ ", with: "")
        }
        if name.contains("Nhóm ") {
            return name.replacingOccurrences(of: "Nhóm ", with: "")
        }
        if name == "Bài chung" { return "BC" }
        return String(name.prefix(2))
    }
}
