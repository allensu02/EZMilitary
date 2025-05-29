import SwiftUI
import VisionKit

struct ContentView: View {
    @State private var scanning = false
    @State private var scanResult: String?
    @State private var scannerController: DataScannerViewController?
    @State private var scanMode: ScanMode = .village
    @State private var transcriptText = ""
    @State private var extractedAddress: String?

    enum ScanMode {
        case village
        case transcript
    }

    private let testAddresses = [
        "收件地址：台中市北屯區松竹路二段123號",
        "病患資料\n姓名：王小明\n地址：臺中市西屯區文心路300號3樓之2\n電話：04-12345678",
        "台中市北區進化北路77巷5號\n住戶：李大明",
        "寄送至：台中市南區建國北路100號\n請於週一至週五配送",
        "雜亂的文字在這裡\n台中市西區美村路一段13號4樓\n更多雜亂的文字",
        "完全沒有地址的文字\n只有一些描述\n沒有台中市的地址"
    ]

    private func runAddressTests() {
        transcriptText = ""
        for (index, test) in testAddresses.enumerated() {
            transcriptText += "測試 #\(index + 1):\n"
            transcriptText += "輸入文字：\n\(test)\n"
            if let extracted = extractAddress(from: test) {
                transcriptText += "✅ 找到地址：\(extracted)\n"
            } else {
                transcriptText += "❌ 未找到地址\n"
            }
            transcriptText += "\n"
        }
        extractedAddress = extractAddress(from: transcriptText)
    }

    private func extractAddress(from text: String) -> String? {
        // For demonstration purposes, this will just return the first line that contains "台中市"
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.contains("台中市") || line.contains("臺中市") {
                return line
            }
        }
        return nil
    }

    var body: some View {
        VStack {
            Picker("掃描模式", selection: $scanMode) {
                Text("地區查詢").tag(ScanMode.village)
                Text("文字轉錄").tag(ScanMode.transcript)
            }
            .pickerStyle(.segmented)
            .padding()

            if scanning {
                DataScannerView(
                    recognizedItems: .constant([]),
                    recognizedDataType: .text(),
                    recognizedText: { text in
                        switch scanMode {
                        case .village:
                            for (team, villages) in teamMappings {
                                if villages.contains(text) {
                                    scanResult = "\(text) 屬於 \(team)"
                                    scanning = false
                                    scannerController?.stopScanning()
                                    return
                                }
                            }
                            scanResult = "找不到 \(text)"
                        case .transcript:
                            transcriptText += text + "\n"
                        }
                    },
                    scannerController: $scannerController
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if scanMode == .village {
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
            } else {
                ScrollView {
                    
                    TextEditor(text: $transcriptText)
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding()
                    
                    if let address = extractedAddress {
                        
                        VStack {
                            Text("偵測到地址：")
                                .font(.headline)
                                .padding(.top)
                            
                            Text(address)
                                .font(.title2)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                    }
                }

                HStack {
                    Button("清除文字") {
                        transcriptText = ""
                        extractedAddress = nil
                    }
                    
                    Button("執行測試") {
                        runAddressTests()
                    }
                }
                .padding()
            }

            if scanResult == nil || scanMode == .transcript {
                Button(scanning ? "停止掃描" : "開始掃描") {
                    scanning.toggle()
                    if !scanning {
                        scannerController?.stopScanning()
                    }
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
