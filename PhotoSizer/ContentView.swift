//
//  ContentView.swift
//  PhotoSizer
//
//  Created by Rob Napier on 5/11/20.
//  Copyright © 2020 Rob Napier. All rights reserved.
//

import SwiftUI
import Combine

extension Int {
    var formattedByteCount: String {
        ByteCountFormatter().string(fromByteCount:Int64(self))
    }
}

extension UIImage {
    var rawByteCount: Int {
        (cgImage?.dataProvider?.data as Data?)?.count ?? 0
    }
}

struct ContentView: View {
    @ObservedObject var model = Model()

    var inputImage: UIImage? { model.inputImage }

    @State var qualitySliderValue: CGFloat = 0.85
    var jpegQuality: CGFloat { model.jpegQuality }

    var targetSize: CGSize { model.targetSize }

    var outputImage: UIImage? { model.outputImage }

    @State var showImagePicker: Bool = false

    @State var showOutputFullScreen: Bool = false

    func jpegByteCount(_ image: UIImage) -> Int {
        image.jpegData(compressionQuality: jpegQuality)?.count ?? 0
    }

    func jpegByteCountString(_ image: UIImage) -> String {
        jpegByteCount(image).formattedByteCount
    }

    var inputCaption: some View {
        if let image = inputImage {
            let size = image.size
            return Text("\(size.width, specifier: "%.0f")⨯\(size.height, specifier: "%.0f") - \(jpegByteCountString(image)) (\(image.rawByteCount.formattedByteCount))")
        } else {
            return Text("---")
        }
    }

    var outputCaption: some View {
        if let input = inputImage, let output = outputImage {
            let inputByteCount = jpegByteCount(input)
            let outputByteCount = jpegByteCount(output)
            let size = output.size
            let ratio: String
            if inputByteCount == 0 {
                ratio = "--%"
            } else {
                let f = NumberFormatter()
                f.maximumFractionDigits = 0
                f.numberStyle = .percent
                ratio = f.string(from: NSNumber(value:
                    Double(outputByteCount)/Double(inputByteCount)))!
            }

            return Text("\(size.width, specifier: "%.0f")⨯\(size.height, specifier: "%.0f") - \(jpegByteCountString(output)) (\(ratio))")
        }
        else {
            return Text("---")
        }
    }

    var outputView: some View {
        Group {
            if outputImage != nil {
                Image(uiImage: outputImage!)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        self.showOutputFullScreen.toggle()
                }
            } else {
                VStack {
                    Spacer()
                    Text("Output Image")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .aspectRatio(targetSize, contentMode: .fit)
        .border(Color.black).padding(.horizontal)
        .frame(maxWidth: .infinity)
    }

    var qualitySliderView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Quality: \(qualitySliderValue, specifier: "%.2f")")
            Slider(value: $qualitySliderValue,
                   in: (0.1)...(1.0),
                   step: 0.05,
                   onEditingChanged: { editing in
                    if !editing {
                        self.model.jpegQuality = self.qualitySliderValue
                    }
            })
        }
        .padding()
    }

    var body: some View {
        ZStack {
            VStack {
                qualitySliderView

                HStack {
                    VStack{
                        Button(action: {self.showImagePicker.toggle()}) {
                            if inputImage != nil {
                                Image(uiImage: inputImage!)
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                            } else {
                                VStack {
                                    Spacer()
                                    Text("Tap to select image")
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .aspectRatio(targetSize, contentMode: .fit)
                        .border(Color.black).padding(.horizontal)

                        inputCaption
                    }

                    Image(systemName: "arrow.right")

                    VStack{
                        outputView

                        outputCaption
                    }
                }
            }
            if (showImagePicker) {
                ImagePickerView(isShown: $showImagePicker, image: $model.inputImage)
            }
            if (showOutputFullScreen) {
                ZStack {
                    Color.white
                    VStack {
                        qualitySliderView
                        outputView
                    }
                }
            }
        }
    }
}

private func resize(image: UIImage?, to targetSize: CGSize) -> UIImage? {
    // Scale the image to fit inside of the target size.
    guard let input = image else { return nil }

    let scaleHeight = targetSize.height / input.size.height
    let scaleWidth = targetSize.width / input.size.width

    // Scale enough that both height and width fit
    let scale = min(scaleHeight, scaleWidth)

    if scale >= 1 { return input }   // Don't scale up

    let size = CGSize(width: input.size.width * scale, height: input.size.height * scale)

    // Draw the pixels at scale 1, not based on the current screen
    UIGraphicsBeginImageContextWithOptions(size, true, 1)
    defer { UIGraphicsEndImageContext() }
    input.draw(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    return UIGraphicsGetImageFromCurrentImageContext()
}

private func compress(image: UIImage?, quality: CGFloat) -> UIImage? {
    guard let input = image,
        let data = input.jpegData(compressionQuality: quality)
        else { return nil }
    return UIImage(data: data)
}

class Model: ObservableObject {
    @Published var inputImage: UIImage?
    @Published var outputImage: UIImage?
    @Published var jpegQuality: CGFloat = 0.85

    let targetSize = CGSize(width: 1080, height: 1920)

    private var observers: Set<AnyCancellable> = []

    init() {
        $inputImage.combineLatest($jpegQuality)
            .map { [targetSize] (image, quality) in compress(image: resize(image: image, to: targetSize),
                                                             quality: quality) }
            .assign(to: \.outputImage, on: self)
            .store(in: &observers)
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// Based on https://www.iosapptemplates.com/blog/swiftui/photo-camera-swiftui

struct ImagePickerView {

    /// MARK: - Properties
    @Binding var isShown: Bool
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator {
        return Coordinator(isShown: $isShown, image: $image)
    }
}

extension ImagePickerView: UIViewControllerRepresentable {
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePickerView>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController,
                                context: UIViewControllerRepresentableContext<ImagePickerView>) {

    }
}

class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    @Binding var isCoordinatorShown: Bool
    @Binding var imageInCoordinator: UIImage?
    init(isShown: Binding<Bool>, image: Binding<UIImage?>) {
        _isCoordinatorShown = isShown
        _imageInCoordinator = image
    }
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let unwrapImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage else { return }
        imageInCoordinator = unwrapImage
        isCoordinatorShown = false
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        isCoordinatorShown = false
    }
}

