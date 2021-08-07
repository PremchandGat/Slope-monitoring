import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

List files = [];
bool save = false;
var fileData = "newFile";

class DeleteFiles extends StatefulWidget {
  final BluetoothDevice server;
  const DeleteFiles({this.server});
  @override
  _DeleteFiles createState() => new _DeleteFiles();
}

class _DeleteFiles extends State<DeleteFiles> {
  BluetoothConnection connection;
  var filename;
  String _messageBuffer = '';
  final TextEditingController textEditingController =
      new TextEditingController();
  bool isConnecting = true;
  bool get isConnected => connection != null && connection.isConnected;
  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();

    files = [];
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
      EasyLoading.showError(error.toString());
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
              setState(() {
                files = [];
              });
              isConnected
                  ? _sendMessage("g")
                  : EasyLoading.showError("Device not connected");
            })
      ];
    } else {
      return [
        for (String i in files)
          ListTile(
            title: Text(i),
            trailing: IconButton(
              icon: Icon(Icons.delete_forever),
              onPressed: () async {
                if (isConnected) {
                  var x = i.split(".TXT");
                  print(x);
                  filename = x[0];
                  fileData = x[0];
                  _sendMessage(x[0]);
                  await Future.delayed(Duration(seconds: 2));
                  setState(() {
                    files = [];
                  });
                } else {
                  EasyLoading.showError("Device not connected");
                }
              },
            ),
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
    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting  to ' + widget.server.name + '...')
              : isConnected
                  ? Text('Connected to ' + widget.server.name)
                  : Text('Failed to connect ' + widget.server.name))),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: <Widget>[
          ExpansionTile(
            title: Text("View Files"),
            initiallyExpanded: true,
            children: fileListWidget(),
          ),
          SizedBox(
            height: 10,
          ),
        ],
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;
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
        print(
          backspacesCounter > 0
              ? _messageBuffer.substring(
                  0, _messageBuffer.length - backspacesCounter)
              : _messageBuffer + dataString.substring(0, index),
        );
        if ((backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index))
            .contains("TXT")) {
          setState(() {
            files.add(backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index));
          });
        }
        if ((backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index))
            .contains("File started")) {
          EasyLoading.show(status: "Saving file");
          save = true;
        }
        if (save) {
          fileData = fileData.toString() +
              "\n" +
              (backspacesCounter > 0
                      ? _messageBuffer.substring(
                          0, _messageBuffer.length - backspacesCounter)
                      : _messageBuffer + dataString.substring(0, index))
                  .toString();
        }
        if ((backspacesCounter > 0
                ? _messageBuffer.substring(
                    0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index))
            .contains("File ended5")) {
          save = false;
          setState(() {
            files = [];
          });
          _sendMessage("g");
          EasyLoading.dismiss();
        }

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
      } catch (e) {
        setState(() {});
      }
    }
  }
}
