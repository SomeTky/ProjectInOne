# ProjectInOne

将一个项目文件夹中的所有文件描述到一个文件中，方便交给大模型阅读。

## 功能说明

这个脚本可以：

1. **生成目录树形结构** - 使用 ASCII 字符绘制项目的目录结构图，目录在前、文件在后，按名称排序
2. **识别文本文件** - 自动检测文件是否为文本文件（支持 UTF-8、GBK、GB2312、GB18030 等编码）
3. **合并文件内容** - 将所有识别出的文本文件内容整合到一个 Markdown 文件中，每个文件使用相对路径作为标题

## 使用方法

### 基本用法

```bash
python generate_structure.py <目标文件夹路径>
```

这将在当前目录生成一个名为 `structure.md` 的文件。

### 指定输出文件

```bash
python generate_structure.py <目标文件夹路径> -o <输出文件路径>
```

或者：

```bash
python generate_structure.py <目标文件夹路径> --output <输出文件路径>
```

### 示例

```bash
# 遍历当前项目目录，输出到 structure.md
python generate_structure.py .

# 遍历指定目录，输出到指定位置
python generate_structure.py /path/to/your/project -o project_structure.md
```

## 输出格式

生成的 Markdown 文件包含两个部分：

### 1. 文件夹结构

```
项目名/
├── src/
│   ├── main.py
│   └── utils.py
├── README.md
└── requirements.txt
```

### 2. 文本文件内容

每个文件的内容都会以二级标题（相对路径）和代码块的形式展示：

```markdown
## src/main.py

```
[文件内容]

```
```

## 注意事项

- **编码支持**：脚本会自动尝试 UTF-8、GBK、GB2312、GB18030 编码读取文件
- **二进制文件过滤**：包含空字节（`\0`）的文件会被识别为二进制文件并跳过
- **空文件处理**：空文件会被视为文本文件
- **错误处理**：无法读取的文件会显示错误信息，不会中断整个流程
