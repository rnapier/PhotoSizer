//
//  ContentView.swift
//  PhotoSizer
//
//  Created by Rob Napier on 5/11/20.
//  Copyright © 2020 Rob Napier. All rights reserved.
//

import SwiftUI

let targetSize = CGSize(width: 1080, height: 1920)

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
    @State var inputImage: UIImage?
    @State var jpegQuality: CGFloat = 0.85
    @State var qualitySliderValue: CGFloat = 0.85

    var outputImage: UIImage? {
        // Scale the image to fit inside of the target size.
        guard let input = inputImage else { return nil }

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

    @State var showImagePicker: Bool = false

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

    var body: some View {
        ZStack {
            VStack {
                VStack(alignment: .leading) {
                    Text("Quality: \(jpegQuality, specifier: "%.2f")")
                    Slider(value: $qualitySliderValue, in: (0.6)...(1.0))
                }
                .padding()

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

                        Group {
                            if outputImage != nil {
                                Image(uiImage: outputImage!)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                        outputCaption
                    }
                }
            }
            if (showImagePicker) {
                ImagePickerView(isShown: $showImagePicker, image: $inputImage)
            }
        }
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

