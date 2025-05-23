
import 'package:arcore_flutter_plugin/src/arcore_augmented_image.dart';
import 'package:arcore_flutter_plugin/src/arcore_rotating_node.dart';
import 'package:arcore_flutter_plugin/src/utils/vector_utils.dart';
import 'package:flutter/services.dart';
import 'arcore_hit_test_result.dart';

import 'arcore_node.dart';
import 'arcore_plane.dart';

typedef StringResultHandler = void Function(String text);
typedef UnsupportedHandler = void Function(String text);
typedef ArCoreHitResultHandler = void Function(List<ArCoreHitTestResult> hits);
typedef ArCorePlaneHandler = void Function(ArCorePlane plane);
typedef ArCoreAugmentedImageTrackingHandler = void Function(
    ArCoreAugmentedImage);

const UTILS_CHANNEL_NAME = 'arcore_flutter_plugin/utils';

class ArCoreController {
  static checkArCoreAvailability() async {
    final bool arcoreAvailable = await MethodChannel(UTILS_CHANNEL_NAME)
        .invokeMethod('checkArCoreApkAvailability');
    return arcoreAvailable;
  }

  static checkIsArCoreInstalled() async {
    final bool arcoreInstalled = await MethodChannel(UTILS_CHANNEL_NAME)
        .invokeMethod('checkIfARCoreServicesInstalled');
    return arcoreInstalled;
  }

  ArCoreController(
      {int? id,
      this.enableTapRecognizer = false,
      this.enablePlaneRenderer = false,
      this.enableUpdateListener = false,
      this.debug = false
//    @required this.onUnsupported,
      }) {
    _channel = MethodChannel('arcore_flutter_plugin_$id');
    _channel?.setMethodCallHandler(_handleMethodCalls);
    init();
  }

  final bool enableUpdateListener;
  final bool enableTapRecognizer;
  final bool enablePlaneRenderer;
  final bool debug;
  MethodChannel? _channel;
  StringResultHandler? onError;
  StringResultHandler? onNodeTap;

//  UnsupportedHandler onUnsupported;
  ArCoreHitResultHandler? onPlaneTap;
  ArCorePlaneHandler? onPlaneDetected;
  String trackingState = '';
  ArCoreAugmentedImageTrackingHandler? onTrackingImage;

  init() async {
    try {
      await _channel?.invokeMethod<void>('init', {
        'enableTapRecognizer': enableTapRecognizer,
        'enablePlaneRenderer': enablePlaneRenderer,
        'enableUpdateListener': enableUpdateListener,
      });
    } on PlatformException catch (ex) {
      print(ex.message);
    }
  }

  Future<dynamic> _handleMethodCalls(MethodCall call) async {
    if (debug) {
      print('_platformCallHandler call ${call.method} ${call.arguments}');
    }

    switch (call.method) {
      case 'onError':
        onError?.call(call.arguments);
              break;
      case 'onNodeTap':
        onNodeTap?.call(call.arguments);
              break;
      case 'onPlaneTap':
        final List<dynamic> input = call.arguments;
        final objects = input
            .cast<Map<dynamic, dynamic>>()
            .map<ArCoreHitTestResult>(
                (Map<dynamic, dynamic> h) => ArCoreHitTestResult.fromMap(h))
            .toList();
        onPlaneTap?.call(objects);
              break;
      case 'onPlaneDetected':
        if (enableUpdateListener) {
          final plane = ArCorePlane.fromMap(call.arguments);
          onPlaneDetected?.call(plane);
        }
        break;
      case 'getTrackingState':
        // TRACKING, PAUSED or STOPPED
        trackingState = call.arguments;
        if (debug) {
          print('Latest tracking state received is: $trackingState');
        }
        break;
      case 'onTrackingImage':
        if (debug) {
          print('flutter onTrackingImage');
        }
        final arCoreAugmentedImage =
            ArCoreAugmentedImage.fromMap(call.arguments);
        onTrackingImage?.call(arCoreAugmentedImage);
        break;
      case 'togglePlaneRenderer':
        if (debug) {
          print('Toggling Plane Renderer Visibility');
        }
        togglePlaneRenderer();
        break;

      default:
        if (debug) {
          print('Unknown method ${call.method}');
        }
    }
    return Future.value();
  }

  Future<void> addArCoreNode(ArCoreNode node, {required String parentNodeName}) async {
    final params = _addParentNodeNameToParams(node.toMap(), parentNodeName);
    if (debug) {
      print(params.toString());
    }
    _addListeners(node);
    await _channel?.invokeMethod('addArCoreNode', params) ?? Future.value();
  }


  Future<String> togglePlaneRenderer() async {
    return await _channel?.invokeMethod('togglePlaneRenderer') ?? '';
  }

  Future<String> getTrackingState() async {
    return await _channel?.invokeMethod('getTrackingState') ?? '';
  }

  addArCoreNodeToAugmentedImage(ArCoreNode node, int index,
      {required String parentNodeName}) {

    final params = _addParentNodeNameToParams(node.toMap(), parentNodeName);
    return _channel?.invokeMethod(
        'attachObjectToAugmentedImage', {'index': index, 'node': params});
  }

  Future<void> addArCoreNodeWithAnchor(ArCoreNode node,
      {required String parentNodeName}) {
    final params = _addParentNodeNameToParams(node.toMap(), parentNodeName);
    if (debug) {
      print(params.toString());
    }
    _addListeners(node);
    if (debug) {
      print('---------_CALLING addArCoreNodeWithAnchor : $params');
    }
    return _channel?.invokeMethod('addArCoreNodeWithAnchor', params) ?? Future.value();
  }

  Future<void> removeNode({required String nodeName}) {
    return _channel?.invokeMethod('removeARCoreNode', {'nodeName': nodeName}) ?? Future.value();
  }

  Map<String, dynamic> _addParentNodeNameToParams(
      Map<String, dynamic> geometryMap, String parentNodeName) {
    if (parentNodeName.isNotEmpty)
      geometryMap['parentNodeName'] = parentNodeName;
    return geometryMap;
  }

  void _addListeners(ArCoreNode node) {
    node.position.addListener(() => _handlePositionChanged(node));
    node.shape.materials.addListener(() => _updateMaterials(node));

    if (node is ArCoreRotatingNode) {
      node.degreesPerSecond.addListener(() => _handleRotationChanged(node));
    }
  }

  void _handlePositionChanged(ArCoreNode node) {
    _channel?.invokeMethod<void>('positionChanged',
        _getHandlerParams(node, convertVector3ToMap(node.position.value)));
  }

  void _handleRotationChanged(ArCoreRotatingNode node) {
    _channel?.invokeMethod<void>('rotationChanged',
        {'name': node.name, 'degreesPerSecond': node.degreesPerSecond.value});
  }

  void _updateMaterials(ArCoreNode node) {
    _channel?.invokeMethod<void>(
        'updateMaterials', _getHandlerParams(node, node.shape.toMap()));
  }

  Map<String, dynamic> _getHandlerParams(
      ArCoreNode node, Map<String, dynamic> params) {
    final Map<String, dynamic> values = <String, dynamic>{'name': node.name}
      ..addAll(params);
    return values;
  }

  Future<void> loadSingleAugmentedImage({required Uint8List bytes}) {
    return _channel?.invokeMethod('load_single_image_on_db', {
      'bytes': bytes,
    }) ?? Future.value();
  }

  Future<void> loadMultipleAugmentedImage(
      {required Map<String, Uint8List> bytesMap}) {
    return _channel?.invokeMethod('load_multiple_images_on_db', {
      'bytesMap': bytesMap,
    }) ?? Future.value();
  }

  Future<void> loadAugmentedImagesDatabase({required Uint8List bytes}) {
    return _channel?.invokeMethod('load_augmented_images_database', {
      'bytes': bytes,
    }) ?? Future.value();
  }

  void dispose() {
    _channel?.invokeMethod<void>('dispose');
  }

  void resume() {
    _channel?.invokeMethod<void>('resume');
  }

  Future<void> removeNodeWithIndex(int index) async {
    try {
      return await _channel?.invokeMethod('removeARCoreNodeWithIndex', {
        'index': index,
      });
    } catch (ex) {
      print(ex);
    }
  }
}
