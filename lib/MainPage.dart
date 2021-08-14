import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:slop_monitoring/Filemanagement.dart';
import 'package:slop_monitoring/deleteFiles.dart';
import 'package:slop_monitoring/downloadedFileGraph.dart';
import 'package:slop_monitoring/newEntry.dart';
import 'package:slop_monitoring/settings.dart';
import 'graph.dart';
import './DiscoveryPage.dart';
import './SelectBondedDevicePage.dart';
import './ChatPage.dart';

class MainPage extends StatefulWidget {
  @override
  _MainPage createState() => new _MainPage();
}

class _MainPage extends State<MainPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  String _address = "...";
  String _name = "...";

  Timer _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  bool _autoAcceptPairingRequests = false;

  @override
  void initState() {
    super.initState();

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    Future.doWhile(() async {
      // Wait if adapter not enabled
      if (await FlutterBluetoothSerial.instance.isEnabled) {
        return false;
      }
      await Future.delayed(Duration(milliseconds: 0xDD));
      return true;
    }).then((_) {
      // Update the address field
      FlutterBluetoothSerial.instance.address.then((address) {
        setState(() {
          _address = address;
        });
      });
    });

    FlutterBluetoothSerial.instance.name.then((name) {
      setState(() {
        _name = name;
      });
    });

    // Listen for futher state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;

        // Discoverable mode is disabled when Bluetooth gets disabled
        _discoverableTimeoutTimer = null;
        _discoverableTimeoutSecondsLeft = 0;
      });
    });
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _discoverableTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.home),
        title: const Text('Slope Monitoring Sytem'),
      ),
      body: ListView(
        children: <Widget>[
          SizedBox(
            height: 10,
          ),
          Card(
            color: Colors.white38,
            child: ExpansionTile(
              title: const Text(
                'Bluetooth Settings',
                style: TextStyle(fontSize: 30),
              ),
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text('Enable Bluetooth'),
                    value: _bluetoothState.isEnabled,
                    onChanged: (bool value) {
                      // Do the request and update with the true value then
                      future() async {
                        // async lambda seems to not working
                        if (value)
                          await FlutterBluetoothSerial.instance.requestEnable();
                        else
                          await FlutterBluetoothSerial.instance
                              .requestDisable();
                      }

                      future().then((_) {
                        setState(() {});
                      });
                    },
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Bluetooth status'),
                    subtitle: Text(_bluetoothState.toString()),
                    trailing: ElevatedButton(
                      child: const Text('Settings'),
                      onPressed: () {
                        FlutterBluetoothSerial.instance.openSettings();
                      },
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Local adapter address'),
                    subtitle: Text(_address),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Local adapter name'),
                    subtitle: Text(_name),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: _discoverableTimeoutSecondsLeft == 0
                        ? const Text("Discoverable")
                        : Text(
                            "Discoverable for ${_discoverableTimeoutSecondsLeft}s"),
                    subtitle: const Text("PsychoX-Luna"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _discoverableTimeoutSecondsLeft != 0,
                          onChanged: null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () async {
                            print('Discoverable requested');
                            final int timeout = await FlutterBluetoothSerial
                                .instance
                                .requestDiscoverable(60);
                            if (timeout < 0) {
                              print('Discoverable mode denied');
                            } else {
                              print(
                                  'Discoverable mode acquired for $timeout seconds');
                            }
                            setState(() {
                              _discoverableTimeoutTimer?.cancel();
                              _discoverableTimeoutSecondsLeft = timeout;
                              _discoverableTimeoutTimer = Timer.periodic(
                                  Duration(seconds: 1), (Timer timer) {
                                setState(() {
                                  if (_discoverableTimeoutSecondsLeft < 0) {
                                    FlutterBluetoothSerial
                                        .instance.isDiscoverable
                                        .then((isDiscoverable) {
                                      if (isDiscoverable) {
                                        print(
                                            "Discoverable after timeout... might be infinity timeout :F");
                                        _discoverableTimeoutSecondsLeft += 1;
                                      }
                                    });
                                    timer.cancel();
                                    _discoverableTimeoutSecondsLeft = 0;
                                  } else {
                                    _discoverableTimeoutSecondsLeft -= 1;
                                  }
                                });
                              });
                            });
                          },
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Card(
            color: Colors.white38,
            child: ExpansionTile(
              title: const Text(
                'Main Menu',
                style: TextStyle(fontSize: 30),
              ),
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text('Auto-try specific pin when pairing'),
                    subtitle: const Text('Pin 1234'),
                    value: _autoAcceptPairingRequests,
                    onChanged: (bool value) {
                      setState(() {
                        _autoAcceptPairingRequests = value;
                      });
                      if (value) {
                        FlutterBluetoothSerial.instance
                            .setPairingRequestHandler(
                                (BluetoothPairingRequest request) {
                          print("Trying to auto-pair with Pin 1234");
                          if (request.pairingVariant == PairingVariant.Pin) {
                            return Future.value("1234");
                          }
                          return null;
                        });
                      } else {
                        FlutterBluetoothSerial.instance
                            .setPairingRequestHandler(null);
                      }
                    },
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 10,
                    ),
                    CupertinoButton(
                        color: Colors.cyan,
                        child: const Text('Explore Discovered Devices'),
                        onPressed: () async {
                          final BluetoothDevice selectedDevice =
                              await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return DiscoveryPage();
                              },
                            ),
                          );

                          if (selectedDevice != null) {
                            print('Discovery -> selected ' +
                                selectedDevice.address);
                          } else {
                            print('Discovery -> no device selected');
                          }
                        }),
                    SizedBox(
                      height: 10,
                    ),
                    CupertinoButton(
                      color: Colors.cyan,
                      child: const Text('Serial Terminal'),
                      onPressed: () async {
                        final BluetoothDevice selectedDevice =
                            await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) {
                              return SelectBondedDevicePage(
                                  checkAvailability: false);
                            },
                          ),
                        );

                        if (selectedDevice != null) {
                          print(
                              'Connect -> selected ' + selectedDevice.address);
                          _startChat(context, selectedDevice);
                        } else {
                          print('Connect -> no device selected');
                        }
                      },
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    CupertinoButton(
                        color: Colors.cyan,
                        child: const Text('Real-Time Data'),
                        onPressed: () async {
                          final BluetoothDevice selectedDevice =
                              await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return SelectBondedDevicePage(
                                    checkAvailability: false);
                              },
                            ),
                          );

                          if (selectedDevice != null) {
                            print('Connect -> selected ' +
                                selectedDevice.address);
                            _graph(context, selectedDevice);
                          } else {
                            print('Connect -> no device selected');
                          }
                        }),
                    SizedBox(
                      height: 10,
                    ),
                    CupertinoButton(
                        color: Colors.cyan,
                        child: const Text('New Entry'),
                        onPressed: () async {
                          final BluetoothDevice selectedDevice =
                              await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return SelectBondedDevicePage(
                                    checkAvailability: false);
                              },
                            ),
                          );

                          if (selectedDevice != null) {
                            print('Connect -> selected ' +
                                selectedDevice.address);
                            _newEntry(context, selectedDevice);
                          } else {
                            print('Connect -> no device selected');
                          }
                        }),
                    SizedBox(
                      height: 10,
                    ),
                    CupertinoButton(
                        color: Colors.cyan,
                        child: const Text('Download Files'),
                        onPressed: () async {
                          final BluetoothDevice selectedDevice =
                              await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return SelectBondedDevicePage(
                                    checkAvailability: false);
                              },
                            ),
                          );
                          if (selectedDevice != null) {
                            print('Connect -> selected ' +
                                selectedDevice.address);
                            _fileManagement(context, selectedDevice);
                          } else {
                            print('Connect -> no device selected');
                          }
                        }),
                    SizedBox(
                      height: 10,
                    ),
                    CupertinoButton(
                        color: Colors.cyan,
                        child: const Text('Delete Files'),
                        onPressed: () async {
                          final BluetoothDevice selectedDevice =
                              await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return SelectBondedDevicePage(
                                    checkAvailability: false);
                              },
                            ),
                          );
                          if (selectedDevice != null) {
                            print('Connect -> selected ' +
                                selectedDevice.address);
                            _deleteFiles(context, selectedDevice);
                          } else {
                            print('Connect -> no device selected');
                          }
                        }),
                    SizedBox(
                      height: 10,
                    ),
                    CupertinoButton(
                        color: Colors.cyan,
                        child: const Text('Settings'),
                        onPressed: () async {
                          final BluetoothDevice selectedDevice =
                              await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return SelectBondedDevicePage(
                                    checkAvailability: false);
                              },
                            ),
                          );

                          if (selectedDevice != null) {
                            print('Connect -> selected ' +
                                selectedDevice.address);
                            _settings(context, selectedDevice);
                          } else {
                            print('Connect -> no device selected');
                          }
                        }),
                    SizedBox(
                      height: 10,
                    ),
                    CupertinoButton(
                      color: Colors.cyan,
                      child: Text("View Graph of Downloaded File"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return ShowGraph();
                            },
                          ),
                        );
                      },
                    )
                  ],
                )
              ],
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(children: [
              Text(
                "Team EIC",
                style: TextStyle(color: Colors.black54),
              ),
              Text(
                "Associate Professor Dr. Rahul Raj Choudhary",
                style: TextStyle(color: Colors.black54),
              ),
              Text(
                "Electronic Instrumentation and control Engineering",
                style: TextStyle(color: Colors.black54),
              ),
              Text(
                "Engineering College Bikaner, Rajasthan, India",
                style: TextStyle(color: Colors.black54),
              ),
              Text(
                "Project leader: rahulrajchoudhary9@gmail.com",
                style: TextStyle(color: Colors.black54),
              ),
              Text(
                "Hardware developer: pushpendrarajpurohit@gmail.com",
                style: TextStyle(color: Colors.black54),
              ),
              Text(
                "App developer: premchandg278@gmail.com",
                style: TextStyle(color: Colors.black54),
              ),
            ]),
          )
        ],
      ),
    );
  }

  void _startChat(BuildContext context, BluetoothDevice server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return ChatPage(server: server);
        },
      ),
    );
  }

  void _newEntry(BuildContext context, BluetoothDevice server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return NewEntry(server: server);
        },
      ),
    );
  }

  void _fileManagement(BuildContext context, BluetoothDevice server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return FileManagement(server: server);
        },
      ),
    );
  }

  void _deleteFiles(BuildContext context, BluetoothDevice server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return DeleteFiles(server: server);
        },
      ),
    );
  }

  void _settings(BuildContext context, BluetoothDevice server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return NewSettings(server: server);
        },
      ),
    );
  }

  void _graph(BuildContext context, BluetoothDevice server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return GraphPage(server: server);
        },
      ),
    );
  }
}
