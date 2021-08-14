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
  String text;
  _Message(this.whom, this.text);
}

class NewEntry extends StatefulWidget {
  final BluetoothDevice server;
  const NewEntry({this.server});
  @override
  _NewEntry createState() => new _NewEntry();
}

class _NewEntry extends State<NewEntry> {
  bool emailValid = true;
  var location = TextEditingController();
  var operator = TextEditingController();
  var customNumber = TextEditingController();
  bool numberValidate = true;
  bool custom = false;
  bool tare = false;
  bool previous = false;
  static final clientID = 0;
  BluetoothConnection connection;
  var filename;
  List<_Message> messages = [];
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
    }).toList();
    return Scaffold(
      appBar: AppBar(
          title: (isConnecting
              ? Text('Connecting to ' + widget.server.name + '...')
              : isConnected
                  ? Text('Connected to ' + widget.server.name)
                  : Text('Connected to' + widget.server.name))),
      body: ListView(
        children: <Widget>[
          SizedBox(
            height: 10,
          ),
          Container(
            width: MediaQuery.of(context).size.width * 90 / 100,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: Colors.black12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
              child: TextField(
                controller: operator,
                decoration: InputDecoration(
                    disabledBorder: InputBorder.none,
                    border: InputBorder.none,
                    hintText: "Enter Operator Name",
                    icon: Icon(Icons.engineering)),
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Container(
            width: MediaQuery.of(context).size.width * 90 / 100,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: Colors.black12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
              child: TextField(
                keyboardType: TextInputType.number,
                controller: location,
                decoration: InputDecoration(
                    errorText: emailValid == false ? "Not valid" : null,
                    disabledBorder: InputBorder.none,
                    border: InputBorder.none,
                    hintText: "Enter Location 00-99",
                    icon: Icon(Icons.location_city)),
                onChanged: (value) {
                  setState(() {
                    try {
                      int x = int.parse(value);
                      emailValid = x <= 99 && x >= 0 ? true : false;
                    } catch (e) {
                      print(e.toString());
                      emailValid = false;
                    }
                  });
                },
              ),
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Text(
            "Initial value: ",
            style: TextStyle(fontSize: 24),
          ),
          Row(
            children: [
              Text("Custom: "),
              Checkbox(
                  value: custom,
                  onChanged: (val) => setState(() {
                        custom = val;
                        tare = false;
                        previous = false;
                      })),
              Text("Tare :"),
              Checkbox(
                  value: tare,
                  onChanged: (val) => setState(() {
                        tare = val;
                        previous = false;
                        custom = false;
                      })),
              Text("Previous: "),
              Checkbox(
                  value: previous,
                  onChanged: (val) => setState(() {
                        previous = val;
                        custom = false;
                        tare = false;
                      })),
              SizedBox(
                height: 10,
              ),
            ],
          ),
          custom
              ? Container(
                  width: MediaQuery.of(context).size.width * 90 / 100,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: Colors.black12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      controller: customNumber,
                      decoration: InputDecoration(
                          errorText:
                              numberValidate == false ? "Not valid" : null,
                          disabledBorder: InputBorder.none,
                          border: InputBorder.none,
                          hintText: "Enter Number",
                          icon: Icon(Icons.dashboard_customize)),
                      onChanged: (value) {
                        setState(() {
                          try {
                            double x = double.parse(value);
                            numberValidate = true;
                            print(x);
                          } catch (e) {
                            print(e.toString());
                            numberValidate = false;
                          }
                        });
                      },
                    ),
                  ),
                )
              : Container(),
          SizedBox(
            height: 10,
          ),
          CupertinoButton(
              color: Colors.green,
              child: Text("Done"),
              onPressed: () async {
                if (isConnected) {
                  EasyLoading.show(status: "Please wait.....");
                  _sendMessage("k");
                  await Future.delayed(const Duration(seconds: 2), () {});
                  _sendMessage(operator.text);
                  await Future.delayed(const Duration(seconds: 2), () {});
                  _sendMessage(location.text);
                  await Future.delayed(const Duration(seconds: 2), () {});
                  tare ? _sendMessage("a") : print("Don't send a");
                  previous ? _sendMessage("b") : print("Don't send b");
                  custom ? _sendMessage("c") : print("Don't send c");
                  await Future.delayed(const Duration(seconds: 2), () {});
                  custom
                      ? _sendMessage(customNumber.text)
                      : print("Don't send custom number");
                  EasyLoading.dismiss();
                } else {
                  EasyLoading.showError("Device not connected");
                }
              }),
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
        connection.output.add(utf8.encode(text));
        await connection.output.allSent;

        setState(() {
          messages.add(_Message(clientID, text));
        });
      } catch (e) {
        print(e.toString());
        setState(() {});
      }
    }
  }
}
