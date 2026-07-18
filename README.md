# 不跑打印店 PDFMark

一个简单、清亮的原生 macOS PDF 标注工具：打开 PDF，随手添加文字和图片，导出新文件。
不用跑打印店，也不用忍受臃肿的 PDF 套件。

<p align="center">
  <img src="docs/app-icon.png" width="160" alt="不跑打印店 图标">
</p>

## 功能

- 打开任意 PDF：按钮选择，或直接把文件拖进窗口
- 多页支持：左侧页面缩略图导航，点击跳转
- 文字标注：双击编辑内容，字号、颜色可调
- 图片标注：插入 PNG / JPG / HEIC 等常见格式
- 自由画布：所有标注可随意拖动，图片可等比缩放
- 导出：把标注压平合并进新 PDF，可选**全部页面**或**指定页码**（如 `1-3, 5, 8`）
- 导出的 PDF 文字保持可搜索、可复制，页面尺寸与原文件一致

## 系统要求

- macOS 14 (Sonoma) 或更高版本
- Apple Silicon（M 系列）Mac

## 安装

1. 在 [Releases](../../releases) 页面下载 `不跑打印店.dmg`
2. 打开 dmg，把「不跑打印店」拖进 Applications 文件夹
3. 首次打开如被 Gatekeeper 拦截（应用使用 ad-hoc 签名、未经 Apple 公证）：
   - 右键点击应用 →「打开」→ 再点「打开」；或
   - 在终端执行：`xattr -dr com.apple.quarantine /Applications/不跑打印店.app`

## 使用

1. 打开一个 PDF
2. 点工具栏「文字」或「图片」，在当前页面添加标注，拖到想要的位置
3. 双击文字框修改内容；选中后可在工具栏调整字号和颜色
4. 选中标注后按 `⌫` 删除
5. 点「导出」，选择全部页面或输入页码范围，保存为新 PDF

## 自行构建

不需要安装 Xcode，只需要 Xcode Command Line Tools：

```bash
xcode-select --install   # 如果还没装过

./build_app.sh           # 编译并打包出 不跑打印店.app
./make_dmg.sh            # 制作 dmg 安装镜像
./make_icon.sh           # （可选）修改 tools/IconGenerator.swift 后重新生成图标
```

## 技术

- SwiftUI + PDFKit
- Swift Package Manager 构建，零第三方依赖
- 导出基于 CGPDFContext 逐页压平渲染，文字层保留（可搜索）

## License

[MIT](LICENSE)
