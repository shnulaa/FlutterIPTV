import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// DLNA 渲染器服务 (DMR - Digital Media Renderer)
/// 让手机 App 可以发现并投屏到本设备
class DlnaService {
  static final DlnaService _instance = DlnaService._internal();
  factory DlnaService() => _instance;
  DlnaService._internal();

  // SSDP 多播地址和端口
  static const String _ssdpAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;

  // 服务端口
  int _httpPort = 8200;

  // 设备信息
  String _deviceUuid = '';
  String _deviceName = 'Lotus IPTV';
  String? _localIp;

  // 服务状态
  RawDatagramSocket? _ssdpSocket;
  HttpServer? _httpServer;
  bool _isRunning = false;

  // 播放回调
  Function(String url, String? title)? onPlayUrl;
  Function()? onPause;
  Function()? onStop;
  Function(int volume)? onSetVolume;
  Function(Duration position)? onSeek;

  // 当前播放状态
  // 状态: NO_MEDIA_PRESENT, STOPPED, TRANSITIONING, PLAYING, PAUSED_PLAYBACK
  String _transportState = 'NO_MEDIA_PRESENT';
  String _currentUri = '';
  String _currentTitle = '';
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  int _volume = 100;
  DateTime? _playStartTime; // 播放开始时间，用于计算模拟位置
  
  // 事件订阅管理
  final Map<String, String> _eventSubscriptions = {}; // SID -> callback URL

  bool get isRunning => _isRunning;
  String get deviceName => _deviceName;

  /// 启动 DLNA 服务
  Future<bool> start({String? customName}) async {
    if (_isRunning) return true;

    try {
      // 生成设备 UUID
      await _generateDeviceUuid();
      
      if (customName != null) {
        _deviceName = customName;
      }

      // 获取本地 IP
      _localIp = await _getLocalIpAddress();
      if (_localIp == null) {
        debugPrint('DLNA: 无法获取本地 IP 地址');
        return false;
      }

      debugPrint('DLNA: 本地 IP: $_localIp');

      // 启动 HTTP 服务器
      if (!await _startHttpServer()) {
        return false;
      }

      // 启动 SSDP 服务
      if (!await _startSsdpService()) {
        await _httpServer?.close();
        return false;
      }

      _isRunning = true;
      debugPrint('DLNA: 服务已启动 - $_deviceName (http://$_localIp:$_httpPort)');
      return true;
    } catch (e) {
      debugPrint('DLNA: 启动失败 - $e');
      return false;
    }
  }

  /// 停止 DLNA 服务
  Future<void> stop() async {
    _isRunning = false;
    _ssdpSocket?.close();
    _ssdpSocket = null;
    await _httpServer?.close();
    _httpServer = null;
    debugPrint('DLNA: 服务已停止');
  }

  /// 更新播放状态
  void updatePlayState({
    String? state,
    Duration? position,
    Duration? duration,
  }) {
    if (state != null && state != _transportState) {
      _transportState = state;
      // 状态变化时通知订阅者
      _notifyAllSubscribers();
    }
    if (position != null) {
      _currentPosition = position;
      // 如果正在播放，重置播放开始时间以保持位置同步
      if (_transportState == 'PLAYING') {
        _playStartTime = DateTime.now();
      }
    }
    if (duration != null) _currentDuration = duration;
  }

  /// 生成设备 UUID
  Future<void> _generateDeviceUuid() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        _deviceUuid = 'uuid:${info.id}-lotus-iptv';
        _deviceName = 'Lotus IPTV (${info.model})';
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        _deviceUuid = 'uuid:${info.deviceId}-lotus-iptv';
        _deviceName = 'Lotus IPTV (${info.computerName})';
      } else {
        _deviceUuid = 'uuid:lotus-iptv-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      _deviceUuid = 'uuid:lotus-iptv-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// 获取本地 IP 地址
  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        final name = interface.name.toLowerCase();
        // 跳过虚拟网卡
        if (name.contains('virtual') || name.contains('vmware') ||
            name.contains('docker') || name.contains('veth')) {
          continue;
        }

        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }

      // 如果没找到 192.168 开头的，返回第一个非回环地址
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('DLNA: 获取 IP 失败 - $e');
    }
    return null;
  }

  /// 启动 HTTP 服务器
  Future<bool> _startHttpServer() async {
    try {
      _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, _httpPort);
      debugPrint('DLNA: HTTP 服务器启动在端口 $_httpPort');

      _httpServer!.listen(_handleHttpRequest);
      return true;
    } catch (e) {
      debugPrint('DLNA: HTTP 服务器启动失败 - $e');
      return false;
    }
  }

  /// 启动 SSDP 服务
  Future<bool> _startSsdpService() async {
    try {
      // 查找对应的网络接口
      NetworkInterface? targetInterface;
      try {
        final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
        for (var iface in interfaces) {
          for (var addr in iface.addresses) {
            if (addr.address == _localIp) {
              targetInterface = iface;
              debugPrint('DLNA: 找到网络接口 ${iface.name} 对应 IP $_localIp');
              break;
            }
          }
          if (targetInterface != null) break;
        }
      } catch (e) {
        debugPrint('DLNA: 获取网络接口失败 - $e');
      }

      // 尝试绑定到多播地址 239.255.255.250:1900
      // 这是接收 SSDP M-SEARCH 请求的标准方式
      try {
        _ssdpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _ssdpPort,
          reuseAddress: true,
          reusePort: true,
        );
        debugPrint('DLNA: SSDP socket 绑定到 0.0.0.0:$_ssdpPort');
      } catch (e) {
        debugPrint('DLNA: 绑定 1900 端口失败: $e，尝试备用端口');
        // 如果 1900 端口被占用，使用随机端口
        _ssdpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );
        debugPrint('DLNA: SSDP socket 绑定到备用端口 ${_ssdpSocket!.port}');
      }

      // 加入多播组
      try {
        final multicastAddr = InternetAddress(_ssdpAddress);
        if (targetInterface != null) {
          _ssdpSocket!.joinMulticast(multicastAddr, targetInterface);
          debugPrint('DLNA: 已加入多播组 $_ssdpAddress (接口: ${targetInterface.name})');
        } else {
          _ssdpSocket!.joinMulticast(multicastAddr);
          debugPrint('DLNA: 已加入多播组 $_ssdpAddress (默认接口)');
        }
      } catch (e) {
        debugPrint('DLNA: 加入多播组失败 - $e');
        // 即使加入多播组失败，也继续运行，因为 NOTIFY 广播仍然可以工作
      }

      // 设置多播 TTL
      _ssdpSocket!.multicastHops = 4;
      
      // 启用多播回环（用于本机测试）
      _ssdpSocket!.multicastLoopback = true;

      // 监听请求
      _ssdpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _ssdpSocket!.receive();
          if (datagram != null) {
            _handleSsdpRequest(datagram);
          }
        }
      }, onError: (e) {
        debugPrint('DLNA: SSDP 监听错误 - $e');
      });

      debugPrint('DLNA: SSDP 服务启动成功');

      // 立即发送多次 NOTIFY 广播
      for (int i = 0; i < 3; i++) {
        _sendSsdpNotify();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 定期发送广播
      Timer.periodic(const Duration(seconds: 15), (_) {
        if (_isRunning) _sendSsdpNotify();
      });

      return true;
    } catch (e) {
      debugPrint('DLNA: SSDP 服务启动失败 - $e');
      return false;
    }
  }

  /// 处理 SSDP 请求
  void _handleSsdpRequest(Datagram datagram) {
    final message = utf8.decode(datagram.data);
    
    // 只处理 M-SEARCH 请求，忽略其他 NOTIFY 消息
    if (message.startsWith('M-SEARCH')) {
      // 检查是否在搜索媒体渲染器
      if (message.contains('ssdp:all') ||
          message.contains('upnp:rootdevice') ||
          message.contains('urn:schemas-upnp-org:device:MediaRenderer:1') ||
          message.contains('urn:schemas-upnp-org:service:AVTransport:1')) {
        
        debugPrint('DLNA: 收到 M-SEARCH 请求来自 ${datagram.address.address}:${datagram.port}');
        _sendSsdpResponse(datagram.address, datagram.port);
      }
    }
  }

  /// 发送 SSDP 响应
  void _sendSsdpResponse(InternetAddress address, int port) {
    final response = '''HTTP/1.1 200 OK\r
CACHE-CONTROL: max-age=1800\r
DATE: ${HttpDate.format(DateTime.now())}\r
EXT:\r
LOCATION: http://$_localIp:$_httpPort/description.xml\r
SERVER: Lotus IPTV/1.0 UPnP/1.0 DLNADOC/1.50\r
ST: urn:schemas-upnp-org:device:MediaRenderer:1\r
USN: $_deviceUuid::urn:schemas-upnp-org:device:MediaRenderer:1\r
\r
''';

    _ssdpSocket?.send(utf8.encode(response), address, port);
    debugPrint('DLNA: 发送 SSDP 响应到 ${address.address}:$port');
  }

  /// 发送 SSDP NOTIFY 广播
  void _sendSsdpNotify() {
    final notify = '''NOTIFY * HTTP/1.1\r
HOST: $_ssdpAddress:$_ssdpPort\r
CACHE-CONTROL: max-age=1800\r
LOCATION: http://$_localIp:$_httpPort/description.xml\r
NT: urn:schemas-upnp-org:device:MediaRenderer:1\r
NTS: ssdp:alive\r
SERVER: Lotus IPTV/1.0 UPnP/1.0 DLNADOC/1.50\r
USN: $_deviceUuid::urn:schemas-upnp-org:device:MediaRenderer:1\r
\r
''';

    _ssdpSocket?.send(
      utf8.encode(notify),
      InternetAddress(_ssdpAddress),
      _ssdpPort,
    );
  }

  /// 处理 HTTP 请求
  void _handleHttpRequest(HttpRequest request) async {
    final path = request.uri.path;
    final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    debugPrint('DLNA: HTTP ${request.method} $path (来自 $clientIp)');

    try {
      if (path == '/description.xml') {
        await _handleDeviceDescription(request);
      } else if (path == '/AVTransport/scpd.xml') {
        await _handleAvTransportScpd(request);
      } else if (path == '/RenderingControl/scpd.xml') {
        await _handleRenderingControlScpd(request);
      } else if (path == '/ConnectionManager/scpd.xml') {
        await _handleConnectionManagerScpd(request);
      } else if (path == '/AVTransport/control') {
        await _handleAvTransportControl(request);
      } else if (path == '/RenderingControl/control') {
        await _handleRenderingControlControl(request);
      } else if (path == '/ConnectionManager/control') {
        await _handleConnectionManagerControl(request);
      } else if (path.endsWith('/event')) {
        // 处理事件订阅
        await _handleEventSubscription(request);
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    } catch (e) {
      debugPrint('DLNA: HTTP 处理错误 - $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  /// 处理事件订阅请求
  Future<void> _handleEventSubscription(HttpRequest request) async {
    debugPrint('DLNA: 事件订阅请求 ${request.method} ${request.uri.path}');
    
    if (request.method == 'SUBSCRIBE') {
      // 获取回调 URL
      final callback = request.headers.value('CALLBACK');
      final sid = 'uuid:${DateTime.now().millisecondsSinceEpoch}';
      
      if (callback != null) {
        // 提取 URL (格式: <http://...>)
        final urlMatch = RegExp(r'<([^>]+)>').firstMatch(callback);
        if (urlMatch != null) {
          _eventSubscriptions[sid] = urlMatch.group(1)!;
          debugPrint('DLNA: 订阅成功 SID: $sid, Callback: ${urlMatch.group(1)}');
        }
      }
      
      request.response.statusCode = 200;
      request.response.headers.set('SID', sid);
      request.response.headers.set('TIMEOUT', 'Second-1800');
      request.response.headers.set('Server', 'Lotus IPTV/1.0 UPnP/1.0');
      request.response.headers.set('Content-Length', '0');
      await request.response.close();
      
      // 立即发送初始事件通知
      _sendEventNotification(sid);
    } else if (request.method == 'UNSUBSCRIBE') {
      final sid = request.headers.value('SID');
      if (sid != null) {
        _eventSubscriptions.remove(sid);
      }
      request.response.statusCode = 200;
      await request.response.close();
    } else {
      request.response.statusCode = 405;
      await request.response.close();
    }
  }
  
  /// 发送事件通知给订阅者
  void _sendEventNotification(String sid) async {
    final callbackUrl = _eventSubscriptions[sid];
    if (callbackUrl == null) return;
    
    try {
      final uri = Uri.parse(callbackUrl);
      final client = HttpClient();
      final request = await client.openUrl('NOTIFY', uri);
      
      request.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      request.headers.set('NT', 'upnp:event');
      request.headers.set('NTS', 'upnp:propchange');
      request.headers.set('SID', sid);
      request.headers.set('SEQ', '0');
      
      final body = '''<?xml version="1.0" encoding="utf-8"?>
<e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">
  <e:property>
    <LastChange>&lt;Event xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/AVT/&quot;&gt;&lt;InstanceID val=&quot;0&quot;&gt;&lt;TransportState val=&quot;$_transportState&quot;/&gt;&lt;TransportStatus val=&quot;OK&quot;/&gt;&lt;CurrentPlayMode val=&quot;NORMAL&quot;/&gt;&lt;/InstanceID&gt;&lt;/Event&gt;</LastChange>
  </e:property>
</e:propertyset>''';
      
      request.write(body);
      await request.close();
      debugPrint('DLNA: 发送事件通知到 $callbackUrl');
    } catch (e) {
      debugPrint('DLNA: 发送事件通知失败 - $e');
    }
  }
  
  /// 通知所有订阅者状态变化
  void _notifyAllSubscribers() {
    for (final sid in _eventSubscriptions.keys) {
      _sendEventNotification(sid);
    }
  }

  /// 设备描述 XML
  Future<void> _handleDeviceDescription(HttpRequest request) async {
    final xml = '''<?xml version="1.0" encoding="UTF-8"?>
<root xmlns="urn:schemas-upnp-org:device-1-0" xmlns:dlna="urn:schemas-dlna-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>$_deviceName</friendlyName>
    <manufacturer>Lotus IPTV</manufacturer>
    <manufacturerURL>https://github.com/shnulaa/FlutterIPTV</manufacturerURL>
    <modelDescription>Lotus IPTV Media Renderer</modelDescription>
    <modelName>Lotus IPTV</modelName>
    <modelNumber>1.0</modelNumber>
    <modelURL>https://github.com/shnulaa/FlutterIPTV</modelURL>
    <UDN>$_deviceUuid</UDN>
    <dlna:X_DLNADOC>DMR-1.50</dlna:X_DLNADOC>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:AVTransport</serviceId>
        <SCPDURL>/AVTransport/scpd.xml</SCPDURL>
        <controlURL>/AVTransport/control</controlURL>
        <eventSubURL>/AVTransport/event</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:RenderingControl</serviceId>
        <SCPDURL>/RenderingControl/scpd.xml</SCPDURL>
        <controlURL>/RenderingControl/control</controlURL>
        <eventSubURL>/RenderingControl/event</eventSubURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:ConnectionManager:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:ConnectionManager</serviceId>
        <SCPDURL>/ConnectionManager/scpd.xml</SCPDURL>
        <controlURL>/ConnectionManager/control</controlURL>
        <eventSubURL>/ConnectionManager/event</eventSubURL>
      </service>
    </serviceList>
  </device>
</root>''';

    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(xml);
    await request.response.close();
  }

  /// AVTransport SCPD
  Future<void> _handleAvTransportScpd(HttpRequest request) async {
    final xml = _getAvTransportScpd();
    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(xml);
    await request.response.close();
  }

  /// RenderingControl SCPD
  Future<void> _handleRenderingControlScpd(HttpRequest request) async {
    final xml = _getRenderingControlScpd();
    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(xml);
    await request.response.close();
  }

  /// ConnectionManager SCPD
  Future<void> _handleConnectionManagerScpd(HttpRequest request) async {
    final xml = _getConnectionManagerScpd();
    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(xml);
    await request.response.close();
  }

  /// 处理 AVTransport 控制请求
  Future<void> _handleAvTransportControl(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    
    // 提取请求类型
    String requestType = 'Unknown';
    if (body.contains('GetPositionInfo')) {
      requestType = 'GetPositionInfo';
    } else if (body.contains('GetTransportInfo')) {
      requestType = 'GetTransportInfo';
    } else if (body.contains('SetAVTransportURI')) {
      requestType = 'SetAVTransportURI';
    } else if (body.contains('Play')) {
      requestType = 'Play';
    } else if (body.contains('Pause')) {
      requestType = 'Pause';
    } else if (body.contains('Stop')) {
      requestType = 'Stop';
    } else if (body.contains('GetMediaInfo')) {
      requestType = 'GetMediaInfo';
    } else if (body.contains('Seek')) {
      requestType = 'Seek';
    } else if (body.contains('GetTransportSettings')) {
      requestType = 'GetTransportSettings';
    } else if (body.contains('GetDeviceCapabilities')) {
      requestType = 'GetDeviceCapabilities';
    }
    
    debugPrint('DLNA: AVTransport [$requestType] 状态: $_transportState');

    String response;

    if (body.contains('SetAVTransportURI')) {
      // 提取 URL 和标题
      final uriMatch = RegExp(r'<CurrentURI>([^<]*)</CurrentURI>').firstMatch(body);
      final metaMatch = RegExp(r'<CurrentURIMetaData>([^<]*)</CurrentURIMetaData>').firstMatch(body);
      
      final uri = uriMatch?.group(1) ?? '';
      final meta = metaMatch?.group(1) ?? '';
      
      // 解码 URL
      final decodedUri = _decodeXmlEntities(uri);
      
      // 从元数据中提取标题
      String? title;
      if (meta.isNotEmpty) {
        final decodedMeta = _decodeXmlEntities(meta);
        final titleMatch = RegExp(r'<dc:title>([^<]*)</dc:title>').firstMatch(decodedMeta);
        title = titleMatch?.group(1);
      }

      _currentUri = decodedUri;
      _currentTitle = title ?? 'Unknown';
      _transportState = 'STOPPED'; // URI 设置后进入 STOPPED 状态
      _currentPosition = Duration.zero;
      _playStartTime = null;
      
      debugPrint('DLNA: SetAVTransportURI - URL: $decodedUri, Title: $title');
      _notifyAllSubscribers();
      
      response = _createSoapResponse('SetAVTransportURI', '');
    } else if (body.contains('"Play"') || body.contains(':Play') || body.contains('Play</')) {
      debugPrint('DLNA: Play - 开始播放');
      
      // 先设置为 TRANSITIONING 状态
      _transportState = 'TRANSITIONING';
      _notifyAllSubscribers();
      
      // 调用播放回调
      onPlayUrl?.call(_currentUri, _currentTitle);
      
      // 延迟后设置为 PLAYING 状态（模拟缓冲完成）
      Future.delayed(const Duration(milliseconds: 300), () {
        _transportState = 'PLAYING';
        _playStartTime = DateTime.now();
        _notifyAllSubscribers();
        debugPrint('DLNA: 状态变更为 PLAYING');
      });
      
      response = _createSoapResponse('Play', '');
    } else if (body.contains('"Pause"') || body.contains(':Pause') || body.contains('Pause</')) {
      debugPrint('DLNA: Pause');
      // 保存当前位置
      if (_playStartTime != null) {
        _currentPosition = DateTime.now().difference(_playStartTime!);
      }
      _transportState = 'PAUSED_PLAYBACK';
      _playStartTime = null;
      onPause?.call();
      _notifyAllSubscribers();
      response = _createSoapResponse('Pause', '');
    } else if (body.contains('"Stop"') || body.contains(':Stop') || body.contains('Stop</')) {
      debugPrint('DLNA: Stop');
      _transportState = 'STOPPED';
      _currentPosition = Duration.zero;
      _playStartTime = null;
      onStop?.call();
      _notifyAllSubscribers();
      response = _createSoapResponse('Stop', '');
    } else if (body.contains('GetTransportInfo')) {
      response = _createSoapResponse('GetTransportInfo', '''<CurrentTransportState>$_transportState</CurrentTransportState>
        <CurrentTransportStatus>OK</CurrentTransportStatus>
        <CurrentSpeed>1</CurrentSpeed>''');
    } else if (body.contains('GetPositionInfo')) {
      // 计算播放位置
      Duration currentPos = _currentPosition;
      if (_transportState == 'PLAYING' && _playStartTime != null) {
        currentPos = _currentPosition + DateTime.now().difference(_playStartTime!);
      }
      final posStr = _formatDuration(currentPos);
      final durStr = _currentDuration == Duration.zero 
          ? '00:00:00'  // 直播流没有时长
          : _formatDuration(_currentDuration);
      
      response = _createSoapResponse('GetPositionInfo', '''<Track>1</Track>
        <TrackDuration>$durStr</TrackDuration>
        <TrackMetaData></TrackMetaData>
        <TrackURI>${_escapeXml(_currentUri)}</TrackURI>
        <RelTime>$posStr</RelTime>
        <AbsTime>$posStr</AbsTime>
        <RelCount>2147483647</RelCount>
        <AbsCount>2147483647</AbsCount>''');
    } else if (body.contains('GetMediaInfo')) {
      final durStr = _currentDuration == Duration.zero 
          ? '00:00:00'
          : _formatDuration(_currentDuration);
      response = _createSoapResponse('GetMediaInfo', '''<NrTracks>1</NrTracks>
        <MediaDuration>$durStr</MediaDuration>
        <CurrentURI>${_escapeXml(_currentUri)}</CurrentURI>
        <CurrentURIMetaData></CurrentURIMetaData>
        <NextURI></NextURI>
        <NextURIMetaData></NextURIMetaData>
        <PlayMedium>NETWORK</PlayMedium>
        <RecordMedium>NOT_IMPLEMENTED</RecordMedium>
        <WriteStatus>NOT_IMPLEMENTED</WriteStatus>''');
    } else if (body.contains('Seek')) {
      final targetMatch = RegExp(r'<Target>([^<]*)</Target>').firstMatch(body);
      final unitMatch = RegExp(r'<Unit>([^<]*)</Unit>').firstMatch(body);
      if (targetMatch != null) {
        final target = targetMatch.group(1)!;
        final unit = unitMatch?.group(1) ?? 'REL_TIME';
        debugPrint('DLNA: Seek Unit=$unit Target=$target');
        
        if (unit == 'REL_TIME' || unit == 'ABS_TIME') {
          final position = _parseDuration(target);
          _currentPosition = position;
          _playStartTime = DateTime.now(); // 重置播放开始时间
          onSeek?.call(position);
          debugPrint('DLNA: Seek 到位置 $position');
        }
      }
      response = _createSoapResponse('Seek', '');
    } else if (body.contains('GetTransportSettings')) {
      response = _createSoapResponse('GetTransportSettings', '''<PlayMode>NORMAL</PlayMode>
        <RecQualityMode>NOT_IMPLEMENTED</RecQualityMode>''');
    } else if (body.contains('GetDeviceCapabilities')) {
      response = _createSoapResponse('GetDeviceCapabilities', '''<PlayMedia>NETWORK</PlayMedia>
        <RecMedia>NOT_IMPLEMENTED</RecMedia>
        <RecQualityModes>NOT_IMPLEMENTED</RecQualityModes>''');
    } else {
      debugPrint('DLNA: 未知 AVTransport 请求');
      response = _createSoapResponse('Unknown', '');
    }

    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(response);
    await request.response.close();
  }

  /// 处理 RenderingControl 控制请求
  Future<void> _handleRenderingControlControl(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    debugPrint('DLNA: RenderingControl 请求: $body');

    String response;

    if (body.contains('GetVolume')) {
      response = _createSoapResponse('GetVolume', '<CurrentVolume>$_volume</CurrentVolume>', service: 'RenderingControl');
    } else if (body.contains('SetVolume')) {
      final volumeMatch = RegExp(r'<DesiredVolume>(\d+)</DesiredVolume>').firstMatch(body);
      if (volumeMatch != null) {
        _volume = int.parse(volumeMatch.group(1)!);
        onSetVolume?.call(_volume);
      }
      response = _createSoapResponse('SetVolume', '', service: 'RenderingControl');
    } else if (body.contains('GetMute')) {
      response = _createSoapResponse('GetMute', '<CurrentMute>0</CurrentMute>', service: 'RenderingControl');
    } else {
      response = _createSoapResponse('Unknown', '', service: 'RenderingControl');
    }

    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(response);
    await request.response.close();
  }

  /// 处理 ConnectionManager 控制请求
  Future<void> _handleConnectionManagerControl(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    debugPrint('DLNA: ConnectionManager 请求: $body');

    String response;

    if (body.contains('GetProtocolInfo')) {
      response = _createSoapResponse('GetProtocolInfo', '''
        <Source></Source>
        <Sink>http-get:*:video/mp4:*,http-get:*:video/x-matroska:*,http-get:*:video/avi:*,http-get:*:video/mpeg:*,http-get:*:audio/mpeg:*,http-get:*:audio/mp4:*,http-get:*:application/x-mpegURL:*,http-get:*:video/x-flv:*</Sink>''', service: 'ConnectionManager');
    } else if (body.contains('GetCurrentConnectionIDs')) {
      response = _createSoapResponse('GetCurrentConnectionIDs', '<ConnectionIDs>0</ConnectionIDs>', service: 'ConnectionManager');
    } else {
      response = _createSoapResponse('Unknown', '', service: 'ConnectionManager');
    }

    request.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
    request.response.write(response);
    await request.response.close();
  }

  /// 创建 SOAP 响应
  String _createSoapResponse(String action, String body, {String service = 'AVTransport'}) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:${action}Response xmlns:u="urn:schemas-upnp-org:service:$service:1">
      $body
    </u:${action}Response>
  </s:Body>
</s:Envelope>''';
  }

  /// 解码 XML 实体
  String _decodeXmlEntities(String text) {
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
  
  /// 转义 XML 特殊字符
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// 格式化时长为 HH:MM:SS
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// 解析时长字符串
  Duration _parseDuration(String str) {
    final parts = str.split(':');
    if (parts.length == 3) {
      return Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
        seconds: int.tryParse(parts[2]) ?? 0,
      );
    }
    return Duration.zero;
  }


  /// AVTransport SCPD XML
  String _getAvTransportScpd() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <actionList>
    <action>
      <name>SetAVTransportURI</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentURI</name>
          <direction>in</direction>
          <relatedStateVariable>AVTransportURI</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentURIMetaData</name>
          <direction>in</direction>
          <relatedStateVariable>AVTransportURIMetaData</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>Play</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Speed</name>
          <direction>in</direction>
          <relatedStateVariable>TransportPlaySpeed</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>Pause</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>Stop</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>Seek</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Unit</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_SeekMode</relatedStateVariable>
        </argument>
        <argument>
          <name>Target</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_SeekTarget</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>GetTransportInfo</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentTransportState</name>
          <direction>out</direction>
          <relatedStateVariable>TransportState</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentTransportStatus</name>
          <direction>out</direction>
          <relatedStateVariable>TransportStatus</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentSpeed</name>
          <direction>out</direction>
          <relatedStateVariable>TransportPlaySpeed</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>GetPositionInfo</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Track</name>
          <direction>out</direction>
          <relatedStateVariable>CurrentTrack</relatedStateVariable>
        </argument>
        <argument>
          <name>TrackDuration</name>
          <direction>out</direction>
          <relatedStateVariable>CurrentTrackDuration</relatedStateVariable>
        </argument>
        <argument>
          <name>TrackMetaData</name>
          <direction>out</direction>
          <relatedStateVariable>CurrentTrackMetaData</relatedStateVariable>
        </argument>
        <argument>
          <name>TrackURI</name>
          <direction>out</direction>
          <relatedStateVariable>CurrentTrackURI</relatedStateVariable>
        </argument>
        <argument>
          <name>RelTime</name>
          <direction>out</direction>
          <relatedStateVariable>RelativeTimePosition</relatedStateVariable>
        </argument>
        <argument>
          <name>AbsTime</name>
          <direction>out</direction>
          <relatedStateVariable>AbsoluteTimePosition</relatedStateVariable>
        </argument>
        <argument>
          <name>RelCount</name>
          <direction>out</direction>
          <relatedStateVariable>RelativeCounterPosition</relatedStateVariable>
        </argument>
        <argument>
          <name>AbsCount</name>
          <direction>out</direction>
          <relatedStateVariable>AbsoluteCounterPosition</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
  </actionList>
  <serviceStateTable>
    <stateVariable sendEvents="no">
      <name>A_ARG_TYPE_InstanceID</name>
      <dataType>ui4</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>AVTransportURI</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>AVTransportURIMetaData</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="yes">
      <name>TransportState</name>
      <dataType>string</dataType>
      <allowedValueList>
        <allowedValue>STOPPED</allowedValue>
        <allowedValue>PLAYING</allowedValue>
        <allowedValue>TRANSITIONING</allowedValue>
        <allowedValue>PAUSED_PLAYBACK</allowedValue>
        <allowedValue>NO_MEDIA_PRESENT</allowedValue>
      </allowedValueList>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>TransportStatus</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>TransportPlaySpeed</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>CurrentTrack</name>
      <dataType>ui4</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>CurrentTrackDuration</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>CurrentTrackMetaData</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>CurrentTrackURI</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>RelativeTimePosition</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>AbsoluteTimePosition</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>RelativeCounterPosition</name>
      <dataType>i4</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>AbsoluteCounterPosition</name>
      <dataType>i4</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>A_ARG_TYPE_SeekMode</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>A_ARG_TYPE_SeekTarget</name>
      <dataType>string</dataType>
    </stateVariable>
  </serviceStateTable>
</scpd>''';
  }

  /// RenderingControl SCPD XML
  String _getRenderingControlScpd() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <actionList>
    <action>
      <name>GetVolume</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Channel</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentVolume</name>
          <direction>out</direction>
          <relatedStateVariable>Volume</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>SetVolume</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Channel</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable>
        </argument>
        <argument>
          <name>DesiredVolume</name>
          <direction>in</direction>
          <relatedStateVariable>Volume</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>GetMute</name>
      <argumentList>
        <argument>
          <name>InstanceID</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_InstanceID</relatedStateVariable>
        </argument>
        <argument>
          <name>Channel</name>
          <direction>in</direction>
          <relatedStateVariable>A_ARG_TYPE_Channel</relatedStateVariable>
        </argument>
        <argument>
          <name>CurrentMute</name>
          <direction>out</direction>
          <relatedStateVariable>Mute</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
  </actionList>
  <serviceStateTable>
    <stateVariable sendEvents="no">
      <name>A_ARG_TYPE_InstanceID</name>
      <dataType>ui4</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>A_ARG_TYPE_Channel</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>Volume</name>
      <dataType>ui2</dataType>
      <allowedValueRange>
        <minimum>0</minimum>
        <maximum>100</maximum>
        <step>1</step>
      </allowedValueRange>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>Mute</name>
      <dataType>boolean</dataType>
    </stateVariable>
  </serviceStateTable>
</scpd>''';
  }

  /// ConnectionManager SCPD XML
  String _getConnectionManagerScpd() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<scpd xmlns="urn:schemas-upnp-org:service-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <actionList>
    <action>
      <name>GetProtocolInfo</name>
      <argumentList>
        <argument>
          <name>Source</name>
          <direction>out</direction>
          <relatedStateVariable>SourceProtocolInfo</relatedStateVariable>
        </argument>
        <argument>
          <name>Sink</name>
          <direction>out</direction>
          <relatedStateVariable>SinkProtocolInfo</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
    <action>
      <name>GetCurrentConnectionIDs</name>
      <argumentList>
        <argument>
          <name>ConnectionIDs</name>
          <direction>out</direction>
          <relatedStateVariable>CurrentConnectionIDs</relatedStateVariable>
        </argument>
      </argumentList>
    </action>
  </actionList>
  <serviceStateTable>
    <stateVariable sendEvents="no">
      <name>SourceProtocolInfo</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>SinkProtocolInfo</name>
      <dataType>string</dataType>
    </stateVariable>
    <stateVariable sendEvents="no">
      <name>CurrentConnectionIDs</name>
      <dataType>string</dataType>
    </stateVariable>
  </serviceStateTable>
</scpd>''';
  }
}
