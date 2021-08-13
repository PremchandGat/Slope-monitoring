import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ShowGraph extends StatefulWidget {
  const ShowGraph({Key key}) : super(key: key);

  @override
  _ShowGraphState createState() => _ShowGraphState();
}

class SalesData {
  SalesData(this.year, this.sales);
  String year;
  double sales;
}

class _ShowGraphState extends State<ShowGraph> {
  var file;
  var data;
  final List<SalesData> chartData = [];
  getFile() async {
    FilePickerResult result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        file = File(result.files.single.path);
      });
      try {
        data = await file.readAsLines();
        for (var item in data) {
          if (item.length < 30 && item.length > 25) {
            List temp = item.toString().split(",");
            setState(() {
              chartData.add(SalesData(
                  "${temp[4]}:${temp[5]}:${temp[6]}", double.parse(temp[0])));
            });
          }
        }
      } catch (e) {
        EasyLoading.showError("File not supported");
      }
    } else {
      EasyLoading.showToast("No file selected !!", dismissOnTap: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("View Graph"),
        ),
        body: ListView(
          children: [
            Container(
                child: SfCartesianChart(
                    zoomPanBehavior: ZoomPanBehavior(
                        // Enables pinch zooming
                        enablePinching: true),
                    title: ChartTitle(text: 'x: Displacement    y: Time'),
                    tooltipBehavior: TooltipBehavior(
                      enable: true,
                    ),
                    primaryXAxis: CategoryAxis(),
                    series: <ChartSeries>[
                  // Renders line chart
                  LineSeries<SalesData, String>(
                      dataSource: chartData,
                      xValueMapper: (SalesData sales, _) => sales.year,
                      yValueMapper: (SalesData sales, _) => sales.sales)
                ])),
            CupertinoButton(
              color: Colors.green,
              child: Text("Open New File"),
              onPressed: () {
                setState(() {
                  chartData.clear();
                  file = null;
                });
                getFile();
              },
            )
          ],
        ));
  }
}
