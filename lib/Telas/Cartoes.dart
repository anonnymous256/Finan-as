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
  final limiteController = TextEditingController();

  Color selectedColor = Colors.blueAccent;
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
    return '💳';
  }

  void salvarCartao({String? id}) async {
    final data = {
      'nome': nomeController.text,
      'limite': tipo == 'credito'
          ? double.tryParse(limiteController.text) ?? 0
          : 0,
      'fatura': 0.0,
      'cor': selectedColor.value,
      'tipo': tipo,
      'numero': gerarNumeroFake(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (id == null) {
      await firestore.collection('cartoes').add(data);
    } else {
      await firestore.collection('cartoes').doc(id).update(data);
    }

    nomeController.clear();
    limiteController.clear();
  }

  void deletarCartao(String id) async {
    await firestore.collection('cartoes').doc(id).delete();
  }

  void abrirModal({DocumentSnapshot? doc}) {
    if (doc != null) {
      nomeController.text = doc['nome'];
      limiteController.text = doc['limite'].toString();
      selectedColor = Color(doc['cor']);
      tipo = doc['tipo'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(0xFF111111),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [selectedColor, selectedColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(getLogo(nomeController.text), style: TextStyle(fontSize: 22)),
                      SizedBox(height: 10),
                      Text(
                        nomeController.text.isEmpty
                            ? 'Nome do Cartão'
                            : nomeController.text,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      SizedBox(height: 10),
                      Text(gerarNumeroFake(), style: TextStyle(color: Colors.white70)),
                      SizedBox(height: 10),
                      Text(tipo.toUpperCase(), style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                TextField(
                  controller: nomeController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'Nome do cartão'),
                  onChanged: (_) => setModalState(() {}),
                ),

                if (tipo == 'credito')
                  TextField(
                    controller: limiteController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: 'Limite'),
                    onChanged: (_) => setModalState(() {}),
                  ),

                SizedBox(height: 15),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _tipoButton('credito', Icons.credit_card, setModalState),
                    _tipoButton('debito', Icons.account_balance_wallet, setModalState),
                  ],
                ),

                SizedBox(height: 15),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _colorOption(Colors.purple, setModalState),
                    _colorOption(Colors.blue, setModalState),
                    _colorOption(Colors.orange, setModalState),
                    _colorOption(Colors.green, setModalState),
                  ],
                ),

                SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    salvarCartao(id: doc?.id);
                    Navigator.pop(context);
                  },
                  child: Text('Salvar'),
                ),

                SizedBox(height: 20),
              ],
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
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.blueAccent : Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 8),
            Text(value.toUpperCase(), style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _colorOption(Color color, Function setModalState) {
    return GestureDetector(
      onTap: () {
        setModalState(() {
          selectedColor = color;
        });
      },
      child: CircleAvatar(
        backgroundColor: color,
        child: selectedColor == color
            ? Icon(Icons.check, color: Colors.white)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0B0B0B),
      appBar: AppBar(title: Text('Meus Cartões')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => abrirModal(),
        child: Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('cartoes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          return ReorderableListView(
            onReorder: (oldIndex, newIndex) {},
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return Dismissible(
                key: Key(doc.id),
                background: Container(color: Colors.red),
                onDismissed: (_) => deletarCartao(doc.id),
                child: Container(
                  key: ValueKey(doc.id),
                  margin: EdgeInsets.all(10),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(data['cor']),
                        Color(data['cor']).withOpacity(0.7)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(getLogo(data['nome']), style: TextStyle(fontSize: 20)),
                      SizedBox(height: 8),
                      Text(data['nome'], style: TextStyle(color: Colors.white)),
                      Text(data['numero'] ?? '', style: TextStyle(color: Colors.white70)),
                      Text(data['tipo'].toUpperCase(), style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
