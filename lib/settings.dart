import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'dart:async';

class _Message {
  int whom;
  var text;
  _Message(this.whom, this.text);
}

int inputText;
var data;
var storedata = false;
var arr;
var save = false;
List files = [];

class Settings extends StatefulWidget {
  final BluetoothDevice server;

  const Settings({this.server});

  @override
  _Settings createState() => new _Settings();
}

class _Settings extends State<Settings> {
  static final clientID = 0;
  BluetoothConnection connection;
  var filename;
  var awaypoint;
  var towardpoint;
  List<_Message> messages = [];
  String _messageBuffer = '';
  bool towardvalidate = false;
  bool awayValidate = false;
  var toward = TextEditingController();
  var away = TextEditingController();
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
    messages.map((_message) {
      var str = _message.text.toString().trim();
      print(str);
      if (str.contains("Away point is:")) {
        print(str);
        setState(() {
          awaypoint = str;
        });
      } else if (str.contains("Toward point is:")) {
        print(str);
        setState(() {
          towardpoint = str;
        });
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting  to ' + widget.server.name + '...')
              : isConnected
                  ? Text('Connected to ' + widget.server.name)
                  : Text('Connected to ' + widget.server.name))),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        controller: listScrollController,
        children: <Widget>[
          Container(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(awaypoint == null
                      ? "Refresh To get Away point"
                      : awaypoint.toString()),
                  Text(towardpoint == null
                      ? "Refresh To get Toward point"
                      : towardpoint.toString()),
                ],
              ),
              IconButton(
                  onPressed: () async {
                    EasyLoading.show(status: "Please wait");
                    _sendMessage("i");
                    await Future.delayed(const Duration(seconds: 2), () {});
                    _sendMessage("a");
                    await Future.delayed(const Duration(seconds: 2), () {});
                    _sendMessage("j");
                    await Future.delayed(const Duration(seconds: 2), () {});
                    _sendMessage("a");
                    await Future.delayed(const Duration(seconds: 2), () {});
                    EasyLoading.dismiss();
                  },
                  icon: Icon(Icons.refresh))
            ],
          ),
          CupertinoButton(
            color: Colors.cyan,
            child: Text("Start Callibration"),
            onPressed: () async {
              _sendMessage("h");
              EasyLoading.showToast("Callibration Started");
            },
          ),
          SizedBox(
            height: 10,
          ),
          CupertinoButton(
            color: Colors.cyan,
            child: Text("Stop Callibration"),
            onPressed: () async {
              _sendMessage("t");
              EasyLoading.showToast("Callibration Stopped");
            },
          ),
          SizedBox(
            height: 10,
          ),
          Container(
            width: MediaQuery.of(context).size.width * 90 / 100,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10), color: Colors.black12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
              child: TextField(
                keyboardType: TextInputType.number,
                controller: away,
                decoration: InputDecoration(
                  errorText: awayValidate == false
                      ? "Value must be positive int and less then 1000"
                      : null,
                  disabledBorder: InputBorder.none,
                  border: InputBorder.none,
                  hintText: "Set away Point ",
                ),
                onChanged: (value) {
                  setState(() {
                    try {
                      int x = int.parse(value);
                      awayValidate = x > 0 && x < 1000;
                      print(x);
                    } catch (e) {
                      print(e.toString());
                      awayValidate = false;
                    }
                  });
                },
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Container(
            width: MediaQuery.of(context).size.width * 90 / 100,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10), color: Colors.black12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
              child: TextField(
                keyboardType: TextInputType.number,
                controller: toward,
                decoration: InputDecoration(
                  errorText: towardvalidate == false
                      ? "Value must negative and greater then -1000"
                      : null,
                  disabledBorder: InputBorder.none,
                  border: InputBorder.none,
                  hintText: "Set toward Point ",
                ),
                onChanged: (value) {
                  setState(() {
                    try {
                      int x = int.parse(value);
                      towardvalidate = x < 0 && x > -1000;
                      print(x);
                    } catch (e) {
                      print(e.toString());
                      towardvalidate = false;
                    }
                  });
                },
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
          CupertinoButton(
            color: Colors.green,
            child: Text("Done"),
            onPressed: () async {
              if (isConnected) {
                EasyLoading.show(status: "Please wait.....");
                if (awayValidate) {
                  _sendMessage("i");
                  await Future.delayed(const Duration(seconds: 2), () {});
                  _sendMessage("b");
                  await Future.delayed(const Duration(seconds: 2), () {});
                  _sendInt(int.parse(away.text));
                  await Future.delayed(const Duration(seconds: 2), () {});
                } else if (towardvalidate) {
                  _sendMessage("j");
                  await Future.delayed(const Duration(seconds: 2), () {});
                  _sendMessage("b");
                  await Future.delayed(const Duration(seconds: 2), () {});
                  _sendInt(int.parse(toward.text));

                  await Future.delayed(const Duration(seconds: 2), () {});
                }
                EasyLoading.showToast("Done");
              } else {
                EasyLoading.showError("Device not connected");
              }
            },
          ),
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
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }

  void _sendInt(int text) async {
    textEditingController.clear();
    if (text > 0) {
      try {
        connection.output.add(utf8.encode(text.toString()));
        await connection.output.allSent;
        setState(() {
          messages.add(_Message(clientID, text));
        });
      } catch (e) {
        // Ignore error, but notify state
        EasyLoading.showError(e.toString());
        setState(() {});
      }
    }
  }
}
