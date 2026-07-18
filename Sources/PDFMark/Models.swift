import SwiftUI

/// 页面上的一个标注元素（文字框或图片）。
/// 坐标使用「页面点」单位，原点为页面左上角，y 轴向下，方便与 SwiftUI 显示直接对应；
/// 导出 PDF 时再换算为 PDF 的左下角原点坐标系。
struct AnnotationItem: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case text
        case image
    }

    let id: UUID = UUID()
    /// 所在页码（从 0 开始）
    var page: Int
    /// 在页面中的位置与尺寸（文字框的 height 仅作初始参考，实际高度随内容自适应）
    var rect: CGRect
    var kind: Kind
    /// 文字内容（kind == .text 时使用）
    var text: String = ""
    var fontSize: CGFloat = 18
    var color: Color = .black
    /// 图片原始数据（kind == .image 时使用）
    var imageData: Data? = nil
}
