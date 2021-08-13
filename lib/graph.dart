import 'dart:convert';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'package:syncfusion_flutter_charts/charts.dart';

class _Message {
  int whom;
  String text;
  _Message(this.whom, this.text);
}

double inputText = 10.0;
List displacement = [];
List time = [];
var warning = 0.0;
var data;
var storedata = false;
var alarm;
var arr;
var date;
var save = false;

class Displacement1 {
  Displacement1(this.year, this.sales);
  final String year;
  final double sales;
}

class GraphPage extends StatefulWidget {
  final BluetoothDevice server;

  const GraphPage({this.server});

  @override
  _GraphPage createState() => new _GraphPage();
}

class _GraphPage extends State<GraphPage> {
  static final clientID = 0;
  BluetoothConnection connection;
  var filename;
  List<_Message> messages = [];
  String _messageBuffer = '';
  final TextEditingController textEditingController =
      new TextEditingController();
  bool isConnecting = true;
  bool get isConnected => connection != null && connection.isConnected;
  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();
    displacement = [];
    time = [];
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
    _sendMessage("b");
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
              ? Text('Connecting Graph to ' + widget.server.name + '...')
              : isConnected
                  ? Text('Live Graph with ' + widget.server.name)
                  : Text('Graph log with ' + widget.server.name))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12.0),
          children: <Widget>[
            Column(
              children: [
                Container(
                  child: date == null
                      ? Text("Date not available")
                      : Text("Date Year/month/day : $date"),
                ),
              ],
            ),
            SwitchListTile(
              title: Text("Alarm status: "),
              value: alarm == 0 ? true : false,
              onChanged: (val) async {
                EasyLoading.show(status: "Please wait...");
                val ? _sendMessage("d") : _sendMessage("c");
                await Future.delayed(Duration(seconds: 4));
                EasyLoading.showToast(
                    alarm == 0 ? "Alarm Enabled" : "Alarm disabled");
              },
            ),
            GestureDetector(
              child: Container(
                height: 600,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: warning == 1.0 ? Colors.red : Colors.black38,
                    borderRadius: BorderRadius.all(Radius.circular(30))),
                child: SfCartesianChart(
                  zoomPanBehavior: ZoomPanBehavior(
                      // Enables pinch zooming
                      enablePinching: true),
                  primaryXAxis: CategoryAxis(),
                  title: ChartTitle(text: 'x: Displacement    y: Time'),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <ChartSeries<Displacement1, String>>[
                    LineSeries<Displacement1, String>(
                        enableTooltip: true,
                        dataSource: <Displacement1>[
                          for (var i = 0; i < displacement.length; i += 1)
                            Displacement1(time[time.length - 1 - i],
                                displacement[displacement.length - 1 - i])
                        ],
                        xValueMapper: (Displacement1 sales, _) => sales.year,
                        yValueMapper: (Displacement1 sales, _) => sales.sales,
                        dataLabelSettings: DataLabelSettings(isVisible: true))
                  ],
                ),
              ),
            ),
            Container(
              height: 50,
            ),
            Slider(
                min: 10,
                max: 100,
                value: inputText == null ? 5 : inputText,
                onChanged: (val) {
                  print(val);
                  setState(() {
                    inputText = val.floorToDouble();
                  });
                }),
            Container(height: 10),
            Card(
                child: ElevatedButton(
              child: Text("Start"),
              onPressed: () {
                _sendMessage("a");
              },
            )),
            Card(
                child: ElevatedButton(
              child: Text("Stop"),
              onPressed: () {
                _sendMessage("b");
              },
            )),
          ],
        ),
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
      var str = (backspacesCounter > 0
              ? _messageBuffer.substring(
                  0, _messageBuffer.length - backspacesCounter)
              : _messageBuffer + dataString.substring(0, index))
          .trim();
      print(str.length);
      if (str.length < 25 || str.length > 29) {
      } else {
        if (save != true) {
          var arr = str.split(',');
          print(arr);
          setState(() {
            date = "${arr[1]}/${arr[2]}/${arr[3]}";
            print("cccccccccccccc" + inputText.toString());
            if (inputText > time.length) {
              displacement = List.from(displacement.reversed);
              displacement.add(double.parse(arr[0]));
              displacement = List.from(displacement.reversed);
              time = List.from(time.reversed);
              time.add("${arr[4]}:${arr[5]}:${arr[6]}");
              time = List.from(time.reversed);
            } else if (inputText < time.length &&
                inputText < displacement.length) {
              time = List.from(time.reversed)
                  .sublist(time.length - inputText.toInt());
              time = List.from(time.reversed);
              displacement = List.from(displacement.reversed)
                  .sublist(displacement.length - inputText.toInt());
              displacement = List.from(displacement.reversed);
            } else {
              for (int i = displacement.length - 1; i >= 0; i--) {
                if (i == 0) {
                  displacement[0] = double.parse(arr[0]);
                } else {
                  displacement[i] = displacement[i - 1];
                }
              }
              for (int i = time.length - 1; i >= 0; i--) {
                if (i == 0) {
                  time[0] = "${arr[4]}:${arr[5]}:${arr[6]}";
                } else {
                  time[i] = time[i - 1];
                }
              }
            }
            print("displacemetn" + displacement.toString());
            print("time" + time.toString());
            warning = double.parse(arr[7]);
            alarm = double.parse(arr[8]);
          });
        }
      }
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
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}
