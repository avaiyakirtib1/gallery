import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';
import '../models/people_group_model.dart';
import '../widgets/grid_thumbnail.dart';

class PeoplePhotosScreen extends StatefulWidget {
  final PersonCluster person;

  const PeoplePhotosScreen({super.key, required this.person});

  @override
  State<PeoplePhotosScreen> createState() => _PeoplePhotosScreenState();
}

class _PeoplePhotosScreenState extends State<PeoplePhotosScreen> {
  late String _name;

  @override
  void initState() {
    super.initState();
    _name = widget.person.name;
  }

  void _editName() {
    final controller = TextEditingController(text: _name);
    final provider = context.read<GalleryProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Name Person'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name (e.g. Alex, Mom)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final newName = controller.text.trim();
                provider.renamePerson(widget.person.id, newName);
                setState(() {
                  _name = newName;
                  widget.person.name = newName;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Text(_name),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: _editName,
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${widget.person.count} photos',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(4.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: widget.person.assets.length,
          itemBuilder: (context, index) {
            return GridThumbnail(
              asset: widget.person.assets[index],
              index: index,
              allAssets: widget.person.assets,
            );
          },
        ),
      ),
    );
  }
}
