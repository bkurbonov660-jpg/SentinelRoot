import 'package:flutter/material.dart';
import 'models.dart';
import 'native_bridge.dart';
import 'theme.dart';

class FileExplorerSheet extends StatefulWidget {
  final void Function(String path, String label, bool isDir) onSelectPath;
  const FileExplorerSheet({required this.onSelectPath, super.key});

  @override
  State<FileExplorerSheet> createState() => _FileExplorerSheetState();
}

class _FileExplorerSheetState extends State<FileExplorerSheet> {
  String _currentPath = '/storage/emulated/0';
  List<FsEntryItem> _entries = [];
  bool _loading = true;
  String _filter = '';

  static const List<(String, String)> _quickDirs = [
    ('Память', '/storage/emulated/0'),
    ('Download', '/storage/emulated/0/Download'),
    ('DCIM', '/storage/emulated/0/DCIM'),
    ('Documents', '/storage/emulated/0/Documents'),
    ('Pictures', '/storage/emulated/0/Pictures'),
    ('Root /data', '/data/data'),
  ];

  @override
  void initState() {
    super.initState();
    _loadDir(_currentPath);
  }

  Future<void> _loadDir(String path) async {
    setState(() {
      _loading = true;
      _currentPath = path;
    });
    final list = await NativeBridge.listDirectory(path);
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  void _goUp() {
    if (_currentPath == '/' || _currentPath.isEmpty) return;
    final idx = _currentPath.lastIndexOf('/');
    final parent = idx <= 0 ? '/' : _currentPath.substring(0, idx);
    _loadDir(parent);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _entries.where((e) {
      if (_filter.trim().isEmpty) return true;
      return e.name.toLowerCase().contains(_filter.trim().toLowerCase());
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 14, 16, MediaQuery.of(context).viewInsets.bottom + 14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_special_rounded, color: SColor.cyan, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Root-Проводник файловой системы',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: SColor.ink),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: SColor.sub),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final q in _quickDirs)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(q.$1),
                          backgroundColor: _currentPath == q.$2 ? SColor.cyan : SColor.card,
                          side: const BorderSide(color: SColor.border),
                          labelStyle: TextStyle(
                            color: _currentPath == q.$2 ? SColor.bg : SColor.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          onPressed: () => _loadDir(q.$2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final p = await NativeBridge.pickSystemFile();
                        if (p != null && p.isNotEmpty && context.mounted) {
                          final parts = p.split('/').where((s) => s.isNotEmpty).toList();
                          widget.onSelectPath(p, parts.isNotEmpty ? parts.last : p, false);
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.file_open_rounded, size: 16, color: SColor.cyan),
                      label: const Text('Системный файл', style: TextStyle(color: SColor.ink, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: SColor.border),
                        backgroundColor: SColor.card,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final p = await NativeBridge.pickSystemFolder();
                        if (p != null && p.isNotEmpty && context.mounted) {
                          final parts = p.split('/').where((s) => s.isNotEmpty).toList();
                          widget.onSelectPath(p, parts.isNotEmpty ? parts.last : p, true);
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.create_new_folder_rounded, size: 16, color: SColor.emerald),
                      label: const Text('Системная папка', style: TextStyle(color: SColor.ink, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: SColor.border),
                        backgroundColor: SColor.card,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: SColor.bg,
                  border: Border.all(color: SColor.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _goUp,
                      icon: const Icon(Icons.arrow_upward_rounded, color: SColor.cyan, size: 18),
                    ),
                    Expanded(
                      child: Text(
                        _currentPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SColor.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        final parts = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
                        final name = parts.isNotEmpty ? parts.last : _currentPath;
                        widget.onSelectPath(_currentPath, 'Папка: $name', true);
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: SColor.emerald,
                        foregroundColor: SColor.bg,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text(
                        'Выбрать папку',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => setState(() => _filter = v),
                style: const TextStyle(color: SColor.ink, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Быстрый фильтр по имени файла или папки…',
                  hintStyle: const TextStyle(color: SColor.sub, fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, color: SColor.sub, size: 18),
                  filled: true,
                  fillColor: SColor.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: SColor.cyan),
                        ),
                      )
                    : visible.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Text('Нет файлов в текущем каталоге', style: TextStyle(color: SColor.sub)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: visible.length,
                            separatorBuilder: (_, __) => const Divider(color: SColor.border, height: 1),
                            itemBuilder: (_, i) {
                              final item = visible[i];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                leading: Icon(
                                  item.isDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                                  color: item.isDir ? SColor.amber : SColor.cyan,
                                  size: 22,
                                ),
                                title: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: SColor.ink,
                                  ),
                                ),
                                subtitle: Text(
                                  item.isDir
                                      ? 'Каталог · Нажмите для входа'
                                      : '${formatDataSize(item.sizeBytes)} · ${item.path}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: SColor.sub, fontSize: 11),
                                ),
                                onTap: () {
                                  if (item.isDir) {
                                    _loadDir(item.path);
                                  } else {
                                    widget.onSelectPath(item.path, item.name, false);
                                    Navigator.of(context).pop();
                                  }
                                },
                                trailing: IconButton(
                                  onPressed: () {
                                    widget.onSelectPath(
                                      item.path,
                                      item.isDir ? 'Папка: ${item.name}' : item.name,
                                      item.isDir,
                                    );
                                    Navigator.of(context).pop();
                                  },
                                  icon: const Icon(Icons.add_circle_rounded, color: SColor.crimson, size: 22),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
