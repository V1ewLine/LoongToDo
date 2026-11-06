# LoongTodo · 翻页的 L

标志以 Loong 的首字母 L 为骨架，一条连续纸带在右侧向上翻起，表达完成眼前一件事、再翻开下一页。圆润外形延续应用的轻盈反馈；雾蓝和淡紫与界面主色一致。

- `LoongTodo-icon.png`：1024 × 1024 透明背景 macOS 应用图标，带外边距与轻阴影。
- `LoongTodo-icon.svg`：应用图标的无阴影矢量版。
- `LoongTodo-mark.svg`：透明背景蓝紫标志，可用于白底页面、印刷或品牌物料。
- `LoongTodo-mark.png`：透明背景标志的 1024 × 1024 PNG。

矢量母版位于 `Sources/LoongToDo/BrandMark.swift`，侧栏直接绘制母版；`scripts/make-icon.swift` 从同一母版生成以上素材和全部 ICNS 尺寸。运行 `zsh scripts/build-app.sh` 即可重新生成。16、32 像素版本省去折面与阴影。

配色：主渐变 `#918FE0 → #4054B3`；白色纸带；浅紫折面 `#E8EBFF → #B3C4FA`。标志不依赖字体、系统符号或外部图片。
