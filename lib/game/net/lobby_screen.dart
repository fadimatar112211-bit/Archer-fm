import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../hero/hero_assets.dart';
import '../../hero/hero_catalog.dart';
import '../progress/hero_progress.dart';
import '../social/account_service.dart';
import 'hotspot_service.dart';
import 'match_models.dart';
import 'network_match_screen.dart';
import 'online_match_client.dart';
import 'online_match_server.dart';
import 'protocol.dart';

/// Pre-match lobby: accounts, friends, duration, four heroes, random
/// matchmaking, private rooms with invite codes and LAN hotspot hosting.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({
    super.key,
    this.socialService,
    this.pendingResults,
    this.loaderFactory,
    this.store,
    this.onlineHost = '127.0.0.1',
    this.onlinePort = 40404,
  });

  final SocialService? socialService;
  final PendingResultStore? pendingResults;
  final HeroLoaderFactory? loaderFactory;
  final ProgressStore? store;

  /// Address of the online match service. No backend is selected yet, so the
  /// default points at a locally hosted process; the field is editable.
  final String onlineHost;
  final int onlinePort;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final SocialService social;
  late final PendingResultStore pending;
  OnlineMatchClient? client;
  HotspotService? hotspot;
  OnlineMatchServer? hostedServer;

  bool _hotspot = false;
  bool _busy = false;
  bool _inMatch = false;
  String? _status;
  String _username = '';
  String _password = '';
  String _code = '';
  String _heroId = 'ranger_new';
  MatchDuration _duration = MatchDuration.m10;
  List<PlayerProfile> _friends = const [];
  List<FriendRequest> _requests = const [];
  int _pendingCount = 0;

  static const playableIds = ['ranger_new', 'flame', 'shadow', 'storm'];

  @override
  void initState() {
    super.initState();
    social = widget.socialService ?? SocialService();
    pending = widget.pendingResults ?? PendingResultStore();
    _loadSocial();
  }

  @override
  void dispose() {
    client?.close();
    hotspot?.stopHosting();
    super.dispose();
  }

  Future<void> _loadSocial() async {
    await social.load();
    if (!mounted) return;
    setState(() {
      _friends = social.friends.toList();
      _requests = social.incomingRequests.toList();
    });
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final count = await pending.unsyncedCount();
    if (mounted) setState(() => _pendingCount = count);
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final ok = await social.signIn(_username, _password);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = ok ? 'تم تسجيل الدخول' : 'تعذّر تسجيل الدخول — تحقق الاسم وكلمة المرور';
      _friends = social.friends.toList();
      _requests = social.incomingRequests.toList();
    });
  }

  void _onNetEvent(String type, Map<String, dynamic> data) {
    if (!mounted || _inMatch) return;
    setState(() {
      if (type == NetMessage.roomState || type == NetMessage.welcome) {
        _status = 'تم تحديث الغرفة';
      } else if (type == NetMessage.error) {
        _status = data['reason'] == 'room unavailable'
            ? 'الغرفة غير متاحة'
            : 'تعذّر إكمال الطلب';
      } else if (type == NetMessage.matchStart) {
        _status = 'بدأت المباراة';
      }
    });
    if (type == NetMessage.matchStart) _openMatch();
  }

  Future<void> _connect({required bool hotspotMode, required String host}) async {
    setState(() => _busy = true);
    try {
      client?.close();
      if (hotspotMode) {
        hotspot ??= HotspotService();
        if (!hotspot!.hosting) await hotspot!.startHosting();
      } else {
        await hotspot?.stopHosting();
        hotspot = null;
      }
      final port = hotspotMode ? hotspotPort : widget.onlinePort;
      final next = await OnlineMatchClient.connect(
        host: host,
        port: port,
        username: social.currentUsername,
        heroId: _heroId,
        onEvent: _onNetEvent,
      );
      if (!mounted) {
        await next.close();
        return;
      }
      setState(() {
        client = next;
        _hotspot = hotspotMode;
        _busy = false;
        _status = hotspotMode ? 'تم الاتصال بالمضيف المحلي' : 'تم الاتصال بالخادم';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'تعذّر الاتصال: $error';
        });
      }
    }
  }

  Future<void> _hostHotspot() async {
    setState(() => _busy = true);
    try {
      hostedServer ??= OnlineMatchServer();
      await hostedServer!.start();
      final addresses = await HotspotService().hostAddresses();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = addresses.isEmpty
            ? 'المضيع يعمل على المنفذ ${hostedServer!.port}'
            : 'عناوين الاتصال: ${addresses.map((a) => a.address).join(' · ')} — المنفذ ${hostedServer!.port}';
      });
    } catch (error) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMatch() async {
    final active = client;
    if (active == null) return;
    setState(() => _inMatch = true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: NetworkMatchScreen(
            client: active,
            hero: heroById(_heroId),
            loaderFactory: widget.loaderFactory ?? defaultHeroLoaderFactory,
            store: widget.store,
            social: social,
            pendingResults: pending,
            hotspot: _hotspot,
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _inMatch = false;
      client = null;
      _status = 'انتهت المباراة';
    });
    _loadSocial();
    _refreshPending();
  }

  @override
  Widget build(BuildContext context) {
    final profile = social.current;
    final room = client?.room;
    final isHost = room != null && room.ownerId == client?.playerId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archer FM — اللعب الجماعي'),
        backgroundColor: Colors.black38,
        actions: [
          IconButton(
            key: const ValueKey('sync_pending'),
            tooltip: 'مزامنة النتائج',
            onPressed: () async {
              final count = await pending.syncToAccount(social);
              if (!mounted) return;
              setState(() {
                _status = count > 0 ? 'تمت مزامنة $count نتيجة' : 'لا توجد نتائج معلّقة';
              });
              _refreshPending();
            },
            icon: Badge(
              isLabelVisible: _pendingCount > 0,
              label: Text('$_pendingCount'),
              child: const Icon(Icons.cloud_sync),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_status != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_status!, style: const TextStyle(color: Colors.white70)),
              ),
            _section('الحساب', [
              if (profile == null) ...[
                TextField(
                  key: const ValueKey('lobby_username'),
                  decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                  onChanged: (value) => _username = value,
                ),
                TextField(
                  key: const ValueKey('lobby_password'),
                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  obscureText: true,
                  onChanged: (value) => _password = value,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const ValueKey('lobby_signin'),
                  onPressed: _busy ? null : _signIn,
                  child: const Text('دخول / إنشاء حساب'),
                ),
              ] else
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(profile.colorValue),
                    child: const Icon(Icons.person, color: Colors.black),
                  ),
                  title: Text(profile.displayName),
                  subtitle: Text(
                    'فوز ${profile.wins} · خسارة ${profile.losses} · قتل ${profile.kills}',
                  ),
                ),
            ]),
            _section('اختيار البطل', [
              Wrap(
                spacing: 8,
                children: [
                  for (final id in playableIds)
                    ChoiceChip(
                      key: ValueKey('lobby_hero_$id'),
                      label: Text(heroById(id).nameAr),
                      avatar: Icon(heroById(id).icon, size: 18),
                      selected: _heroId == id,
                      onSelected: client == null
                          ? (selected) {
                              if (selected) setState(() => _heroId = id);
                            }
                          : null,
                    ),
                ],
              ),
            ]),
            _section('مدة المباراة', [
              Wrap(
                spacing: 8,
                children: [
                  for (final duration in MatchDuration.values)
                    ChoiceChip(
                      key: ValueKey('lobby_duration_${duration.minutes}'),
                      label: Text(duration.labelAr),
                      selected: _duration == duration,
                      onSelected: (selected) {
                        if (!selected) return;
                        setState(() => _duration = duration);
                        client?.queue(duration);
                      },
                    ),
                ],
              ),
            ]),
            _section('نوع الاتصال', [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('أونلاين'),
                      selected: !_hotspot,
                      onSelected: (_) => setState(() => _hotspot = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('هوتسبوت'),
                      selected: _hotspot,
                      onSelected: (_) => setState(() => _hotspot = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!_hotspot)
                TextField(
                  key: const ValueKey('lobby_online_host'),
                  decoration: InputDecoration(
                    labelText: 'عنوان خادم المباراة (افتراضي: $_onlineHostLabel)',
                  ),
                  onChanged: (value) => _onlineHostInput = value,
                )
              else
                TextField(
                  key: const ValueKey('lobby_hotspot_host'),
                  decoration: const InputDecoration(
                    labelText: 'عنوان جهاز المضيف (مثال: 192.168.43.1)',
                  ),
                  onChanged: (value) => _hostInput = value,
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('lobby_connect'),
                    onPressed: (profile == null || _busy || client != null)
                        ? null
                        : () => _connect(
                              hotspotMode: _hotspot,
                              host: _hotspot
                                  ? (_hostInput.isEmpty ? '127.0.0.1' : _hostInput)
                                  : (_onlineHostInput.isEmpty
                                      ? widget.onlineHost
                                      : _onlineHostInput),
                            ),
                    icon: const Icon(Icons.link),
                    label: Text(_hotspot ? 'اتصل بالمضيف' : 'اتصل بالخادم'),
                  ),
                  if (_hotspot)
                    OutlinedButton.icon(
                      key: const ValueKey('lobby_start_host'),
                      onPressed: _busy ? null : _hostHotspot,
                      icon: const Icon(Icons.router),
                      label: const Text('استضافة المباراة'),
                    ),
                ],
              ),
            ]),
            if (client != null) ...[
              _section('الغرفة', [
                if (room != null)
                  Text(
                    'رمز الغرفة: ${room.code}',
                    style: const TextStyle(
                      color: Color(0xFF9BE845),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 8),
                for (final member in room?.players ?? const <MatchPlayer>[])
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(member.colorValue),
                      child: Text(
                        member.username.isNotEmpty ? member.username[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    title: Text(member.username),
                    subtitle: Text(
                      '${heroById(member.heroId).nameAr} · ${member.state.name}',
                    ),
                    trailing: isHost && member.id != client!.playerId
                        ? IconButton(
                            key: ValueKey('remove_${member.id}'),
                            icon: const Icon(Icons.person_remove),
                            onPressed: () => client!.removePlayer(member.id),
                          )
                        : null,
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      key: const ValueKey('lobby_matchmaking'),
                      onPressed: () => client!.queue(_duration),
                      child: const Text('مطابقة عشوائية'),
                    ),
                    OutlinedButton(
                      key: const ValueKey('lobby_create_room'),
                      onPressed: () => client!.createRoom(_duration),
                      child: const Text('إنشاء غرفة'),
                    ),
                    OutlinedButton(
                      key: const ValueKey('lobby_ready'),
                      onPressed: () => client!.ready(
                        room?.player(client!.playerId ?? '')?.state !=
                            RoomMemberState.ready,
                      ),
                      child: const Text('جاهز / إلغاء'),
                    ),
                    if (isHost)
                      FilledButton(
                        key: const ValueKey('lobby_start_match'),
                        onPressed: room.everyoneReady
                            ? () => client!.startMatch()
                            : null,
                        child: const Text('بدء المباراة'),
                      ),
                    OutlinedButton(
                      key: const ValueKey('lobby_leave_room'),
                      onPressed: () {
                        client!.leave();
                        client!.close();
                        setState(() => client = null);
                      },
                      child: const Text('مغادرة الغرفة'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('lobby_room_code'),
                  decoration: const InputDecoration(labelText: 'رمز غرفة للانضمام'),
                  onChanged: (value) => _code = value,
                ),
                OutlinedButton(
                  key: const ValueKey('lobby_join_room'),
                  onPressed: _code.isEmpty ? null : () => client!.joinRoom(_code),
                  child: const Text('انضم برمز الدعوة'),
                ),
              ]),
              _section('الأصدقاء', [
                for (final request in _requests)
                  ListTile(
                    title: Text('طلب صداقة من ${request.from}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () async {
                            await social.acceptFriendRequest(request.from);
                            _loadSocial();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await social.declineFriendRequest(request.from);
                            _loadSocial();
                          },
                        ),
                      ],
                    ),
                  ),
                for (final friend in _friends)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(friend.colorValue),
                      child: const Icon(Icons.person, color: Colors.black),
                    ),
                    title: Text(friend.username),
                    trailing: TextButton(
                      key: ValueKey('invite_${friend.username}'),
                      onPressed: () async {
                        client!.invite(friend.username);
                        if (room != null) {
                          await Clipboard.setData(ClipboardData(text: room.code));
                        }
                        if (mounted) {
                          setState(() => _status = 'تمت دعوة ${friend.username} — شارك رمز الغرفة');
                        }
                      },
                      child: const Text('دعوة'),
                    ),
                  ),
                if (_friends.isEmpty && _requests.isEmpty)
                  const Text('لا يوجد أصدقاء بعد — ابحث باسم المستخدم'),
              ]),
            ],
            if (_pendingCount > 0)
              ListTile(
                leading: const Icon(Icons.cloud_off),
                title: Text('$_pendingCount نتيجة محفوظة محليًا'),
                subtitle: const Text('تُزامن مع الحساب عند عودة الإنترنت'),
              ),
          ],
        ),
      ),
    );
  }

  String get _onlineHostLabel => widget.onlineHost;
  String _onlineHostInput = '';
  String _hostInput = '';

  Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
}
