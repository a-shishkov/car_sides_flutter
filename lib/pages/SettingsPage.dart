import 'package:flutter/material.dart';
import 'package:flutter_app/utils/cache_folder_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final SharedPreferences prefs;

  const SettingsPage(this.prefs, {Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool saveImagesToDownloadDir =
      widget.prefs.getBool('saveToDownloadDir') ?? false;
  late bool testPicture = widget.prefs.getBool('testPicture') ?? false;
  late String modelType = widget.prefs.getString('modelType') ?? 'parts';
  late String selectedTestImage =
      widget.prefs.getString('selectedTestImage') ?? 'car_800_552.jpg';

  String cacheDirInfo = "Calculating...";

  @override
  void initState() {
    // _initImages();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    bool deleteEnabled = true;
    return Container(
      alignment: Alignment.center,
      child: ListView(
        physics: NeverScrollableScrollPhysics(),
        children: ListTile.divideTiles(
          context: context,
          tiles: [
            SwitchListTile(
              title: Text('Save photos to download dir'),
              value: saveImagesToDownloadDir,
              onChanged: (bool value) {
                widget.prefs.setBool('saveToDownloadDir', value);
                setState(() {
                  saveImagesToDownloadDir = value;
                });
              },
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(0))),
            ),
            SwitchListTile(
              title: Text('Show test picture instead of camera'),
              value: testPicture,
              onChanged: (bool value) {
                widget.prefs.setBool('testPicture', value);
                setState(() {
                  testPicture = value;
                });
              },
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(0))),
            ),
            ListTile(
              title: Text("Model type"),
              // TODO: create dropdownbutton list
              trailing: DropdownButton(
                value: modelType,
                items: [
                  DropdownMenuItem(
                    child: Text('parts'),
                    value: 'parts',
                  ),
                  DropdownMenuItem(
                    child: Text('damage'),
                    value: 'damage',
                  )
                ],
                onChanged: (String? value) {
                  widget.prefs.setString('modelType', value!);
                  setState(() {
                    modelType = value;
                  });
                },
              ),
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(0))),
            ),
            FutureBuilder(
              future: cacheDirImagesSize(),
              builder: (context, snapshot) {
                cacheDirInfo =
                    widget.prefs.getString('cacheDirInfo') ?? 'Calculating...';
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.data.toString() == "0 items") {
                    deleteEnabled = false;
                  } else {
                    deleteEnabled = true;
                  }
                  cacheDirInfo = snapshot.data.toString();
                  widget.prefs
                      .setString('cacheDirInfo', snapshot.data.toString());
                }
                return ListTile(
                  enabled: deleteEnabled,
                  trailing: Icon(
                    Icons.delete,
                    color: deleteEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text('Delete all photos'),
                  subtitle: Text(cacheDirInfo),
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
                            onPressed: () => Navigator.pop(context, 'No'),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context, 'Yes');
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
                  tileColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(0))),
                );
              },
            ),
          ],
        ).toList(),
      ),
    );
  }
}
