import 'package:test/test.dart';

import 'package:bitcoin_light_client/util.dart';

void main() {
  test('get padded comment', () {
    expect(getPaddedCommand("test"), [116, 101, 115, 116, 0, 0, 0, 0, 0, 0, 0, 0]);
    expect(getPaddedCommand("padded"), [112, 97, 100, 100, 101, 100, 0, 0, 0, 0, 0, 0]);
    expect(getPaddedCommand("comment"), [99, 111, 109, 109, 101, 110, 116, 0, 0, 0, 0, 0]);
  });
  test('getIPv4String', () {
    expect(getIPv4String([192, 168, 1, 1]), '192.168.1.1');
    expect(getIPv4String([222, 222, 222, 222]), '222.222.222.222');
    expect(getIPv4String([123, 1, 123, 3]), '123.1.123.3');
  });
  test('getIPv4ListInt', () {
    expect(getIPv4ListInt('192.168.1.1'), [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 192, 168, 1, 1]);
    expect(getIPv4ListInt('222.222.222.222'), [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 222, 222, 222, 222]);
    expect(getIPv4ListInt('123.1.123.3'), [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 123, 1, 123, 3]);
  });
}
