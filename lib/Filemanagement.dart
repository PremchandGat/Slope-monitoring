import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

class _Message {
  int whom;
  String text;
  _Message(this.whom, this.text);
}

int inputText;
var data;
var storedata = false;
var arr;
var save = false;
List files = [];

class FileManagement extends StatefulWidget {
  final BluetoothDevice server;

  const FileManagement({this.server});

  @override
  _FileManagement createState() => new _FileManagement();
}

class _FileManagement extends State<FileManagement> {
  static final clientID = 0;
  BluetoothConnection connection;
  var filename;
  List<_Message> messages = List<_Message>();
  String _messageBuffer = '';

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => connection != null && connection.isConnected;

  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection.input.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  fileListWidget() {
    if (files.isEmpty) {
      return [
        CupertinoButton(
            child: Text("Refresh"),
            onPressed: () {
              isConnected
                  ? _sendMessage("l")
                  : EasyLoading.showError("Device not connected");
            })
      ];
    } else {
      return [
        for (String i in files)
          ListTile(
            title: Text(i),
            trailing: IconButton(
                onPressed: () async {
                  if (isConnected) {
                    EasyLoading.show(status: "Please wait ...");
                    save = false;
                    _sendMessage("f");
                    await Future.delayed(const Duration(seconds: 4), () {});
                    var x = i.split(".TXT");
                    filename = x[0];
                    print(":::::::::::");
                    print(filename);
                    save = true;
                    _sendMessage(x[0]);
                  } else {
                    EasyLoading.showError("Device not connected");
                  }
                },
                icon: Icon(Icons.download)),
          )
      ];
    }
  }

  @override
  void dispose() {
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Row> list = messages.map((_message) {
      var str = _message.text.trim();
      print(str);
      if (save) {
        saveVideo(str, filename);
      }
      if (str.toString().toLowerCase().contains(".txt")) {
        //    print("//////////////" + str);
        if (files.contains(str)) {
        } else {
          setState(() {
            files.add(str);
            print(files);
          });
        }
      }
      if (str == "s") {
        save = false;
        EasyLoading.dismiss();
      }
      if (str.length < 25 || str.length > 29) {}
    }).toList();

    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting  to ' + widget.server.name + '...')
              : isConnected
                  ? Text('Connected to ' + widget.server.name)
                  : Text('Failed to connect ' + widget.server.name))),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        controller: listScrollController,
        children: <Widget>[
          ExpansionTile(
            trailing: IconButton(
              onPressed: () {
                setState(() {
                  files = [];
                });
                isConnected
                    ? _sendMessage("l")
                    : EasyLoading.showError("Device not connected");
              },
              icon: Icon(Icons.refresh),
            ),
            title: Text("Files"),
            children: fileListWidget(),
          ),
          Card(
              child: ElevatedButton(
            child: Text("Retrive File"),
            onPressed: () {
              isConnected
                  ? _sendMessage("f")
                  : EasyLoading.showError("Device not connected");
            },
          )),
          Card(
              child: ElevatedButton(
            child: Text("Delete File"),
            onPressed: () {
              isConnected
                  ? _sendMessage("g")
                  : EasyLoading.showError("Device not connected");
            },
          )),
          Container(height: 50),
        ],
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        messages.add(
          _Message(
            1,
            backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index),
          ),
        );
        _messageBuffer = dataString.substring(index);
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
              0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    textEditingController.clear();
    if (text.length > 0) {
      try {
        connection.output.add(utf8.encode(text + "\r\n"));
        await connection.output.allSent;

        setState(() {
          messages.add(_Message(clientID, text));
        });

        Future.delayed(Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(
              listScrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 333),
              curve: Curves.easeOut);
        });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}

Future<bool> saveVideo(data, name) async {
  Directory directory;
  try {
    if (Platform.isAndroid) {
      if (await _requestPermission(Permission.storage)) {
        directory = await getExternalStorageDirectory();
        String newPath = "";
        print(directory);
        List<String> paths = directory.path.split("/");
        for (int x = 1; x < paths.length; x++) {
          String folder = paths[x];
          if (folder != "Android") {
            newPath += "/" + folder;
          } else {
            break;
          }
        }
        newPath = newPath + "/BlueTooth_ArduinoGraph_data";
        directory = Directory(newPath);
      } else {
        return false;
      }
    } else {
      if (await _requestPermission(Permission.photos)) {
        directory = await getTemporaryDirectory();
      } else {
        return false;
      }
    }
    File saveFile = File(directory.path + "/$name.txt");
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    if (await directory.exists()) {
      await saveFile.writeAsString("${data.toString()}\n",
          mode: FileMode.append);
      return true;
    }
    return false;
  } catch (e) {
    print(e);
    return false;
  }
}

Future<bool> _requestPermission(Permission permission) async {
  if (await permission.isGranted) {
    return true;
  } else {
    var result = await permission.request();
    if (result == PermissionStatus.granted) {
      return true;
    }
  }
  return false;
}
