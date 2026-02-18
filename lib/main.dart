import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '电视直播',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LiveTVPage(),
      debugShowCheckedModeBanner: false, // 隐藏调试横幅
    );
  }
}

class LiveTVPage extends StatefulWidget {
  const LiveTVPage({super.key});

  @override
  State<LiveTVPage> createState() => _LiveTVPageState();
}

class _LiveTVPageState extends State<LiveTVPage> {
  // 直播源配置（CCTV+荔枝网）
  final Map<String, String> _liveChannels = {
    'CCTV1 综合': 'https://tv.cctv.com/live/cctv1/',
    'CCTV3 综艺': 'https://tv.cctv.com/live/cctv3/',
    'CCTV4 中文国际': 'https://tv.cctv.com/live/cctv4/',
    'CCTV5 体育': 'https://tv.cctv.com/live/cctv5/',
    'CCTV6 电影': 'https://tv.cctv.com/live/cctv6/',
    '广东卫视': 'https://www.gdtv.cn/tvChannelDetail/43',
    '广东珠江': 'https://www.gdtv.cn/tvChannelDetail/44',
  };

  // 当前播放的频道
  String _currentChannel = 'CCTV1 综合';
  late WebViewController _webViewController;
  bool _isFullScreen = true;

  @override
  void initState() {
    super.initState();
    // 初始化 WebView 控制器
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // 启用 JS（直播网页必需）
      ..loadRequest(Uri.parse(_liveChannels[_currentChannel]!))
      ..setNavigationDelegate(
        NavigationDelegate(
          // 页面加载完成后自动触发全屏
          onPageFinished: (String url) {
            if (_isFullScreen) {
              FullScreenWindow.setFullScreen(true);
              // 注入 JS 隐藏网页非直播区域（适配全屏）
              _webViewController.runJavaScript('''
                // 隐藏网页头部/底部（不同网页需调整选择器）
                document.querySelector('header')?.style.display = 'none';
                document.querySelector('footer')?.style.display = 'none';
                document.querySelector('.nav')?.style.display = 'none';
                // 让直播视频占满屏幕
                const video = document.querySelector('video');
                if (video) {
                  video.style.width = '100%';
                  video.style.height = '100vh';
                  video.style.objectFit = 'cover';
                  video.play(); // 自动播放（部分网页需用户交互后生效）
                }
              ''');
            }
          },
        ),
      );

    // 监听遥控器/键盘按键（左右键切台，ESC退出全屏）
    RawKeyboard.instance.addListener((RawKeyEvent event) {
      if (event is RawKeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _switchChannel(next: true); // 右键切下一个台
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _switchChannel(next: false); // 左键切上一个台
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          setState(() {
            _isFullScreen = !_isFullScreen;
            FullScreenWindow.setFullScreen(_isFullScreen);
          });
        }
      }
    });

    // 初始化全屏
    FullScreenWindow.setFullScreen(true);
  }

  // 切台逻辑
  void _switchChannel({required bool next}) {
    List<String> channels = _liveChannels.keys.toList();
    int currentIndex = channels.indexOf(_currentChannel);
    int newIndex;

    if (next) {
      newIndex = (currentIndex + 1) % channels.length; // 下一个台（循环）
    } else {
      newIndex = (currentIndex - 1 + channels.length) % channels.length; // 上一个台
    }

    setState(() {
      _currentChannel = channels[newIndex];
      // 加载新频道
      _webViewController.loadRequest(Uri.parse(_liveChannels[_currentChannel]!));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 核心 WebView 播放区域
          WebViewWidget(controller: _webViewController),
          // 悬浮菜单（点击屏幕显示/隐藏）
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                // 点击顶部显示频道列表
                showModalBottomSheet(
                  context: context,
                  builder: (context) => ListView(
                    children: _liveChannels.keys.map((channel) {
                      return ListTile(
                        title: Text(
                          channel,
                          style: TextStyle(
                            color: _currentChannel == channel ? Colors.red : Colors.black,
                            fontSize: 20,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _currentChannel = channel;
                            _webViewController.loadRequest(Uri.parse(_liveChannels[channel]!));
                          });
                          Navigator.pop(context); // 关闭菜单
                        },
                      );
                    }).toList(),
                  ),
                );
              },
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(10),
                child: Text(
                  '当前频道：$_currentChannel（点击切换）',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 退出全屏并释放资源
    FullScreenWindow.setFullScreen(false);
    RawKeyboard.instance.removeListener((_) {});
    super.dispose();
  }
}