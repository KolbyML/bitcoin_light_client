// Copyright (c) 2021 Kolby Moroz Liebl
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

library bitcoin_light_client;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'util.dart';
import 'package:crypto/crypto.dart';
import 'package:collection/collection.dart';

// Actually use global vars
List<int> IPV4_COMPAT = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff];
Map<String, int> nodeList = {'47.88.86.79': 8333, '165.227.84.200': 8333, '173.48.121.181': 8333, '47.88.86.79': 8333, };
List<MessageNodes> nodes = [];
ServerSocket server;
Configuration config;

class Configuration {
  String default_user_agent;
  int default_port;
  int connection_limit;
  List<int> magic;

  Configuration({String this.default_user_agent = "/Bitcoin Dart LN:1.0.0/", int this.default_port = 8333, int this.connection_limit = 6, List<int> this.magic = const [0xf9, 0xbe, 0xb4, 0xd9]});
}

// Default Message Types
String version = "version";
String verack = "verack";
String ping = "ping";
String pong = "pong";
String inv = "inv";
String getdata = "getdata";
String addr = "addr";
String getaddr = "getaddr";
String reject = "reject";

class MsgPing {
  int nonce;

  MsgPing() {
    nonce = getrandbits64();
  }

  List<int> serialize() {
    List<int> messageData = uint64ToListIntLE(nonce);
    return messageData;
  }

  void deserialize(List<int> data) {
    nonce = listIntToUint64LE(data.sublist(0,8));
  }
}

class MsgReject {
  String message;
  int ccode;
  String reason;

  MsgReject() {
    ccode = 0;
  }

  List<int> serialize() {
    List<int> messageData = uint8ToListIntLE(message.length) + utf8.encode(message) + uint8ToListIntLE(ccode) + uint8ToListIntLE(reason.length) + utf8.encode(reason);
    return messageData;
  }

  void deserialize(List<int> data) {
    int messageLength = listIntToUint8LE(data.sublist(0, 1));
    if (messageLength == 0) {
      message = "";
    } else {
      message = utf8.decode(data.sublist(1, 1 + messageLength));
    }
    ccode = listIntToUint8LE(data.sublist(1 + messageLength, 1 + messageLength + 1));
    int reasonLength = listIntToUint8LE(data.sublist(1 + messageLength + 1, 1 + messageLength + 2));
    if (reasonLength == 0) {
      reason = "";
    } else {
      reason = utf8.decode(data.sublist(1 + messageLength + 2, 1 + messageLength + 2 + reasonLength));
    }
  }
}

class CInv {
  int type;
  List<int> hash;

  CInv() {
    type = 0;
  }

  void setTypeAndHash(int inputType, List<int> inputHash) {
    type = inputType;
    hash = inputHash;
  }

  List<int> serialize() {
    List<int> messageData = uint32ToListIntLE(type) + hash;
    return messageData;
  }
}

class MsgInv {
  List<CInv> invVector;

  MsgInv() {
    invVector = [];
  }

  void deserialize(List<int> data) {
    int invCount = listIntToUint8LE(data.sublist(0, 1));
    for (var i=0; i < invCount; i++) {
      CInv cInv = CInv();
      cInv.setTypeAndHash(listIntToUint32LE(data.sublist(1 + (36 * i), 5 + (36 * i))), data.sublist(5 + (36 * i), 37 + (36 * i)));
      invVector.add(cInv);
    }
  }
}

class MsgGetData {
  List<CInv> invVector;

  MsgGetData() {
    invVector = [];
  }

  List<int> serialize() {
    List<int> messageData = uint8ToListIntLE(invVector.length);
    for (var i=0; i < invVector.length; i++) {
      messageData += invVector[i].serialize();
    }
    return messageData;
  }

  void deserialize(List<int> data) {
    int invCount = listIntToUint8LE(data.sublist(0, 1));
    for (var i=0; i < invCount; i++) {
      CInv cInv = CInv();
      cInv.setTypeAndHash(listIntToUint32LE(data.sublist(1 + (36 * i), 5 + (36 * i))), data.sublist(5 + (36 * i), 37 + (36 * i)));
      invVector.add(cInv);
    }
  }
}

class MsgVersion {
  int version;
  int services;
  int timestamp;
  CAddress addr_recv;
  CAddress addr_from;
  int nonce;
  String user_agent;
  int start_height;
  int relay;

  MsgVersion() {
    version = 70210;
    services = 0;
    timestamp = new DateTime.now().millisecondsSinceEpoch ~/ 1000;
    addr_recv = CAddress.data("127.0.0.1");
    addr_from = CAddress();
    nonce = getrandbits64();
    user_agent = config.default_user_agent;
    start_height = 0;
    relay = 0;
  }

  List<int> serialize() {
    List<int> messageData = uint32ToListIntLE(version) + uint64ToListIntLE(services) + uint64ToListIntLE(timestamp) + addr_recv.serialize() + addr_from.serialize() + uint64ToListIntLE(nonce) + uint8ToListIntLE(user_agent.length) + utf8.encode(user_agent) + uint32ToListIntLE(start_height) + [relay];
    return messageData;
  }

  void deserialize(List<int> data) {
    version = listIntToUint32LE(data.sublist(0, 4));
    services = listIntToUint64LE(data.sublist(4, 12));
    timestamp = listIntToUint64LE(data.sublist(12, 20));
    addr_recv = CAddress.data("127.0.0.1");
    addr_from = CAddress();
    nonce = listIntToUint64LE(data.sublist(72,80));
    int userAgentLength = listIntToUint8LE(data.sublist(80, 81));
    if (userAgentLength == 0) {
      user_agent = "";
    } else {
      user_agent = utf8.decode(data.sublist(81, 81 + userAgentLength));
    }
    start_height = listIntToUint32LE(data.sublist(81 + userAgentLength, 81 + userAgentLength + 4));
    relay = listIntToUint8LE(data.sublist(81 + userAgentLength + 4, 81 + userAgentLength + 5));
  }
}

class MsgHeader {
  List<int> _magic;
  String _command;
  int _length;
  int _checksum;
  List<int> _payload;

  List<int> get magic => _magic;

  set magic(List<int> value) {
    _magic = value;
  }

  MsgHeader() {
    _magic = config.magic;
    _command = "";
    _length = 0;
    _checksum = 0;
    _payload = new List<int>();
  }

  List<int> serialize() {
    List<int> checksum = sha256.convert(sha256.convert(_payload).bytes).bytes.sublist(0, 4);
    List<int> messageData = _magic + getPaddedCommand(_command) + uint32ToListIntLE(_payload.length) + checksum + _payload;
    return messageData;
  }

  void deserialize(List<int> data) {
    _command = utf8.decode(removeTrailingZeros(data.sublist(4,16)));
    _length = listIntToUint32LE(data.sublist(16,20));
    _checksum = listIntToUint32LE(data.sublist(20,24));
    _payload = data.sublist(24, 24 + _length);
  }

  String get command => _command;

  set command(String value) {
    _command = value;
  }

  int get length => _length;

  set length(int value) {
    _length = value;
  }

  int get checksum => _checksum;

  set checksum(int value) {
    _checksum = value;
  }

  List<int> get payload => _payload;

  set payload(List<int> value) {
    _payload = value;
  }
}

class MessageNodes {
  Socket socket;
  String ip;
  int port;
  bool fSuccessfullyConnected;
  bool didWeSendVersion;
  List<int> socketDataBuffer = [];

  MessageNodes(Socket inputsocket) {
    socket = inputsocket;
    ip = socket.remoteAddress.address;
    port = socket.remotePort;
    fSuccessfullyConnected = false;
    didWeSendVersion = false;

    socket.listen(processMessages,
        onError: errorHandler,
        onDone: finishedHandler);
  }

  void processMessages(List<int> data) {
    //
    // Message format
    //  (4) message start
    //  (12) command
    //  (4) size
    //  (4) checksum
    //  (x) data
    //
    socketDataBuffer = socketDataBuffer + data;
    List<int> mutableDataList = new List<int>.from(data);
    Map<int, List<int>> listOfTcpPackets = new Map<int, List<int>>();
    List<int> dataTmp = [];
    int k = 0;

    bool continueWhileLoop = true;
    while (socketDataBuffer.isNotEmpty && continueWhileLoop) {
      if (IterableEquality().equals([socketDataBuffer[0], socketDataBuffer[1], socketDataBuffer[2], socketDataBuffer[3]], config.magic)) {
        int size = listIntToUint32LE(socketDataBuffer.sublist(16,20));
        int checksum = listIntToUint32LE(socketDataBuffer.sublist(20,24));

        // if buffer doesn't hold enough data to use sublist breakout
        if (socketDataBuffer.length < 24 + size) {
          continueWhileLoop = false;
          break;
        }

        List<int> payloadData =  socketDataBuffer.sublist(24, 24 + size);
        int checksumCalculated = listIntToUint32LE(sha256.convert(sha256.convert(payloadData).bytes).bytes.sublist(0, 4));

        if (checksum == checksumCalculated) {
          listOfTcpPackets[k] = [];
          listOfTcpPackets[k] = socketDataBuffer.sublist(0, 24 + size);
          k += 1;

          if (socketDataBuffer.length > 24 + size) {
            dataTmp.clear();
            dataTmp = new List<int>.from(socketDataBuffer.sublist(24 + size));
            socketDataBuffer.clear();
            socketDataBuffer = new List<int>.from(dataTmp);
          } else {
            continueWhileLoop = false;
          }
        }
      }
    }

    listOfTcpPackets.values.forEach((element) {
      processMessage(element);
    });
  }

  void processMessage(List<int> data){
    MsgHeader msgHeader = new MsgHeader();
    msgHeader.deserialize(data);
    String strCommand = msgHeader._command;
    print('ProcessMessage: Message Command: $strCommand');


    if (msgHeader._command == version) {
      if (!didWeSendVersion) {
        MsgHeader versionMessage = new MsgHeader();
        MsgVersion versionPayload = new MsgVersion();
        versionPayload.addr_from = CAddress.data(ip);
        versionMessage._command = version;
        versionMessage._payload = versionPayload.serialize();

        // send the message
        pushMessage(versionMessage.serialize());
        didWeSendVersion = true;
      }

      MsgHeader verackMessage = new MsgHeader();
      verackMessage._command = verack;

      // send the message
      pushMessage(verackMessage.serialize());

      extendVersion();

    } else if (msgHeader._command == verack) {
      fSuccessfullyConnected = true;
    } else if (msgHeader._command == ping) {
      MsgHeader pongMessage = new MsgHeader();
      MsgPing pongPayload = new MsgPing();
      pongPayload.deserialize(msgHeader._payload);
      pongMessage._command = pong;
      pongMessage._payload = pongPayload.serialize();

      // send the message
      pushMessage(pongMessage.serialize());
    } else if (msgHeader._command == pong) {
      // We don't check so we will never get this as we don't care
    } else if (msgHeader._command == inv) {
      MsgInv msgInv = MsgInv();
      msgInv.deserialize(msgHeader._payload);

      MsgGetData msgGetData = MsgGetData();

      msgGetData.invVector = extendInv(msgInv.invVector, msgGetData.invVector);

      if (msgGetData.invVector.isNotEmpty) {
        MsgHeader msgGetMessage = new MsgHeader();
        msgGetMessage._command = getdata;
        msgGetMessage._payload = msgGetData.serialize();

        pushMessage(msgGetMessage.serialize());
      }

    } else if (msgHeader._command == getdata) {
      // We don't check so we will never get this as we don't care
    } else if (msgHeader._command == addr) {
      MsgAddr msgAddr = MsgAddr();
      msgAddr.deserialize(msgHeader._payload);

      List<CAddress> okAddr = msgAddr.addrList;
      List<CAddressLite> okAddrG = [];

      for (int i = 0; i < okAddr.length; i++) {
        if (okAddr[i].port == 7777) {
          okAddrG.add(CAddressLite(okAddr[i].ip, okAddr[i].port));
        }
      }

      List<CAddressLite> okAddrGG = okAddrG.toSet().toList();

      // any nodes we get try to add.
      for (int i = 0; i < okAddrGG.length; i++) {
        if (nodes.length <= 6) {
          customAddNode(okAddrGG[i].ip, okAddrGG[i].port);
        }
      }
    } else if (msgHeader._command == reject) {
      MsgReject msgReject = new MsgReject();
      msgReject.deserialize(msgHeader._payload);
      String message = msgReject.message;
      int ccode = msgReject.ccode;
      String reason = msgReject.reason;

      print('ERROR code: $ccode\n'
          'message: $message\n'
          'reason: $reason\n');
    } else {
      extendCommandsSupported(msgHeader);
    }
  }

  void customAddNode(String ip, [port = null]) {
    addNode(ip, port);
  }

  void extendVersion() {
  }

  List<CInv> extendInv(List<CInv> msgInvData, List<CInv> msgGetDataInvData) {
    return msgGetDataInvData;
  }

  void extendCommandsSupported(MsgHeader msgHeader) {
  }

  void errorHandler(error){
    print('$ip:$port Error: $error');
    removeNode(this);
    socket.close();
  }

  void finishedHandler() {
    print('$ip:$port Disconnected');
    removeNode(this);
    socket.close();
  }

  void pushMessage(List<int> data) {
    socket.add(data);
  }
}

void startServerSocket(int port) {
  ServerSocket.bind(InternetAddress.anyIPv4, port)
      .then((ServerSocket socket) {
    server = socket;
    server.listen((node) {
      handleConnection(node, false);
    });
  });
}

void startNode({Configuration configuration = null, Map<String, int> customNodeList = null}) {
  if (configuration == null) {
    config = Configuration();
  } else {
    config = configuration;
  }

  if (customNodeList != null) {
    nodeList = customNodeList;
  }

  for (var k in nodeList.keys) {
    addNode(k, nodeList[k]);
  }

  for (var i = 0; i < nodes.length; i++) {
    sendGetAddrMessage(nodes[i]);
  }

  Timer.periodic(Duration(seconds: 20), (timer) {
    if (nodes.length <= 6) {
      for (var i = 0; i < nodes.length; i++) {
        sendGetAddrMessage(nodes[i]);
      }
    }
    // if nodes are ever zero try to add nodes from nodes list again
    if (nodes.length == 0) {
      for (var k in nodeList.keys) {
        addNode(k, nodeList[k]);
      }
    }
  });
}

// Hacky way to limit the connections works like a semiphore
int periodCount = 0;
bool addNode(String ip, [port = null]) {

  if (port == null) {
    port = config.default_port;
  }

  periodCount++;
  if (periodCount >= config.connection_limit) {
    periodCount--;
    return false;
  }
  if (nodes.length > config.connection_limit) {
    periodCount--;
    return false;
  }

  // If node is already connected don't add it
  for (var i = 0; i < nodes.length; i++) {
    if (nodes[i].ip == ip) {
      periodCount--;
      return false;
    }
  }

  Socket.connect(ip, port).then((Socket socket) {
    handleConnection(socket, true);
    periodCount--;
    return true;
  }, onError: (e) {
    // If we get a error connections failed return false
    print('Error $e');
    periodCount--;
    return false;
  });
}

void handleConnection(Socket node, bool didWeInitiateConnection){
  MessageNodes messageNodes = new MessageNodes(node);
  nodes.add(messageNodes);

  if (didWeInitiateConnection) {
    MsgHeader versionMessage = new MsgHeader();
    MsgVersion versionPayload = new MsgVersion();
    versionPayload.addr_from = CAddress.data(messageNodes.ip);
    versionMessage._command = version;
    versionMessage._payload = versionPayload.serialize();

    // send the message
    messageNodes.pushMessage(versionMessage.serialize());
    messageNodes.didWeSendVersion = true;
  }
}

void removeNode(MessageNodes messageNodes) {
  nodes.remove(messageNodes);
}

void relayMessage(List<int> message) {
  nodes.forEach((messageNodes) {
    messageNodes.pushMessage(message);
  });
}

void sendGetAddrMessage(MessageNodes messageNodes) {
  MsgHeader getAddrMessage = new MsgHeader();
  getAddrMessage._command = getaddr;

  // send the message
  messageNodes.pushMessage(getAddrMessage.serialize());
}

class MsgAddr {
  List<CAddress> addrList;

  MsgAddr() {
    addrList = [];
  }

  void deserialize(List<int> data) {
    int addrCount = listIntToUint8LE(data.sublist(0, 1));
    for (var i=0; i < addrCount; i++) {
      CAddress cAddress = CAddress.notVersion();

      String ip;
      if (IterableEquality().equals(data.sublist(13 + (30 * i), 25 + (30 * i)), IPV4_COMPAT)) {
        ip = getIPv4String(data.sublist(25, 29));
      } else {
        ip; // I didn't write code to support IPv6, but if I did it would be here.
        // we are passing cause we don't want to handle IPv6 nodes
        continue;
      }
      cAddress.setData(listIntToUint32LE(data.sublist(1 + (30 * i), 5 + (30 * i))), listIntToUint64LE(data.sublist(5 + (30 * i), 13 + (30 * i))), ip, listIntToUint16BE(data.sublist(29 + (30 * i), 31 + (30 * i))).abs());
      addrList.add(cAddress);
    }
  }
}

class CAddress {
  int nServices;
  int nTime;
  String ip;
  int port;
  bool isVersionMessage;

  CAddress() {
    nServices = 0;
    ip = "0.0.0.0";
    port = config.default_port;
    nTime = new DateTime.now().millisecondsSinceEpoch ~/ 1000;
    isVersionMessage = true;
  }

  CAddress.data(String ipIn, [int portIn = null, int nServicesIn = 0]) {
    nServices = nServicesIn;
    ip = ipIn;
    port = (portIn == null) ? config.default_port : portIn;
    nTime = new DateTime.now().millisecondsSinceEpoch ~/ 1000;
    isVersionMessage = true;
  }

  CAddress.notVersion() {
    nServices = 0;
    ip = "0.0.0.0";
    port = config.default_port;
    nTime = new DateTime.now().millisecondsSinceEpoch ~/ 1000;
    isVersionMessage = false;
  }

  void setData(int inputTime, int inputService, String inputIp, int inputPort) {
    nServices = inputService;
    ip = inputIp;
    port = inputPort;
    nTime = inputTime;
  }

  List<int> serialize() {
    List<int> messageData;
    if (isVersionMessage) {
      messageData = uint64ToListIntLE(nServices) + getIPv4ListInt(ip) + uint16ToListIntBE(port);
    } else {
      messageData = uint32ToListIntLE(nTime) + uint64ToListIntLE(nServices) + getIPv4ListInt(ip) + uint16ToListIntBE(port);
    }
    return messageData;
  }

  void deserialize(List<int> data) {
    if (isVersionMessage) {
      nServices = listIntToUint64LE(data.sublist(0, 8));
      if (data.sublist(8, 20) == IPV4_COMPAT) {
        ip = getIPv4String(data.sublist(20, 24));
      } else {
        ip; // I didn't write code to support IPv6, but if I did it would be here.
      }
      port = listIntToUint16BE(data.sublist(24, 26));
    } else {
      nTime = listIntToUint32LE(data.sublist(0, 4));
      nServices = listIntToUint64LE(data.sublist(4, 12));
      if (IterableEquality().equals(data.sublist(12, 24), IPV4_COMPAT)) {
        ip = getIPv4String(data.sublist(24, 28));
      } else {
        ip; // I didn't write code to support IPv6, but if I did it would be here.
      }
      port = listIntToUint16BE(data.sublist(28, 30));
    }
  }
}

class CAddressLite {
  String ip;
  int port;

  CAddressLite(String inputIp, int inputPort) {
    ip = inputIp;
    port = inputPort;
  }
}

