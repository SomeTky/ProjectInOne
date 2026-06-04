import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';



// 测试用：打印并打开配置文件路径
void testConfigPath() async {
  final appDir = await getApplicationDocumentsDirectory();
  // 直接打开文件夹
  await Process.run('open', [appDir.path]);
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '文件夹结构工具',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FolderToolPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _TreeNode {
  final String name;
  final String fullPath;
  final bool isDir;
  final List<_TreeNode> children;
  _TreeNode(this.name, this.fullPath, this.isDir, this.children);
}

class FolderToolPage extends StatefulWidget {
  const FolderToolPage({super.key});

  @override
  State<FolderToolPage> createState() => _FolderToolPageState();
}

class _FolderToolPageState extends State<FolderToolPage> {
  List<String> _fileSuffixes = [];
  late File _tempFile;
  final _suffixController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isProcessing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initTempFile();
    _loadConfig();
    _requestPermissions();
    // 监听焦点，失去焦点时清输入法状态
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    });
  }

  Future<void> _initTempFile() async {
    final String home = Platform.environment['HOME']!;
    _tempFile = File("$home/Desktop/目录扫描结果.txt");
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
    }
  }

  Future<bool> _isTextFile(File file) async {
    try {
      // 以只读模式打开文件，仅读取前 512 字节
      final raf = await file.open(mode: FileMode.read);
      final bytes = await raf.read(512);
      await raf.close();
      if (bytes.isEmpty) return true;
      
      // 检查是否包含空字节（典型二进制特征）
      if (bytes.any((b) => b == 0)) return false;
      
      // 尝试解码，允许替换非法字符（出现 �）
      final decoded = utf8.decode(bytes, allowMalformed: true);
      // 统计解码后出现的 � 字符数量
      int replacementCount = 0;
      for (int i = 0; i < decoded.length; i++) {
        if (decoded[i] == '�') replacementCount++;
      }
      // 若替换字符比例超过 10% 则视为二进制
      return replacementCount / decoded.length <= 0.1;
    } catch (_) {
      return false;
    }
  }


  Future<void> _loadConfig() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File('${appDir.path}/config.json');
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final List<dynamic> list = json.decode(content);
        _safeSetState(() {
          _fileSuffixes = List<String>.from(list);
        });
      } else {
        _safeSetState(() => _fileSuffixes = ['txt', 'md', 'dart']);
        await _saveConfig();
      }
    } catch (e) {
      _showSnack("配置加载失败");
    }
  }

  Future<void> _saveConfig() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final configFile = File('${appDir.path}/config.json');
      await configFile.writeAsString(json.encode(_fileSuffixes));
    } catch (e) {
      _showSnack("配置保存失败");
    } finally {
      _isSaving = false;
    }
  }

  bool _validateSuffix(String suffix) {
    final cleanSuffix = suffix.replaceAll('.', '').trim();
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cleanSuffix);
  }

  Future<void> _addSuffix() async {
    final input = _suffixController.text.trim();
    if (!_validateSuffix(input)) {
      _showSnack("后缀不合法！仅支持字母/数字");
      return;
    }
    final cleanSuffix = input.replaceAll('.', '');
    if (_fileSuffixes.contains(cleanSuffix)) {
      _showSnack("后缀已存在");
      _suffixController.clear();
      return;
    }

    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _focusNode.unfocus();

    setState(() {
      _fileSuffixes.add(cleanSuffix);
      _suffixController.clear();
    });
    
    await _saveConfig();
    _showSnack("添加成功");
  }

  void _deleteSuffix(int index) {
    final item = _fileSuffixes[index];
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _focusNode.unfocus();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("确认删除"),
        content: Text("确定要删除后缀 [$item] 吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _fileSuffixes.removeAt(index);
              });
              await _saveConfig();
              _showSnack("删除成功");
            },
            child: const Text("确定", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 安全刷新：放在下一帧，避免和输入法消息冲突
  void _safeSetState(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(fn);
    });
  }


  Future<void> _selectFolder() async {
    if (_fileSuffixes.isEmpty) {
      _showSnack("请先配置文件后缀！");
      return;
    }
    _safeSetState(() => _isProcessing = true);
    try {
      final String? selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath == null) return;
      final rootDir = Directory(selectedPath);
      if (!await rootDir.exists()) {
        _showSnack("文件夹不存在");
        return;
      }

      // 1. 同步获取目录树节点（已过滤非文本文件）
      final treeRoot = await _generateDirectoryTreeAsync(rootDir);
      // 2. 根据节点结构收集文件内容
      final contentMap = await _collectTargetFilesAsync(treeRoot);
      // 3. 生成最终报告
      final resultContent = await _buildResultContentAsync(treeRoot, contentMap);

      final String home = Platform.environment['HOME']!;
      final File outFile = File("$home/Desktop/目录扫描结果.txt");
      await outFile.parent.create(recursive: true);
      await outFile.writeAsString(resultContent, encoding: utf8);

      _showSnack("处理完成！文件已保存至：${outFile.path}");
    } catch (e) {
      _showSnack("处理失败：${e.toString()}");
    } finally {
      if (mounted) _safeSetState(() => _isProcessing = false);
    }
  }

  Future<_TreeNode> _generateDirectoryTreeAsync(Directory root) async {
    final suffixList = _fileSuffixes.map((e) => e.toLowerCase()).toList();

    Future<_TreeNode> buildNode(Directory dir) async {
      final entities = await dir.list().toList();
      final List<_TreeNode> children = [];

      for (final entity in entities) {
        final name = path.basename(entity.path);
        // 跳过隐藏文件和特殊目录 . / ..
        if (name.startsWith('.') || name == '.' || name == '..') continue;

        if (entity is Directory) {
          final subNode = await buildNode(entity);
          children.add(subNode);
        } else if (entity is File) {
          final ext = path.extension(entity.path).replaceAll('.', '').trim().toLowerCase();
          // 仅当后缀匹配且为文本文件时添加
          if (suffixList.contains(ext) && await _isTextFile(entity)) {
            children.add(_TreeNode(name, entity.path, false, []));
          }
        }
      }

      // 排序：目录在前，文件在后
      children.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      final dirName = path.basename(dir.path);
      return _TreeNode(dirName, dir.path, true, children);
    }

    return await buildNode(root);
  }

  Future<Map<String, String>> _collectTargetFilesAsync(_TreeNode root) async {
    final Map<String, String> contentMap = {};

    void walkNode(_TreeNode node, String relativePath) {
      if (!node.isDir) {
        // 只处理文件节点
        final file = File(node.fullPath);
        // 再次尝试读取（目录树生成时已过滤，此处不再重复判断文本性）
        try {
          final content = file.readAsStringSync(encoding: utf8); // 同步读取（小文件可用）
          contentMap[relativePath] = content;
        } catch (e) {
          contentMap[relativePath] = "[文件读取失败]";
        }
      } else {
        // 递归子节点
        for (final child in node.children) {
          final childRelative = path.join(relativePath, child.name);
          walkNode(child, childRelative);
        }
      }
    }

    walkNode(root, root.name);
    return contentMap;
  }

  Future<String> _buildResultContentAsync(_TreeNode root, Map<String, String> contentMap) async {
    final buffer = StringBuffer();
    buffer.writeln("# 📁 文件夹结构\n");
    buffer.writeln("```");

    void writeTree(_TreeNode node, String prefix, bool isLast) {
      buffer.write(prefix);
      buffer.write(isLast ? "└── " : "├── ");
      buffer.writeln("${node.name}${node.isDir ? '/' : ''}");
      if (node.isDir && node.children.isNotEmpty) {
        final newPrefix = prefix + (isLast ? "    " : "│   ");
        for (int i = 0; i < node.children.length; i++) {
          writeTree(node.children[i], newPrefix, i == node.children.length - 1);
        }
      }
    }

    // 输出根目录
    buffer.writeln("${root.name}/");
    if (root.children.isNotEmpty) {
      for (int i = 0; i < root.children.length; i++) {
        writeTree(root.children[i], "", i == root.children.length - 1);
      }
    } else {
      buffer.writeln("    (空目录)");
    }

    buffer.writeln("```\n");
    buffer.writeln("# 📄 文件内容\n");

    final keys = contentMap.keys.toList()..sort();
    for (final relPath in keys) {
      buffer.writeln("## $relPath\n");
      buffer.writeln("```");
      buffer.writeln(contentMap[relPath]!);
      buffer.writeln("```\n");
    }

    return buffer.toString();
  }

  Future<void> _copyToClipboard() async {
    if (!await _tempFile.exists()) {
      _showSnack("请先选择文件夹生成临时文件！");
      return;
    }
    try {
      final content = await _tempFile.readAsString(encoding: utf8);
      await Clipboard.setData(ClipboardData(text: content));
      _showSnack("已复制到剪贴板！");
    } catch (e) {
      _showSnack("复制失败");
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _suffixController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("文件夹结构生成工具")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _selectFolder,
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("选择文件夹"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _copyToClipboard,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("复制到剪贴板"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "文件后缀配置",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      // 输入框+提交按钮，不依赖回车
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _suffixController,
                              focusNode: _focusNode,
                              decoration: const InputDecoration(
                                hintText: "输入文件后缀（如：txt/md）",
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addSuffix,
                            child: const Text("添加"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "已配置后缀：",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 5),
                      if (_fileSuffixes.isEmpty)
                        const Text(
                          "暂无配置，默认：txt/md/dart",
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          children: List.generate(_fileSuffixes.length, (index) {
                            return Chip(
                              label: Text(_fileSuffixes[index]),
                              onDeleted: () => _deleteSuffix(index),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}