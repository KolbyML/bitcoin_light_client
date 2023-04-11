// Copyright (c) 2021-2023 Kolby Moroz Liebl
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';

// same values just the List below is encoded in utf8
const String CHARS_ALPHA_NUM = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,;-_/:?@()";
const List<int> CHARS_ALPHA_NUM_BYTES = [97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 32, 46, 44, 59, 45, 95, 47, 58, 63, 64, 40, 41];

// converts uint8 to List of Little Endian Ints
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

// converts uint32 to List of Little Endian Ints
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

// converts uint64 to List of Little Endian Ints
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

// converts uint16 to List of Big Endian Ints
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

// converts uint32 to List of Big Endian Ints
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

// converts string to a padded List of charecters in utf8 format
List<int> getPaddedCommand(String command) {
  var spaceToPad = 12 - command.length;
  List<int> byteCommand = utf8.encode(command) + List.filled(spaceToPad, 0);
  return byteCommand;
}

// get an IPv4 string representation from bytes
String getIPv4String(List<int> data) {
  String ipAddress = data[0].toString()+'.'+data[1].toString()+'.'+data[2].toString()+'.'+data[3].toString();
  return ipAddress;
}

// get an IPv4 address in IPv6 extended format from a string
List<int> getIPv4ListInt(String data) {
  List<String> dataList = data.split(".");
  List<int> hexList = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, int.parse(dataList[0]), int.parse(dataList[1]), int.parse(dataList[2]), int.parse(dataList[3])];
  return hexList;
}

// remove trailing zero's in a byte list
List<int> removeTrailingZeros(List<int> data) {
  List<int> hexList = List.filled(0, 0, growable: true);
  data.forEach((element) {
    if (element != 0) {
      hexList += [element];
    }
  });
  return hexList;
}

// sanitize a string
String SanitizeString(String data) {
  String string = "";

  for (int i=0; i<data.length; i++) {
    if (CHARS_ALPHA_NUM.contains(data[i])) {
      string += data[i];
    }
  }
  return string;
}

// sanitize a string which was converted to a byte array
String SanitizeStringListInt(List<int> data) {
  String string = "";
  data.forEach((element) {
    if (CHARS_ALPHA_NUM_BYTES.contains(element)) {
      string += utf8.decode([element]);
    }
  });
  return string;
}

// generate a random 64 bit number
int getrandbits64() {
  var r = new Random();
  int random1 = r.nextInt(pow(2, 32).toInt());
  int random2 = r.nextInt(pow(2, 32).toInt());
  return ((random1 << 32) | random2).abs(); // 64bit random number
}
