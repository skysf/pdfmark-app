import SwiftUI
import PDFKit
import AppKit
import UniformTypeIdentifiers

/// 整个文档的状态：打开的 PDF、所有标注元素、当前选中项。
@MainActor
final class DocumentViewModel: ObservableObject {
    @Published var document: PDFDocument?
    @Published var documentName: String = ""
    @Published var items: [AnnotationItem] = []
    @Published var selectedID: UUID?
    /// 是否正在弹窗里编辑文字（此时禁用 ⌫ 删除元素快捷键，避免误删）
    @Published var isEditingText = false
    @Published var currentPage: Int = 0
    @Published var showExportAlert = false
    @Published var exportMessage = ""

    /// 屏幕显示缩放倍数（PDF point -> 屏幕 point）
    let scale: CGFloat = 1.5

    private var fullThumbCache: [Int: NSImage] = [:]
    private var miniThumbCache: [Int: NSImage] = [:]
    private var imageCache: [UUID: NSImage] = [:]

    var pageCount: Int { document?.pageCount ?? 0 }

    var selectedItem: AnnotationItem? {
        items.first { $0.id == selectedID }
    }

    // MARK: - 页面信息

    func pageSize(for index: Int) -> CGSize {
        guard let page = document?.page(at: index) else {
            return CGSize(width: 595, height: 842) // A4 兜底
        }
        return page.bounds(for: .mediaBox).size
    }

    /// 主画布用高清缩略图（按 2x 像素渲染，Retina 清晰）
    func thumbnail(for index: Int) -> NSImage {
        if let cached = fullThumbCache[index] { return cached }
        guard let page = document?.page(at: index) else { return NSImage() }
        let size = pageSize(for: index)
        let image = page.thumbnail(
            of: CGSize(width: size.width * scale * 2, height: size.height * scale * 2),
            for: .mediaBox
        )
        fullThumbCache[index] = image
        return image
    }

    /// 侧栏用小缩略图
    func miniThumbnail(for index: Int) -> NSImage {
        if let cached = miniThumbCache[index] { return cached }
        guard let page = document?.page(at: index) else { return NSImage() }
        let size = pageSize(for: index)
        let w: CGFloat = 220
        let image = page.thumbnail(of: CGSize(width: w, height: w * size.height / size.width), for: .mediaBox)
        miniThumbCache[index] = image
        return image
    }

    func nsImage(for item: AnnotationItem) -> NSImage? {
        if let cached = imageCache[item.id] { return cached }
        guard let data = item.imageData, let image = NSImage(data: data) else { return nil }
        imageCache[item.id] = image
        return image
    }

    // MARK: - 打开

    func openPDFPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url: url)
    }

    func open(url: URL) {
        guard let doc = PDFDocument(url: url) else { return }
        document = doc
        documentName = url.lastPathComponent
        items = []
        selectedID = nil
        currentPage = 0
        fullThumbCache.removeAll()
        miniThumbCache.removeAll()
        imageCache.removeAll()
    }

    // MARK: - 添加元素

    func addTextItem() {
        guard document != nil else { return }
        let size = pageSize(for: currentPage)
        let width: CGFloat = 220
        let item = AnnotationItem(
            page: currentPage,
            rect: CGRect(x: (size.width - width) / 2, y: size.height / 3, width: width, height: 30),
            kind: .text,
            text: "双击编辑文字",
            fontSize: 18,
            color: .black
        )
        items.append(item)
        selectedID = item.id
    }

    func addImageItem() {
        guard document != nil else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .gif, .bmp]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data) else { return }

        // 按图片像素尺寸插入，过宽时缩到 280pt 以内
        var pixelSize = image.size
        if let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            pixelSize = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        let factor = min(1, 280 / pixelSize.width)
        let w = pixelSize.width * factor
        let h = pixelSize.height * factor
        let size = pageSize(for: currentPage)
        let item = AnnotationItem(
            page: currentPage,
            rect: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h),
            kind: .image,
            imageData: data
        )
        items.append(item)
        selectedID = item.id
    }

    // MARK: - 编辑选中项

    func deleteSelected() {
        guard let id = selectedID else { return }
        items.removeAll { $0.id == id }
        selectedID = nil
    }

    func adjustFontSize(by delta: CGFloat) {
        guard let id = selectedID, let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].fontSize = min(120, max(8, items[i].fontSize + delta))
    }

    func setSelectedColor(_ color: Color) {
        guard let id = selectedID, let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].color = color
    }

    func deselect() {
        selectedID = nil
    }

    // MARK: - 导出

    /// pages：要导出的页码（0 起始，已排序）；nil 表示全部页面
    func exportPDF(pages: [Int]? = nil) {
        guard let document else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let base = (documentName as NSString).deletingPathExtension
        panel.nameFieldStringValue = base.isEmpty ? "导出.pdf" : "\(base)_标注.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try PDFExporter.export(document: document, items: items, pageIndices: pages, to: url)
            exportMessage = "已导出到：\n\(url.path)"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
        showExportAlert = true
    }

    /// 解析用户输入的页码范围，如 "1-3, 5, 8"（兼容中文逗号、顿号、破折号）。
    /// 返回 0 起始的升序页码数组；输入为空或有任何非法内容时返回 nil。
    nonisolated static func parsePageRanges(_ text: String, pageCount: Int) -> [Int]? {
        let normalized = text
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "、", with: ",")
            .replacingOccurrences(of: "；", with: ",")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
        var pages = Set<Int>()
        for part in normalized.split(separator: ",") {
            let piece = part.trimmingCharacters(in: .whitespaces)
            guard !piece.isEmpty else { return nil }
            if piece.contains("-") {
                let ends = piece.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                guard ends.count == 2, let lower = Int(ends[0]), let upper = Int(ends[1]),
                      lower >= 1, upper >= lower, upper <= pageCount else { return nil }
                pages.formUnion(lower...upper)
            } else {
                guard let number = Int(piece), number >= 1, number <= pageCount else { return nil }
                pages.insert(number)
            }
        }
        return pages.isEmpty ? nil : pages.map { $0 - 1 }.sorted()
    }
}
