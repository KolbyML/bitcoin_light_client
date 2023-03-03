// Copyright (c) 2021 Kolby Moroz Liebl
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'bitcoindart.dart';

// same values just the List below is encoded in utf8
const String CHARS_ALPHA_NUM = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,;-_/:?@()";
const List<int> CHARS_ALPHA_NUM_BYTES = [97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 32, 46, 44, 59, 45, 95, 47, 58, 63, 64, 40, 41];


List<int> uint8ToListIntLE(int interger) {
  var bdata = new ByteData(1);
  bdata.setInt8(0, interger);
  var _list = bdata.buffer.asUint8List();
  return _list.toList();
}

int listIntToUint8LE(List<int> list) {
  var _list = Uint8List.fromList(list);
  var byteData = _list.buffer.asByteData();
  return byteData.getInt8(0);
}

List<int> uint32ToListIntLE(int interger) {
  var bdata = new ByteData(4);
  bdata.setInt32(0, interger, Endian.little);
  var _list = bdata.buffer.asUint8List();
  return _list.toList();
}

int listIntToUint32LE(List<int> list) {
  var _list = Uint8List.fromList(list);
  var byteData = _list.buffer.asByteData();
  return byteData.getInt32(0, Endian.little);
}

List<int> uint64ToListIntLE(int interger) {
  var bdata = new ByteData(8);
  bdata.setInt64(0, interger, Endian.little);
  var _list = bdata.buffer.asUint8List();
  return _list.toList();
}

int listIntToUint64LE(List<int> list) {
  var _list = Uint8List.fromList(list);
  var byteData = _list.buffer.asByteData();
  return byteData.getInt64(0, Endian.little);
}

List<int> uint16ToListIntBE(int interger) {
  var bdata = new ByteData(2);
  bdata.setInt16(0, interger, Endian.big);
  var _list = bdata.buffer.asUint8List();
  return _list.toList();
}

int listIntToUint16BE(List<int> list) {
  var _list = Uint8List.fromList(list);
  var byteData = _list.buffer.asByteData();
  return byteData.getInt16(0, Endian.big);
}

List<int> uint32ToListIntBE(int interger) {
  var bdata = new ByteData(4);
  bdata.setInt32(0, interger, Endian.big);
  var _list = bdata.buffer.asUint8List();
  return _list.toList();
}

int listIntToUint32BE(List<int> list) {
  var _list = Uint8List.fromList(list);
  var byteData = _list.buffer.asByteData();
  return byteData.getInt32(0, Endian.big);
}

List<int> getPaddedCommand(String command) {
  var spaceToPad = 12 - command.length;
  List<int> byteCommand = utf8.encode(command) + List.filled(spaceToPad, 0);
  return byteCommand;
}

String getIPv4String(List<int> data) {
  String ipAddress = data[0].toString()+'.'+data[1].toString()+'.'+data[2].toString()+'.'+data[3].toString();
  return ipAddress;
}

List<int> getIPv4ListInt(String data) {
  List<String> dataList = data.split(".");
  List<int> hexList = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, int.parse(dataList[0]), int.parse(dataList[1]), int.parse(dataList[2]), int.parse(dataList[3])];
  return hexList;
}

List<int> removeTrailingZeros(List<int> data) {
  List<int> hexList = List<int>();
  data.forEach((element) {
    if (element != 0) {
      hexList += [element];
    }
  });
  return hexList;
}

String SanitizeString(String data) {
  String string = "";

  for (int i=0; i<data.length; i++) {
    if (CHARS_ALPHA_NUM.contains(data[i])) {
      string += data[i];
    }
  }
  return string;
}

String SanitizeStringListInt(List<int> data) {
  String string = "";
  data.forEach((element) {
    if (CHARS_ALPHA_NUM_BYTES.contains(element)) {
      string += utf8.decode([element]);
    }
  });
  return string;
}

int getrandbits64() {
  var r = new Random();
  int random1 = r.nextInt(pow(2, 32));
  int random2 = r.nextInt(pow(2, 32));
  return ((random1 << 32) | random2).abs(); // 64bit random number
}

class NodeListClass {
  Map<String, int> listOfNodes = Map<String, int>();

  NodeListClass({this.listOfNodes});

  factory NodeListClass.fromJson(Map<String, dynamic> json) {
    Map<String, int> tmp = Map<String, int>();
    for (var i = 0; i < json['nodelist'].length; i++) {
      tmp[json['nodelist'][i][0]] = json['nodelist'][i][1];
    }
    return NodeListClass(
      listOfNodes: tmp,
    );
  }
}

Future<NodeListClass> fetchNodeList() async {
  final response = await http.get(Uri.parse('https://omegablockchain.net/omeganodelist.json'));
  if (response.statusCode == 200) {
    print(jsonDecode(response.body));
    return NodeListClass.fromJson(json.decode(response.body));
  } else {
    print('Something went wrong. \nResponse Code : ${response.statusCode}');
    throw Error();
  }
}