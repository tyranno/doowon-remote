import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

import '../common.dart';
import '../desktop/pages/server_page.dart' show checkClickTime;
import '../models/platform_model.dart';
import '../models/server_model.dart';

const kDoowonTitle = '두원전자통신 원격지원';
const kDoowonC1 = Color(0xFF2A9BB8);
const kDoowonC2 = Color(0xFF1D3F73);
const kDoowonInk = Color(0xFF1F2A33);
const kDoowonSub = Color(0xFF52606D);
const kDoowonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kDoowonC1, kDoowonC2],
);

bool get isDoowon => bind.mainGetAppNameSync().startsWith('Doowon');
bool get isDoowonAgent => bind.mainGetAppNameSync() == 'DoowonAgent';
bool get isDoowonCustomer => isDoowon && !isDoowonAgent;

const kDoowonCustomerSize = Size(380, 460);
const kDoowonAgentSize = Size(440, 420);
const kDoowonCmSize = Size(360, 300);

class DoowonTitleBar extends StatelessWidget {
  final String title;
  final Future<void> Function() onClose;
  final bool showMinimize;
  const DoowonTitleBar(
      {Key? key,
      required this.title,
      required this.onClose,
      this.showMinimize = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(gradient: kDoowonGradient),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => windowManager.startDragging(),
            child: Row(children: [
              const SizedBox(width: 12),
              Image.asset('assets/logo.png', width: 20, height: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        if (showMinimize)
          _TitleButton(
              icon: Icons.remove, onTap: () => windowManager.minimize()),
        _TitleButton(icon: Icons.close, onTap: onClose),
      ]),
    );
  }
}

class _TitleButton extends StatelessWidget {
  final IconData icon;
  final FutureOr<void> Function() onTap;
  const _TitleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      hoverColor: Colors.white24,
      child: SizedBox(
          width: 44,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 18)),
    );
  }
}

Future<void> _quitApp() async {
  await windowManager.setPreventClose(false);
  exit(0);
}

Future<bool> _confirm(BuildContext context, String message) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message, style: const TextStyle(fontSize: 14)),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kDoowonC2),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('종료', style: TextStyle(color: Colors.white))),
      ],
    ),
  );
  return res == true;
}

Future<void> doowonFitMainWindow() async {
  final size = isDoowonAgent ? kDoowonAgentSize : kDoowonCustomerSize;
  await windowManager.setSize(size);
  await windowManager.setResizable(false);
  await windowManager.setTitle(kDoowonTitle);
}

enum _CustomerState { connecting, waiting, inSession }

/// 고객 PC의 메인 창. 상담원이 웹 대기 목록에서 이 PC를 고르면 연결되므로
/// 화면에는 회사 안내와 진행 상태만 보여 준다.
class DoowonCustomerHome extends StatefulWidget {
  const DoowonCustomerHome({Key? key}) : super(key: key);

  @override
  State<DoowonCustomerHome> createState() => _DoowonCustomerHomeState();
}

class _DoowonCustomerHomeState extends State<DoowonCustomerHome> {
  Timer? _timer;
  _CustomerState _state = _CustomerState.connecting;
  String _pcName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => doowonFitMainWindow());
    try {
      final info = jsonDecode(bind.mainGetLoginDeviceInfo());
      _pcName = (info['name'] as String?) ?? '';
    } catch (_) {}
    _timer = periodic_immediate(const Duration(seconds: 1), _poll);
  }

  Future<void> _poll() async {
    var next = _CustomerState.connecting;
    try {
      final status = jsonDecode(await bind.mainGetConnectStatus())
          as Map<String, dynamic>;
      final ready = status['status_num'] == 1;
      final viewers = (status['video_conn_count'] as int?) ?? 0;
      if (viewers > 0) {
        next = _CustomerState.inSession;
      } else if (ready) {
        next = _CustomerState.waiting;
      }
    } catch (_) {}
    if (mounted && next != _state) setState(() => _state = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _close() async {
    final msg = _state == _CustomerState.inSession
        ? '상담원과 연결되어 있습니다.\n원격지원을 종료할까요?'
        : '원격지원 프로그램을 종료할까요?';
    if (await _confirm(context, msg)) await _quitApp();
  }

  @override
  Widget build(BuildContext context) {
    final (color, headline, detail) = switch (_state) {
      _CustomerState.connecting => (
          const Color(0xFFE0A030),
          '지원 서버에 연결하는 중입니다',
          '인터넷 연결을 확인하고 잠시만 기다려 주세요.'
        ),
      _CustomerState.waiting => (
          const Color(0xFF32BEA6),
          '상담원 연결을 기다리고 있습니다',
          '상담원이 연결을 요청하면 수락 창이 나타납니다.\n수락하기 전에는 아무도 화면을 볼 수 없습니다.'
        ),
      _CustomerState.inSession => (
          const Color(0xFFE04F5F),
          '상담원이 원격지원 중입니다',
          '언제든 이 창을 닫으면 지원이 즉시 종료됩니다.'
        ),
    };
    return Material(
      color: Colors.white,
      child: Column(children: [
        DoowonTitleBar(title: kDoowonTitle, onClose: _close),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            child: Column(children: [
              Image.asset('assets/logo.png', width: 64, height: 64),
              const SizedBox(height: 14),
              const Text('두원전자통신',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kDoowonC2)),
              const SizedBox(height: 2),
              const Text('고객 원격지원 서비스',
                  style: TextStyle(fontSize: 13, color: kDoowonSub)),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE1EAEF)),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _PulseDot(color: color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(headline,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: kDoowonInk)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(detail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12.5, height: 1.5, color: kDoowonSub)),
                ]),
              ),
              const Spacer(),
              if (_pcName.isNotEmpty) ...[
                Text('이 PC: $_pcName',
                    style: const TextStyle(fontSize: 12, color: kDoowonSub)),
                const SizedBox(height: 4),
                const Text('문의 시 상담원에게 위 PC 이름을 알려 주세요.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8A96A0))),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

/// 상담원 PC의 메인 창. 실제 접속은 웹 대기 목록의 '연결' 버튼이
/// doowonagent:// 링크로 이 프로그램을 불러 원격 화면 창을 바로 연다.
class DoowonAgentHome extends StatefulWidget {
  const DoowonAgentHome({Key? key}) : super(key: key);

  @override
  State<DoowonAgentHome> createState() => _DoowonAgentHomeState();
}

class _DoowonAgentHomeState extends State<DoowonAgentHome> {
  String _api = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => doowonFitMainWindow());
    bind.mainGetOption(key: 'api-server').then((v) {
      if (mounted) setState(() => _api = v.trim());
    });
  }

  Future<void> _close() async {
    if (await _confirm(context, '상담원 프로그램을 종료할까요?\n열려 있는 원격 화면도 함께 닫힙니다.')) {
      await _quitApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(children: [
        DoowonTitleBar(title: '$kDoowonTitle · 상담원', onClose: _close),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
            child: Column(children: [
              Image.asset('assets/logo.png', width: 56, height: 56),
              const SizedBox(height: 12),
              const Text('상담원 프로그램',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kDoowonC2)),
              const SizedBox(height: 20),
              const Text(
                '웹 대기 목록에서 고객의 [연결] 버튼을 누르면\n원격 화면이 이 프로그램으로 바로 열립니다.\n\n이 창은 닫지 말고 최소화해 두세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.6, color: kDoowonSub),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: kDoowonGradient,
                      borderRadius: BorderRadius.circular(8)),
                  child: TextButton(
                    onPressed: _api.isEmpty
                        ? null
                        : () => launchUrlString('$_api/agent'),
                    child: const Text('대기 목록 열기',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// 고객 PC에서 상담원이 접속을 요청했을 때 뜨는 수락 창(별도 --cm 창).
class DoowonCmView extends StatefulWidget {
  const DoowonCmView({Key? key}) : super(key: key);

  @override
  State<DoowonCmView> createState() => _DoowonCmViewState();
}

class _DoowonCmViewState extends State<DoowonCmView> {
  @override
  void initState() {
    super.initState();
    gFFI.chatModel.isConnManager = true;
    gFFI.serverModel.updateClientState();
    windowManager.setTitle(kDoowonTitle);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerModel>(builder: (context, model, _) {
      final clients = model.clients;
      final client = clients.isEmpty
          ? null
          : clients.firstWhere((c) => !c.disconnected,
              orElse: () => clients.last);
      return Material(
        color: Colors.white,
        child: Column(children: [
          DoowonTitleBar(
            title: kDoowonTitle,
            showMinimize: client?.authorized == true,
            onClose: () async {
              if (client != null && !client.disconnected) {
                if (client.authorized) {
                  bind.cmCloseConnection(connId: client.id);
                } else {
                  model.sendLoginResponse(client, false);
                }
              }
              await windowManager.setPreventClose(false);
              await windowManager.close();
            },
          ),
          Expanded(
            child: client == null
                ? const SizedBox.shrink()
                : _CmBody(client: client, model: model),
          ),
        ]),
      );
    });
  }
}

class _CmBody extends StatelessWidget {
  final Client client;
  final ServerModel model;
  const _CmBody({required this.client, required this.model});

  @override
  Widget build(BuildContext context) {
    final String headline;
    final String detail;
    final List<Widget> buttons;
    if (client.disconnected) {
      headline = '원격지원이 종료되었습니다';
      detail = '이용해 주셔서 감사합니다.';
      buttons = [
        _btn('닫기', primary: true, onTap: () async {
          await bind.cmRemoveDisconnectedConnection(connId: client.id);
          if (await bind.cmGetClientsLength() == 0) {
            await windowManager.close();
          }
        }),
      ];
    } else if (!client.authorized) {
      headline = '상담원이 원격지원을 요청했습니다';
      detail = '수락하면 상담원이 이 PC의 화면을 보고\n마우스·키보드로 도와드립니다.';
      buttons = [
        _btn('거절',
            onTap: () => checkClickTime(
                client.id, () => model.sendLoginResponse(client, false))),
        const SizedBox(width: 12),
        _btn('수락',
            primary: true,
            onTap: () => checkClickTime(
                client.id, () => model.sendLoginResponse(client, true))),
      ];
    } else {
      headline = '상담원이 원격지원 중입니다';
      detail = '지원이 끝나면 아래 버튼으로 연결을 끊을 수 있습니다.';
      buttons = [
        _btn('연결 끊기',
            danger: true,
            onTap: () => checkClickTime(
                client.id, () => bind.cmCloseConnection(connId: client.id))),
      ];
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
              gradient: kDoowonGradient, shape: BoxShape.circle),
          child: Icon(
              client.authorized ? Icons.support_agent : Icons.headset_mic,
              color: Colors.white,
              size: 28),
        ),
        const SizedBox(height: 14),
        Text(headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: kDoowonInk)),
        const SizedBox(height: 8),
        Text(detail,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 12.5, height: 1.5, color: kDoowonSub)),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: buttons),
      ]),
    );
  }

  Widget _btn(String label,
      {bool primary = false,
      bool danger = false,
      required FutureOr<void> Function() onTap}) {
    final Color bg = danger
        ? const Color(0xFFE04F5F)
        : (primary ? kDoowonC2 : const Color(0xFFEEF2F5));
    final Color fg = (primary || danger) ? Colors.white : kDoowonInk;
    return SizedBox(
      width: 120,
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => onTap(),
        child: Text(label,
            style: TextStyle(
                color: fg, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
