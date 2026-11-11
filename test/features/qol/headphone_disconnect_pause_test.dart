import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:softify/features/qol/headphone_disconnect_pause.dart';

void main() {
  group('PauseOnDisconnectEnabledNotifier tests', () {
    test('defaults to true and toggles correctly', () {
      final notifier = PauseOnDisconnectEnabledNotifier(null);
      expect(notifier.state, isTrue);

      notifier.toggle();
      expect(notifier.state, isFalse);

      notifier.toggle();
      expect(notifier.state, isTrue);

      notifier.setEnabled(false);
      expect(notifier.state, isFalse);

      notifier.setEnabled(true);
      expect(notifier.state, isTrue);
    });
  });

  group('HeadphoneDisconnectPauseHandler device recognition tests', () {
    test('identifies headphone and Bluetooth device types accurately', () {
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.wiredHeadphones,
        ),
        isTrue,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.wiredHeadset,
        ),
        isTrue,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.bluetoothA2dp,
        ),
        isTrue,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.bluetoothSco,
        ),
        isTrue,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.bluetoothLe,
        ),
        isTrue,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.usbAudio,
        ),
        isTrue,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.hearingAid,
        ),
        isTrue,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.airPlay,
        ),
        isTrue,
      );
    });

    test('identifies internal speaker and earpiece as non-headphones', () {
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.builtInSpeaker,
        ),
        isFalse,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.builtInEarpiece,
        ),
        isFalse,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.builtInSpeakerSafe,
        ),
        isFalse,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetoothType(
          AudioDeviceType.hdmi,
        ),
        isFalse,
      );
    });

    test('isHeadphoneOrBluetooth checks output direction and type', () {
      final headphoneOutput = AudioDevice(
        id: '1',
        name: 'Sony WH-1000XM4',
        isInput: false,
        isOutput: true,
        type: AudioDeviceType.bluetoothA2dp,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetooth(headphoneOutput),
        isTrue,
      );

      final micInput = AudioDevice(
        id: '2',
        name: 'Headset Mic',
        isInput: true,
        isOutput: false,
        type: AudioDeviceType.wiredHeadset,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetooth(micInput),
        isFalse,
      );

      final speaker = AudioDevice(
        id: '3',
        name: 'Built-in Speaker',
        isInput: false,
        isOutput: true,
        type: AudioDeviceType.builtInSpeaker,
      );
      expect(
        HeadphoneDisconnectPauseHandler.isHeadphoneOrBluetooth(speaker),
        isFalse,
      );
    });

    test('hasHeadphonesOrBluetooth returns true only if collection contains headphones', () {
      final speaker = AudioDevice(
        id: '1',
        name: 'Speaker',
        isInput: false,
        isOutput: true,
        type: AudioDeviceType.builtInSpeaker,
      );
      final bluetooth = AudioDevice(
        id: '2',
        name: 'AirPods Pro',
        isInput: false,
        isOutput: true,
        type: AudioDeviceType.bluetoothA2dp,
      );

      expect(
        HeadphoneDisconnectPauseHandler.hasHeadphonesOrBluetooth([speaker]),
        isFalse,
      );
      expect(
        HeadphoneDisconnectPauseHandler.hasHeadphonesOrBluetooth([speaker, bluetooth]),
        isTrue,
      );
    });
  });

  group('HeadphoneDisconnectPauseHandler simulation & callbacks', () {
    test('simulateDisconnect notifies onPauseTriggered listener', () async {
      HeadphoneDisconnectReason? caughtReason;
      final handler = HeadphoneDisconnectPauseHandler(
        onPauseTriggered: (reason) {
          caughtReason = reason;
        },
      );

      await handler.simulateDisconnect(reason: HeadphoneDisconnectReason.deviceDisconnected);
      expect(caughtReason, equals(HeadphoneDisconnectReason.deviceDisconnected));

      handler.dispose();
      expect(handler.isDisposed, isTrue);
    });
  });

  group('PauseOnDisconnectTile widget tests', () {
    testWidgets('renders standard switch list tile with default state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PauseOnDisconnectTile(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pause on Headphone Disconnect'), findsOneWidget);
      expect(
        find.text('Automatically pauses playback when headphones or Bluetooth devices disconnect.'),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
    });

    testWidgets('renders card mode with custom subtitle', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PauseOnDisconnectTile.card(
                subtitle: 'Custom pause description test',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pause on Headphone Disconnect'), findsOneWidget);
      expect(find.text('Custom pause description test'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('toggling switch updates pauseOnDisconnectEnabledProvider and fires callback', (tester) async {
      late WidgetRef refHolder;
      bool callbackFired = false;
      bool? callbackValue;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  refHolder = ref;
                  return PauseOnDisconnectTile(
                    onChanged: (val) {
                      callbackFired = true;
                      callbackValue = val;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(refHolder.read(pauseOnDisconnectEnabledProvider), isTrue);

      // Tap to toggle off
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(refHolder.read(pauseOnDisconnectEnabledProvider), isFalse);
      expect(callbackFired, isTrue);
      expect(callbackValue, isFalse);
    });
  });
}
