import SwiftUI

/// 单页画布：底层是 PDF 页面渲染图，上面叠放可拖拽的标注元素。
struct PageCanvasView: View {
    @ObservedObject var vm: DocumentViewModel
    let pageIndex: Int

    var body: some View {
        let size = vm.pageSize(for: pageIndex)
        ZStack(alignment: .topLeading) {
            Image(nsImage: vm.thumbnail(for: pageIndex))
                .resizable()
                .frame(width: size.width * vm.scale, height: size.height * vm.scale)
                .onTapGesture {
                    vm.deselect()
                    vm.currentPage = pageIndex
                }

            ForEach($vm.items) { $item in
                if item.page == pageIndex {
                    ItemView(vm: vm, item: $item)
                }
            }
        }
        .frame(width: size.width * vm.scale, height: size.height * vm.scale, alignment: .topLeading)
        .background(Color.white)
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}

/// 单个标注元素视图：支持点选、拖动、双击编辑文字、右下角手柄缩放。
struct ItemView: View {
    @ObservedObject var vm: DocumentViewModel
    @Binding var item: AnnotationItem

    @State private var dragStartRect: CGRect?
    @State private var editingText = false

    private var scale: CGFloat { vm.scale }
    private var isSelected: Bool { vm.selectedID == item.id }

    var body: some View {
        content
            .overlay {
                if isSelected {
                    Rectangle()
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if isSelected { resizeHandle }
            }
            .offset(x: item.rect.minX * scale, y: item.rect.minY * scale)
            .onTapGesture(count: 2) {
                if item.kind == .text {
                    vm.selectedID = item.id
                    editingText = true
                }
            }
            .onTapGesture(count: 1) {
                vm.selectedID = item.id
                vm.currentPage = item.page
            }
            .gesture(moveGesture)
            .popover(isPresented: $editingText, arrowEdge: .bottom) {
                VStack(spacing: 8) {
                    TextEditor(text: $item.text)
                        .font(.system(size: item.fontSize))
                        .frame(width: 280, height: 160)
                    HStack {
                        Spacer()
                        Button("完成") { editingText = false }
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(10)
            }
            .onChange(of: editingText) { _, editing in
                vm.isEditingText = editing
            }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(item.text.isEmpty ? " " : item.text)
                .font(.system(size: item.fontSize * scale))
                .foregroundColor(item.color)
                .frame(width: item.rect.width * scale, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        case .image:
            if let image = vm.nsImage(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: item.rect.width * scale, height: item.rect.height * scale)
            } else {
                Color.gray.opacity(0.3)
                    .frame(width: item.rect.width * scale, height: item.rect.height * scale)
            }
        }
    }

    private var resizeHandle: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .offset(x: 6, y: 6)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartRect == nil { dragStartRect = item.rect }
                        guard let start = dragStartRect else { return }
                        let dx = value.translation.width / scale
                        switch item.kind {
                        case .image:
                            // 等比缩放
                            let newWidth = max(24, start.width + dx)
                            let aspect = start.height / start.width
                            item.rect.size = CGSize(width: newWidth, height: newWidth * aspect)
                        case .text:
                            item.rect.size.width = max(60, start.width + dx)
                        }
                    }
                    .onEnded { _ in dragStartRect = nil }
            )
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStartRect == nil {
                    dragStartRect = item.rect
                    vm.selectedID = item.id
                    vm.currentPage = item.page
                }
                guard let start = dragStartRect else { return }
                var rect = start
                rect.origin.x += value.translation.width / scale
                rect.origin.y += value.translation.height / scale
                let pageSize = vm.pageSize(for: item.page)
                rect.origin.x = min(max(0, rect.origin.x), pageSize.width - rect.width)
                rect.origin.y = min(max(0, rect.origin.y), pageSize.height - rect.height)
                item.rect = rect
            }
            .onEnded { _ in dragStartRect = nil }
    }
}
