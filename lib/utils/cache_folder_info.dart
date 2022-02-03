import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:filesize/filesize.dart';
import 'package:path/path.dart';

Future<String?> cacheDirImagesSize() async {
  var cacheDir = await getTemporaryDirectory();
  var totalSize = 0;
  var totalCount = 0;
  try {
    var cacheDirList = cacheDir.list();
    await cacheDirList.forEach((f) {
      if (f is File && extension(f.path) == '.jpg' ||
          extension(f.path) == '.png') {
        totalSize += (f as File).lengthSync();
        totalCount++;
      }
    });
    if (totalCount == 0) {
      return '$totalCount items';
    } else if (totalCount == 1) {
      return '$totalCount item ${filesize(totalSize)}';
    } else {
      return '$totalCount items ${filesize(totalSize)}';
    }
  } catch (e) {
    print(e.toString());
  }
}

Future<void> deleteAllImages() async {
  var cacheDir = await getTemporaryDirectory();
  try {
    var cacheDirList = cacheDir.list();
    await cacheDirList.forEach((f) async {
      if (f is File && extension(f.path) == '.jpg' ||
          extension(f.path) == '.png') {
        await f.delete();
      }
    });
  } catch (e) {
    print(e.toString());
  }
}
