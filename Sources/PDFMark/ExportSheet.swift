import SwiftUI

/// 导出前选择页面范围：全部页面，或输入页码范围（如 1-3, 5, 8）。
struct ExportSheet: View {
    @ObservedObject var vm: DocumentViewModel
    @Binding var isPresented: Bool

    @State private var exportAll = true
    @State private var rangeText = ""

    /// 解析出的页码（0 起始）；输入非法时为 nil
    private var parsedPages: [Int]? {
        DocumentViewModel.parsePageRanges(rangeText, pageCount: vm.pageCount)
    }

    private var canExport: Bool {
        exportAll || parsedPages != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导出 PDF")
                .font(.headline)

            Picker("", selection: $exportAll) {
                Text("全部页面（共 \(vm.pageCount) 页）").tag(true)
                Text("指定页码").tag(false)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            HStack(spacing: 8) {
                TextField("例如：1-3, 5, 8", text: $rangeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)
                    .disabled(exportAll)

                if !exportAll {
                    if rangeText.isEmpty {
                        Text(" ")
                    } else if let pages = parsedPages {
                        Text("将导出 \(pages.count) 页")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("页码格式不正确")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.leading, 20)

            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("导出") {
                    isPresented = false
                    vm.exportPDF(pages: exportAll ? nil : parsedPages)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canExport)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
