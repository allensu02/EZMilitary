import SwiftUI
import VisionKit

struct ContentView: View {
    @State private var scanning = false
    @State private var scanResult: String?
    @State private var scannerController: DataScannerViewController?
    
    
    var body: some View {
        VStack {
            if scanning {
                DataScannerView(
                    recognizedItems: .constant([]),
                    recognizedDataType: .text(),
                    recognizedText: { text in
                        for (team, villages) in teamMappings {
                            if villages.contains(text) {
                                scanResult = "\(text) 屬於 \(team)"
                                scanning = false  // Stop scanning when match found
                                scannerController?.stopScanning()
                                return
                            }
                        }
                        scanResult = "找不到 \(text)"
                    },
                    scannerController: $scannerController
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            if let result = scanResult {
                Text(result)
                    .padding()
                Button("繼續掃描") {
                    scanResult = nil
                    scanning = true
                    try? scannerController?.startScanning()
                }
                .padding()
            }
            
            if scanResult == nil {
                Button(scanning ? "停止掃描" : "開始掃描") {
                    scanning.toggle()
                }
                .padding()
            }
        }
    }
}

struct DataScannerView: UIViewControllerRepresentable {
    @Binding var recognizedItems: [RecognizedItem]
    let recognizedDataType: DataScannerViewController.RecognizedDataType
    let recognizedText: (String) -> Void
    @Binding var scannerController: DataScannerViewController?
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [recognizedDataType],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        scannerController = vc
        return vc
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        try? uiViewController.startScanning()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(recognizedText: recognizedText)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let recognizedText: (String) -> Void
        
        init(recognizedText: @escaping (String) -> Void) {
            self.recognizedText = recognizedText
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for case let .text(text) in items {
                recognizedText(text.transcript)
            }
        }
    }
}
