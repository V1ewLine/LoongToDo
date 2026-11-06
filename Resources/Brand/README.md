# LoongTodo · 翻页的 L

标志以 Loong 的首字母 L 为骨架，一条连续纸带在右侧向上翻起，表达完成眼前一件事、再翻开下一页。采用 C 方案：纯白底、午夜蓝 L、亮橙色尾端。竖笔画通过修改实心轮廓加粗 20%，符号整体放大以减少白底留白；保留圆润转角，并用独立色块突出翻页部分。

- `LoongTodo-icon.png`：1024 × 1024 透明背景 macOS 应用图标，带外边距与轻阴影。
- `LoongTodo-icon.svg`：应用图标的无阴影矢量版。
- `LoongTodo-mark.svg`：透明背景蓝橙双色标志，可用于白底页面、印刷或品牌物料。
- `LoongTodo-mark.png`：透明背景标志的 1024 × 1024 PNG。

矢量母版与配色位于 `Sources/LoongToDo/BrandMark.swift`，侧栏直接绘制母版；`scripts/make-icon.swift` 从同一母版生成以上素材和全部 ICNS 尺寸。运行 `zsh scripts/build-app.sh` 即可重新生成。16、32 像素版本省去阴影，仍保留橙色尾端。

配色：纯白底 `#FFFFFF`；午夜蓝主体 `#273651`；亮橙尾端 `#FF984F`。白色底板外部保持透明，使用浅灰细边和轻阴影。标志不依赖字体、系统符号或外部图片。
