import PDFKit
import AppKit

/// 把原 PDF 的每一页连同标注元素一起「压平」绘制到一个新的 PDF 文件。
///
/// 注意：macOS 的 CGPDFContext 只在创建时接受 mediaBox，
/// beginPDFPage 的 pageInfo 里传 kCGPDFContextMediaBox 会被忽略（回落到 Letter 尺寸）。
/// 因此所有页面尺寸一致时直接一次写入（文字保持可搜索）；
/// 尺寸不一致时逐页渲染为单页 PDF 再用 PDFKit 拼装，保证每页尺寸与原文档一致。
enum PDFExporter {
    /// pageIndices：要导出的页码（0 起始）；nil 表示全部页面
    static func export(document: PDFDocument, items: [AnnotationItem], pageIndices: [Int]? = nil, to url: URL) throws {
        let indices = (pageIndices ?? Array(0..<document.pageCount))
            .filter { $0 >= 0 && $0 < document.pageCount }
        guard !indices.isEmpty else { throw exportError("没有可导出的页面") }

        var boxes: [CGRect] = []
        for index in indices {
            guard let page = document.page(at: index) else { continue }
            boxes.append(page.bounds(for: .mediaBox))
        }
        guard !boxes.isEmpty else { throw exportError("文档没有页面") }

        let uniform = boxes.allSatisfy { $0 == boxes[0] }
        if uniform {
            try writeUniform(document: document, items: items, pageIndices: indices, mediaBox: boxes[0], to: url)
        } else {
            try writeMixed(document: document, items: items, pageIndices: indices, to: url)
        }
    }

    /// 所有页同尺寸：直接用一个 PDF 上下文写出
    private static func writeUniform(document: PDFDocument, items: [AnnotationItem], pageIndices: [Int], mediaBox: CGRect, to url: URL) throws {
        var box = mediaBox
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else {
            throw exportError("无法创建 PDF 文件")
        }
        withGraphicsContext(ctx) {
            for index in pageIndices {
                guard let page = document.page(at: index) else { continue }
                ctx.beginPDFPage(nil)
                drawPage(page, items: items.filter { $0.page == index }, into: ctx)
                ctx.endPDFPage()
            }
            ctx.closePDF()
        }
    }

    /// 页面尺寸不一：逐页渲染为单页 PDF 数据，再按顺序拼装
    private static func writeMixed(document: PDFDocument, items: [AnnotationItem], pageIndices: [Int], to url: URL) throws {
        let output = PDFDocument()
        for index in pageIndices {
            guard let page = document.page(at: index) else { continue }
            var box = page.bounds(for: .mediaBox)
            let data = NSMutableData()
            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else {
                throw exportError("无法创建绘图上下文")
            }
            withGraphicsContext(ctx) {
                ctx.beginPDFPage(nil)
                drawPage(page, items: items.filter { $0.page == index }, into: ctx)
                ctx.endPDFPage()
                ctx.closePDF()
            }
            guard let flattened = PDFDocument(data: data as Data)?.page(at: 0) else {
                throw exportError("第 \(index + 1) 页渲染失败")
            }
            output.insert(flattened, at: output.pageCount)
        }
        guard output.pageCount > 0, output.write(to: url) else {
            throw exportError("无法写入 PDF 文件")
        }
    }

    /// 绘制一页：原始内容 + 该页的所有标注
    private static func drawPage(_ page: PDFPage, items: [AnnotationItem], into ctx: CGContext) {
        let bounds = page.bounds(for: .mediaBox)
        // save/restore 防止 draw 改动 CTM 影响后续标注绘制
        ctx.saveGState()
        page.draw(with: .mediaBox, to: ctx)
        ctx.restoreGState()
        for item in items {
            draw(item: item, pageHeight: bounds.height)
        }
    }

    /// AppKit 的 NSString / NSImage 绘制方法需要 current NSGraphicsContext；
    /// PDF 上下文是左下角原点（未翻转），AppKit 会自动画正。
    private static func withGraphicsContext(_ ctx: CGContext, body: () -> Void) {
        let gc = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gc
        body()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func draw(item: AnnotationItem, pageHeight: CGFloat) {
        switch item.kind {
        case .image:
            guard let data = item.imageData, let image = NSImage(data: data) else { return }
            let rect = flipped(item.rect, pageHeight: pageHeight)
            image.draw(in: rect)

        case .text:
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: item.fontSize),
                .foregroundColor: NSColor(item.color)
            ]
            let text = item.text as NSString
            // 按文字框宽度测出实际高度，与屏幕上的自动换行保持一致
            let measured = text.boundingRect(
                with: CGSize(width: item.rect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes
            )
            let rect = flipped(
                CGRect(x: item.rect.minX, y: item.rect.minY,
                       width: item.rect.width, height: ceil(measured.height)),
                pageHeight: pageHeight
            )
            text.draw(in: rect, withAttributes: attributes)
        }
    }

    /// 左上角原点坐标 -> PDF 左下角原点坐标（假设 mediaBox 原点为 (0,0)，绝大多数 PDF 如此）
    private static func flipped(_ rect: CGRect, pageHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: pageHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func exportError(_ message: String) -> NSError {
        NSError(domain: "PDFMark", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
