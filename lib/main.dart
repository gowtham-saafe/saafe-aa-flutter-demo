import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saafe_aa_sdk/saafe_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SaafeDemoApp());
}

class SaafeDemoApp extends StatelessWidget {
  const SaafeDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SAAFE Demo',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007F73)),
      scaffoldBackgroundColor: const Color(0xFFF4F7F8),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      useMaterial3: true,
    ),
    home: const ConsentDemoPage(),
  );
}

String? validateConsentUrl(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter the consent URL from your backend.';
  if (text.length > 8192) return 'Consent URL must be at most 8192 characters.';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    return 'Enter a complete HTTPS URL.';
  }
  if (uri.userInfo.isNotEmpty) return 'URL must not contain credentials.';
  return null;
}

/// Show only diagnostic fields; consent URLs and personal data stay off-screen.
Map<String, Object?> callbackSummary(dynamic data) {
  dynamic decoded = data;
  if (data is String) {
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return {'message': 'SDK returned an unstructured response.'};
    }
  }
  if (decoded is! Map) return {'message': 'SDK callback received.'};
  return {
    for (final key in [
      'type',
      'status',
      'flowCompleted',
      'errorCode',
      'errorType',
    ])
      if (decoded[key] is String || decoded[key] is bool || decoded[key] is num)
        key: decoded[key],
  };
}

typedef ConsentLauncher =
    Future<void> Function(
      BuildContext context,
      String clientId,
      SaafeEnvironment environment,
      SaafeRedirectOptions options,
    );

Future<void> launchConsent(
  BuildContext context,
  String clientId,
  SaafeEnvironment environment,
  SaafeRedirectOptions options,
) async {
  await SaafeSdk.initialize(
    clientId: clientId,
    environment: environment,
    enableLogs: true,
  );
  if (!context.mounted) return;
  await SaafeSdk.openProtectedRedirect(context, options);
}

class ConsentDemoPage extends StatefulWidget {
  const ConsentDemoPage({super.key, this.launch = launchConsent});

  final ConsentLauncher launch;

  @override
  State<ConsentDemoPage> createState() => _ConsentDemoPageState();
}

class _ConsentDemoPageState extends State<ConsentDemoPage> {
  final _formKey = GlobalKey<FormState>();
  final _clientId = TextEditingController(
    text: '6rSQHJjTJLsPu',
  );
  final _redirectUrl = TextEditingController(
    text: "https://consent.uat.saafe.tech/?fi=d3lkHGdxZht1AgM=&reqdate=10112026033557929&ecreq=-BCWUBewoyD0BXJNF31n9g_MoeuQKL__xpK0RYn6XOHD3f5YsaD3-iNDKu8PXnDZIyxUszr3jDJMsYj_NZfPzlSDr--DvjjfawSY0j0LGHJhW3TOhSlOmUetWRlLnMCJMRMMnQ6vNSqdw9Uc8jSvohDlLOi-k5-ii3CGQ43G5h69AJRUfZQlgSLI99RnoUeXaLlGuHXQqojuJG_jBKEz0pASNUFTK484k1qhjauUie5_a2t2GETXhzw6bMJ_p1kJ4hIi3kRp1p7EuaESxsa4P7QqQu3fpQAkZAfq8WdokaWKAD-c097EhGl_DkfQMO7l&aa=saafe&theme=%7B%22redirectUrl%22%3A%22www.saafe.tech%22%7D&origin=uat&redirection_api_key=KYrEY9EQcGfYSdK5YGreum4UbjbrTPT0",
  );
  SaafeEnvironment _environment = SaafeEnvironment.values.firstWhere(
    (value) =>
        value.name ==
        const String.fromEnvironment(
          'SAAFE_ENVIRONMENT',
          defaultValue: 'sandbox',
        ),
    orElse: () => SaafeEnvironment.sandbox,
  );
  DisplayMode _displayMode = DisplayMode.fullPage;
  bool _showCloseButton = true;
  bool _busy = false;
  String _status = 'Ready to configure';
  String _detail = 'Enter your registered client ID and a fresh consent URL.';
  Map<String, Object?>? _summary;

  @override
  void dispose() {
    _clientId.dispose();
    _redirectUrl.dispose();
    super.dispose();
  }

  void _finish(String status, String detail, [dynamic data]) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = status;
      _detail = detail;
      _summary = data == null ? null : callbackSummary(data);
    });
  }

  Future<void> _openConsent() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _status = 'Authorizing app';
      _detail = 'Checking app registration before opening the consent flow.';
      _summary = null;
    });
    try {
      await widget.launch(
        context,
        _clientId.text.trim(),
        _environment,
        SaafeRedirectOptions(
          redirectUrl: _redirectUrl.text.trim(),
          displayMode: _displayMode,
          showCloseButton: _showCloseButton,
          onLoad: () {
            if (!mounted) return;
            setState(() {
              _status = 'Consent flow open';
              _detail = 'Complete or cancel the flow to return here.';
            });
          },
          // The SDK closes its own route before invoking terminal callbacks.
          onComplete: (data) => _finish(
            'Flow completed',
            'Callback received. Verify the final consent state with your backend.',
            data,
          ),
          onCancel: () => _finish(
            'Flow cancelled',
            'You can start again with a fresh consent URL.',
          ),
          onError: (error) => _finish(
            'Flow failed',
            'The SDK reported a terminal error. Check the code below and retry.',
            error,
          ),
        ),
      );
    } on SaafeAccessDeniedException catch (error) {
      _finish(
        'Access denied',
        'Check client registration, environment, app identity and device trust.',
        {'errorCode': error.code},
      );
    } on PlatformException catch (error) {
      _finish(
        'Platform error',
        'Check your network and native SDK setup, then try again.',
        {'errorCode': error.code},
      );
    } catch (_) {
      _finish(
        'Unable to start',
        'Run on Android or iOS and check the SDK configuration.',
      );
    }
  }

  Widget _section(String title, List<Widget> children) => Card(
    elevation: 0,
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 20),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SAAFE / Developer demo')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 44,
                    color: Color(0xFF007F73),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect with consent',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try the SAAFE Account Aggregator flow on Android and iOS.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  _section('1. App registration', [
                    TextFormField(
                      controller: _clientId,
                      enabled: !_busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Client ID',
                        helperText:
                            'Use the ID registered for this app and environment.',
                        helperMaxLines: 2,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your registered client ID.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<SaafeEnvironment>(
                      initialValue: _environment,
                      decoration: const InputDecoration(
                        labelText: 'Environment',
                      ),
                      items: SaafeEnvironment.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.name),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _environment = value!),
                    ),
                  ]),
                  _section('2. Consent request', [
                    TextFormField(
                      controller: _redirectUrl,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 5,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Consent redirect URL',
                        hintText: 'https://…',
                        helperText:
                            'Paste the complete, fresh URL returned by your consent API.',
                        helperMaxLines: 2,
                      ),
                      validator: validateConsentUrl,
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<DisplayMode>(
                      initialValue: _displayMode,
                      decoration: const InputDecoration(
                        labelText: 'Presentation',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: DisplayMode.fullPage,
                          child: Text('Full page'),
                        ),
                        DropdownMenuItem(
                          value: DisplayMode.bottomSheet,
                          child: Text('Bottom sheet'),
                        ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _displayMode = value!),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show close button'),
                      value: _showCloseButton,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _showCloseButton = value),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy ? null : _openConsent,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.open_in_new),
                      label: Text(
                        _busy ? 'Flow in progress…' : 'Open consent flow',
                      ),
                    ),
                  ]),
                  _section('3. Flow result', [
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_detail),
                    if (_summary != null && _summary!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        const JsonEncoder.withIndent('  ').convert(_summary),
                      ),
                    ],
                  ]),
                  const Text(
                    'Client registration and consent generation are managed by your backend. '
                    'This demo keeps input and callback summaries in memory only. '
                    'SDK logs are disabled.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
