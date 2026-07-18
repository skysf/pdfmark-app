import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = DocumentViewModel()
    @State private var showExportSheet = false

    var body: some View {
        Group {
            if vm.document == nil {
                welcomeView
            } else {
                mainView
            }
        }
        .frame(minWidth: 1000, minHeight: 680)
        .onDrop(of: [UTType.pdf], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    DispatchQueue.main.async { vm.open(url: url) }
                }
            }
            return true
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(vm: vm, isPresented: $showExportSheet)
        }
        .alert("导出", isPresented: $vm.showExportAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(vm.exportMessage)
        }
    }

    // MARK: - 欢迎页

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("不跑打印店")
                .font(.largeTitle.bold())
            Text("打开一个 PDF，在上面添加文字和图片，然后导出新文件")
                .foregroundStyle(.secondary)
            Button("打开 PDF") { vm.openPDFPanel() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Text("也可以直接把 PDF 文件拖进窗口")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 主界面

    private var mainView: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 140, ideal: 170, max: 220)
        } detail: {
            canvasArea
        }
        .navigationTitle(vm.documentName)
        .toolbar { toolbarContent }
    }

    private var sidebar: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<vm.pageCount, id: \.self) { index in
                    Button {
                        vm.currentPage = index
                    } label: {
                        VStack(spacing: 4) {
                            Image(nsImage: vm.miniThumbnail(for: index))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(index == vm.currentPage ? Color.accentColor : Color.gray.opacity(0.3),
                                                lineWidth: index == vm.currentPage ? 2 : 1)
                                )
                            Text("第 \(index + 1) 页")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
    }

    private var canvasArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(0..<vm.pageCount, id: \.self) { index in
                        PageCanvasView(vm: vm, pageIndex: index)
                            .id(index)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            .onChange(of: vm.currentPage) { _, newPage in
                withAnimation { proxy.scrollTo(newPage, anchor: .top) }
            }
        }
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { vm.addTextItem() } label: {
                Label("文字", systemImage: "textformat")
            }
            .help("在当前页面添加文字框")

            Button { vm.addImageItem() } label: {
                Label("图片", systemImage: "photo")
            }
            .help("在当前页面插入图片")

            if vm.selectedItem?.kind == .text {
                Divider()
                Button { vm.adjustFontSize(by: -2) } label: {
                    Image(systemName: "minus")
                }
                Text("\(Int(vm.selectedItem?.fontSize ?? 18))")
                    .frame(minWidth: 22)
                Button { vm.adjustFontSize(by: 2) } label: {
                    Image(systemName: "plus")
                }
                ColorPicker(
                    "",
                    selection: Binding(
                        get: { vm.selectedItem?.color ?? .black },
                        set: { vm.setSelectedColor($0) }
                    )
                )
                .labelsHidden()
                .frame(width: 30)
            }

            Divider()

            Button(role: .destructive) { vm.deleteSelected() } label: {
                Label("删除", systemImage: "trash")
            }
            .disabled(vm.selectedID == nil || vm.isEditingText)
            .keyboardShortcut(.delete, modifiers: [])
            .help("删除选中的元素 (⌫)")

            Button { showExportSheet = true } label: {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .help("把所有标注合并导出为新的 PDF")
        }
    }
}
