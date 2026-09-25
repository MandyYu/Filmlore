# CameraTemplatePreset 参数说明

模板定义位于 `Sources/StyleCameraCore/CameraTemplate.swift` 的 `BuiltInCameraTemplates.all`。

## 顶层参数

| 参数 | 类型 / 默认值 | 用途 |
| --- | --- | --- |
| `id` | `String`，必填 | 稳定且唯一的模板标识，用于查找、选择和持久化。不要随模板名称一起修改。 |
| `name` | `String`，必填 | 模板显示名称。 |
| `summary` | `String`，必填 | 模板简短说明；是否显示由具体页面决定。 |
| `category` | `CameraTemplateCategory`，必填 | 模板库所属分类。 |
| `coverImageName` | `String? = nil` | 模板库封面的 Asset 名称，不含扩展名。只决定示例照片，不改变边框、水印和拍摄结果。 |
| `coverOrientation` | `CameraTemplateCoverOrientation = .portrait` | 模板列表中的卡片方向：`.portrait` 竖版，`.landscape` 横版。 |
| `watermark` | `WatermarkPreset`，必填 | 水印默认内容、字体、颜色、大小和位置。 |
| `photoFrame` | `PhotoFramePreset`，必填 | 照片边框、背景、圆角、阴影和四周留白。 |
| `insetContent` | `CameraTemplateInsetContent = .empty` | 左、中、右三列的预设内容，每列支持多行，每行支持多个字段。 |
| `isPro` | `Bool = false` | 是否需要 Pro 权益。 |

## 分类及展示顺序

模板列表按以下顺序展示，尚无模板的分类保留分类标题。

| 分类 | `category` | 当前模板 |
| --- | --- | --- |
| 亲密关系 | `.relationships` | 暂无 |
| 节日纪念 | `.celebrations` | 暂无 |
| 旅行出行 | `.travel` | 旅拍记录（`minimal-travel`、`classic-travel`）、旅行明信片 |
| 日常生活 | `.dailyLife` | 日期札记、拍立得、胶片边框、星期札记 |
| 自然瞬间 | `.nature` | 橄榄漫步、海岸蓝、落日珊瑚 |
| 运动爱好 | `.sportsAndHobbies` | 暂无 |
| 成长记录 | `.growth` | 暂无 |
| 实用档案 | `.practicalArchive` | 经典铭牌（`classic-leica`、`classic-leicax`）、取景框、摄影师签名 |

旧版已保存的内置模板按模板 `id` 迁移到新分类，保留用户设置的字体、颜色、字号、封面和边框等参数。新分类值直接保留。无法匹配内置模板的旧记录按旧分类回退：`colorWalk` → 自然瞬间，`personalFrame` → 亲密关系，`seasonalFrame` → 节日纪念，其余旧分类 → 日常生活。

## 封面图片配置

`classic-travel` 已配置：

```swift
coverImageName: "template-cover-classic-travel",
```

对应资源为：

```text
StyleCameraApp/Assets.xcassets/
  template-cover-classic-travel.imageset/
    Contents.json
    classic-travel.jpg
```

图片使用用户提供的原始 JPEG。模板卡片将图片等比填充到照片区域，超出区域的部分裁切，并叠加该模板现有的边框和水印。封面应使用未叠加模板效果的照片，避免重复绘制。

- 模板库：优先使用 `coverImageName` 指向的图片。
- 未配置封面或资源不存在：回退到 `photo-frame-sample`，再回退到系统 `photo` 图标。
- 模板编辑页：使用实时相机画面；实时画面尚未准备好时沿用通用示例图，不使用模板封面。
- 实时取景和最终照片渲染不读取封面配置。
- 旧版已保存的模板没有该字段时，解码为 `nil`；原有样式保留。模板库使用最新内置定义，因此仍能显示新封面。

新增封面时，在 Asset Catalog 添加相应 imageset，然后在模板初始化参数 `category` 后填写 `coverImageName` 即可。

## 列表横版 / 竖版配置

在模板初始化参数中，放在 `coverImageName` 后、`watermark` 前：

```swift
coverImageName: "template-cover-classic-travel",
coverOrientation: .landscape, // 横版；改成 .portrait 即为竖版
```

- 竖版 `.portrait`：`195 × 260`，比例 `3:4`，也是不填写时的默认值。
- 横版 `.landscape`：`260 × 195`，比例 `4:3`。
- 同一分类支持横竖混排，顶部对齐；行高按该分类最高卡片确定，横向滚动时保持稳定。
- 封面等比填充并裁切，边框和水印按新的卡片尺寸重新布局，不旋转或拉伸原图。
- 只影响模板列表，编辑页实时画面、拍摄比例和最终输出保持原有逻辑。
- 旧版保存的模板缺少 `coverOrientation` 时按竖版读取。
- `classic-travel` 已显式填写 `.portrait`，可直接在此处修改。

## 水印参数 `watermark`

| 参数组 | 说明 |
| --- | --- |
| `enabled` | 是否显示水印内容。 |
| `mode`、`template`、`text` | 水印模式、内容组织方式、签名文字。`watermark.template` 是水印样式枚举，不是当前模板的 `id`。 |
| `position`、`customPosition` | 水印位置及自定义锚点。 |
| `opacity` | 不透明度，范围 `0...1`。 |
| `watermarkScale` | 默认整体字号倍率，范围 `0.5...2`。 |
| `font` | 默认字体；字段可单独覆盖。 |
| `textColor`、`customTextColorHex` | 默认颜色；自定义颜色需设 `textColor: .custom`，并填写 `#RRGGBB`。 |
| `includedFields` | 普通文字水印的附加内容集合：`.date`、`.device`、`.styleName`、`.location`。`.all` 全选，`[]` 全关，默认 `[.date, .styleName]`。底栏字段仍由 `insetContent` 独立决定。 |
| `locationOverrideText` | 手动指定地点文字。 |
| `visualStyle`、`effect` | 水印外观和阴影、发光等效果。 |
| `imageData`、`imageScale` | 图片水印的数据与大小，和模板封面无关。 |

## 边框参数 `photoFrame`

| 参数 | 说明 |
| --- | --- |
| `enabled`、`style` | 是否启用边框及边框样式。 |
| `backgroundColor`、`opacity` | 边框背景色与不透明度。 |
| `borderWidth` | 边框宽度参数，初始化时限制在 `4...40`。 |
| `cornerRadius`、`shadowEnabled` | 圆角与阴影。 |
| `baseInsets` | 上、左、下、右四周留白。封面、实时预览和输出照片沿用现有布局逻辑。 |

## 预设字段 `insetContent`

结构为 `left / center / right → lines → fields`。每个字段是 `CameraTemplateSlot`：

| 参数 | 说明 |
| --- | --- |
| `type` | 空字段、图标或文本。 |
| `iconName` | 图标资源名或 SF Symbol 名称。 |
| `textSource`、`customText` | 文本来源及固定文字；来源可为签名、地点、日期、星期、设备、风格或自定义文字。 |
| `fontScale` | 字段字号倍率，范围 `0.5...2.5`，与模板默认字号倍率叠乘。 |
| `font` | `nil` 跟随模板默认字体，非空则覆盖。 |
| `textColor` | `.automatic` 跟随模板默认颜色，其他值覆盖。 |
| `customTextColorHex` | 仅在该字段 `textColor == .custom` 时生效。 |

模板编辑界面只开放字号、颜色和字体。行、字段数量及预设内容由代码配置。
