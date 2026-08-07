import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Produto {
  String id;
  String nome;
  double preco;
  int qnt;
  int qntComprada;
  String categoria;
  String? descricao;

  Produto(
    this.nome,
    this.preco,
    this.qnt,
    this.id,
    this.qntComprada,
    this.categoria,
    this.descricao,
  );
}

class Marmita {
  String guarnicao;
  String proteina1;
  String proteina2;
  String salada1;
  String salada2;

  Marmita(
    this.guarnicao,
    this.proteina1,
    this.proteina2,
    this.salada1,
    this.salada2,
  );
}

Future<Marmita> fetchMarmita() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Usuário não autenticado');

  final snapshot = await FirebaseFirestore.instance
      .collection('marmitas')
      .where('idMarmita', isEqualTo: '1')
      .limit(1)
      .get();
  if (snapshot.docs.isEmpty) {
    return Marmita('', '', '', '', '');
  }

  final data = snapshot.docs.first.data();

  return Marmita(
    data['guarnicao']?.toString() ?? '',
    data['proteina1']?.toString() ?? '',
    data['proteina2']?.toString() ?? '',
    data['salada1']?.toString() ?? '',
    data['salada2']?.toString() ?? '',
  );
}

final List<String> _categorias = [
  'Salgados',
  'Bebidas',
  'Doces',
  'Laticinios',
  'Fichas',
];
final List<Produto> _carrinho = [];

void main() async { // Executa quando o app é iniciado
  WidgetsFlutterBinding.ensureInitialized(); // Incia alguns plugins do Flutter, como o Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // Incia o Firebase

  try {
    await FirebaseAuth.instance.signInAnonymously(); // Cria uma sessão temporária que não exige cadastro
  } catch (e) {
    debugPrint("Erro ao logar anonimamente: $e"); // Caso de algum erro
  }

  runApp(const AppCantina()); // Executa o primeiro Widget do app
}

class AppCantina extends StatelessWidget { // Widget principal do app
  const AppCantina({super.key}); 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "App Cantina",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.lightGreen),
      home: const HomePage(),
    );
  }
}

//Home Page
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cantina Donieda')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/imagens/CantinaLogo.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 70),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PaginaCardapio(),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, color: Colors.black),
              label: const Text('Entrar'),
            ),

            const SizedBox(height: 20),
            FloatingActionButton(
              heroTag: 'btn_login',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AreaLogin()),
                );
              },
              tooltip: 'Login',
              backgroundColor: Colors.white70,
              child: const Icon(Icons.lock, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}

//Cardapio
class PaginaCardapio extends StatefulWidget {
  const PaginaCardapio({super.key});

  @override
  State<PaginaCardapio> createState() => _PaginaCardapioState();
}

class _PaginaCardapioState extends State<PaginaCardapio> {
  final Map<String, TextEditingController> _descricaoControllers = {};
  final Map<String, String> _descriptionsPorProduto = {};
  final marmita = fetchMarmita();

  @override
  void dispose() {
    for (final i in _descricaoControllers.values) {
      i.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produtos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('produtos').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final produtos = snapshot.data!.docs;

          Map<String, List<QueryDocumentSnapshot<Object?>>> produtosAgrupados =
              {};

          for (var produto in produtos) {
            final categoria = produto['categoria'];
            if (!produtosAgrupados.containsKey(categoria)) {
              produtosAgrupados[categoria] = [];
            }
            produtosAgrupados[categoria]!.add(produto);
          }

          List<String> categorias = produtosAgrupados.keys.toList();

          return ListView.builder(
            itemCount: categorias.length,
            itemBuilder: (context, indexCategoria) {
              String categoria = categorias[indexCategoria];
              List<QueryDocumentSnapshot<Object?>> produtosDaCategoria =
                  produtosAgrupados[categoria]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Text(
                      categoria.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 31, 142, 111),
                      ),
                    ),
                  ),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: produtosDaCategoria.length,
                    itemBuilder: (context, indexProduto) {
                      final produto = produtosDaCategoria[indexProduto];

                      final produtoData =
                          produto.data() as Map<String, dynamic>? ?? {};
                      final nomeProduto =
                          produtoData['nome']?.toString() ?? 'Produto sem nome';
                      final qtdEstoque =
                          (produtoData['qnt'] as num?)?.toInt() ?? 0;
                      final precoProduto =
                          (produtoData['preco'] as num?)?.toDouble() ?? 0.0;
                      final categoriaProduto =
                          produtoData['categoria']?.toString() ??
                          'Sem categoria';
                      final descricaoProduto =
                          produtoData['descricao']?.toString() ?? '';

                      final controller = _descricaoControllers.putIfAbsent(
                        produto.id,
                        () => TextEditingController(
                          text: _descriptionsPorProduto[produto.id] ?? '',
                        ),
                      );

                      final noCarrinho = _carrinho.any(
                        (item) => item.id == produto.id,
                      );
                      final itemCarrinho = _carrinho.firstWhere(
                        (item) => item.id == produto.id,
                        orElse: () => Produto('', 0, 0, '', 0, '', ''),
                      );

                      return ListTile(
                        title: qtdEstoque == 0
                            ? Text(
                                '$nomeProduto,',
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Colors.black,
                                ),
                              )
                            : Text(nomeProduto),
                        subtitle: noCarrinho
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (categoriaProduto == 'Fichas') ...[
                                    FutureBuilder<Marmita>(
                                      future: fetchMarmita(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Text('Carregando...');
                                        }
                                        if (snapshot.hasError) {
                                          return Text(
                                            'Erro: ${snapshot.error}',
                                          );
                                        }
                                        final marmita = snapshot.data!;
                                        return Text(
                                          'Guarnição: ${marmita.guarnicao}\nProteínas: ${marmita.proteina1} e ${marmita.proteina2}\nSaladas: ${marmita.salada1} e ${marmita.salada2}',
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                    ),
                                  ],
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: () {
                                          setState(() {
                                            if (itemCarrinho.qntComprada > 1) {
                                              itemCarrinho.qntComprada--;
                                            } else {
                                              _carrinho.removeWhere(
                                                (item) => item.id == produto.id,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                      Text('${itemCarrinho.qntComprada}'),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: () {
                                          setState(() {
                                            if (itemCarrinho.qntComprada <
                                                qtdEstoque) {
                                              itemCarrinho.qntComprada++;
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "$nomeProduto sem estoque!",
                                                  ),
                                                ),
                                              );
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),

                                  if (categoriaProduto == 'Fichas') ...[
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Descrição (opcional)',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.text,
                                        textInputAction: TextInputAction.done,
                                      ),
                                    ),

                                    ElevatedButton(
                                      onPressed: () {
                                        final novaDescricao = controller.text
                                            .trim();
                                        setState(() {
                                          _descriptionsPorProduto[produto.id] =
                                              novaDescricao;
                                          final itemExistente = _carrinho
                                              .firstWhere(
                                                (item) => item.id == produto.id,
                                                orElse: () => Produto(
                                                  '',
                                                  0,
                                                  0,
                                                  '',
                                                  0,
                                                  '',
                                                  '',
                                                ),
                                              );
                                          if (itemExistente.id.isNotEmpty) {
                                            itemExistente.descricao =
                                                novaDescricao;
                                          }
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Descrição adicionada ao produto!',
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('Adicionar descrição'),
                                    ),
                                  ],
                                ],
                              )
                            : null,
                        trailing: Text(
                          NumberFormat.currency(
                            locale: "pt_BR",
                            symbol: "R\$",
                          ).format(precoProduto),
                        ),
                        leading: IconButton(
                          onPressed: qtdEstoque == 0
                              ? null
                              : () {
                                  setState(() {
                                    if (noCarrinho) {
                                      _carrinho.removeWhere(
                                        (item) => item.id == produto.id,
                                      );
                                    } else {
                                      _carrinho.add(
                                        Produto(
                                          nomeProduto,
                                          precoProduto,
                                          qtdEstoque,
                                          produto.id,
                                          1,
                                          categoriaProduto,
                                          _descriptionsPorProduto[produto.id] ??
                                              descricaoProduto,
                                        ),
                                      );
                                    }
                                  });
                                },
                          icon: qtdEstoque == 0
                              ? const Icon(Icons.block, color: Colors.red)
                              : noCarrinho
                              ? const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                )
                              : const Icon(Icons.add_circle_outline),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: const BottomAppBar(
        shape: CircularNotchedRectangle(),
        color: Colors.green,
        child: IconTheme(
          data: IconThemeData(color: Colors.green),
          child: Row(
            children: <Widget>[SizedBox(height: 64), Text("Cantina Donieda")],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'btn_carrinho',
            onPressed: () async {
              if (_carrinho.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Carrinho vazio!")),
                );
                return;
              }

              // Verifica se algum produto do carrinho está sem estoque
              for (var item in _carrinho) {
                final doc = await FirebaseFirestore.instance
                    .collection('produtos')
                    .doc(item.id)
                    .get();

                final estoqueAtual = doc['qnt'];

                if (estoqueAtual <= 0) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("${item.nome} está sem estoque!")),
                  );
                  return;
                }
              }
              Navigator.push(
                // ignore: use_build_context_synchronously
                context,
                MaterialPageRoute(builder: (context) => CarrinhoCompra()),
              );
            },
            tooltip: 'Carrinho',
            child: Badge(
              label: Text('${_carrinho.length}'),
              child: const Icon(Icons.shopping_basket),
            ),
          ),
        ],
      ),
    );
  }
}

//Carrinho
class CarrinhoCompra extends StatefulWidget {
  const CarrinhoCompra({super.key});

  @override
  State<CarrinhoCompra> createState() => _CarrinhoCompra();
}

class _CarrinhoCompra extends State<CarrinhoCompra> {
  @override
  Widget build(BuildContext context) {
    var c = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");
    double total = 0;
    for (var produto in _carrinho) {
      var valorProduto = produto.preco * produto.qntComprada;
      total += valorProduto;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Carrinho')),
      body: _carrinho.isEmpty
          ? const Center(child: Text('Carrinho vazio'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _carrinho.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        title: Text(_carrinho[index].nome),
                        subtitle: Text(
                          "Quantidade: ${_carrinho[index].qntComprada}",
                        ),
                        trailing: Text(
                          "Preço por unidade: ${c.format(_carrinho[index].preco)}",
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        "Total: ${c.format(total)}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.all(15),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TelaPagamento(valor: total),
                              ),
                            );
                          },
                          child: const Text(
                            "Pagar",
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

//Tela do Pagamento
class TelaPagamento extends StatefulWidget {
  final double valor;

  const TelaPagamento({super.key, required this.valor});

  @override
  State<TelaPagamento> createState() => _TelaPagamentoState();
}

class _TelaPagamentoState extends State<TelaPagamento> {
  bool contaPaga = false;
  String idPedido = "";
  String gerarPixPayload({
    required String chave,
    required String nome,
    required String cidade,
    required double valor,
  }) {
    String format(String id, String value) {
      return id + value.length.toString().padLeft(2, '0') + value;
    }

    String payload = "";

    payload += format("00", "01");
    payload += format(
      "26",
      format("00", "BR.GOV.BCB.PIX") + format("01", chave),
    );
    payload += format("52", "0000");
    payload += format("53", "986");
    payload += format("54", valor.toStringAsFixed(2));
    payload += format("58", "BR");
    payload += format("59", nome);
    payload += format("60", cidade);
    payload += format("62", format("05", "***"));
    payload += "6304";

    payload += _crc16(payload);

    return payload;
  }

  String _crc16(String payload) {
    int polinomio = 0x1021;
    int resultado = 0xFFFF;

    for (int i = 0; i < payload.length; i++) {
      resultado ^= (payload.codeUnitAt(i) << 8);

      for (int j = 0; j < 8; j++) {
        if ((resultado & 0x8000) != 0) {
          resultado = (resultado << 1) ^ polinomio;
        } else {
          resultado <<= 1;
        }
        resultado &= 0xFFFF;
      }
    }

    return resultado.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  @override
  Widget build(BuildContext context) {
    var c = NumberFormat.currency(locale: "pt_BR", symbol: "R\$");
    final payload = gerarPixPayload(
      chave: "+5527997253921",
      nome: "CANTINA DONIEDA",
      cidade: "SANTA TERESA",
      valor: widget.valor,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Pagamento Pix")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              "Total: ${c.format(widget.valor)}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            QrImageView(data: payload, size: 250),
            const SizedBox(height: 20),
            const Text("Copia e Cola Pix:"),

            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(payload),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                if (_carrinho.isEmpty) return;
                var doc = FirebaseFirestore.instance
                    .collection('pedidos')
                    .doc();

                await doc.set({
                  'arquivado': false,
                  'id_pedido': doc.id,
                  'criadoPorAdmin': false,
                  'produtos': _carrinho
                      .map(
                        (produto) => {
                          'nome': produto.nome,
                          'preco': produto.preco,
                          'qntComprada': produto.qntComprada,
                          'descricao': produto.descricao ?? '',
                        },
                      )
                      .toList(),
                  'valorTotal': widget.valor,
                });
                for (var produto in _carrinho) {
                  var query = await FirebaseFirestore.instance
                      .collection('produtos')
                      .where('nome', isEqualTo: produto.nome)
                      .get();

                  if (query.docs.isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('produtos')
                        .doc(query.docs.first.id)
                        .update({
                          'qnt': FieldValue.increment(-produto.qntComprada),
                        });
                  }
                }
                contaPaga = true;
                setState(() {
                  contaPaga = true;
                  idPedido = doc.id;
                });
                _carrinho.clear();
              },
              child: const Text("Confirma Pedido!"),
            ),

            if (contaPaga)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Pagamento confirmado!\nID do pedido: $idPedido",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

//Area do Login (Adm)
class AreaLogin extends StatefulWidget {
  const AreaLogin({super.key});
  @override
  State<AreaLogin> createState() => _AreaLogin();
}

class _AreaLogin extends State<AreaLogin> {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  String erro = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 95, 41, 41),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextFormField(
                autofocus: true,
                controller: usuarioController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "E-mail",
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ),
              TextFormField(
                autofocus: true,
                controller: senhaController,
                obscureText: true,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Senha",
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ),

              ButtonTheme(
                height: 40,
                child: ElevatedButton(
                  onPressed: () async {
                    final email = usuarioController.text.trim();
                    final senha = senhaController.text.trim();

                    if (email.isEmpty || senha.isEmpty) {
                      setState(() {
                        erro = 'Preencha e-mail e senha antes de entrar';
                      });
                      return;
                    }

                    try {
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                        email: email,
                        password: senha,
                      );

                      if (!mounted) return;

                      setState(() {
                        erro = '';
                      });

                      Navigator.pushReplacement(
                        // ignore: use_build_context_synchronously
                        context,
                        MaterialPageRoute(builder: (context) => const HubAdm()),
                      );
                    } on FirebaseAuthException catch (e) {
                      String mensagem;
                      switch (e.code) {
                        case 'user-not-found':
                        case 'wrong-password':
                          mensagem = 'Usuário ou senha incorretos';
                          break;
                        default:
                          mensagem =
                              'Erro ao autenticar: ${e.message ?? e.code}';
                      }
                      setState(() {
                        erro = mensagem;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              ButtonTheme(
                height: 40,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: Text('Voltar', style: TextStyle(color: Colors.black)),
                ),
              ),
              SizedBox(height: 10),

              Text(
                erro,
                style: TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),

              // ATENÇÃO: LEMBRAR DE REMOVER ESSA LINHA ANTES DE PUBLICAR O APP, POIS É SÓ PARA TESTE!
              SizedBox(height: 50),
              Text(
                'E-mail: cantina@escola.com\nSenha: 123456',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Hub da area do administrador
class HubAdm extends StatefulWidget {
  const HubAdm({super.key});
  @override
  State<HubAdm> createState() => _HubAdm();
}

class _HubAdm extends State<HubAdm> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Área do Administrador")),
      body: Center(
        child: Column(
          //crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AreaAdm()),
                  );
                },
                child: const Text("Área dos Pedidos"),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProdutosArquivados(),
                    ),
                  );
                },
                child: const Text("Produtos Arquivados"),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Estoque()),
                  );
                },
                child: const Text("Estoque"),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NovoProduto(),
                    ),
                  );
                },
                child: const Text("Cadastrar Produto"),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CriarMarmita(),
                    ),
                  );
                },
                child: const Text("Cadastrar Marmita"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//Area do Adm
class AreaAdm extends StatefulWidget {
  const AreaAdm({super.key});
  @override
  State<AreaAdm> createState() => _AreaAdm();
}

class _AreaAdm extends State<AreaAdm> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pedidos")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Voltar"),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pedidos')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pedidos = snapshot.data!.docs;
                final pedidosAtivos = pedidos.where((pedido) {
                  final data = pedido.data() as Map<String, dynamic>? ?? {};
                  return data['arquivado'] != true;
                }).toList();

                if (pedidosAtivos.isEmpty) {
                  return const Center(child: Text("Nenhum pedido ainda"));
                }

                return ListView.builder(
                  itemCount: pedidosAtivos.length,
                  itemBuilder: (context, index) {
                    final pedido = pedidosAtivos[index];
                    final pedidoData =
                        pedido.data() as Map<String, dynamic>? ?? {};
                    final produtos = pedidoData['produtos'];
                    final listaProdutos = produtos is List
                        ? produtos
                        : <dynamic>[];

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Pedido #${pedido.id.substring(0, 5)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 5),
                            ...listaProdutos.map((p) {
                              final dadosProduto = p is Map
                                  ? Map<String, dynamic>.from(p)
                                  : <String, dynamic>{};
                              final nome =
                                  dadosProduto['nome']?.toString() ??
                                  'Produto sem nome';
                              final quantidade =
                                  dadosProduto['qntComprada'] ?? 1;
                              final descricaoItem =
                                  (dadosProduto['descricao']?.toString() ?? '')
                                      .trim();
                              final mostrarDescricao =
                                  descricaoItem.isNotEmpty &&
                                  descricaoItem.toLowerCase() != 'nenhuma' &&
                                  descricaoItem.toLowerCase() !=
                                      'sem descrição' &&
                                  descricaoItem.toLowerCase() !=
                                      'sem descricao';
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("- $nome ${quantidade}x"),
                                  if (mostrarDescricao)
                                    Text(
                                      '  • $descricaoItem',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              );
                            }),
                            const SizedBox(height: 5),
                            Text("Total: R\$ ${pedidoData['valorTotal'] ?? 0}"),
                            const SizedBox(height: 5),
                            Text(
                              "ID do pedido: ${pedidoData['id_pedido'] ?? pedido.id}",
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('pedidos')
                                        .doc(pedido.id)
                                        .delete();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.archive,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('pedidos')
                                        .doc(pedido.id)
                                        .update({'arquivado': true});
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

//Pedidos Arquivados
class ProdutosArquivados extends StatefulWidget {
  const ProdutosArquivados({super.key});
  @override
  State<ProdutosArquivados> createState() => _ProdutosArquivados();
}

class _ProdutosArquivados extends State<ProdutosArquivados> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Arquivados")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Voltar"),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pedidos')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pedidos = snapshot.data!.docs;
                final pedidosArquivados = pedidos.where((pedido) {
                  final data = pedido.data() as Map<String, dynamic>? ?? {};
                  return data['arquivado'] == true;
                }).toList();

                if (pedidosArquivados.isEmpty) {
                  return const Center(child: Text("Nenhum pedido ainda"));
                }

                return ListView.builder(
                  itemCount: pedidosArquivados.length,
                  itemBuilder: (context, index) {
                    final pedido = pedidosArquivados[index];
                    final pedidoData =
                        pedido.data() as Map<String, dynamic>? ?? {};
                    final produtos = pedidoData['produtos'];
                    final listaProdutos = produtos is List
                        ? produtos
                        : <dynamic>[];

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Pedido #${pedido.id.substring(0, 5)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 5),

                            ...listaProdutos.map((p) {
                              final dadosProduto = p is Map
                                  ? Map<String, dynamic>.from(p)
                                  : <String, dynamic>{};
                              final nome =
                                  dadosProduto['nome']?.toString() ??
                                  'Produto sem nome';
                              final quantidade =
                                  dadosProduto['qntComprada'] ?? 1;
                              final descricaoItem =
                                  (dadosProduto['descricao']?.toString() ?? '')
                                      .trim();
                              final mostrarDescricao =
                                  descricaoItem.isNotEmpty &&
                                  descricaoItem.toLowerCase() != 'nenhuma' &&
                                  descricaoItem.toLowerCase() !=
                                      'sem descrição' &&
                                  descricaoItem.toLowerCase() !=
                                      'sem descricao';
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("- $nome ${quantidade}x"),
                                  if (mostrarDescricao)
                                    Text(
                                      '  • $descricaoItem',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              );
                            }),

                            const SizedBox(height: 5),
                            Text("Total: R\$ ${pedidoData['valorTotal'] ?? 0}"),

                            const SizedBox(height: 5),
                            Text(
                              "ID do pedido: ${pedidoData['id_pedido'] ?? pedido.id}",
                            ),

                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('pedidos')
                                        .doc(pedido.id)
                                        .delete();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.archive,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('pedidos')
                                        .doc(pedido.id)
                                        .update({'arquivado': false});
                                    // ignore: unused_local_variable
                                    List produtosArquivados = [];
                                    FirebaseFirestore.instance
                                        .collection('pedidos')
                                        .where('arquivado', isEqualTo: true)
                                        .snapshots()
                                        .listen((snapshot) {
                                          produtosArquivados = snapshot.docs
                                              .map((doc) => doc.data())
                                              .toList();
                                        });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

//Estoque
class Estoque extends StatelessWidget {
  const Estoque({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Estoque")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('produtos').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final produtos = snapshot.data!.docs;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Voltar"),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                itemCount: produtos.length,
                itemBuilder: (context, index) {
                  var produto = produtos[index];

                  return ListTile(
                    leading: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('produtos')
                            .doc(produto.id)
                            .delete();
                      },
                    ),
                    title: Text(produto['nome']),
                    subtitle: Text("Quantidade: ${produto['qnt']}"),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () async {
                            final produto = produtos[index];

                            if ((produto['qnt'] as int) > 0) {
                              await FirebaseFirestore.instance
                                  .collection('produtos')
                                  .doc(produto.id)
                                  .update({'qnt': (produto['qnt']) - 1});
                            }
                          },
                        ),

                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            final produto = produtos[index];

                            await FirebaseFirestore.instance
                                .collection('produtos')
                                .doc(produto.id)
                                .update({'qnt': (produto['qnt']) + 1});
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

//Novo Produto
class NovoProduto extends StatefulWidget {
  const NovoProduto({super.key});

  @override
  State<NovoProduto> createState() => _NovoProdutoState();
}

class _NovoProdutoState extends State<NovoProduto> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController precoController = TextEditingController();
  final TextEditingController qntController = TextEditingController();
  String? categoriaSelecionada;

  @override
  void dispose() {
    nomeController.dispose();
    precoController.dispose();
    qntController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Produto')),
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextField(
                controller: nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome do produto',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 5),

              TextField(
                controller: precoController,
                decoration: InputDecoration(
                  labelText: 'Preço',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 5),

              TextField(
                controller: qntController,
                decoration: InputDecoration(
                  labelText: 'Quantidade',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 5),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                ),
                items: _categorias.map((categoria) {
                  return DropdownMenuItem(
                    value: categoria,
                    child: Text(categoria),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    categoriaSelecionada = value;
                  });
                },
              ),

              SizedBox(height: 16),

              ElevatedButton(
                onPressed: () async {
                  final nome = nomeController.text.trim();
                  final preco = double.tryParse(
                    precoController.text.replaceAll(',', '.'),
                  );
                  final qnt = int.tryParse(qntController.text);
                  if (nome.isEmpty ||
                      preco == null ||
                      preco <= 0 ||
                      qnt == null ||
                      qnt <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Preencha nome, preço e quantidade corretamente',
                        ),
                      ),
                    );
                    return;
                  }
                  await FirebaseFirestore.instance.collection('produtos').add({
                    'nome': nome,
                    'preco': preco,
                    'qnt': qnt,
                    'categoria': categoriaSelecionada,
                  });
                  nomeController.clear();
                  precoController.clear();
                  qntController.clear();
                  categoriaSelecionada = null;

                  showDialog(
                    // ignore: use_build_context_synchronously
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: InkWell(
                                child: const Icon(Icons.close),
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Produto adicionado com sucesso!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  );
                },

                child: Text('Salvar'),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Voltar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//Criar Marmita
class CriarMarmita extends StatefulWidget {
  const CriarMarmita({super.key});

  @override
  State<CriarMarmita> createState() => _CriarMarmitaState();
}

class _CriarMarmitaState extends State<CriarMarmita> {
  final TextEditingController guarnicaoController = TextEditingController();
  final TextEditingController proteina1Controller = TextEditingController();
  final TextEditingController proteina2Controller = TextEditingController();
  final TextEditingController salada1Controller = TextEditingController();
  final TextEditingController salada2Controller = TextEditingController();

  @override
  void dispose() {
    guarnicaoController.dispose();
    proteina1Controller.dispose();
    proteina2Controller.dispose();
    salada1Controller.dispose();
    salada2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Marmita')),
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextField(
                controller: guarnicaoController,
                decoration: InputDecoration(
                  labelText: 'Guarnição',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 5),

              TextField(
                controller: proteina1Controller,
                decoration: InputDecoration(
                  labelText: 'Proteína 1',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 5),

              TextField(
                controller: proteina2Controller,
                decoration: InputDecoration(
                  labelText: 'Proteína 2',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 5),

              TextField(
                controller: salada1Controller,
                decoration: InputDecoration(
                  labelText: 'Salada 1',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 5),

              TextField(
                controller: salada2Controller,
                decoration: InputDecoration(
                  labelText: 'Salada 2',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),

              SizedBox(height: 16),

              ElevatedButton(
                onPressed: () async {
                  final guarnicao = guarnicaoController.text.trim();
                  final proteina1 = proteina1Controller.text.trim();
                  final proteina2 = proteina2Controller.text.trim();
                  final salada1 = salada1Controller.text.trim();
                  final salada2 = salada2Controller.text.trim();
                  if (guarnicao.isEmpty ||
                      proteina1.isEmpty ||
                      proteina2.isEmpty ||
                      salada1.isEmpty ||
                      salada2.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preencha os campos corretamente'),
                      ),
                    );
                    return;
                  }
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Usuário não autenticado')),
                    );
                    return;
                  }

                  final marmitasRef = FirebaseFirestore.instance.collection(
                    'marmitas',
                  );
                  final marmitasSnapshot = await marmitasRef
                      .where('idMarmita', isEqualTo: '1')
                      .get();
                  for (final doc in marmitasSnapshot.docs) {
                    await doc.reference.delete();
                  }

                  await marmitasRef.add({
                    'idMarmita': '1',
                    'guarnicao': guarnicao,
                    'proteina1': proteina1,
                    'proteina2': proteina2,
                    'salada1': salada1,
                    'salada2': salada2,
                    'criadoPor': user.uid,
                  });
                  guarnicaoController.clear();
                  proteina1Controller.clear();
                  proteina2Controller.clear();
                  salada1Controller.clear();
                  salada2Controller.clear();

                  showDialog(
                    // ignore: use_build_context_synchronously
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: InkWell(
                                child: const Icon(Icons.close),
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Marmita adicionada com sucesso!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  );
                },

                child: Text('Salvar'),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Voltar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
