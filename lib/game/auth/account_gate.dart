import 'dart:async';

import 'package:flutter/material.dart';

import 'supabase_account_service.dart';

/// Enforces sign-in when cloud accounts are configured. The game remains
/// available in offline development mode when no Supabase config is supplied.
class AccountGate extends StatefulWidget {
  const AccountGate({
    required this.accountService,
    required this.child,
    super.key,
  });

  final SupabaseAccountService accountService;
  final Widget child;

  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  StreamSubscription? _subscription;
  late bool _signedIn;

  @override
  void initState() {
    super.initState();
    _signedIn = widget.accountService.isSignedIn;
    _subscription = widget.accountService.authStateChanges.listen((_) {
      if (!mounted) return;
      setState(() => _signedIn = widget.accountService.isSignedIn);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _signedIn
      ? widget.child
      : ArcherFmAccountScreen(accountService: widget.accountService);
}

class ArcherFmAccountScreen extends StatefulWidget {
  const ArcherFmAccountScreen({required this.accountService, super.key});

  final SupabaseAccountService accountService;

  @override
  State<ArcherFmAccountScreen> createState() => _ArcherFmAccountScreenState();
}

class _ArcherFmAccountScreenState extends State<ArcherFmAccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _loading = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@') || password.length < 8) {
      setState(() {
        _error = 'أدخل بريداً إلكترونياً صحيحاً وكلمة مرور من 8 أحرف على الأقل.';
        _notice = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_createAccount) {
        final response = await widget.accountService.signUpWithEmail(
          email: email,
          password: password,
        );
        if (response.session == null && mounted) {
          setState(() => _notice = 'تم إنشاء الحساب. افحص بريدك لتأكيده ثم سجّل الدخول.');
        }
      } else {
        await widget.accountService.signInWithEmail(
          email: email,
          password: password,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر إتمام العملية. تحقق من البيانات وحاول مجدداً.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_moon_rounded, size: 64, color: colors.primary),
                const SizedBox(height: 12),
                Text(
                  'Archer FM',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _createAccount ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    helperText: '8 أحرف على الأقل',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {\n                    if (!_loading) _submit();\n                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: colors.error)),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  Text(_notice!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_createAccount ? 'إنشاء الحساب' : 'دخول'),
                  ),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _createAccount = !_createAccount;
                            _error = null;
                            _notice = null;
                          }),
                  child: Text(
                    _createAccount
                        ? 'لديك حساب؟ سجّل الدخول'
                        : 'ليس لديك حساب؟ أنشئ حساباً',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
