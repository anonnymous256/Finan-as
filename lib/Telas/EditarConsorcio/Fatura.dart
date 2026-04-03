import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditarFaturaScreen extends StatefulWidget {
  @override
  _EditarFaturaScreenState createState() => _EditarFaturaScreenState();
}

class _EditarFaturaScreenState extends State<EditarFaturaScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  String _cartaoSelecionadoId = '';
  String _cartaoSelecionadoNome = '';
  double _valorFatura = 0.0;
  int _diaVencimento = 10;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _carregarDadosFatura();
  }
  
  Future<void> _carregarDadosFatura() async {
    setState(() => _isLoading = true);
    
    try {
      final cartoesSnapshot = await firestore.collection('cartoes').get();
      
      if (cartoesSnapshot.docs.isNotEmpty) {
        final doc = cartoesSnapshot.docs.first;
        final data = doc.data();
        
        setState(() {
          _cartaoSelecionadoId = doc.id;
          _cartaoSelecionadoNome = data['nome'];
          _diaVencimento = data['diaVencimento'] ?? 10;
        });
        
        await _calcularFaturaDoCartao();
      }
    } catch (e) {
      print('Erro ao carregar dados: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _calcularFaturaDoCartao() async {
    if (_cartaoSelecionadoId.isEmpty) return;
    
    DateTime now = DateTime.now();
    int mesAtual = now.month;
    int anoAtual = now.year;
    double total = 0.0;
    
    final comprasSnapshot = await firestore
        .collection('compras')
        .where('cartaoId', isEqualTo: _cartaoSelecionadoId)
        .get();
    
    for (var doc in comprasSnapshot.docs) {
      final data = doc.data();
      
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
    
    setState(() {
      _valorFatura = total;
    });
  }
  
  Future<void> _salvarAlteracoes() async {
    setState(() => _isLoading = true);
    
    try {
      await firestore
          .collection('cartoes')
          .doc(_cartaoSelecionadoId)
          .update({
            'diaVencimento': _diaVencimento,
          });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dia de vencimento atualizado com sucesso!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _pagarFatura() async {
    setState(() => _isLoading = true);
    
    try {
      // Busca todas as compras do cartão
      final comprasSnapshot = await firestore
          .collection('compras')
          .where('cartaoId', isEqualTo: _cartaoSelecionadoId)
          .get();
      
      DateTime now = DateTime.now();
      int mesAtual = now.month;
      int anoAtual = now.year;
      
      for (var doc in comprasSnapshot.docs) {
        final data = doc.data();
        
        if (data['tipo'] == 'credito') {
          List parcelasList = List.from(data['parcelasList']);
          bool atualizou = false;
          
          for (var i = 0; i < parcelasList.length; i++) {
            DateTime vencimento = (parcelasList[i]['dataVencimento'] as Timestamp).toDate();
            if (!parcelasList[i]['pago'] && 
                vencimento.month == mesAtual && 
                vencimento.year == anoAtual) {
              
              parcelasList[i]['pago'] = true;
              atualizou = true;
            }
          }
          
          if (atualizou) {
            double novoValorPago = (data['valorPago'] ?? 0.0) + _valorFatura;
            await firestore.collection('compras').doc(doc.id).update({
              'parcelasList': parcelasList,
              'valorPago': novoValorPago,
            });
          }
        }
      }
      
      // Atualiza o limite do cartão
      final cartaoDoc = await firestore.collection('cartoes').doc(_cartaoSelecionadoId).get();
      final cartaoData = cartaoDoc.data()!;
      double limiteAtual = cartaoData['valor'];
      
      await firestore.collection('cartoes').doc(_cartaoSelecionadoId).update({
        'valor': limiteAtual + _valorFatura,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fatura paga com sucesso! R\$ ${_valorFatura.toStringAsFixed(2)} liberado no limite.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      await _calcularFaturaDoCartao();
      Navigator.pop(context);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao pagar fatura: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }
  
  void _mostrarDialogoPagarFatura() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Pagar Fatura',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Deseja marcar esta fatura como paga?',
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Valor da Fatura',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    'R\$ ${_valorFatura.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCELAR', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _pagarFatura();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('CONFIRMAR PAGAMENTO'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        title: Text(
          'Editar Fatura',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _salvarAlteracoes,
            child: Text(
              'SALVAR',
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card de informações
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.orange.shade900,
                          Colors.orange.shade800,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.receipt, size: 48, color: Colors.white),
                        SizedBox(height: 12),
                        Text(
                          'Fatura do Mês',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Edite as informações da sua fatura',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Seletor de cartão
                  Text(
                    'Cartão',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  StreamBuilder<QuerySnapshot>(
                    stream: firestore.collection('cartoes').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      
                      final docs = snapshot.data!.docs;
                      
                      if (docs.isEmpty) {
                        return Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Nenhum cartão cadastrado',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ),
                        );
                      }
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[800]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _cartaoSelecionadoId.isEmpty ? null : _cartaoSelecionadoId,
                            hint: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Selecione um cartão',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ),
                            dropdownColor: const Color(0xFF1A1A1A),
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                            items: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Icon(
                                        data['tipo'] == 'credito' 
                                            ? Icons.credit_card 
                                            : Icons.payment,
                                        color: Color(data['cor']),
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        data['nome'],
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) async {
                              if (newValue != null) {
                                final doc = docs.firstWhere((d) => d.id == newValue);
                                final data = doc.data() as Map<String, dynamic>;
                                
                                setState(() {
                                  _cartaoSelecionadoId = newValue;
                                  _cartaoSelecionadoNome = data['nome'];
                                  _diaVencimento = data['diaVencimento'] ?? 10;
                                });
                                
                                await _calcularFaturaDoCartao();
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Valor da fatura
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Valor da Fatura',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                        Text(
                          'R\$ ${_valorFatura.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _valorFatura > 0 ? _mostrarDialogoPagarFatura : null,
                            icon: Icon(Icons.payment),
                            label: Text('PAGAR FATURA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Dia de vencimento
                  Text(
                    'Dia de Vencimento',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _diaVencimento,
                        dropdownColor: const Color(0xFF1A1A1A),
                        isExpanded: true,
                        icon: Icon(Icons.calendar_today, color: Colors.blueAccent, size: 20),
                        items: List.generate(28, (index) => index + 1).map((dia) {
                          return DropdownMenuItem<int>(
                            value: dia,
                            child: Text(
                              '$dia',
                              style: TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _diaVencimento = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Últimas compras que compõem a fatura
                  Text(
                    'Compras na fatura atual',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  _buildComprasNaFatura(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildComprasNaFatura() {
    if (_cartaoSelecionadoId.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Selecione um cartão para ver as compras',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
      );
    }
    
    DateTime now = DateTime.now();
    int mesAtual = now.month;
    int anoAtual = now.year;
    
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('compras')
          .where('cartaoId', isEqualTo: _cartaoSelecionadoId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        
        List<Map<String, dynamic>> comprasNaFatura = [];
        
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          
          if (data['tipo'] == 'credito') {
            List parcelasList = List.from(data['parcelasList']);
            for (var parcela in parcelasList) {
              if (!parcela['pago']) {
                DateTime vencimento = (parcela['dataVencimento'] as Timestamp).toDate();
                if (vencimento.month == mesAtual && vencimento.year == anoAtual) {
                  comprasNaFatura.add({
                    'descricao': data['observacao'] ?? 'Compra sem descrição',
                    'valor': parcela['valor'],
                    'parcela': parcela['numero'],
                    'totalParcelas': data['parcelas'],
                  });
                }
              }
            }
          }
        }
        
        if (comprasNaFatura.isEmpty) {
          return Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Nenhuma compra na fatura atual',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
          );
        }
        
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: comprasNaFatura.length,
          itemBuilder: (context, index) {
            final compra = comprasNaFatura[index];
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          compra['descricao'],
                          style: TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${compra['parcela']}/${compra['totalParcelas']}ª parcela',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'R\$ ${compra['valor'].toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}