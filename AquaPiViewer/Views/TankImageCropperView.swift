import AppKit
import SwiftUI

struct TankImageCropperView: View {
    let image: NSImage
    let onCancel: () -> Void
    let onSave: (TankImageCrop) -> Void

    @State private var zoom = 1.0
    @State private var offset = CGSize.zero
    @State private var dragStartOffset: CGSize?
    @State private var cropFrameSize = CGSize.zero

    private let minimumZoom = 1.0
    private let maximumZoom = 3.0
    private let cropAspectRatio = 16.0 / 9.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Crop Tank Photo")
                .font(.headline)

            cropArea

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "minus.magnifyingglass")
                    Slider(value: $zoom, in: minimumZoom...maximumZoom)
                        .onChange(of: zoom) {
                            offset = clampedOffset(offset, in: cropFrameSize, zoom: zoom)
                        }
                    Image(systemName: "plus.magnifyingglass")
                }
                Text("Drag to position the photo inside the 16:9 frame.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                Button("Save") {
                    let imageDisplaySize = displayedImageSize(in: cropFrameSize, zoom: zoom)
                    onSave(
                        TankImageCrop(
                            cropFrameSize: cropFrameSize,
                            imageDisplaySize: imageDisplaySize,
                            offset: offset
                        )
                    )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(cropFrameSize == .zero)
            }
        }
        .padding(20)
        .frame(width: 760, height: 560)
        .onPreferenceChange(CropFrameSizeKey.self) { size in
            cropFrameSize = size
            offset = clampedOffset(offset, in: size, zoom: zoom)
        }
    }

    private var cropArea: some View {
        GeometryReader { proxy in
            let cropSize = proxy.size
            let imageSize = displayedImageSize(in: cropSize, zoom: zoom)

            ZStack {
                Color.black

                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .offset(offset)

                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
            }
            .frame(width: cropSize.width, height: cropSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let startOffset = dragStartOffset ?? offset
                        if dragStartOffset == nil {
                            dragStartOffset = startOffset
                        }

                        let proposedOffset = CGSize(
                            width: startOffset.width + value.translation.width,
                            height: startOffset.height + value.translation.height
                        )
                        offset = clampedOffset(proposedOffset, in: cropSize, zoom: zoom)
                    }
                    .onEnded { _ in
                        dragStartOffset = nil
                    }
            )
            .preference(key: CropFrameSizeKey.self, value: cropSize)
        }
        .aspectRatio(cropAspectRatio, contentMode: .fit)
        .frame(height: 405)
    }

    private func displayedImageSize(in cropSize: CGSize, zoom: Double) -> CGSize {
        guard cropSize.width > 0, cropSize.height > 0, image.size.width > 0, image.size.height > 0 else {
            return .zero
        }

        let baseScale = max(cropSize.width / image.size.width, cropSize.height / image.size.height)
        let displayScale = baseScale * zoom

        return CGSize(
            width: image.size.width * displayScale,
            height: image.size.height * displayScale
        )
    }

    private func clampedOffset(_ proposedOffset: CGSize, in cropSize: CGSize, zoom: Double) -> CGSize {
        let imageSize = displayedImageSize(in: cropSize, zoom: zoom)
        guard imageSize != .zero else {
            return .zero
        }

        let maximumX = max(0, (imageSize.width - cropSize.width) / 2)
        let maximumY = max(0, (imageSize.height - cropSize.height) / 2)

        return CGSize(
            width: min(max(proposedOffset.width, -maximumX), maximumX),
            height: min(max(proposedOffset.height, -maximumY), maximumY)
        )
    }
}

private struct CropFrameSizeKey: PreferenceKey {
    static var defaultValue = CGSize.zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

#Preview {
    TankImageCropperView(
        image: NSImage(size: CGSize(width: 1200, height: 900)),
        onCancel: {},
        onSave: { _ in }
    )
}
