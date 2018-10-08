/*
 * Package : mqtt_client
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 27/06/2017
 * Copyright :  S.Hamblett
 */
import 'package:mqtt_client/mqtt_client.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'mqtt_client_test_connection_handler.dart';
import 'package:typed_data/typed_data.dart' as typed;

// Mock classes
class MockCH extends Mock implements MqttConnectionHandler {}

class MockCON extends Mock implements MqttNormalConnection {}

final TestConnectionHandlerNoSend testCHNS = TestConnectionHandlerNoSend();
final TestConnectionHandlerSend testCHS = TestConnectionHandlerSend();

void main() {
  group("Message Identifier", () {
    test("Numbering starts at 1", () {
      final MessageIdentifierDispenser dispenser = MessageIdentifierDispenser();
      expect(dispenser.getNextMessageIdentifier(), 1);
    });
    test("Numbering increments by 1", () {
      final MessageIdentifierDispenser dispenser = MessageIdentifierDispenser();
      final int first = dispenser.getNextMessageIdentifier();
      final int second = dispenser.getNextMessageIdentifier();
      expect(second, first + 1);
    });
    test("Numbering overflows back to 1", () {
      final MessageIdentifierDispenser dispenser = MessageIdentifierDispenser();
      dispenser.reset();
      for (int i = 0;
      i == MessageIdentifierDispenser.maxMessageIdentifier;
      i++) {
        dispenser.getNextMessageIdentifier();
      }
      // One more call should overflow us and reset us back to 1.
      expect(dispenser.getNextMessageIdentifier(), 1);
    });
  });

  group("Message registration", () {
    // Group wide
    final MockCON con = MockCON();
    var message;
    when(con.send(message)).thenReturn(() => print(message?.toString()));
    final MockCH ch = MockCH();
    testCHNS.connection = con;
    ch.connection = con;
    MessageCallbackFunction cbFunc;

    test("Register for publish messages", () {
      testCHNS.registerForMessage(MqttMessageType.publish, cbFunc);
      expect(
          testCHNS.messageProcessorRegistry
              .containsKey(MqttMessageType.publish),
          isTrue);
      expect(
          testCHNS.messageProcessorRegistry[MqttMessageType.publish], cbFunc);
    });
    test("Register for publish ack messages", () {
      testCHNS.registerForMessage(MqttMessageType.publishAck, cbFunc);
      expect(
          testCHNS.messageProcessorRegistry
              .containsKey(MqttMessageType.publishAck),
          isTrue);
      expect(testCHNS.messageProcessorRegistry[MqttMessageType.publishAck],
          cbFunc);
    });
    test("Register for publish complete messages", () {
      testCHNS.registerForMessage(MqttMessageType.publishComplete, cbFunc);
      expect(
          testCHNS.messageProcessorRegistry
              .containsKey(MqttMessageType.publishComplete),
          isTrue);
      expect(testCHNS.messageProcessorRegistry[MqttMessageType.publishComplete],
          cbFunc);
    });
    test("Register for publish received messages", () {
      testCHNS.registerForMessage(MqttMessageType.publishReceived, cbFunc);
      expect(
          testCHNS.messageProcessorRegistry
              .containsKey(MqttMessageType.publishReceived),
          isTrue);
      expect(testCHNS.messageProcessorRegistry[MqttMessageType.publishReceived],
          cbFunc);
    });
    test("Register for publish release messages", () {
      testCHNS.registerForMessage(MqttMessageType.publishRelease, cbFunc);
      expect(
          testCHNS.messageProcessorRegistry
              .containsKey(MqttMessageType.publishRelease),
          isTrue);
      expect(testCHNS.messageProcessorRegistry[MqttMessageType.publishRelease],
          cbFunc);
    });
  });

  group("Publishing", () {
    test("Publish at least once", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      pm.messageIdentifierDispenser.reset();
      final typed.Uint8Buffer buff = typed.Uint8Buffer(4);
      buff[0] = 't'.codeUnitAt(0);
      buff[1] = 'e'.codeUnitAt(0);
      buff[2] = 's'.codeUnitAt(0);
      buff[3] = 't'.codeUnitAt(0);
      final int msgId = pm.publish(
          PublicationTopic("A/rawTopic"), MqttQos.atMostOnce, buff, true);
      expect(msgId, 1);
      expect(pm.publishedMessages.containsKey(1), isFalse);
      final MqttPublishMessage pubMess =
      testCHS.sentMessages[0] as MqttPublishMessage;
      expect(pubMess.header.messageType, MqttMessageType.publish);
      expect(pubMess.variableHeader.messageIdentifier, 1);
      expect(pubMess.header.qos, MqttQos.atMostOnce);
      expect(pubMess.header.retain, true);
      expect(pubMess.variableHeader.topicName, "A/rawTopic");
      expect(pubMess.payload.toString(),
          "Payload: {4 bytes={<116><101><115><116>");
    });

    test("Publish at least once", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      final typed.Uint8Buffer buff = typed.Uint8Buffer(4);
      buff[0] = 't'.codeUnitAt(0);
      buff[1] = 'e'.codeUnitAt(0);
      buff[2] = 's'.codeUnitAt(0);
      buff[3] = 't'.codeUnitAt(0);
      pm.messageIdentifierDispenser.reset();
      final int msgId =
      pm.publish(PublicationTopic("A/rawTopic"), MqttQos.atLeastOnce, buff);
      expect(msgId, 1);
      expect(pm.publishedMessages.containsKey(1), isTrue);
      final MqttPublishMessage pubMess = pm.publishedMessages[1];
      expect(pubMess.header.messageType, MqttMessageType.publish);
      expect(pubMess.variableHeader.messageIdentifier, 1);
      expect(pubMess.header.qos, MqttQos.atLeastOnce);
      expect(pubMess.header.retain, false);
      expect(pubMess.variableHeader.topicName, "A/rawTopic");
      expect(pubMess.payload.toString(),
          "Payload: {4 bytes={<116><101><115><116>");
    });
    test("Publish at exactly once", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      pm.messageIdentifierDispenser.reset();
      final typed.Uint8Buffer buff = typed.Uint8Buffer(4);
      buff[0] = 't'.codeUnitAt(0);
      buff[1] = 'e'.codeUnitAt(0);
      buff[2] = 's'.codeUnitAt(0);
      buff[3] = 't'.codeUnitAt(0);
      final int msgId =
      pm.publish(PublicationTopic("A/rawTopic"), MqttQos.exactlyOnce, buff);
      expect(msgId, 1);
      expect(pm.publishedMessages.containsKey(1), isTrue);
      final MqttPublishMessage pubMess = pm.publishedMessages[1];
      expect(pubMess.header.messageType, MqttMessageType.publish);
      expect(pubMess.variableHeader.messageIdentifier, 1);
      expect(pubMess.header.qos, MqttQos.exactlyOnce);
      expect(pubMess.variableHeader.topicName, "A/rawTopic");
      expect(pubMess.payload.toString(),
          "Payload: {4 bytes={<116><101><115><116>");
    });
    test("Publish consecutive topics", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      final typed.Uint8Buffer buff = typed.Uint8Buffer(4);
      buff[0] = 't'.codeUnitAt(0);
      buff[1] = 'e'.codeUnitAt(0);
      buff[2] = 's'.codeUnitAt(0);
      buff[3] = 't'.codeUnitAt(0);
      final int msgId1 =
      pm.publish(PublicationTopic("A/rawTopic"), MqttQos.exactlyOnce, buff);
      final int msgId2 =
      pm.publish(PublicationTopic("A/rawTopic"), MqttQos.exactlyOnce, buff);
      expect(msgId2, msgId1 + 1);
    });
    test("Publish at least once and ack", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      pm.messageIdentifierDispenser.reset();
      final typed.Uint8Buffer buff = typed.Uint8Buffer(4);
      buff[0] = 't'.codeUnitAt(0);
      buff[1] = 'e'.codeUnitAt(0);
      buff[2] = 's'.codeUnitAt(0);
      buff[3] = 't'.codeUnitAt(0);
      final int msgId =
      pm.publish(PublicationTopic("A/rawTopic"), MqttQos.atLeastOnce, buff);
      expect(msgId, 1);
      pm.handlePublishAcknowledgement(
          MqttPublishAckMessage().withMessageIdentifier(msgId));
      expect(pm.publishedMessages.containsKey(1), isFalse);
    });
    test("Publish exactly once, release and complete", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      pm.messageIdentifierDispenser.reset();
      final typed.Uint8Buffer buff = typed.Uint8Buffer(4);
      buff[0] = 't'.codeUnitAt(0);
      buff[1] = 'e'.codeUnitAt(0);
      buff[2] = 's'.codeUnitAt(0);
      buff[3] = 't'.codeUnitAt(0);
      final int msgId =
      pm.publish(PublicationTopic("A/rawTopic"), MqttQos.exactlyOnce, buff);
      expect(msgId, 1);
      expect(pm.publishedMessages.containsKey(1), isTrue);
      pm.handlePublishReceived(
          MqttPublishReceivedMessage().withMessageIdentifier(msgId));
      final MqttPublishReleaseMessage pubMessRel =
      testCHS.sentMessages[1] as MqttPublishReleaseMessage;
      expect(pubMessRel.variableHeader.messageIdentifier, msgId);
      pm.handlePublishComplete(
          MqttPublishCompleteMessage().withMessageIdentifier(msgId));
      expect(pm.publishedMessages, isEmpty);
    });
    test("Publish recieved at most once", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      final int msgId = 1;
      final typed.Uint8Buffer data = typed.Uint8Buffer(3);
      data[0] = 0;
      data[1] = 1;
      data[2] = 2;
      final MqttPublishMessage pubMess = MqttPublishMessage()
          .withMessageIdentifier(msgId)
          .toTopic("A/rawTopic")
          .withQos(MqttQos.atMostOnce)
          .publishData(data);
      pm.handlePublish(pubMess);
      expect(pm.receivedMessages.containsKey(msgId), isFalse);
      expect(testCHS.sentMessages.isEmpty, isTrue);
    });
    test("Publish recieved at least once", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      final int msgId = 1;
      final typed.Uint8Buffer data = typed.Uint8Buffer(3);
      data[0] = 0;
      data[1] = 1;
      data[2] = 2;
      final MqttPublishMessage pubMess = MqttPublishMessage()
          .withMessageIdentifier(msgId)
          .toTopic("A/rawTopic")
          .withQos(MqttQos.atLeastOnce)
          .publishData(data);
      pm.handlePublish(pubMess);
      expect(pm.receivedMessages.containsKey(msgId), isFalse);
      expect(testCHS.sentMessages[0].header.messageType,
          MqttMessageType.publishAck);
    });
    test("Publish recieved exactly once", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      final int msgId = 1;
      final typed.Uint8Buffer data = typed.Uint8Buffer(3);
      data[0] = 0;
      data[1] = 1;
      data[2] = 2;
      final MqttPublishMessage pubMess = MqttPublishMessage()
          .withMessageIdentifier(msgId)
          .toTopic("A/rawTopic")
          .withQos(MqttQos.exactlyOnce)
          .publishData(data);
      pm.handlePublish(pubMess);
      expect(pm.receivedMessages.containsKey(msgId), isTrue);
      expect(testCHS.sentMessages[0].header.messageType,
          MqttMessageType.publishReceived);
    });
    test("Release recieved exactly once", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      final int msgId = 1;
      final typed.Uint8Buffer data = typed.Uint8Buffer(3);
      data[0] = 0;
      data[1] = 1;
      data[2] = 2;
      final MqttPublishMessage pubMess = MqttPublishMessage()
          .withMessageIdentifier(msgId)
          .toTopic("A/rawTopic")
          .withQos(MqttQos.exactlyOnce)
          .publishData(data);
      pm.handlePublish(pubMess);
      expect(pm.receivedMessages.containsKey(msgId), isTrue);
      expect(testCHS.sentMessages[0].header.messageType,
          MqttMessageType.publishReceived);
      final MqttPublishReleaseMessage relMess =
      MqttPublishReleaseMessage().withMessageIdentifier(msgId);
      pm.handlePublishRelease(relMess);
      expect(pm.receivedMessages.containsKey(msgId), isFalse);
      expect(testCHS.sentMessages[1].header.messageType,
          MqttMessageType.publishComplete);
    });
    test("Publish exactly once, interleaved scenario 1", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      pm.messageIdentifierDispenser.reset();
      final MqttClientPayloadBuilder payload1 = new MqttClientPayloadBuilder();
      payload1.addString("test1");
      final MqttClientPayloadBuilder payload2 = new MqttClientPayloadBuilder();
      payload2.addString("test2");
      final int msgId1 = pm.publish(
          PublicationTopic("topic1"), MqttQos.exactlyOnce, payload1.payload);
      expect(msgId1, 1);
      final int msgId2 = pm.publish(
          PublicationTopic("topic2"), MqttQos.exactlyOnce, payload2.payload);
      expect(msgId2, 2);
      expect(pm.publishedMessages.containsKey(msgId1), isTrue);
      expect(pm.publishedMessages.containsKey(msgId2), isTrue);
      expect(pm.publishedMessages.length, 2);
      testCHS.sentMessages.clear();
      pm.handlePublishReceived(
          MqttPublishReceivedMessage().withMessageIdentifier(msgId1));
      pm.handlePublishReceived(
          MqttPublishReceivedMessage().withMessageIdentifier(msgId2));
      expect(testCHS.sentMessages.length, 2);
      final MqttPublishReleaseMessage pubMessRel2 =
      testCHS.sentMessages[1] as MqttPublishReleaseMessage;
      expect(pubMessRel2.variableHeader.messageIdentifier, msgId2);
      final MqttPublishReleaseMessage pubMessRel1 =
      testCHS.sentMessages[0] as MqttPublishReleaseMessage;
      expect(pubMessRel1.variableHeader.messageIdentifier, msgId1);
      pm.handlePublishComplete(
          MqttPublishCompleteMessage().withMessageIdentifier(msgId1));
      pm.handlePublishComplete(
          MqttPublishCompleteMessage().withMessageIdentifier(msgId2));
      expect(pm.publishedMessages, isEmpty);
    });
    test("Publish exactly once, interleaved scenario 2", () {
      testCHS.sentMessages.clear();
      final PublishingManager pm = PublishingManager(testCHS);
      pm.messageIdentifierDispenser.reset();
      final MqttClientPayloadBuilder payload1 = new MqttClientPayloadBuilder();
      payload1.addString("test1");
      final MqttClientPayloadBuilder payload2 = new MqttClientPayloadBuilder();
      payload2.addString("test2");

      // Publish 1
      final int msgId1 = pm.publish(
          PublicationTopic("topic1"), MqttQos.exactlyOnce, payload1.payload);
      expect(pm.publishedMessages.length, 1);
      expect(pm.publishedMessages.containsKey(msgId1), isTrue);
      expect(msgId1, 1);
      expect(testCHS.sentMessages.length, 1);

      // PubRel 1
      pm.handlePublishReceived(
          MqttPublishReceivedMessage().withMessageIdentifier(msgId1));
      expect(testCHS.sentMessages.length, 2);

      // Publish 2
      final int msgId2 = pm.publish(
          PublicationTopic("topic2"), MqttQos.exactlyOnce, payload2.payload);
      expect(msgId2, 2);
      expect(pm.publishedMessages.length, 2);
      expect(pm.publishedMessages.containsKey(msgId2), isTrue);

      // PubRel 2
      pm.handlePublishReceived(
          MqttPublishReceivedMessage().withMessageIdentifier(msgId2));
      expect(testCHS.sentMessages.length, 4);
      final MqttPublishReleaseMessage pubMessRel1 =
      testCHS.sentMessages[1] as MqttPublishReleaseMessage;
      expect(pubMessRel1.variableHeader.messageIdentifier, msgId1);
      final MqttPublishReleaseMessage pubMessRel2 =
      testCHS.sentMessages[3] as MqttPublishReleaseMessage;
      expect(pubMessRel2.variableHeader.messageIdentifier, msgId2);

      // PubComp 1
      pm.handlePublishComplete(
          MqttPublishCompleteMessage().withMessageIdentifier(msgId1));
      expect(pm.publishedMessages.length, 1);
    });
  });
}
