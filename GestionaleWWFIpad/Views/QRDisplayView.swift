//
//  QRDisplayView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRDisplayView: View {
    let poi: POI
    @Environment(\.dismiss) private var dismiss

    var qrImage: UIImage {
        generateQR(from: poi.qrPayload)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Text("QR Code da stampare")
                    .font(.headline)

                // QR Code
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 6)

                VStack(spacing: 6) {
                    Text(poi.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(poi.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(poi.qrPayload)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Condividi
                ShareLink(
                    item: Image(uiImage: qrImage),
                    preview: SharePreview(
                        "QR – \(poi.name)",
                        image: Image(uiImage: qrImage)
                    )
                ) {
                    Label("Esporta / Stampa QR", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("WWFGreen"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    private func generateQR(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard
            let ciImage = filter.outputImage,
            let cgImage = context.createCGImage(
                ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
                from: ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10)).extent
            )
        else {
            return UIImage(systemName: "qrcode") ?? UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}