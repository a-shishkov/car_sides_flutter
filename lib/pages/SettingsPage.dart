import 'package:flutter/material.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/utils/cache_folder_info.dart';
import 'package:enum_to_string/enum_to_string.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage(
      {required this.saveExternal,
      required this.testImage,
      required this.doAnnotate,
      required this.model,
      required this.onSaveExternal,
      required this.onTestImage,
      required this.onDoAnnotate,
      required this.onModelType,
      Key? key})
      : super(key: key);

  final bool saveExternal;
  final bool testImage;
  final bool doAnnotate;
  final ModelType model;

  final Function(bool value) onSaveExternal;
  final Function(bool value) onTestImage;
  final Function(bool value) onDoAnnotate;
  final Function(ModelType? value) onModelType;

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String cacheDirInfo = 'Calculating...';
  bool deleteEnabled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: ListView(
        physics: NeverScrollableScrollPhysics(),
        children: ListTile.divideTiles(
          context: context,
          tiles: [
            SwitchListTile(
              title: Text('Save photos to download dir'),
              value: widget.saveExternal,
              onChanged: true ? null : widget.onSaveExternal,
              tileColor: Theme.of(context).colorScheme.surface,
            ),
            SwitchListTile(
              title: Text('Show test image instead of camera'),
              value: widget.testImage,
              onChanged: widget.onTestImage,
              tileColor: Theme.of(context).colorScheme.surface,
            ),
            SwitchListTile(
              title: Text('Annotate images before inference'),
              value: widget.doAnnotate,
              onChanged: widget.onDoAnnotate,
              tileColor: Theme.of(context).colorScheme.surface,
            ),
            ListTile(
              title: Text('Model type'),
              tileColor: Theme.of(context).colorScheme.surface,
              trailing: DropdownButton(
                value: widget.model,
                items: ModelType.values
                    .map((model) => DropdownMenuItem(
                        child: Text(EnumToString.convertToString(model,
                            camelCase: true)),
                        value: model))
                    .toList(),
                onChanged: widget.onModelType,
              ),
            ),
            FutureBuilder(
              future: cacheDirImagesSize(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  cacheDirInfo = snapshot.data.toString();
                  deleteEnabled = cacheDirInfo == '0 items' ? false : true;
                }
                return ListTile(
                  enabled: deleteEnabled,
                  title: Text('Delete all photos'),
                  subtitle: Text(cacheDirInfo),
                  tileColor: Theme.of(context).colorScheme.surface,
                  trailing: Icon(
                    Icons.delete,
                    color: deleteEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  onTap: () {
                    showDialog<String>(
                      barrierDismissible: false,
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('Delete files?'),
                        content:
                            const Text('Delete all files in cache folder?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await deleteAllImages();
                              setState(() {});
                            },
                            child: const Text('Yes'),
                            style: ButtonStyle(
                                foregroundColor:
                                    MaterialStateProperty.all<Color>(
                                        Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ).toList(),
      ),
    );
  }
}
