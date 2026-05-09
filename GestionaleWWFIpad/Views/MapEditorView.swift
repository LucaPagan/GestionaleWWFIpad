import SwiftUI
import SwiftData
import UIKit

// MARK: - MapEditorView

struct MapEditorView: View {
    @Environment(\.modelContext) private var context
    @Query private var allPOIs: [POI]

    @State private var showPOIEditor    = false
    @State private var pendingPosition: CGPoint? = nil
    @State private var selectedPOI: POI? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // ── Mappa scrollabile nativa ──
                InteractiveMapView(
                    imageName: "astroni_map",
                    pois: allPOIs,
                    selectedPOIId: selectedPOI?.id,
                    onTapMap: { normalizedPoint in
                        pendingPosition = normalizedPoint
                        selectedPOI = nil
                        showPOIEditor = true
                    },
                    onTapPOI: { poi in
                        selectedPOI = poi
                        showPOIEditor = true
                    }
                )
                .ignoresSafeArea()

                // ── HUD overlay ──
                VStack {
                    HStack {
                        Label("Tap per aggiungere un POI", systemImage: "hand.tap.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(Color("WWFGreen"))
                            Text("\(allPOIs.count) POI")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()

                    // Legenda tipi POI
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(POIType.allCases, id: \.self) { type in
                                HStack(spacing: 5) {
                                    Image(systemName: type.icon)
                                        .font(.caption2)
                                        .foregroundColor(Color(hex: type.color) ?? .green)
                                    Text(type.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Editor Mappa")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPOIEditor, onDismiss: {
                pendingPosition = nil
                selectedPOI = nil
            }) {
                if let existing = selectedPOI {
                    POIEditorView(
                        mode: .edit(existing),
                        onSave: { handleSave($0) },
                        onDelete: { handleDelete($0) }
                    )
                    .presentationDetents([.medium, .large])
                } else if let pos = pendingPosition {
                    POIEditorView(
                        mode: .create(x: pos.x, y: pos.y),
                        onSave: { handleSave($0) },
                        onDelete: nil
                    )
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }

    // MARK: - Handlers

    private func handleSave(_ poi: POI) {
        let isNew = !allPOIs.contains(where: { $0.id == poi.id })
        if isNew { context.insert(poi) }
        try? context.save()
        showPOIEditor = false
        selectedPOI = nil
        pendingPosition = nil
    }

    private func handleDelete(_ poi: POI) {
        context.delete(poi)
        try? context.save()
        showPOIEditor = false
        selectedPOI = nil
        pendingPosition = nil
    }
}

// MARK: - InteractiveMapView (UIScrollView wrapper)

struct InteractiveMapView: UIViewRepresentable {
    let imageName: String
    let pois: [POI]
    var selectedPOIId: UUID?
    let onTapMap: (CGPoint) -> Void
    let onTapPOI: (POI) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .normal
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 8.0

        // Container: contiene mappa + marker
        let container = UIView()
        container.backgroundColor = .clear
        context.coordinator.containerView = container
        scrollView.addSubview(container)

        // Immagine mappa
        guard let img = UIImage(named: imageName) else { return scrollView }
        let imageView = UIImageView(image: img)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        container.addSubview(imageView)
        context.coordinator.imageView = imageView

        // Tap gesture sul container
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        container.addGestureRecognizer(tap)
        context.coordinator.tapGesture = tap

        DispatchQueue.main.async {
            context.coordinator.setupLayout(in: scrollView, image: img)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let container = context.coordinator.containerView,
              let imageView = context.coordinator.imageView else { return }

        let imageSize = imageView.frame.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let currentScale = scrollView.zoomScale

        // Rimuovi tutti i marker precedenti
        container.subviews
            .filter { $0 is EditorPOIMarkerView }
            .forEach { $0.removeFromSuperview() }

        // Calcola posizioni per collision detection
        let positions: [(poi: POI, center: CGPoint)] = pois.map { poi in
            let cx = poi.x * imageSize.width
            let cy = poi.y * imageSize.height
            return (poi, CGPoint(x: cx, y: cy))
        }

        // Aggiungi marker aggiornati
        for (index, entry) in positions.enumerated() {
            let poi = entry.poi
            let center = entry.center

            // Dimensione base del cerchio in punti-mappa (verrà contro-scalata dallo scroll)
            // Target: ~36pt a schermo indipendentemente dallo zoom
            let targetScreenDiameter: CGFloat = 40
            let markerDiameter = targetScreenDiameter / currentScale

            // Controlla se c'è un POI vicino per offset etichetta
            let labelAbove = shouldPlaceLabelAbove(
                index: index,
                positions: positions,
                markerDiameter: markerDiameter
            )

            let markerView = EditorPOIMarkerView(
                poi: poi,
                isSelected: poi.id == selectedPOIId,
                markerDiameter: markerDiameter,
                zoomScale: currentScale,
                labelAbove: labelAbove
            )

            // Frame nel map-space (include area etichetta)
            let labelHeight: CGFloat = 18 / currentScale
            let labelGap: CGFloat = 4 / currentScale
            let totalW = max(markerDiameter * 3, 80 / currentScale)
            let totalH = markerDiameter + labelGap + labelHeight + (labelAbove ? labelHeight + labelGap : 0)

            markerView.frame = CGRect(
                x: center.x - totalW / 2,
                y: center.y - markerDiameter / 2 - (labelAbove ? labelHeight + labelGap : 0),
                width: totalW,
                height: totalH
            )

            markerView.onTap = { [context] in
                context.coordinator.parent.onTapPOI(poi)
            }

            container.addSubview(markerView)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: InteractiveMapView
        weak var containerView: UIView?
        weak var imageView: UIImageView?
        weak var tapGesture: UITapGestureRecognizer?

        init(_ parent: InteractiveMapView) {
            self.parent = parent
        }

        // MARK: Layout iniziale

        func setupLayout(in scrollView: UIScrollView, image: UIImage) {
            guard let container = containerView,
                  let imageView = imageView else { return }

            let screenW = scrollView.bounds.width
            let screenH = scrollView.bounds.height
            let imgRatio = image.size.height / image.size.width

            let mapW = screenW
            let mapH = mapW * imgRatio

            imageView.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)
            container.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)
            scrollView.contentSize = CGSize(width: mapW, height: mapH)

            let scaleToFitH = screenH / mapH
            let initialScale = min(1.0, scaleToFitH)
            scrollView.minimumZoomScale = max(0.3, min(initialScale, 0.8))
            scrollView.zoomScale = initialScale

            let scaledH = mapH * initialScale
            let offsetY = max(0, scaledH - screenH)
            scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
        }

        // MARK: UIScrollViewDelegate

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            containerView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
            // Ri-disegna i marker con la nuova scala
            // Forza un updateUIView passando attraverso il parent
            if let container = containerView, let imageView = imageView {
                let imageSize = imageView.frame.size
                guard imageSize.width > 0 else { return }

                let currentScale = scrollView.zoomScale
                let targetScreenDiameter: CGFloat = 40
                let markerDiameter = targetScreenDiameter / currentScale

                var positions: [(poi: POI, center: CGPoint)] = parent.pois.map { poi in
                    let cx = poi.x * imageSize.width
                    let cy = poi.y * imageSize.height
                    return (poi, CGPoint(x: cx, y: cy))
                }

                container.subviews
                    .filter { $0 is EditorPOIMarkerView }
                    .forEach { $0.removeFromSuperview() }

                for (index, entry) in positions.enumerated() {
                    let poi = entry.poi
                    let center = entry.center

                    let labelAbove = shouldPlaceLabelAbove(
                        index: index,
                        positions: positions,
                        markerDiameter: markerDiameter
                    )

                    let markerView = EditorPOIMarkerView(
                        poi: poi,
                        isSelected: poi.id == parent.selectedPOIId,
                        markerDiameter: markerDiameter,
                        zoomScale: currentScale,
                        labelAbove: labelAbove
                    )

                    let labelHeight: CGFloat = 18 / currentScale
                    let labelGap: CGFloat = 4 / currentScale
                    let totalW = max(markerDiameter * 3, 80 / currentScale)

                    markerView.frame = CGRect(
                        x: center.x - totalW / 2,
                        y: center.y - markerDiameter / 2 - (labelAbove ? labelHeight + labelGap : 0),
                        width: totalW,
                        height: markerDiameter + labelGap + labelHeight + (labelAbove ? labelHeight + labelGap : 0)
                    )

                    markerView.onTap = { [weak self] in
                        self?.parent.onTapPOI(poi)
                    }

                    container.addSubview(markerView)
                }
            }
        }

        // Non necessario: usiamo la free-function globale shouldPlaceLabelAbove

        func scrollViewDidScroll(_ scrollView: UIScrollView) {}

        private func centerContent(in scrollView: UIScrollView) {
            guard let container = containerView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = container.frame

            frameToCenter.origin.x = frameToCenter.size.width < boundsSize.width
                ? (boundsSize.width - frameToCenter.size.width) / 2 : 0
            frameToCenter.origin.y = frameToCenter.size.height < boundsSize.height
                ? (boundsSize.height - frameToCenter.size.height) / 2 : 0
            container.frame = frameToCenter
        }

        // MARK: Tap handler

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let imageView = imageView else { return }
            let location = gesture.location(in: imageView)
            let normX = location.x / imageView.frame.width
            let normY = location.y / imageView.frame.height
            guard normX >= 0, normX <= 1, normY >= 0, normY <= 1 else { return }
            parent.onTapMap(CGPoint(x: normX, y: normY))
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf other: UIGestureRecognizer
        ) -> Bool {
            if gestureRecognizer === tapGesture,
               other is UIPanGestureRecognizer { return true }
            return false
        }
    }
}

// MARK: - Collision helper (free function)

private func shouldPlaceLabelAbove(
    index: Int,
    positions: [(poi: POI, center: CGPoint)],
    markerDiameter: CGFloat
) -> Bool {
    let current = positions[index].center
    // Soglia di prossimità: se un altro marker è entro 2.5x il diametro sotto di me,
    // metto l'etichetta sopra per evitare sovrapposizione
    let proximityThreshold = markerDiameter * 2.5
    for (i, other) in positions.enumerated() {
        guard i != index else { continue }
        let dx = abs(other.center.x - current.x)
        let dy = other.center.y - current.y   // positivo se other è più in basso
        if dx < proximityThreshold && dy > 0 && dy < proximityThreshold {
            return true  
        }
    }
    return false
}

// MARK: - EditorPOIMarkerView

/// Marker UIKit con dimensione adattiva allo zoom usato nell'Editor Mappa.
/// Vive nello spazio dell'immagine (map-space) ma le sue dimensioni
/// vengono calcolate in screen-space e poi divise per lo zoom corrente,
/// così il risultato visivo è sempre costante a ~40pt sullo schermo.
final class EditorPOIMarkerView: UIView {
    var onTap: (() -> Void)?

    private let poi: POI
    private let isSelected: Bool
    private let markerDiameter: CGFloat   // in map-space (= targetPt / zoomScale)
    private let zoomScale: CGFloat
    private let labelAbove: Bool

    // Dimensioni fisse in screen-space
    private let targetScreenDiameter: CGFloat = 40
    private let targetLabelFontSize: CGFloat   = 10
    private let targetLabelPaddingH: CGFloat   = 6
    private let targetLabelPaddingV: CGFloat   = 3

    init(poi: POI, isSelected: Bool, markerDiameter: CGFloat, zoomScale: CGFloat, labelAbove: Bool) {
        self.poi = poi
        self.isSelected = isSelected
        self.markerDiameter = markerDiameter
        self.zoomScale = zoomScale
        self.labelAbove = labelAbove
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onTap?() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Centro del cerchio: orizzontalmente centrato nel rect,
        // verticalmente posizionato a metà del cerchio dal top (se etichetta è sopra) oppure dal top
        let circleCenterX = rect.midX
        let circleCenterY: CGFloat

        if labelAbove {
            // L'etichetta occupa la zona alta del rect
            let labelH = (targetLabelFontSize + targetLabelPaddingV * 2) / zoomScale
            let labelGap = 4 / zoomScale
            circleCenterY = labelH + labelGap + markerDiameter / 2
        } else {
            circleCenterY = markerDiameter / 2
        }

        let radius = markerDiameter / 2

        // ── Anello selezione ──
        if isSelected {
            let selectionPadding = 5 / zoomScale
            ctx.setStrokeColor(UIColor.systemYellow.cgColor)
            ctx.setLineWidth(2.5 / zoomScale)
            ctx.addArc(
                center: CGPoint(x: circleCenterX, y: circleCenterY),
                radius: radius + selectionPadding,
                startAngle: 0, endAngle: .pi * 2, clockwise: false
            )
            ctx.strokePath()
        }

        // ── Ombra cerchio ──
        ctx.setShadow(
            offset: CGSize(width: 0, height: 2 / zoomScale),
            blur: 4 / zoomScale,
            color: UIColor.black.withAlphaComponent(0.4).cgColor
        )

        // ── Cerchio colorato ──
        let fillColor = UIColor(Color(hex: poi.type.color) ?? .green)
        ctx.setFillColor(fillColor.cgColor)
        ctx.addArc(
            center: CGPoint(x: circleCenterX, y: circleCenterY),
            radius: radius,
            startAngle: 0, endAngle: .pi * 2, clockwise: false
        )
        ctx.fillPath()

        // Reset ombra
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // ── Bordo bianco sottile ──
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(1 / zoomScale)
        ctx.addArc(
            center: CGPoint(x: circleCenterX, y: circleCenterY),
            radius: radius - 0.5 / zoomScale,
            startAngle: 0, endAngle: .pi * 2, clockwise: false
        )
        ctx.strokePath()

        // ── Icona SF Symbol ──
        let iconPtSize = max(8, (targetScreenDiameter * 0.35) / zoomScale)
        let config = UIImage.SymbolConfiguration(pointSize: iconPtSize, weight: .semibold)
        if let icon = UIImage(systemName: poi.type.icon, withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) {
            let iconSize = icon.size
            let iconOrigin = CGPoint(
                x: circleCenterX - iconSize.width / 2,
                y: circleCenterY - iconSize.height / 2
            )
            icon.draw(in: CGRect(origin: iconOrigin, size: iconSize))
        }

        // ── Etichetta nome ──
        let labelFontSize = targetLabelFontSize / zoomScale
        let paddingH = targetLabelPaddingH / zoomScale
        let paddingV = targetLabelPaddingV / zoomScale
        let labelGap = 4 / zoomScale

        let font = UIFont.systemFont(ofSize: labelFontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let label = poi.name as NSString

        // Misura il testo e poi clampalo alla larghezza disponibile
        let maxLabelWidth = rect.width - paddingH * 2
        var labelSize = label.size(withAttributes: attrs)
        labelSize.width = min(labelSize.width, maxLabelWidth)

        let bgWidth = labelSize.width + paddingH * 2
        let bgHeight = labelSize.height + paddingV * 2

        let bgX = circleCenterX - bgWidth / 2

        let bgY: CGFloat
        if labelAbove {
            bgY = circleCenterY - radius - labelGap - bgHeight
        } else {
            bgY = circleCenterY + radius + labelGap
        }

        let bgRect = CGRect(x: bgX, y: bgY, width: bgWidth, height: bgHeight)

        // Background etichetta con blur simulato (colore semi-opaco)
        let cornerR = bgRect.height / 2
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: cornerR)

        // Ombra sull'etichetta
        ctx.setShadow(
            offset: CGSize(width: 0, height: 1 / zoomScale),
            blur: 3 / zoomScale,
            color: UIColor.black.withAlphaComponent(0.5).cgColor
        )
        UIColor.black.withAlphaComponent(0.72).setFill()
        bgPath.fill()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // Testo (clipped se necessario)
        let textRect = CGRect(
            x: bgRect.origin.x + paddingH,
            y: bgRect.origin.y + paddingV,
            width: labelSize.width,
            height: labelSize.height
        )
        label.draw(
            with: textRect,
            options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin],
            attributes: attrs,
            context: nil
        )
    }

    // Area di hit testing leggermente più grande del cerchio
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitRadius = (markerDiameter / 2) + 8
        let center = CGPoint(x: bounds.midX, y: markerDiameter / 2 + (labelAbove ? (18 / zoomScale + 4 / zoomScale) : 0))
        let dx = point.x - center.x
        let dy = point.y - center.y
        return (dx * dx + dy * dy) <= (hitRadius * hitRadius)
    }
}
