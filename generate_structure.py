import os
import sys
import argparse
from pathlib import Path

def is_text_file(file_path: Path) -> bool:
    """
    使用纯Python方法判断文件是否为文本文件。
    策略：
      1. 读取文件前 1024 字节（如果文件更小则全部读取）。
      2. 如果包含空字节（\0），判定为二进制文件。
      3. 尝试用 UTF-8、GBK、GB2312、GB18030 等编码解码，任意成功则判定为文本文件。
    对于空文件，判定为文本文件。
    """
    try:
        with open(file_path, 'rb') as f:
            sample = f.read(1024)
        # 空文件视为文本文件
        if len(sample) == 0:
            return True
        # 包含空字节 -> 二进制
        if b'\0' in sample:
            return False
        # 尝试多种常见编码（优先 UTF-8，其次中文编码）
        for encoding in ('utf-8', 'gbk', 'gb2312', 'gb18030'):
            try:
                sample.decode(encoding)
                return True
            except UnicodeDecodeError:
                continue
        return False
    except Exception:
        return False

def generate_tree(root_dir: Path) -> list:
    """
    生成目录树形结构的字符串列表。
    使用ASCII字符绘制树形图，目录名后加斜杠。
    """
    root = root_dir.resolve()
    if not root.exists() or not root.is_dir():
        raise ValueError(f"路径不存在或不是目录: {root_dir}")

    lines = []

    def _walk_dir(path: Path, prefix: str = '', is_last: bool = True):
        # 输出当前项（目录或文件）
        connector = '└── ' if is_last else '├── '
        lines.append(f"{prefix}{connector}{path.name}{'/' if path.is_dir() else ''}")

        if path.is_dir():
            # 子项排序：目录在前，然后按名称排序
            children = sorted(path.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower()))
            for i, child in enumerate(children):
                is_last_child = (i == len(children) - 1)
                new_prefix = prefix + ('    ' if is_last else '│   ')
                _walk_dir(child, new_prefix, is_last_child)

    # 输出根目录
    lines.append(f"{root.name}/")
    children = sorted(root.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower()))
    for i, child in enumerate(children):
        is_last_child = (i == len(children) - 1)
        _walk_dir(child, '', is_last_child)

    return lines

def collect_text_files(root_dir: Path) -> list:
    """递归收集所有文本文件的路径列表"""
    text_files = []
    for file_path in root_dir.rglob('*'):
        if file_path.is_file() and is_text_file(file_path):
            text_files.append(file_path)
    return text_files

def main():
    parser = argparse.ArgumentParser(
        description='生成文件夹树形结构并将所有文本文件内容输出到Markdown文件'
    )
    parser.add_argument('folder', help='要遍历的文件夹路径')
    parser.add_argument('-o', '--output', default='structure.md',
                        help='输出的Markdown文件路径 (默认: structure.md)')
    args = parser.parse_args()

    # 关键修改：立即解析为绝对路径
    folder_path = Path(args.folder).resolve()
    output_file = args.output

    # 生成树形结构
    try:
        tree_lines = generate_tree(folder_path)   # generate_tree 内部也会 resolve，但传入绝对路径更安全
    except Exception as e:
        print(f"生成树形结构失败: {e}", file=sys.stderr)
        sys.exit(1)

    # 收集文本文件
    print("正在识别文本文件...")
    text_files = collect_text_files(folder_path)
    print(f"找到 {len(text_files)} 个文本文件")

    # 写入Markdown文件
    with open(output_file, 'w', encoding='utf-8') as md:
        md.write("# 📁 文件夹结构\n\n")
        md.write("```\n")
        for line in tree_lines:
            md.write(line + "\n")
        md.write("```\n\n")

        md.write("# 📄 文本文件内容\n\n")
        for idx, file_path in enumerate(text_files, 1):
            # 现在 file_path 和 folder_path 都是绝对路径，可以正常计算相对路径
            rel_path = file_path.relative_to(folder_path)
            md.write(f"## {rel_path}\n\n")

            try:
                content = file_path.read_text(encoding='utf-8', errors='replace')
            except Exception as e:
                content = f"[读取文件失败: {e}]"

            md.write("```\n")
            md.write(content)
            if not content.endswith('\n'):
                md.write('\n')
            md.write("```\n\n")

            if idx % 10 == 0:
                print(f"已写入 {idx}/{len(text_files)} 个文件...")

    print(f"✅ 成功生成Markdown文件: {output_file}")

if __name__ == '__main__':
    main()