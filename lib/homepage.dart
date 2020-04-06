import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:popiwishlist/playvideo.dart';
import 'package:popiwishlist/supportclasses.dart';
import 'package:sqflite/sqflite.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<List<DataFile>> _filesFuture;
  TextEditingController _controller = new TextEditingController();

  @override
  void initState() {
    super.initState();
    initVals();
  }

  void initVals() async {
    if (await initDb()) {
      setState(() {
        _filesFuture = _readSavedFiles();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Popi Play List'),
      ),
      body: FutureBuilder(
        future: _filesFuture,
        builder: (context, snapshot) {
          print(snapshot.connectionState);
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              List<DataFile> snapData = snapshot.data;
              List<Widget> widgets = [];
              snapData.forEach((f) {
                try {
                  File thumbImg = File(f.thumb);
                  try {
                    File(f.video);
                    widgets.add(
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => new PlayVideo(file: f))),
                        child: Container(
                          child: Row(
                            children: <Widget>[
                              Image.file(
                                thumbImg,
                                width: MediaQuery.of(context).size.width / 3,
                                height: MediaQuery.of(context).size.height / 3,
                                scale: .2,
                              ),
                              Container(width: 10),
                              GestureDetector(
                                onLongPress: () => showDialog(
                                    context: context,
                                    builder: (context) {
                                      _controller ??=
                                          new TextEditingController();
                                      _controller.text = f.name;
                                      return new AlertDialog(
                                        content: Wrap(
                                          children: <Widget>[
                                            TextField(
                                              controller: _controller,
                                            ),
                                          ],
                                        ),
                                        actions: <Widget>[
                                          RaisedButton(
                                            child: Text('Save'),
                                            color: Colors.green,
                                            onPressed: () async {
                                              await _changeName(
                                                  f.name, _controller);
                                              _controller = null;
                                              Navigator.pop(context);
                                              setState(() {
                                                _filesFuture =
                                                    _readSavedFiles();
                                              });
                                            },
                                          ),
                                          RaisedButton(
                                              child: Text('Discard'),
                                              color: Colors.red,
                                              onPressed: () =>
                                                  Navigator.pop(context))
                                        ],
                                      );
                                    }),
                                child: Container(
                                  width: MediaQuery.of(context).size.width / 2,
                                  child: Text(
                                    f.name,
                                    style: TextStyle(
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(),
                              ),
                              Container(
                                width: 10,
                              ),
                              GestureDetector(
                                onTap: () => showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        content:
                                            Text('Sure remove from wishlist?'),
                                        actions: <Widget>[
                                          RaisedButton(
                                            child: Text('Remove'),
                                            color: Colors.red,
                                            onPressed: () {
                                              _removeFileId(f.name);
                                              Navigator.pop(context);
                                              setState(() {
                                                _filesFuture =
                                                    _readSavedFiles();
                                              });
                                            },
                                          ),
                                          RaisedButton(
                                              child: Text('Cancel'),
                                              color: Colors.green,
                                              onPressed: () =>
                                                  Navigator.pop(context))
                                        ],
                                      );
                                    }),
                                child: Container(
                                  child: Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } catch (ex) {
                    widgets.add(Container());
                    _removeFileId(f.name);
                  }
                } catch (e) {
                  print(e);
                  _replaceThumbPath('files', f.video, f.name);
                }
              });
              return ListView(
                children: widgets,
              );
            } else {
              return Center(child: Text('Add new Videos'));
            }
          } else {
            return Center(
              child: Text('Please wait'),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addFile(),
        child: Icon(Icons.add),
      ),
    );
  }

  Future<File> _chooseFile() async {
    return await ImagePicker.pickVideo(source: ImageSource.gallery);
  }

  Future<String> _createThumb(String path) async {
    return await VideoThumbnail.thumbnailFile(
      video: path,
      thumbnailPath: (await getTemporaryDirectory()).path,
      imageFormat: ImageFormat.PNG,
      maxHeight: 0,
      quality: 0,
    );
  }

  _addFile() async {
    File video = await _chooseFile();
    final uint8list = await _createThumb(video.path);
    await _saveFileId(
        'files', video.path, uint8list, video.path.split('/').removeLast());
  }

  _saveFileId(
      String table, String videoLink, String thumbLink, String name) async {
    var databasesPath = await getDatabasesPath();
    String path = '${databasesPath}data.db';
    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      db.close();
    });
    try {
      Batch batch = database.batch();
      batch.insert(table, {
        'name': name,
        'video': videoLink,
        'thumb': thumbLink,
      });
      await batch.commit(noResult: true);
    } catch (e) {
      print(e);
    }
    setState(() {
      _filesFuture = _readSavedFiles();
    });
  }

  Future _replaceThumbPath(String table, String path, String name) async {
    var databasesPath = await getDatabasesPath();
    String path = '${databasesPath}data.db';
    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      db.close();
    });
    await database.rawQuery('update files set thumb=? where name =?',
        [await _createThumb(path), name]);
  }

  Future<List<DataFile>> _readSavedFiles() async {
    var databasesPath = await getDatabasesPath();
    String path = '${databasesPath}data.db';
    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      db.close();
    });
    List filesList = await database.rawQuery('select * from files');
    List<DataFile> filesOut = [];
    filesList.forEach((f) {
      filesOut.add(new DataFile(f['name'], f['video'], f['thumb']));
    });
    print(filesOut);
    return filesOut == [] ? null : filesOut;
  }

  Future<bool> initDb() async {
    try {
      Database database;
      var databasesPath = await getDatabasesPath();
      String path = '${databasesPath}data.db';

      database = await openDatabase(path, version: 1,
          onCreate: (Database db, int version) async {
        db.close();
      });
      Batch batch = database.batch();
      batch.execute(
          '''create table if not exists files(name text primary key,video text,thumb text)''');
      List l = await batch.commit(noResult: true);
      print(l);
    } catch (e) {
      print(e);
    }
    return true;
  }

  Future<void> _removeFileId(String name) async {
    var databasesPath = await getDatabasesPath();
    String path = '${databasesPath}data.db';
    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      db.close();
    });
    await database.rawQuery('delete from files where name =?', [name]);
  }

  _changeName(String name, TextEditingController controller) async {
    var databasesPath = await getDatabasesPath();
    String path = '${databasesPath}data.db';
    Database database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      db.close();
    });
    await database.rawQuery(
        'update files set name=? where name =?', [controller.text, name]);
    return;
  }
}
