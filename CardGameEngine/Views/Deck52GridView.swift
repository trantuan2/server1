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

// MARK: - PreferenceKey tracking exact frames of A->K keys in shared keypad space
private struct RankKeyFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Rank: CGRect] = [:]
    static func reduce(value: inout [Rank: CGRect], nextValue: () -> [Rank: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
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

// MARK: - Rank-Only Keypad (A -> K for ALL games, with Press-Hold + Swipe Suit Picker ♥ ♦ ♣ ♠)
public struct RankOnlyGridView: View {
    @ObservedObject var viewModel: GameViewModel
    @AppStorage("server1_rank_swipe_suit_enabled") private var isSwipeSuitEnabled: Bool = true
    
    let row1: [Rank] = [.ace, .two, .three, .four, .five]
    let row2: [Rank] = [.six, .seven, .eight, .nine, .ten]
    let row3: [Rank] = [.jack, .queen, .king]
    
    // Thứ tự 4 chất trên popup nổi (trái -> phải)
    private let popupSuits: [Suit] = [.hearts, .diamonds, .clubs, .spades]
    
    @State private var keyFrames: [Rank: CGRect] = [:]
    @State private var keypadWidth: CGFloat = 0
    @State private var pressedRank: Rank? = nil
    @State private var activePopupRank: Rank? = nil
    @State private var hoveredSuit: Suit? = nil
    @State private var dragStartLocation: CGPoint? = nil
    @State private var currentDragLocation: CGPoint? = nil
    @State private var holdWorkItem: DispatchWorkItem? = nil
    
    private let holdDelay: TimeInterval = 0.18
    private let popupHeight: CGFloat = 60
    private let popupGapAboveKey: CGFloat = 10
    
    public var body: some View {
        VStack(spacing: 6) {
            // Row 1: A, 2, 3, 4, 5
            HStack(spacing: 6) {
                ForEach(row1) { rank in
                    rankKeyCell(rank)
                }
            }
            
            // Row 2: 6, 7, 8, 9, 10
            HStack(spacing: 6) {
                ForEach(row2) { rank in
                    rankKeyCell(rank)
                }
            }
            
            // Row 3: J, Q, K
            HStack(spacing: 6) {
                ForEach(row3) { rank in
                    rankKeyCell(rank)
                }
            }
            
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
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .onAppear { keypadWidth = geo.size.width }
                    .onChange(of: geo.size.width) { newWidth in keypadWidth = newWidth }
            }
        )
        .coordinateSpace(name: "rankKeypadSpace")
        .onPreferenceChange(RankKeyFramePreferenceKey.self) { frames in
            keyFrames = frames
        }
        .overlay(alignment: .topLeading) {
            if let popupRank = activePopupRank, let keyRect = keyFrames[popupRank] {
                let rect = popupRect(for: keyRect)
                SuitSwipePopupView(
                    rank: popupRank,
                    suits: popupSuits,
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
    }
    
    // MARK: - Single Rank Key Cell with Unified Press / Hold / Swipe-Up Gesture
    @ViewBuilder
    private func rankKeyCell(_ rank: Rank) -> some View {
        let isPressed = (pressedRank == rank)
        let isPopupOpen = (activePopupRank == rank)
        
        RankButtonVisual(
            rank: rank,
            isPressed: isPressed,
            isPopupOpen: isPopupOpen,
            showSwipeHint: isSwipeSuitEnabled
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: RankKeyFramePreferenceKey.self,
                    value: [rank: geo.frame(in: .named("rankKeypadSpace"))]
                )
            }
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("rankKeypadSpace"))
                .onChanged { value in
                    handleDragChanged(for: rank, value: value)
                }
                .onEnded { value in
                    handleDragEnded(for: rank, value: value)
                }
        )
    }
    
    // MARK: - Gesture Handlers
    private func handleDragChanged(for rank: Rank, value: DragGesture.Value) {
        currentDragLocation = value.location
        if pressedRank == nil {
            pressedRank = rank
            dragStartLocation = value.location
            hoveredSuit = nil
            
            if isSwipeSuitEnabled {
                holdWorkItem?.cancel()
                let work = DispatchWorkItem {
                    guard self.pressedRank == rank, self.activePopupRank == nil else { return }
                    self.openSuitPopup(for: rank, currentLocation: self.currentDragLocation ?? value.location)
                }
                holdWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay, execute: work)
            }
            return
        }
        
        guard pressedRank == rank else { return }
        
        // Nếu bật vuốt chất và người dùng kéo ngón tay hướng lên trên >= 18pt, mở popup ngay tức thì
        if isSwipeSuitEnabled && activePopupRank == nil, let start = dragStartLocation {
            let dy = value.location.y - start.y
            let dx = abs(value.location.x - start.x)
            if dy <= -18 {
                holdWorkItem?.cancel()
                holdWorkItem = nil
                openSuitPopup(for: rank, currentLocation: value.location)
                return
            } else if dy > 24 || dx > 34 {
                // Kéo lệch mạnh ra ngoài trước khi mở popup -> hủy hẹn giờ giữ
                holdWorkItem?.cancel()
                holdWorkItem = nil
            }
        }
        
        // Nếu popup 4 chất đang mở -> cập nhật chất đang vuốt vào
        if activePopupRank == rank, let keyRect = keyFrames[rank] {
            let newSuit = suitAtLocation(value.location, for: rank, keyRect: keyRect)
            if newSuit != hoveredSuit {
                hoveredSuit = newSuit
                if newSuit != nil {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        }
    }
    
    private func handleDragEnded(for rank: Rank, value: DragGesture.Value) {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        
        guard pressedRank == rank else {
            resetGestureState()
            return
        }
        
        if activePopupRank == rank {
            // Đang mở popup chọn chất: nếu đang trỏ vào chất hợp lệ (chưa bị chia) -> chọn lá đó
            let finalSuit: Suit?
            if let keyRect = keyFrames[rank] {
                finalSuit = suitAtLocation(value.location, for: rank, keyRect: keyRect)
            } else {
                finalSuit = hoveredSuit
            }
            
            if let suit = finalSuit {
                let card = Card(rank: rank, suit: suit)
                if viewModel.cardOwner(card) == nil {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.onCardTapped(card)
                }
            }
        } else {
            // Chạm nhanh bình thường: chỉ kích hoạt nếu thả tay trong vùng nút (mở rộng nhẹ 16pt)
            if let keyRect = keyFrames[rank] {
                if keyRect.insetBy(dx: -16, dy: -16).contains(value.location) {
                    viewModel.onRankTapped(rank)
                }
            } else {
                viewModel.onRankTapped(rank)
            }
        }
        
        resetGestureState()
    }
    
    private func openSuitPopup(for rank: Rank, currentLocation: CGPoint) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.16, dampingFraction: 0.82)) {
            activePopupRank = rank
        }
        if let keyRect = keyFrames[rank] {
            hoveredSuit = suitAtLocation(currentLocation, for: rank, keyRect: keyRect)
        }
    }
    
    private func resetGestureState() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        pressedRank = nil
        dragStartLocation = nil
        currentDragLocation = nil
        hoveredSuit = nil
        withAnimation(.easeOut(duration: 0.12)) {
            activePopupRank = nil
        }
    }
    
    // MARK: - Popup Geometry & Hit-Test Helpers
    private func popupRect(for keyRect: CGRect) -> CGRect {
        let effectiveWidth = keypadWidth > 0 ? keypadWidth : 360
        let width: CGFloat = min(236, max(196, effectiveWidth - 12))
        let minX: CGFloat = 6
        let maxX: CGFloat = max(minX, effectiveWidth - width - 6)
        let originX = min(max(minX, keyRect.midX - width / 2), maxX)
        let originY = keyRect.minY - popupHeight - popupGapAboveKey
        return CGRect(x: originX, y: originY, width: width, height: popupHeight)
    }
    
    private func suitAtLocation(_ point: CGPoint, for rank: Rank, keyRect: CGRect) -> Suit? {
        let rect = popupRect(for: keyRect)
        // Khi ngón tay vẫn còn nằm trong thân phím (chưa vuốt lên hướng thanh chất) -> chưa chọn chất nào (thả tay = hủy an toàn)
        guard point.y <= keyRect.minY + 4 else { return nil }
        // Vùng nhận rộng hơn một chút ở phía trên & hai bên để vuốt 1 tay cực nhạy mà không bị che tầm nhìn
        guard point.y >= rect.minY - 44 else { return nil }
        guard point.x >= rect.minX - 20 && point.x <= rect.maxX + 20 else { return nil }
        
        let slotWidth = rect.width / CGFloat(popupSuits.count)
        let rawIndex = Int(floor((point.x - rect.minX) / slotWidth))
        let clampedIndex = min(max(0, rawIndex), popupSuits.count - 1)
        let suit = popupSuits[clampedIndex]
        
        // Không cho chọn trùng lá đã có người cầm
        if viewModel.cardOwner(Card(rank: rank, suit: suit)) != nil {
            return nil
        }
        return suit
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
