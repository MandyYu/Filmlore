# WatermarkPreset 参数梳理与优化建议

四个 `include*` 开关已合并为 `includedFields`，所有内置模板已使用新配置。显示行为及持久化格式保持兼容；其余优化建议尚未实施。

## 1. 当前参数（18 个）

定义：`Sources/StyleCameraCore/StylePreset.swift`。

| 参数 | 默认值 | 含义 / 生效条件 |
| --- | --- | --- |
| `enabled` | `false` | 水印总开关。 |
| `mode` | `.manual` | `.manual` 为文字模式（包含模板字段路径），`.image` 为图片水印。 |
| `text` | `"Shot by Me"` | 普通水印签名文字；模板中由 `.signature` 字段引用。不是所有字段的统一文字。 |
| `position` | `.bottomRight` | 水印位置；`.bottom` 还参与决定是否启用模板底栏字段。 |
| `customPosition` | `nil` | 自定义位置的归一化坐标；仅在 `.custom` 位置使用。 |
| `opacity` | `0.65` | 不透明度，初始化及解码限制为 `0...1`。部分文字样式还会乘额外透明度系数。 |
| `imageData` | `nil` | 图片水印二进制内容，仅图片模式使用；不是模板封面。 |
| `imageScale` | `0.22` | 图片水印尺寸系数，范围 `0.08...0.6`，仅图片模式使用。 |
| `watermarkScale` | `1` | 整体缩放系数，范围 `0.5...2`；影响文字字号，也与图片水印尺寸系数叠乘。 |
| `template` | `.signature` | 普通文字的组织方式，如签名、旅拍卡片、日期、星期短句；也影响部分文字排版。 |
| `includedFields` | `.standard`（日期和风格） | 普通文字水印包含的信息集合，支持 `.date`、`.device`、`.styleName`、`.location`。不会关闭底栏显式声明的同类字段。 |
| `locationOverrideText` | `""` | 非空时优先使用手动地点；普通文字和地点字段均会读取。 |
| `textColor` | `.automatic` | 默认文字颜色；字段可以覆盖；图片水印不使用。 |
| `customTextColorHex` | `"#FFFFFF"` | 自定义十六进制颜色，仅在对应 `textColor == .custom` 时使用。 |
| `font` | `.sourceHanSans` | 默认字体，模板文本字段可独立覆盖。 |
| `visualStyle` | `.minimal` | 影响普通水印背景、内边距，以及文字字重、大小、透明度等；底栏字段也会间接使用部分文字样式规则。 |
| `effect` | `.shadow` | 无效果、阴影或发光；不同预览路径的支持程度不完全一致。 |

注意：上述数值范围目前只在初始化或解码时约束；属性是公开的 `var`，之后直接赋值可以绕过约束。

### 附加内容配置示例

以下是替代写法，每个水印只选其中一种：

```swift
includedFields: .all,                    // 日期、设备、风格、地点全部显示
includedFields: [.date, .location],      // 仅日期和地点
includedFields: [.date, .device],        // 仅日期和设备
includedFields: [],                     // 四项全部关闭，签名等原有文字仍保留
```

不填写时使用 `.standard`，等同于 `[.date, .styleName]`。这是信息选择集合，集合的书写顺序不会改变文字排列；排列仍由 `template` 决定。

运行期间可使用 `includedFields.insert(.location)`、`remove(.location)`、`contains(.location)` 添加、移除和检查字段。

保存仍使用原来的 `includeDate / includeDevice / includeStyleName / includeLocation` 四个布尔 JSON 键。读取旧记录时逐项转换，缺失键保留原默认值，显式 `false` 不被覆盖。源码初始化参数已改为 `includedFields`，旧调用写法需同步调整。

## 2. 当前实际渲染路径

1. `enabled == false`：最终输出不绘制水印。
2. `mode == .image`：读取 `imageData`，应用尺寸、位置、不透明度；缺失或无效图片时不绘制。
3. `mode == .manual` 且 `position == .bottom`、模板有字段：优先走模板字段路径；绘制底栏还需要有效的边框底部区域。
4. 其他文字模式：通过 `displayText()`，按 `template` 和 `includedFields` 拼接文字。

模板字段存放在 `CameraTemplatePreset.insetContent`，并不属于 `WatermarkPreset`。如果没有有效底栏，渲染器还存在回退到普通文字的逻辑。因此不能简单把 `template`、`includedFields` 当作所有底栏模板里完全无用的字段直接删除。

## 3. 已确认的问题

### A. 内容来源重复，参数作用不直观

普通文字通过 `template + includedFields` 组织；底栏通过 `insetContent` 的行和字段组织。

例如 `relationships-family` 当前底栏配置了图标、地点、分隔符和日期，而 `watermark.includedFields` 为 `.all`。底栏路径不会因此自动增加设备和风格字段；这些配置用于普通文字路径及其回退。

建议明确区分「普通文字」「图片水印」「模板字段」，并以实际生效路径决定内容与定位需求。

### B. 自定义颜色需要同时维护两个值

当前配置必须成对填写：

```swift
textColor: .custom,
customTextColorHex: "#FF0000"
```

只修改十六进制字符串不会自动启用自定义颜色。当前部分城市图标已有这种配置组合。

建议先增加统一的颜色设置入口和校验；后续可用 `.custom(hex: ...)` 一类组合类型表示自定义颜色。字段「跟随模板」应和模板级「自动选色」区分，避免两者都叫 `.automatic`。

### C. 预览和最终输出的规则有差异

- `TemplateSettingsView.watermarkLabel` 的普通文字预览使用系统字体；最终渲染使用 `preset.font`。
- `CameraTemplateSlotBarView` 的字段预览使用固定半粗字重与模板不透明度；最终字段渲染在未覆盖字体、颜色时继承 `visualStyle` 的字重和额外透明度系数。
- 字段预览的自动颜色根据边框背景选择；最终渲染默认颜色的回退与 `visualStyle` 有关。
- 模板编辑预览自定义位置缺失时回退到 `(0.5, 0.78)`，相机预览和最终渲染回退到 `(0.5, 0.86)`。
- 模板预览部分路径只处理阴影，最终渲染还支持发光。
- 图片水印的相机预览应用 `effect`，最终图片水印渲染没有应用该效果。

建议统一生成解析后的颜色、字体、字号、透明度、效果和位置，再交给 SwiftUI 预览与 UIKit 输出绘制。共用参数解析不保证两套排版完全一致，仍需图像对照验证。

### D. 数值与默认值维护重复

构造器和解码器重复默认值及限幅。后续修改容易遗漏一处；运行期间直接赋值又可能越界。`WatermarkAnchor` 的构造器限制坐标范围，但自动合成的解码不经过该构造器。

建议统一默认值和规范化逻辑，在设置、解码及渲染边界明确校验规则；兼顾非有限数值与非法十六进制颜色。

### E. 图片与配置存储耦合

当前选中的模板整体 JSON 编码后保存到 `UserDefaults`。若未来使用较大的图片水印，`imageData` 会随配置一起编码存储。

可以将图片资源另存文件或资源库，配置只保存引用。现有内置文字模板无需为了这个潜在问题立即改动存储。

## 4. 建议的优化顺序

### 第一阶段：整理与减少重复配置

- 把水印类型及相关枚举从 `StylePreset.swift` 拆到独立文件，补充生效条件注释，并同步 Xcode 工程文件。
- 保留现有字段名和 JSON 键；先通过分组、默认值与工厂方法提升可读性。
- 提供底栏模板的便捷构造入口，集中设置模式、位置和合理默认值；保留旧行为所需的回退配置。
- 统一自定义颜色设置和数值校验入口。

### 第二阶段：统一显示规则

- 统一字段继承、自动颜色、字重、透明度、效果、自定义锚点的解析。
- 使用实际绘制内容判断是否需要定位，考虑水印开关、图片模式和已填写的手动地点。
- 对照验证模板卡片、编辑预览、相机预览和保存照片。

### 第三阶段：必要时调整数据结构

建议的职责分组（尚未实现）：

```text
WatermarkPreset
  enabled
  content      普通文字 / 图片 / 模板字段引用
  appearance   默认字体、颜色、不透明度、背景样式、效果
  placement    位置、锚点、整体缩放
```

注意避免让 `content` 再复制一份 `insetContent`；模板字段需保留唯一的数据来源。可让模板与普通水印共享外观和位置配置，并由模板拥有字段结构。

## 5. 验证与兼容性要求

- 旧 JSON 缺省值仍按旧版语义读取；如调整存储结构，提供明确迁移。
- 保留原有用户字体、字号、颜色、位置和图片水印数据。
- 对照三种内容路径及底栏缺失时的回退。
- 验证字段继承、字段覆盖、图片模式、缺少自定义锚点、非法颜色和越界数值。
- 显示规则统一可能改变当前输出外观，应明确期望并用样图验证，不能当作纯重命名处理。
