# 文件夹结构生成工具

这是一个基于 Flutter 开发的跨平台桌面应用程序，用于扫描指定文件夹，生成目录树结构，并提取符合配置后缀的文本文件内容，最终生成一份完整的 Markdown 格式报告。

## 功能特性

- 选择目标文件夹进行扫描
- 可配置需要提取的文件后缀（如 txt、md、dart 等）
- 自动生成目录树结构
- 提取符合条件的文本文件内容
- 生成包含目录树和文件内容的 Markdown 报告
- 支持将报告内容复制到剪贴板
- 报告默认保存在桌面 `目录扫描结果.txt`

## 技术栈

- Flutter (支持多平台：Windows、macOS、Linux、Android、iOS、Web)
- Dart
- 依赖库：
  - `file_picker` - 文件夹选择
  - `path_provider` - 获取应用文档目录
  - `permission_handler` - 权限申请
  - `fluttertoast` - 轻量提示

## 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.13.0
- 各平台对应的开发工具（见下方编译说明）

## 快速开始

### 获取依赖

```bash
flutter pub get
```

### 运行应用

```bash
flutter run
```

## 编译各平台可执行文件

### 通用前置步骤

在任何平台编译之前，请确保：

1. 已安装 Flutter SDK 并配置好环境变量
2. 已执行 `flutter pub get` 获取所有依赖
3. 确保所有依赖库版本兼容

### Windows

**编译命令：**
```bash
flutter build windows
```

**生成位置：** `build/windows/x64/runner/Release/project_in_one.exe`

**权限说明：**
- Windows 平台无需额外配置应用权限
- 应用通过 `file_picker` 访问用户选择的文件夹，使用系统原生文件选择对话框，无需特殊权限声明
- 如需写入桌面等用户目录，依赖系统默认文件系统权限

### macOS

**编译命令：**
```bash
flutter build macos
```

**生成位置：** `build/macos/Build/Products/Release/project_in_one.app`

**权限配置：**

编译 macOS 版本时，需要配置关闭应用沙盒权限。项目已包含权限配置文件：

- **DebugProfile.entitlements** (调试模式)
- **Release.entitlements** (发布模式)

配置文件内容：
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

**重要说明：**
- `com.apple.security.app-sandbox` 设置为 `false`，表示禁用应用沙盒，允许应用访问用户选择的文件
- `com.apple.security.files.user-selected.read-write` 设置为 `true`，允许读写用户通过文件选择器选中的文件
- **代码签名要求**：如需分发 macOS 应用，必须使用 Apple Developer 证书进行签名
- **Notarization**：如需在 macOS Catalina 及以上版本公开发布，需要向 Apple 提交公证

### Linux

**编译命令：**
```bash
flutter build linux
```

**生成位置：** `build/linux/x64/release/bundle/project_in_one`

**权限说明：**
- Linux 平台无需应用级别权限配置
- 文件访问权限由系统文件权限控制
- 应用运行需要用户对目标文件夹具有读取权限

### Android

**编译命令：**
```bash
flutter build apk   # 生成 APK
# 或
flutter build appbundle   # 生成 AAB（用于 Google Play）
```

**生成位置：**
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

**权限配置：**

项目已在 `android/app/src/main/AndroidManifest.xml` 中配置了必要的权限：

```xml
<!-- 在 debug 和 profile 模式下需要 -->
<uses-permission android:name="android.permission.INTERNET"/>
```

应用内动态申请的权限（在 `main.dart` 中）：
```dart
if (Platform.isAndroid) {
  await Permission.storage.request();
  await Permission.manageExternalStorage.request();
}
```

**重要说明：**
- Android 6.0 (API 23) 及以上需要运行时动态申请存储权限
- Android 11 (API 30) 及以上，`manageExternalStorage` 权限需要额外在 Play Console 中声明
- 如需发布到 Google Play，需要在应用商店描述中说明权限用途

### iOS

**编译命令：**
```bash
flutter build ios
```

**权限说明：**
- iOS 应用默认运行在沙盒中
- 文件访问通过 `UIDocumentPickerViewController` 实现，用户需主动授权选择文件
- 如需发布到 App Store，需要 Apple Developer 账号和有效的发布证书
- 需要在 `ios/Runner/Info.plist` 中添加隐私用途描述（如有文件访问需求）

### Web

**编译命令：**
```bash
flutter build web
```

**生成位置：** `build/web/` 目录

**权限说明：**
- Web 平台受浏览器安全策略限制
- 无法直接访问本地文件系统
- `file_picker` 在 Web 平台通过 File API 工作，需要用户主动点击选择文件
- 如需部署，可以将 `build/web` 目录内容部署到任何静态服务器

## 平台权限配置总览

| 平台 | 是否需要代码签名 | 是否需要运行时权限 | 特殊配置 |
|------|-----------------|-------------------|----------|
| Windows | 可选 | 否 | 无 |
| macOS | 必须（分发时） | 否 | Entitlements 文件 |
| Linux | 否 | 否 | 无 |
| Android | 可选（发布时） | 是（存储权限） | Manifest 权限声明 |
| iOS | 必须（发布时） | 是（文件选择） | Info.plist 配置 |
| Web | 否 | 否（浏览器限制） | 无 |

## 项目结构

```
sometky-projectinone/
├── android/          # Android 平台配置
├── ios/              # iOS 平台配置
├── linux/            # Linux 平台配置
├── macos/            # macOS 平台配置
├── windows/          # Windows 平台配置
├── web/              # Web 平台配置
├── lib/              # 主代码目录
│   └── main.dart     # 应用入口
├── test/             # 测试文件
├── pubspec.yaml      # 依赖配置
└── analysis_options.yaml  # 代码分析配置
```

## 注意事项

1. **大文件夹扫描**：扫描包含大量文件的文件夹时，处理时间可能较长，应用已做异步处理避免 UI 卡顿
2. **文本文件识别**：程序会通过检测文件内容中的空字节和非法 UTF-8 字符来判断是否为文本文件
3. **隐藏文件**：扫描时会自动跳过以 `.` 开头的隐藏文件和目录
4. **配置文件**：用户配置的后缀规则保存在 `应用文档目录/config.json` 中

## 常见问题

### Q: Windows 编译失败，提示找不到 CMake？
A: 需要安装 Visual Studio 2022（包含 C++ 开发工具）或单独安装 CMake。

### Q: macOS 编译的 .app 无法打开？
A: 可能是权限问题，尝试：
```bash
chmod +x /path/to/project_in_one.app/Contents/MacOS/project_in_one
```
或移除隔离属性：
```bash
xattr -d com.apple.quarantine /path/to/project_in_one.app
```

### Q: Android 运行时提示权限拒绝？
A: 应用会在启动时自动请求权限，请确保用户授予存储权限。如未弹出，可检查系统权限设置。

### Q: 如何修改应用图标？
A: 替换各平台 `res` 或 `Assets.xcassets` 目录下的图标文件即可。