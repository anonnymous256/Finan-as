import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

// ========================= CONFIGURAÇÃO DE CARTÕES =========================
class CardConfigScreen extends StatefulWidget {
  @override
  _CardConfigScreenState createState() => _CardConfigScreenState();
}

class _CardConfigScreenState extends State<CardConfigScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final nomeController = TextEditingController();
  final valorController = TextEditingController();
  int diaVencimento = 10; // Dia padrão de vencimento

  Color selectedColor = const Color(0xFF6C63FF);
  String tipo = 'credito';

  String gerarNumeroFake() {
    final rand = Random();
    return '**** ${rand.nextInt(9000) + 1000}';
  }

  String getLogo(String nome) {
    nome = nome.toLowerCase();
    if (nome.contains('nubank')) return '🟣';
    if (nome.contains('c6')) return '⚫';
    if (nome.contains('itau')) return '🟠';
    if (nome.contains('bradesco')) return '🔵';
    if (nome.contains('santander')) return '🔴';
    return '💳';
  }

  String getValorLabel() {
    return tipo == 'credito' ? 'Limite do cartão' : 'Saldo disponível';
  }

  IconData getValorIcon() {
    return tipo == 'credito' ? Icons.credit_card : Icons.account_balance;
  }

  Future<void> salvarCartao({String? id}) async {
    if (nomeController.text.trim().isEmpty) {
      _showSnackBar('Por favor, informe o nome do cartão', Colors.orange);
      return;
    }

    if (valorController.text.trim().isEmpty) {
      final label = getValorLabel();
      _showSnackBar('Por favor, informe o $label', Colors.orange);
      return;
    }

    final valorNumerico = double.tryParse(valorController.text) ?? 0;
    
    if (valorNumerico < 0) {
      _showSnackBar('O valor não pode ser negativo', Colors.orange);
      return;
    }

    final data = {
      'nome': nomeController.text.trim(),
      'valor': valorNumerico,
      'tipo': tipo,
      'cor': selectedColor.value,
      'numero': gerarNumeroFake(),
      'diaVencimento': tipo == 'credito' ? diaVencimento : null,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (id == null) {
        await firestore.collection('cartoes').add(data);
        _showSnackBar('Cartão adicionado com sucesso!', Colors.green);
      } else {
        await firestore.collection('cartoes').doc(id).update(data);
        _showSnackBar('Cartão atualizado com sucesso!', Colors.green);
      }

      nomeController.clear();
      valorController.clear();
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Erro ao salvar cartão', Colors.red);
    }
  }

  Future<void> deletarCartao(String id, String nome) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDeleteDialog(cardName: nome),
    );

    if (confirm == true) {
      try {
        await firestore.collection('cartoes').doc(id).delete();
        _showSnackBar('Cartão removido com sucesso!', Colors.green);
      } catch (e) {
        _showSnackBar('Erro ao remover cartão', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void abrirModal({DocumentSnapshot? doc}) {
    if (doc != null) {
      nomeController.text = doc['nome'];
      valorController.text = doc['valor'].toString();
      selectedColor = Color(doc['cor']);
      tipo = doc['tipo'];
      diaVencimento = doc['diaVencimento'] ?? 10;
    } else {
      nomeController.clear();
      valorController.clear();
      selectedColor = const Color(0xFF6C63FF);
      tipo = 'credito';
      diaVencimento = 10;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: 20),

                    Row(
                      children: [
                        Icon(
                          doc == null ? Icons.add_card : Icons.edit,
                          color: selectedColor,
                          size: 24,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            doc == null ? 'ADICIONAR CARTÃO' : 'EDITAR CARTÃO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Card Preview
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            selectedColor,
                            selectedColor.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: selectedColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                getLogo(nomeController.text),
                                style: TextStyle(fontSize: 28),
                              ),
                              Icon(Icons.credit_card, color: Colors.white70, size: 32),
                            ],
                          ),
                          SizedBox(height: 30),
                          Text(
                            nomeController.text.isEmpty
                                ? 'NOME DO CARTÃO'
                                : nomeController.text.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 12),
                          Text(
                            doc != null && doc['numero'] != null 
                                ? doc['numero'] 
                                : gerarNumeroFake(),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tipo.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    TextField(
                      controller: nomeController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nome do cartão',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[800]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: selectedColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.credit_card, color: Colors.grey[400]),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),

                    SizedBox(height: 16),

                    TextField(
                      controller: valorController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: getValorLabel(),
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        helperText: tipo == 'credito' 
                            ? 'Defina o limite do seu cartão de crédito'
                            : 'Informe o saldo disponível na sua conta',
                        helperStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[800]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: selectedColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(getValorIcon(), color: Colors.grey[400]),
                        suffixText: 'R\$',
                        suffixStyle: TextStyle(color: Colors.grey[400]),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),

                    if (tipo == 'credito') ...[
                      SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dia de Vencimento da Fatura',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[800]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
  child: DropdownButton<int>(
    value: diaVencimento,
    isExpanded: true,
    dropdownColor: const Color(0xFF2A2A2A),
    style: TextStyle(color: Colors.white),
    items: List.generate(28, (index) => index + 1).map((dia) {
      return DropdownMenuItem<int>(
        value: dia,
        child: Text('Dia $dia'),
      );
    }).toList(), // Adicione .toList() aqui
    onChanged: (value) {
      setModalState(() {
        diaVencimento = value!;
      });
    },
  ),
),
                          ),
                        ],
                      ),
                    ],

                    SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: _tipoButton('credito', Icons.credit_card, setModalState),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _tipoButton('debito', Icons.account_balance_wallet, setModalState),
                        ),
                      ],
                    ),

                    SizedBox(height: 20),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COR DO CARTÃO',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _colorOption(const Color(0xFF6C63FF), setModalState),
                            _colorOption(const Color(0xFF2196F3), setModalState),
                            _colorOption(const Color(0xFFFF9800), setModalState),
                            _colorOption(const Color(0xFF4CAF50), setModalState),
                            _colorOption(const Color(0xFFE91E63), setModalState),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => salvarCartao(id: doc?.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedColor,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          doc == null ? 'ADICIONAR CARTÃO' : 'ATUALIZAR CARTÃO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _tipoButton(String value, IconData icon, Function setModalState) {
    final selected = tipo == value;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          tipo = value;
          if (valorController.text.isNotEmpty) {
            valorController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? selectedColor : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? selectedColor : Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.grey[400], size: 20),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                value.toUpperCase(),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey[400],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorOption(Color color, Function setModalState) {
    final isSelected = selectedColor == color;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          selectedColor = color;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 20,
          backgroundColor: color,
          child: isSelected
              ? Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        title: Text(
          'Configurar Cartões',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => abrirModal(),
        backgroundColor: const Color(0xFF6C63FF),
        child: Icon(Icons.add, size: 30),
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('cartoes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Erro ao carregar cartões',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF6C63FF)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Carregando cartões...',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card_off, color: Colors.grey[600], size: 80),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum cartão cadastrado',
                    style: TextStyle(color: Colors.grey[400], fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Toque no botão + para adicionar',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.all(16),
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                return Dismissible(
                  key: Key(doc.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete_outline, color: Colors.white, size: 32),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => _ConfirmDeleteDialog(cardName: data['nome']),
                    );
                  },
                  onDismissed: (direction) => deletarCartao(doc.id, data['nome']),
                  child: GestureDetector(
                    onTap: () => abrirModal(doc: doc),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(data['cor']),
                            Color(data['cor']).withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Color(data['cor']).withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                getLogo(data['nome']),
                                style: TextStyle(fontSize: 28),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'EDITAR',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          Text(
                            data['nome'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            data['numero'] ?? '**** 0000',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                          if (data['tipo'] == 'credito') ...[
                            SizedBox(height: 8),
                            Text(
                              'Vence dia ${data['diaVencimento']}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Limite: R\$ ${data['valor'].toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ] else ...[
                            SizedBox(height: 12),
                            Text(
                              'Saldo: R\$ ${data['valor'].toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// Dialog de confirmação de exclusão
class _ConfirmDeleteDialog extends StatelessWidget {
  final String cardName;

  const _ConfirmDeleteDialog({required this.cardName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_rounded, color: Colors.red, size: 48),
            ),
            SizedBox(height: 16),
            Text(
              'Excluir Cartão?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Flexible(
              child: Text(
                'Você tem certeza que deseja excluir o cartão "$cardName"?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'CANCELAR',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'EXCLUIR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}