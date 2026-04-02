import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatelessWidget {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0B0B0B),
      body: Row(
        children: [
          // MENU LATERAL
          Container(
            width: 70,
            color: Color(0xFF111111),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(Icons.home, color: Colors.blueAccent),
                Icon(Icons.credit_card, color: Colors.grey),
                Icon(Icons.bar_chart, color: Colors.grey),
                Icon(Icons.settings, color: Colors.grey),
              ],
            ),
          ),

          // CONTEÚDO PRINCIPAL
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // TOPO
                  Row(
                    children: [
                      _topButton('Meus Cartões'),
                      SizedBox(width: 10),
                      _topButton('Configurar Cartões'),
                    ],
                  ),

                  SizedBox(height: 20),

                  Expanded(
                    child: Row(
                      children: [
                        // LISTA DE CARTÕES DINÂMICA
                        Expanded(
                          flex: 2,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: firestore.collection('cartoes').snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(child: CircularProgressIndicator());
                              }

                              final docs = snapshot.data!.docs;

                              return ListView.builder(
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final data = docs[index];
                                  return _cardItem(
                                    nome: data['nome'],
                                    limite: data['limite'],
                                    fatura: data['fatura'],
                                    cor: Color(data['cor']),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        SizedBox(width: 20),

                        // DASHBOARD DIREITA
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _dashboardCard(),
                              SizedBox(height: 20),
                              Expanded(child: _tabela()),
                            ],
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _topButton(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: Colors.white)),
    );
  }

  Widget _cardItem({required String nome, required double limite, required double fatura, required Color cor}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cor, cor.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nome, style: TextStyle(color: Colors.white)),
          SizedBox(height: 10),
          Text('Fatura: R\$ ${fatura.toStringAsFixed(2)}', style: TextStyle(color: Colors.white)),
          Text('Limite: R\$ ${limite.toStringAsFixed(2)}', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _dashboardCard() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text('Dashboard', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _tabela() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text('Tabela de faturas', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// FUNÇÃO PARA SALVAR CARTÃO NO FIREBASE
Future<void> salvarCartao({required String nome, required double limite, required double fatura, required int cor}) async {
  await FirebaseFirestore.instance.collection('cartoes').add({
    'nome': nome,
    'limite': limite,
    'fatura': fatura,
    'cor': cor,
  });
}
