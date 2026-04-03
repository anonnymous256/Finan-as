import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/Telas/EditarConsorcio/Consorcio.dart';
import '/Telas/EditarConsorcio/Fatura.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  // Controllers para o diálogo de compra
  final valorCompraController = TextEditingController();
  final parcelasController = TextEditingController();
  final observacaoController = TextEditingController();
  String cartaoSelecionadoId = '';
  String cartaoSelecionadoNome = '';
  String cartaoSelecionadoTipo = '';
  int cartaoSelecionadoDiaVencimento = 10;
  String categoriaSelecionada = '';
  
  // Dados do consórcio
 // Dados do consórcio (agora vão ser carregados do Firebase)
late double valorParcelaConsorcio;
late int parcelasPagasConsorcio;
late int parcelasTotaisConsorcio;
late double valorTotalConsorcio;
  
  // Categorias pré-definidas
  List<String> categorias = ['Alimentação', 'Transporte', 'Lazer', 'Saúde', 'Educação', 'Moradia', 'Outros'];
  
  // Controlador para nova categoria
  final novaCategoriaController = TextEditingController();

  @override
  void dispose() {
    valorCompraController.dispose();
    parcelasController.dispose();
    observacaoController.dispose();
    novaCategoriaController.dispose();
    super.dispose();
  }

    @override
  void initState() {
    super.initState();
    _carregarDadosConsorcio();  // <--- ADICIONE ESTA LINHA
  }

  Future<void> _carregarDadosConsorcio() async {
    try {
      final querySnapshot = await firestore
          .collection('consorcio')
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        setState(() {
          valorParcelaConsorcio = (data['valorParcela'] ?? 850.0).toDouble();
          parcelasPagasConsorcio = (data['parcelasPagas'] ?? 12).toInt();
          parcelasTotaisConsorcio = (data['parcelasTotais'] ?? 60).toInt();
          valorTotalConsorcio = (data['valorTotal'] ?? 50000.0).toDouble();
        });
      } else {
        // Valores padrão caso não exista documento
        setState(() {
          valorParcelaConsorcio = 850.0;
          parcelasPagasConsorcio = 12;
          parcelasTotaisConsorcio = 60;
          valorTotalConsorcio = 50000.0;
        });
      }
    } catch (e) {
      print('Erro ao carregar consórcio: $e');
      // Valores padrão em caso de erro
      setState(() {
        valorParcelaConsorcio = 850.0;
        parcelasPagasConsorcio = 12;
        parcelasTotaisConsorcio = 60;
        valorTotalConsorcio = 50000.0;
      });
    }
  }

  // Função para calcular em qual mês cada parcela cai
  DateTime calcularDataVencimentoParcela(DateTime dataCompra, int parcelaNumero, int diaVencimento) {
    DateTime dataBase = DateTime(dataCompra.year, dataCompra.month, diaVencimento);
    
    if (dataCompra.day > diaVencimento) {
      return DateTime(dataCompra.year, dataCompra.month + parcelaNumero, diaVencimento);
    } else {
      return DateTime(dataCompra.year, dataCompra.month + (parcelaNumero - 1), diaVencimento);
    }
  }

  // Função para calcular total a pagar no mês atual
  Future<double> calcularTotalMesAtual() async {
    double total = 0.0;
    DateTime now = DateTime.now();
    int mesAtual = now.month;
    int anoAtual = now.year;
    
    // Adiciona parcela do consórcio
    total += valorParcelaConsorcio;
    
    // Busca compras do Firebase
    final comprasSnapshot = await firestore.collection('compras').get();
    
    for (var doc in comprasSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      if (data['tipo'] == 'credito') {
        List parcelasList = List.from(data['parcelasList']);
        for (var parcela in parcelasList) {
          if (!parcela['pago']) {
            DateTime vencimento = (parcela['dataVencimento'] as Timestamp).toDate();
            if (vencimento.month == mesAtual && vencimento.year == anoAtual) {
              total += parcela['valor'];
            }
          }
        }
      }
    }
    
    return total;
  }

  Future<void> adicionarNovaCategoria() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Nova Categoria', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: novaCategoriaController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nome da categoria',
            labelStyle: TextStyle(color: Colors.grey[400]),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[800]!),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blueAccent),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              if (novaCategoriaController.text.trim().isNotEmpty) {
                setState(() {
                  categorias.add(novaCategoriaController.text.trim());
                  categoriaSelecionada = novaCategoriaController.text.trim();
                });
                Navigator.pop(context);
                _showSnackBar('Categoria adicionada!', Colors.green);
                novaCategoriaController.clear();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('ADICIONAR'),
          ),
        ],
      ),
    );
  }

  Future<void> adicionarCompra(String cartaoId, double valorTotal, int parcelas, String cartaoNome, String tipo, Color corCartao, int diaVencimento) async {
    try {
      final cartaoRef = firestore.collection('cartoes').doc(cartaoId);
      final cartaoDoc = await cartaoRef.get();
      final cartaoData = cartaoDoc.data() as Map<String, dynamic>;
      
      double valorAtual = cartaoData['valor'];
      
      if (tipo == 'credito') {
        if (valorAtual < valorTotal) {
          _showSnackBar('Limite insuficiente!', Colors.red);
          return;
        }
        
        double novoLimite = valorAtual - valorTotal;
        await cartaoRef.update({'valor': novoLimite});
        
        double valorParcela = valorTotal / parcelas;
        List<Map<String, dynamic>> parcelasList = [];
        DateTime dataCompra = DateTime.now();
        
        for (int i = 1; i <= parcelas; i++) {
          DateTime dataVencimento = calcularDataVencimentoParcela(dataCompra, i, diaVencimento);
          parcelasList.add({
            'numero': i,
            'valor': valorParcela,
            'pago': false,
            'dataVencimento': Timestamp.fromDate(dataVencimento),
            'mesReferencia': '${dataVencimento.month}/${dataVencimento.year}',
          });
        }
        
        final compraData = {
          'cartaoId': cartaoId,
          'cartaoNome': cartaoNome,
          'valorTotal': valorTotal,
          'parcelas': parcelas,
          'valorParcela': valorParcela,
          'dataCompra': FieldValue.serverTimestamp(),
          'parcelasList': parcelasList,
          'valorPago': 0.0,
          'tipo': 'credito',
          'cor': corCartao.value,
          'observacao': observacaoController.text.trim(),
          'categoria': categoriaSelecionada,
          'diaVencimento': diaVencimento,
        };
        
        await firestore.collection('compras').add(compraData);
        _showSnackBar('Compra parcelada adicionada com sucesso!', Colors.green);
        
      } else if (tipo == 'debito') {
        if (valorAtual < valorTotal) {
          _showSnackBar('Saldo insuficiente!', Colors.red);
          return;
        }
        
        double novoSaldo = valorAtual - valorTotal;
        await cartaoRef.update({'valor': novoSaldo});
        
        final compraData = {
          'cartaoId': cartaoId,
          'cartaoNome': cartaoNome,
          'valorTotal': valorTotal,
          'parcelas': 1,
          'valorParcela': valorTotal,
          'dataCompra': FieldValue.serverTimestamp(),
          'parcelasList': [
            {
              'numero': 1,
              'valor': valorTotal,
              'pago': true,
              'dataCompra': DateTime.now(),
            }
          ],
          'valorPago': valorTotal,
          'tipo': 'debito',
          'cor': corCartao.value,
          'observacao': observacaoController.text.trim(),
          'categoria': categoriaSelecionada,
        };
        
        await firestore.collection('compras').add(compraData);
        _showSnackBar('Compra realizada com sucesso!', Colors.green);
      }
      
      observacaoController.clear();
      categoriaSelecionada = '';
      Navigator.pop(context);
      
    } catch (e) {
      _showSnackBar('Erro ao adicionar compra', Colors.red);
    }
  }
  
  Future<void> marcarParcelaComoPaga(String compraId, int parcelaNumero, double valorParcela, String cartaoId) async {
    try {
      final compraRef = firestore.collection('compras').doc(compraId);
      final compraDoc = await compraRef.get();
      final compraData = compraDoc.data() as Map<String, dynamic>;
      
      List parcelasList = List.from(compraData['parcelasList']);
      
      bool parcelaEncontrada = false;
      for (var i = 0; i < parcelasList.length; i++) {
        if (parcelasList[i]['numero'] == parcelaNumero && !parcelasList[i]['pago']) {
          parcelasList[i]['pago'] = true;
          parcelaEncontrada = true;
          break;
        }
      }
      
      if (!parcelaEncontrada) {
        _showSnackBar('Parcela já foi paga ou não encontrada!', Colors.orange);
        return;
      }
      
      double novoValorPago = compraData['valorPago'] + valorParcela;
      
      await compraRef.update({
        'parcelasList': parcelasList,
        'valorPago': novoValorPago,
      });
      
      final cartaoRef = firestore.collection('cartoes').doc(cartaoId);
      final cartaoDoc = await cartaoRef.get();
      final cartaoData = cartaoDoc.data() as Map<String, dynamic>;
      double valorAtual = cartaoData['valor'];
      
      await cartaoRef.update({
        'valor': valorAtual + valorParcela,
      });
      
      _showSnackBar('Parcela $parcelaNumero paga! Limite liberado: R\$ ${valorParcela.toStringAsFixed(2)}', Colors.green);
      
    } catch (e) {
      _showSnackBar('Erro ao marcar parcela como paga', Colors.red);
    }
  }
  
  Future<void> reverterParcelaPaga(String compraId, int parcelaNumero, double valorParcela, String cartaoId) async {
    try {
      final compraRef = firestore.collection('compras').doc(compraId);
      final compraDoc = await compraRef.get();
      final compraData = compraDoc.data() as Map<String, dynamic>;
      
      List parcelasList = List.from(compraData['parcelasList']);
      
      bool parcelaEncontrada = false;
      for (var i = 0; i < parcelasList.length; i++) {
        if (parcelasList[i]['numero'] == parcelaNumero && parcelasList[i]['pago']) {
          parcelasList[i]['pago'] = false;
          parcelaEncontrada = true;
          break;
        }
      }
      
      if (!parcelaEncontrada) {
        _showSnackBar('Parcela não encontrada ou já está não paga!', Colors.orange);
        return;
      }
      
      double novoValorPago = compraData['valorPago'] - valorParcela;
      
      await compraRef.update({
        'parcelasList': parcelasList,
        'valorPago': novoValorPago,
      });
      
      final cartaoRef = firestore.collection('cartoes').doc(cartaoId);
      final cartaoDoc = await cartaoRef.get();
      final cartaoData = cartaoDoc.data() as Map<String, dynamic>;
      double valorAtual = cartaoData['valor'];
      
      await cartaoRef.update({
        'valor': valorAtual - valorParcela,
      });
      
      _showSnackBar('Pagamento da parcela $parcelaNumero revertido!', Colors.orange);
      
    } catch (e) {
      _showSnackBar('Erro ao reverter pagamento', Colors.red);
    }
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  void mostrarDialogoCompra(String cartaoId, String cartaoNome, String tipo, Color corCartao, int diaVencimento) {
    cartaoSelecionadoId = cartaoId;
    cartaoSelecionadoNome = cartaoNome;
    cartaoSelecionadoTipo = tipo;
    cartaoSelecionadoDiaVencimento = diaVencimento;
    valorCompraController.clear();
    parcelasController.clear();
    observacaoController.clear();
    categoriaSelecionada = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.shopping_cart, color: corCartao),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nova Compra - $cartaoNome',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: valorCompraController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Valor da compra',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.attach_money, color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[800]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: corCartao),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  if (tipo == 'credito') ...[
                    TextField(
                      controller: parcelasController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Número de parcelas',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.receipt, color: Colors.grey[400]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[800]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: corCartao),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  TextField(
                    controller: observacaoController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Observação (ex: Celular, Restaurante...)',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.note, color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[800]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: corCartao),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Categoria',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      SizedBox(height: 8),
                      Container(
                        constraints: BoxConstraints(maxHeight: 120),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...categorias.map((categoria) {
                              return FilterChip(
                                label: Text(categoria),
                                labelStyle: TextStyle(
                                  color: categoriaSelecionada == categoria ? Colors.white : Colors.grey[400],
                                  fontSize: 12,
                                ),
                                backgroundColor: const Color(0xFF2A2A2A),
                                selectedColor: corCartao,
                                selected: categoriaSelecionada == categoria,
                                onSelected: (selected) {
                                  setDialogState(() {
                                    categoriaSelecionada = selected ? categoria : '';
                                  });
                                },
                              );
                            }),
                            ActionChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 16),
                                  SizedBox(width: 4),
                                  Text('Nova'),
                                ],
                              ),
                              backgroundColor: const Color(0xFF2A2A2A),
                              onPressed: adicionarNovaCategoria,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CANCELAR', style: TextStyle(color: Colors.grey[400])),
              ),
              ElevatedButton(
                onPressed: () {
                  double valor = double.tryParse(valorCompraController.text) ?? 0;
                  
                  if (valor <= 0) {
                    _showSnackBar('Valor inválido!', Colors.orange);
                    return;
                  }
                  
                  if (tipo == 'credito') {
                    int parcelas = int.tryParse(parcelasController.text) ?? 1;
                    if (parcelas <= 0 || parcelas > 24) {
                      _showSnackBar('Número de parcelas inválido! (1-24)', Colors.orange);
                      return;
                    }
                    adicionarCompra(cartaoSelecionadoId, valor, parcelas, cartaoSelecionadoNome, tipo, corCartao, cartaoSelecionadoDiaVencimento);
                  } else {
                    adicionarCompra(cartaoSelecionadoId, valor, 1, cartaoSelecionadoNome, tipo, corCartao, 0);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: corCartao,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(tipo == 'credito' ? 'ADICIONAR COMPRA' : 'PAGAR'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void mostrarDetalhesCompra(String compraId, Map<String, dynamic> compraData, String cartaoId, Color corCartao) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt, color: corCartao, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Detalhes da Compra',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: corCartao.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: corCartao.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            _infoRow('Cartão', compraData['cartaoNome'], corCartao),
                            _infoRow('Valor Total', 'R\$ ${compraData['valorTotal'].toStringAsFixed(2)}', corCartao),
                            if (compraData['observacao'] != null && compraData['observacao'].isNotEmpty)
                              _infoRow('Observação', compraData['observacao'], corCartao),
                            if (compraData['categoria'] != null && compraData['categoria'].isNotEmpty)
                              _infoRow('Categoria', compraData['categoria'], corCartao),
                            if (compraData['tipo'] == 'credito') ...[
                              _infoRow('Parcelas', '${compraData['parcelas']}x de R\$ ${compraData['valorParcela'].toStringAsFixed(2)}', corCartao),
                              _infoRow('Valor Pago', 'R\$ ${compraData['valorPago'].toStringAsFixed(2)}', corCartao),
                              _infoRow('Saldo Devedor', 'R\$ ${(compraData['valorTotal'] - compraData['valorPago']).toStringAsFixed(2)}', corCartao),
                            ],
                          ],
                        ),
                      ),
                      if (compraData['tipo'] == 'credito') ...[
                        SizedBox(height: 20),
                        Text(
                          'Parcelas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          height: 300,
                          child: ListView.builder(
                            itemCount: compraData['parcelasList'].length,
                            itemBuilder: (context, index) {
                              final parcela = compraData['parcelasList'][index];
                              DateTime vencimento = (parcela['dataVencimento'] as Timestamp).toDate();
                              return Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: corCartao.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: corCartao.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${parcela['numero']}ª Parcela',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Vence: ${vencimento.day}/${vencimento.month}/${vencimento.year}',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'R\$ ${parcela['valor'].toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: parcela['pago'] ? Colors.green : Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        if (!parcela['pago'])
                                          ElevatedButton(
                                            onPressed: () {
                                              marcarParcelaComoPaga(
                                                compraId,
                                                parcela['numero'],
                                                parcela['valor'],
                                                cartaoId,
                                              ).then((_) {
                                                Navigator.pop(context);
                                                setState(() {});
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text('PAGAR'),
                                          )
                                        else
                                          Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'PAGO',
                                                  style: TextStyle(color: Colors.green, fontSize: 12),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              IconButton(
                                                onPressed: () {
                                                  reverterParcelaPaga(
                                                    compraId,
                                                    parcela['numero'],
                                                    parcela['valor'],
                                                    cartaoId,
                                                  ).then((_) {
                                                    Navigator.pop(context);
                                                    setState(() {});
                                                  });
                                                },
                                                icon: Icon(Icons.undo, color: Colors.orange, size: 20),
                                                tooltip: 'Reverter pagamento',
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _infoRow(String label, String value, Color cor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(value, style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return _buildMobileLayout();
          } else {
            return _buildDesktopLayout();
          }
        },
      ),
    );
  }

  // Layout para Desktop
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // MENU LATERAL ESQUERDO - LISTA DE CARTÕES
        Container(
          width: 350,
          color: const Color(0xFF111111),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meus Cartões',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Selecione um cartão para ver as compras',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestore.collection('cartoes').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.credit_card_off, color: Colors.grey[600], size: 48),
                            SizedBox(height: 16),
                            Text(
                              'Nenhum cartão cadastrado',
                              style: TextStyle(color: Colors.grey[400], fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final corCartao = Color(data['cor']);
                        
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                corCartao,
                                corCartao.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: corCartao.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {},
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['nome'],
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white24,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            data['tipo'].toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      data['tipo'] == 'credito' ? 'Limite Disponível' : 'Saldo Disponível',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    Text(
                                      'R\$ ${data['valor'].toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (data['tipo'] == 'credito' && data['diaVencimento'] != null)
                                      Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Vence dia ${data['diaVencimento']}',
                                          style: TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ),
                                    SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => mostrarDialogoCompra(
                                          doc.id, 
                                          data['nome'], 
                                          data['tipo'], 
                                          corCartao,
                                          data['diaVencimento'] ?? 10
                                        ),
                                        icon: Icon(Icons.shopping_cart, size: 14),
                                        label: Text(data['tipo'] == 'credito' ? 'COMPRAR' : 'PAGAR'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white24,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
        ),
        
        // CONTEÚDO PRINCIPAL
        Expanded(
          flex: 3,
          child: Container(
            color: const Color(0xFF0B0B0B),
            child: Column(
              children: [
                // Card de Resumo Mensal
                Padding(
                  padding: EdgeInsets.all(20),
                  child: _buildResumoMensalCard(),
                ),
                
                // Lista de compras
                Expanded(
                  child: _buildComprasList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Layout para Mobile
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Cards dos cartões (scroll horizontal)
          Container(
            height: 220,
            color: const Color(0xFF111111),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Meus Cartões',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: firestore.collection('cartoes').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.credit_card_off, color: Colors.grey[600], size: 48),
                              SizedBox(height: 16),
                              Text(
                                'Nenhum cartão cadastrado',
                                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final corCartao = Color(data['cor']);
                          
                          return Container(
                            width: 280,
                            margin: EdgeInsets.only(right: 17),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  corCartao,
                                  corCartao.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: corCartao.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Container(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          data['nome'],
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          data['tipo'].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    data['tipo'] == 'credito' ? 'Limite Disponível' : 'Saldo Disponível',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  Text(
                                    'R\$ ${data['valor'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (data['tipo'] == 'credito' && data['diaVencimento'] != null)
                                    // Padding(
                                    //   padding: EdgeInsets.only(top: 8),
                                    //   child: Text(
                                    //     'Vence dia ${data['diaVencimento']}',
                                    //     style: TextStyle(color: Colors.white70, fontSize: 12),
                                    //   ),
                                    // ),
                                  SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => mostrarDialogoCompra(
                                        doc.id, 
                                        data['nome'], 
                                        data['tipo'], 
                                        corCartao,
                                        data['diaVencimento'] ?? 10
                                      ),
                                      icon: Icon(Icons.shopping_cart, size: 14),
                                      label: Text(data['tipo'] == 'credito' ? 'COMPRAR' : 'PAGAR'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white24,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                    
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
          ),
          
          // Card de Resumo Mensal
          Padding(
            padding: EdgeInsets.all(16),
            child: _buildResumoMensalCard(),
          ),
          
          // Lista de compras
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Últimas Compras',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                _buildComprasList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card de Resumo Mensal (Consórcio + Faturas)
  // Card de Resumo Mensal (Consórcio + Faturas) - COM BOTÕES CLICÁVEIS
Widget _buildResumoMensalCard() {
  return FutureBuilder<double>(
    future: calcularTotalMesAtual(),
    builder: (context, snapshot) {
      double totalFaturas = snapshot.data ?? 0.0;
      double totalGeral = valorParcelaConsorcio + totalFaturas;
      
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E),
              Color(0xFF0D1B3E),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.amber, size: 28),
                SizedBox(width: 12),
                Text(
                  'Resumo do Mês',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // Total a pagar
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Text(
                    'TOTAL A PAGAR',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'R\$ ${totalGeral.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // Detalhamento - COM BOTÕES CLICÁVEIS
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditarConsorcioScreen()),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Consórcio',
          style: TextStyle(color: Colors.green, fontSize: 12),
        ),
        Icon(Icons.edit, color: Colors.green, size: 14),
      ],
    ),
    SizedBox(height: 4),
    Text(
      'R\$ ${valorParcelaConsorcio.toStringAsFixed(2)}',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    SizedBox(height: 4),
    Text(
      '$parcelasPagasConsorcio/$parcelasTotaisConsorcio parcelas',
      style: TextStyle(color: Colors.grey[500], fontSize: 10),
    ),
    // NOVO: Valor já pago
    SizedBox(height: 8),
    Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Já pago:',
            style: TextStyle(color: Colors.grey[400], fontSize: 10),
          ),
          Text(
            'R\$ ${(parcelasPagasConsorcio * valorParcelaConsorcio).toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  ],
),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditarFaturaScreen()),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Fatura do Mês',
                                style: TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                              Icon(Icons.edit, color: Colors.orange, size: 14),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'R\$ ${totalFaturas.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Clique para editar',
                            style: TextStyle(color: Colors.grey[500], fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

  // Lista de compras (sem cores)
  Widget _buildComprasList() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('compras').orderBy('dataCompra', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        
        final docs = snapshot.data!.docs;
        
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, color: Colors.grey[600], size: 80),
                SizedBox(height: 16),
                Text(
                  'Nenhuma compra realizada',
                  style: TextStyle(color: Colors.grey[400], fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'Adicione compras nos cartões acima',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final parcelasPagas = data['tipo'] == 'credito' 
                ? (data['parcelasList'] as List).where((p) => p['pago'] == true).length
                : 1;
            final totalParcelas = data['parcelas'];
            final status = parcelasPagas == totalParcelas ? 'PAGO' : 'EM ANDAMENTO';
            final statusColor = parcelasPagas == totalParcelas ? Colors.green : Colors.orange;
            
            return GestureDetector(
              onTap: () => mostrarDetalhesCompra(doc.id, data, data['cartaoId'], Color(data['cor'])),
              child: Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['cartaoNome'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (data['observacao'] != null && data['observacao'].isNotEmpty)
                                Text(
                                  data['observacao'],
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (data['categoria'] != null && data['categoria'].isNotEmpty)
                                Container(
                                  margin: EdgeInsets.only(top: 4),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    data['categoria'],
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'R\$ ${data['valorTotal'].toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (data['tipo'] == 'credito') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${parcelasPagas}/$totalParcelas parcelas pagas',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                          Text(
                            'R\$ ${data['valorParcela'].toStringAsFixed(2)}/mês',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: parcelasPagas / totalParcelas,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          minHeight: 4,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Compra à vista',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.touch_app, color: Colors.grey[600], size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Toque para ver detalhes',
                          style: TextStyle(color: Colors.grey[600], fontSize: 10),
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
    );
  }
}