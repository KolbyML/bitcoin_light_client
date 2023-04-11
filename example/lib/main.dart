// Copyright (c) 2021-2023 Kolby Moroz Liebl
// Distributed under the MIT software license, see the accompanying
// file LICENSE or http://www.opensource.org/licenses/mit-license.php.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bitcoin_light_client/util.dart';
import 'package:bitcoin_light_client/bitcoin_light_client.dart';
import 'package:crypto/crypto.dart';

Map<List<int>, CAnonMsg> mapAnonMsg = Map<List<int>, CAnonMsg>();

// Custom Message Types
String anonmsg = "anonmsg";
String getanonmsg = "getanonmsg";

class CAnonMsg {
  int msgTime;
  int version = 1;
  String msgData;

  CAnonMsg() {
    msgTime = 0;
  }

  void setMessage(String msgContent) {
    msgTime = new DateTime.now().millisecondsSinceEpoch ~/ 1000;
    msgData = msgContent;
  }

  String getMessage() {
    return msgData;
  }

  int getTimestamp() {
    return msgTime;
  }

  String toString() {
    String string = ('CAnonMsg msgTime: $msgTime, msgData: $msgData');
    return string;
  }

  List<int> getHash() {
    return sha256.convert(sha256.convert(serialize()).bytes).bytes;
  }
  List<int> serialize() {
    List<int> messageData = uint64ToListIntLE(msgTime) + [utf8.encode(msgData).length] + utf8.encode(msgData);
    return messageData;
  }

  void deserialize(List<int> data) {
    msgTime = listIntToUint64LE(data.sublist(0, 8));
    int msgDataLength = listIntToUint8LE(data.sublist(8, 9));
    msgData = utf8.decode(data.sublist(9, 9 + msgDataLength.abs()), allowMalformed: true);
  }
}

class OmegaMessageNodes extends MessageNodes {
  OmegaMessageNodes(Socket inputsocket) : super(inputsocket);

  void customAddNode(String ip, [port = null]) {
    addOmegaNode(ip, port);
  }

  void extendVersion() {
    sendGetAnonMessage();
  }

  List<CInv> extendInv(List<CInv> msgInvData, List<CInv> msgGetDataInvData) {
    for (CInv k in msgInvData) {
      if (k.type == 20) {
        for (List<int> i in mapAnonMsg.keys) {
          if (IterableEquality().equals(k.hash, i)) {
            break;
          }
        }
        msgGetDataInvData.add(k);
      }
    }
    return msgGetDataInvData;
  }

  void extendCommandsSupported(MsgHeader msgHeader) {
    if (msgHeader.command == anonmsg) {
      CAnonMsg cAnonMsg = new CAnonMsg();
      cAnonMsg.deserialize(msgHeader.payload);

      // If we already have this message return and don't add it.
      if (mapAnonMsg.isNotEmpty) {
        for (var k in mapAnonMsg.keys) {
          if (IterableEquality().equals(k, cAnonMsg.getHash())) {
            return;
          }
        }
      }

      // Don't add message if it is over a day old
      if ((cAnonMsg.msgTime + 24*60*60) < DateTime.now().millisecondsSinceEpoch ~/ 1000) {
        return;
      }

      mapAnonMsg[cAnonMsg.getHash()] = cAnonMsg;

      MsgHeader anonMsgMessage = new MsgHeader();
      anonMsgMessage.command = anonmsg;
      anonMsgMessage.payload = cAnonMsg.serialize();
      relayMessage(anonMsgMessage.serialize());
    } else if (msgHeader.command == getanonmsg) {
      mapAnonMsg.values.forEach((cAnonMsg) {
        MsgHeader anonMsgMessage = new MsgHeader();
        anonMsgMessage.command = anonmsg;
        anonMsgMessage.payload = cAnonMsg.serialize();

        // send the message
        pushMessage(anonMsgMessage.serialize());
      });
    } else {
      // We don't support this command add code to tell the node to ignore us for it or something
    }
  }
}

void sendGetAnonMessage() {
  nodes.forEach((messageNodes) {
    MsgHeader getAnonMessage = new MsgHeader();
    getAnonMessage.command = getanonmsg;

    // send the message
    messageNodes.pushMessage(getAnonMessage.serialize());
  });
}

void sendAnonMessage(String message) {
  bool didWeAddMessage = false;
  nodes.forEach((messageNodes) {
    MsgHeader sendAnonMessage = new MsgHeader();
    CAnonMsg cAnonMsg = CAnonMsg();
    sendAnonMessage.command = anonmsg;
    cAnonMsg.setMessage(message);
    sendAnonMessage.payload = cAnonMsg.serialize();

    if (!didWeAddMessage) {
      mapAnonMsg[cAnonMsg.getHash()] = cAnonMsg;
      didWeAddMessage = true;
    }

    // send the message
    messageNodes.pushMessage(sendAnonMessage.serialize());
  });
}

void updateAnonMessage() {
  nodes.forEach((messageNodes) {
    MsgHeader getanonMessage = new MsgHeader();
    getanonMessage.command = getanonmsg;

    // send the message
    messageNodes.pushMessage(getanonMessage.serialize());
  });
}

void removeOldAnonMessage() {
  mapAnonMsg.keys.forEach((element) {
    if (((mapAnonMsg[element].getTimestamp() + 24*60*60) < (DateTime.now().millisecondsSinceEpoch ~/ 1000))) {
      mapAnonMsg.remove(element);
    }
  });
}

void startOmegaNode({Configuration configuration = null}) {
  if (configuration == null) {
    config = Configuration();
  } else {
    config = configuration;
  }

  // getnode list
  fetchNodeList().then((value) {
    nodeList = value.listOfNodes;

    // code start

    for (var k in nodeList.keys) {
      addOmegaNode(k, nodeList[k]);
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
          addOmegaNode(k, nodeList[k]);
        }
      }
    });
  });
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

int periodCount = 0;
bool addOmegaNode(String ip, [port = null]) {

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
    handleOmegaConnection(socket, true);
    periodCount--;
    return true;
  }, onError: (e) {
    // If we get a error connections failed return false
    print('Error $e');
    periodCount--;
    return false;
  });
}

void handleOmegaConnection(Socket node, bool didWeInitiateConnection){
  OmegaMessageNodes messageNodes = new OmegaMessageNodes(node);
  nodes.add(messageNodes);

  if (didWeInitiateConnection) {
    MsgHeader versionMessage = new MsgHeader();
    MsgVersion versionPayload = new MsgVersion();
    versionPayload.addr_from = CAddress.data(messageNodes.ip);
    versionMessage.command = version;
    versionMessage.payload = versionPayload.serialize();

    // send the message
    messageNodes.pushMessage(versionMessage.serialize());
    messageNodes.didWeSendVersion = true;
  }
}