import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const baseUrl = 'https://api.spaceflightnewsapi.net/v4';
const barColor = Color(0xFF5B67F5);

// ===================== MODEL =====================
class Item {
  final String type; // news | blog | report
  final int id;
  final String title, imageUrl, author, summary, url, publishedAt;

  Item({
    required this.type,
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.author,
    required this.summary,
    required this.url,
    required this.publishedAt,
  });

  String get key => '$type-$id';

  static String endpoint(String type) =>
      {'news': 'articles', 'blog': 'blogs', 'report': 'reports'}[type]!;

  factory Item.fromApi(String type, Map j) {
    String author = (j['news_site'] ?? '').toString();
    if (author.isEmpty && j['authors'] is List && (j['authors'] as List).isNotEmpty) {
      author = (j['authors'][0]['name'] ?? '').toString();
    }
    return Item(
      type: type,
      id: j['id'] ?? 0,
      title: (j['title'] ?? '').toString(),
      imageUrl: (j['image_url'] ?? '').toString(),
      author: author.isEmpty ? 'Unknown' : author,
      summary: (j['summary'] ?? '').toString(),
      url: (j['url'] ?? '').toString(),
      publishedAt: (j['published_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type, 'id': id, 'title': title, 'imageUrl': imageUrl,
        'author': author, 'summary': summary, 'url': url, 'publishedAt': publishedAt,
      };

  factory Item.fromJson(Map j) => Item(
        type: j['type'], id: j['id'], title: j['title'], imageUrl: j['imageUrl'],
        author: j['author'], summary: j['summary'], url: j['url'],
        publishedAt: j['publishedAt'],
      );
}

// ===================== FAVORITE STORE (global, reactive) =====================
class FavStore extends ChangeNotifier {
  String _user = '';
  List<Item> items = [];

  String get _key => 'fav_$_user';

  Future<void> load(String user) async {
    _user = user;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    items = raw == null
        ? []
        : (jsonDecode(raw) as List).map((e) => Item.fromJson(e)).toList();
    notifyListeners();
  }

  void clear() {
    _user = '';
    items = [];
    notifyListeners();
  }

  bool isFav(Item i) => items.any((e) => e.key == i.key);

  /// returns true jika ditambahkan, false jika dihapus
  Future<bool> toggle(Item i) async {
    final added = !isFav(i);
    if (added) {
      items.add(i);
    } else {
      items.removeWhere((e) => e.key == i.key);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
    notifyListeners();
    return added;
  }
}

final favStore = FavStore();

// ===================== HELPERS =====================
void showError(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
}

void showInfo(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

PreferredSizeWidget appBar(String title, {List<Widget>? actions}) => AppBar(
      title: Text(title),
      centerTitle: true,
      backgroundColor: barColor,
      foregroundColor: Colors.white,
      actions: actions,
    );

Widget netImage(String url, {double? w, double? h}) {
  final fallback = Container(
    width: w, height: h, color: Colors.black12,
    child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
  );
  if (url.isEmpty) return fallback;
  return Image.network(
    url, width: w, height: h, fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => fallback,
    loadingBuilder: (_, child, p) => p == null
        ? child
        : SizedBox(width: w, height: h,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
  );
}

// ===================== MAIN =====================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final p = await SharedPreferences.getInstance();
  final user = p.getString('session');
  if (user != null) await favStore.load(user);
  runApp(MyApp(sessionUser: user));
}

class MyApp extends StatelessWidget {
  final String? sessionUser;
  const MyApp({super.key, this.sessionUser});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Spaceflight News',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF7B1FA2),
          scaffoldBackgroundColor: const Color(0xFFFDF4FF),
        ),
        home: sessionUser == null ? const LoginPage() : HomePage(username: sessionUser!),
      );
}

// ===================== LOGIN =====================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _u = TextEditingController(), _p = TextEditingController();

  Future<void> _login() async {
    final u = _u.text.trim(), pw = _p.text;
    final prefs = await SharedPreferences.getInstance();
    final users = jsonDecode(prefs.getString('users') ?? '{}') as Map;
    if (u.isNotEmpty && users[u] == pw) {
      await prefs.setString('session', u);
      await favStore.load(u);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(username: u)));
    } else {
      showError(context, 'Login Gagal! Pastikan sudah Register atau cek password.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar('Login'),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Text('Silakan Login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _u, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))))),
              const SizedBox(height: 12),
              TextField(controller: _p, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))))),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _login, child: const Text('Login')),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                child: const Text('Belum punya akun? Daftar di sini'),
              ),
            ]),
          ),
        ),
      );
}

// ===================== REGISTER =====================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _u = TextEditingController(), _p = TextEditingController();

  Future<void> _register() async {
    final u = _u.text.trim(), pw = _p.text;
    if (u.isEmpty || pw.isEmpty) {
      showError(context, 'Username dan password tidak boleh kosong!');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final users = jsonDecode(prefs.getString('users') ?? '{}') as Map;
    if (users.containsKey(u)) {
      showError(context, 'Username sudah terdaftar!');
      return;
    }
    users[u] = pw;
    await prefs.setString('users', jsonEncode(users));
    if (!mounted) return;
    Navigator.pop(context);
    showInfo(context, 'Registrasi berhasil, silakan login.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar('Register'),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Text('Daftar Akun Baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _u, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))))),
              const SizedBox(height: 12),
              TextField(controller: _p, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))))),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _register, child: const Text('Daftar')),
            ]),
          ),
        ),
      );
}

// ===================== HOME =====================
class HomePage extends StatelessWidget {
  final String username;
  const HomePage({super.key, required this.username});

  Future<void> _logout(BuildContext context) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('session');
    favStore.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  Widget _menu(BuildContext c, String type, String title, String desc, IconData icon) => Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.purple),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          subtitle: Text(desc),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ListPage(type: type, title: title))),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar('Hai, $username!', actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            tooltip: 'Favorite',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritePage())),
          ),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _menu(context, 'news', 'News', 'Get an overview of the latest SpaceFlight news, from various sources! Easily link your users to the right websites.', Icons.newspaper),
          _menu(context, 'blog', 'Blog', 'Blogs often provide a more detailed overview of launches and missions. A must-have for the serious spaceflight enthusiast.', Icons.article_outlined),
          _menu(context, 'report', 'Reports', 'Space stations and other missions often publish their data. With SNAPI, you can include it in your app.', Icons.insert_chart_outlined),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => _logout(context),
              child: const Text('Log Out'),
            ),
          ),
        ]),
      );
}

// ===================== LIST + FILTER =====================
class ItemTile extends StatelessWidget {
  final Item item;
  final Widget? trailing;
  const ItemTile({super.key, required this.item, this.trailing});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: netImage(item.imageUrl, w: 80, h: 56),
          ),
          title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(item.author),
          trailing: trailing,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(item: item))),
        ),
      );
}

class ListPage extends StatefulWidget {
  final String type, title;
  const ListPage({super.key, required this.type, required this.title});
  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  late Future<List<Item>> _future;
  String? _selected; // author aktif

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Item>> _fetch() async {
    final res = await http
        .get(Uri.parse('$baseUrl/${Item.endpoint(widget.type)}/?limit=50'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = jsonDecode(res.body)['results'] as List;
    return data.map((e) => Item.fromApi(widget.type, e)).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar(widget.title, actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritePage())),
          ),
        ]),
        body: FutureBuilder<List<Item>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Gagal memuat data'),
                  TextButton(onPressed: () => setState(() => _future = _fetch()), child: const Text('Coba lagi')),
                ]),
              );
            }
            final all = snap.data!;
            final authors = all.map((e) => e.author).toSet().toList()..sort();
            final shown = _selected == null ? all : all.where((e) => e.author == _selected).toList();
            return Column(children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: authors
                      .map((a) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(a),
                              selected: _selected == a,
                              onSelected: (s) => setState(() => _selected = s ? a : null),
                            ),
                          ))
                      .toList(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) => ItemTile(item: shown[i]),
                ),
              ),
            ]);
          },
        ),
      );
}

// ===================== FAVORITE =====================
class FavoritePage extends StatelessWidget {
  const FavoritePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar('Favorite'),
        body: ListenableBuilder(
          listenable: favStore,
          builder: (context, _) {
            if (favStore.items.isEmpty) {
              return const Center(child: Text('Belum ada data favorite'));
            }
            return ListView(
              padding: const EdgeInsets.only(top: 8),
              children: favStore.items
                  .map((e) => ItemTile(
                        item: e,
                        trailing: IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          onPressed: () => favStore.toggle(e),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      );
}

// ===================== DETAIL =====================
class DetailPage extends StatefulWidget {
  final Item item;
  const DetailPage({super.key, required this.item});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Item _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadDetail();
  }

  // ambil detail berdasarkan id: /v4/{menu}/{id}/
  Future<void> _loadDetail() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/${Item.endpoint(_item.type)}/${_item.id}/'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && mounted) {
        setState(() => _item = Item.fromApi(_item.type, jsonDecode(res.body)));
      }
    } catch (_) {/* tetap pakai data dari list */}
  }

  Future<void> _openWeb() async {
    final ok = await launchUrl(Uri.parse(_item.url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showError(context, 'Tidak dapat membuka situs');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: favStore,
        builder: (context, _) {
          final fav = favStore.isFav(_item);
          return Scaffold(
            appBar: appBar('Detail', actions: [
              IconButton(
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? Colors.red : Colors.white),
                onPressed: () async {
                  final added = await favStore.toggle(_item);
                  if (!context.mounted) return;
                  showInfo(context, added ? 'Ditambahkan ke favorite' : 'Dihapus dari favorite');
                },
              ),
            ]),
            floatingActionButton: FloatingActionButton(
              tooltip: 'Buka Web',
              onPressed: _openWeb,
              child: const Icon(Icons.open_in_new),
            ),
            body: ListView(children: [
              netImage(_item.imageUrl, w: double.infinity, h: 220),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_item.author, style: const TextStyle(color: Colors.grey)),
                  Text(_item.publishedAt, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  Text(_item.summary),
                  const SizedBox(height: 80),
                ]),
              ),
            ]),
          );
        },
      );
}
