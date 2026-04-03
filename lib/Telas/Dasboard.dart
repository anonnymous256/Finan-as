import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  
  // Dados do dashboard
  double _totalGastoMes = 0.0;
  double _totalGastoAno = 0.0;
  double _mediaGastoMes = 0.0;
  double _maiorGastoMes = 0.0;
  int _totalCompras = 0;
  int _totalParcelasAtivas = 0;
  
  // Dados por categoria
  Map<String, double> _gastosPorCategoria = {};
  
  // Dados por cartão
  Map<String, double> _gastosPorCartao = {};
  
  // Gastos mensais (últimos 6 meses)
  List<double> _gastosMensais = [];
  List<String> _mesesLabels = [];
  
  // Gastos por dia do mês
  Map<int, double> _gastosPorDia = {};
  
  // Compras recentes
  List<Map<String, dynamic>> _comprasRecentes = [];
  
  // Dados do consórcio
  double _valorParcelaConsorcio = 0;
  int _parcelasPagasConsorcio = 0;
  int _parcelasTotaisConsorcio = 0;
  
  @override
  void initState() {
    super.initState();
    _carregarDados();
  }
  
  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    
    await Future.wait([
      _carregarGastosMes(),
      _carregarGastosAno(),
      _carregarGastosPorCategoria(),
      _carregarGastosPorCartao(),
      _carregarGastosMensais(),
      _carregarComprasRecentes(),
      _carregarDadosConsorcio(),
      _carregarEstatisticasGerais(),
    ]);
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _carregarEstatisticasGerais() async {
    final comprasSnapshot = await firestore.collection('compras').get();
    
    int totalCompras = 0;
    int totalParcelasAtivas = 0;
    double maiorGasto = 0;
    
    for (var doc in comprasSnapshot.docs) {
      final data = doc.data();
      totalCompras++;
      
      double valorTotal = (data['valorTotal'] ?? 0).toDouble();
      if (valorTotal > maiorGasto) {
        maiorGasto = valorTotal;
      }
      
      if (data['tipo'] == 'credito') {
        List parcelasList = List.from(data['parcelasList']);
        int parcelasNaoPagas = parcelasList.where((p) => p['pago'] == false).length;
        totalParcelasAtivas += parcelasNaoPagas;
      }
    }
    
    setState(() {
      _totalCompras = totalCompras;
      _totalParcelasAtivas = totalParcelasAtivas;
      _maiorGastoMes = maiorGasto;
      _mediaGastoMes = totalCompras > 0 ? _totalGastoMes / totalCompras : 0;
    });
  }
  
  Future<void> _carregarGastosMes() async {
    DateTime now = DateTime.now();
    int mesAtual = now.month;
    int anoAtual = now.year;
    double total = 0;
    
    final comprasSnapshot = await firestore.collection('compras').get();
    
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
      _totalGastoMes = total;
    });
  }
  
  Future<void> _carregarGastosAno() async {
    DateTime now = DateTime.now();
    int anoAtual = now.year;
    double total = 0;
    
    final comprasSnapshot = await firestore.collection('compras').get();
    
    for (var doc in comprasSnapshot.docs) {
      final data = doc.data();
      
      if (data['tipo'] == 'credito') {
        List parcelasList = List.from(data['parcelasList']);
        for (var parcela in parcelasList) {
          if (!parcela['pago']) {
            DateTime vencimento = (parcela['dataVencimento'] as Timestamp).toDate();
            if (vencimento.year == anoAtual) {
              total += parcela['valor'];
            }
          }
        }
      }
    }
    
    setState(() {
      _totalGastoAno = total;
    });
  }
  
  Future<void> _carregarGastosPorCategoria() async {
    Map<String, double> gastos = {};
    
    final comprasSnapshot = await firestore.collection('compras').get();
    
    for (var doc in comprasSnapshot.docs) {
      final data = doc.data();
      String categoria = data['categoria'] ?? 'Sem categoria';
      double valor = data['valorTotal'] ?? 0;
      
      gastos[categoria] = (gastos[categoria] ?? 0) + valor;
    }
    
    setState(() {
      _gastosPorCategoria = gastos;
    });
  }
  
  Future<void> _carregarGastosPorCartao() async {
    Map<String, double> gastos = {};
    
    final comprasSnapshot = await firestore.collection('compras').get();
    
    for (var doc in comprasSnapshot.docs) {
      final data = doc.data();
      String cartaoNome = data['cartaoNome'] ?? 'Desconhecido';
      double valor = data['valorTotal'] ?? 0;
      
      gastos[cartaoNome] = (gastos[cartaoNome] ?? 0) + valor;
    }
    
    setState(() {
      _gastosPorCartao = gastos;
    });
  }
  
  Future<void> _carregarGastosMensais() async {
    List<double> gastos = List.filled(6, 0.0);
    List<String> meses = [];
    
    DateTime now = DateTime.now();
    
    for (int i = 5; i >= 0; i--) {
      DateTime mes = DateTime(now.year, now.month - i);
      meses.add(DateFormat('MMM').format(mes));
      
      double total = 0;
      final comprasSnapshot = await firestore.collection('compras').get();
      
      for (var doc in comprasSnapshot.docs) {
        final data = doc.data();
        
        if (data['tipo'] == 'credito') {
          List parcelasList = List.from(data['parcelasList']);
          for (var parcela in parcelasList) {
            if (!parcela['pago']) {
              DateTime vencimento = (parcela['dataVencimento'] as Timestamp).toDate();
              if (vencimento.month == mes.month && vencimento.year == mes.year) {
                total += parcela['valor'];
              }
            }
          }
        }
      }
      
      gastos[5 - i] = total;
    }
    
    setState(() {
      _gastosMensais = gastos;
      _mesesLabels = meses;
    });
  }
  
  Future<void> _carregarComprasRecentes() async {
    final comprasSnapshot = await firestore
        .collection('compras')
        .orderBy('dataCompra', descending: true)
        .limit(10)
        .get();
    
    List<Map<String, dynamic>> compras = [];
    
    for (var doc in comprasSnapshot.docs) {
      final data = doc.data();
      compras.add({
        'id': doc.id,
        ...data,
      });
    }
    
    setState(() {
      _comprasRecentes = compras;
    });
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
          _valorParcelaConsorcio = (data['valorParcela'] ?? 0).toDouble();
          _parcelasPagasConsorcio = (data['parcelasPagas'] ?? 0).toInt();
          _parcelasTotaisConsorcio = (data['parcelasTotais'] ?? 0).toInt();
        });
      }
    } catch (e) {
      print('Erro ao carregar consórcio: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(
                    'Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: const Color(0xFF111111),
                  elevation: 0,
                  floating: true,
                  pinned: true,
                ),
                
                SliverPadding(
                  padding: EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Cards de indicadores principais
                      _buildIndicadoresPrincipais(),
                      
                      SizedBox(height: 20),
                      
                      // Gráfico de gastos mensais
                      _buildGraficoGastosMensais(),
                      
                      SizedBox(height: 20),
                      
                      // Gastos por categoria e cartão
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildGraficoGastosPorCategoria()),
                          SizedBox(width: 16),
                          Expanded(child: _buildGraficoGastosPorCartao()),
                        ],
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Cards de resumo
                      _buildCardsResumo(),
                      
                      SizedBox(height: 20),
                      
                      // Últimas compras
                      _buildUltimasCompras(),
                      
                      SizedBox(height: 30),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildIndicadoresPrincipais() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildIndicadorCard(
          titulo: 'Gasto do Mês',
          valor: 'R\$ ${_totalGastoMes.toStringAsFixed(2)}',
          cor: Colors.blue,
          icone: Icons.monetization_on,
          subtitulo: 'Total de gastos neste mês',
        ),
        _buildIndicadorCard(
          titulo: 'Gasto do Ano',
          valor: 'R\$ ${_totalGastoAno.toStringAsFixed(2)}',
          cor: Colors.green,
          icone: Icons.calendar_today,
          subtitulo: 'Total de gastos no ano',
        ),
        _buildIndicadorCard(
          titulo: 'Média por Compra',
          valor: 'R\$ ${_mediaGastoMes.toStringAsFixed(2)}',
          cor: Colors.orange,
          icone: Icons.trending_up,
          subtitulo: 'Valor médio por compra',
        ),
        _buildIndicadorCard(
          titulo: 'Maior Gasto',
          valor: 'R\$ ${_maiorGastoMes.toStringAsFixed(2)}',
          cor: Colors.red,
          icone: Icons.arrow_upward,
          subtitulo: 'Maior compra realizada',
        ),
        _buildIndicadorCard(
          titulo: 'Total Compras',
          valor: '$_totalCompras',
          cor: Colors.purple,
          icone: Icons.shopping_cart,
          subtitulo: 'Compras realizadas',
        ),
        _buildIndicadorCard(
          titulo: 'Parcelas Ativas',
          valor: '$_totalParcelasAtivas',
          cor: Colors.teal,
          icone: Icons.receipt,
          subtitulo: 'Parcelas pendentes',
        ),
      ],
    );
  }
  
  Widget _buildIndicadorCard({
    required String titulo,
    required String valor,
    required Color cor,
    required IconData icone,
    required String subtitulo,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
              Icon(icone, color: cor, size: 20),
            ],
          ),
          Text(
            valor,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitulo,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGraficoGastosMensais() {
    // Verifica se tem dados
    if (_gastosMensais.isEmpty || _gastosMensais.every((value) => value == 0)) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: Colors.blue, size: 24),
                SizedBox(width: 12),
                Text(
                  'Gastos nos Últimos 6 Meses',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(Icons.bar_chart, color: Colors.grey[600], size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Nenhum gasto registrado',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    double maxY = _gastosMensais.reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 100;
    
    return Container(
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
            children: [
              Icon(Icons.show_chart, color: Colors.blue, size: 24),
              SizedBox(width: 12),
              Text(
                'Gastos nos Últimos 6 Meses',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _mesesLabels.length) {
                          return Text(
                            _mesesLabels[index],
                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                          );
                        }
                        return Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'R\$ ${value.toInt()}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_gastosMensais.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: _gastosMensais[index],
                        color: Colors.blue,
                        width: 30,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGraficoGastosPorCategoria() {
    if (_gastosPorCategoria.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Column(
          children: [
            Icon(Icons.pie_chart, color: Colors.green, size: 24),
            SizedBox(height: 12),
            Text(
              'Gastos por Categoria',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Nenhum dado disponível',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    
    List<MapEntry<String, double>> sortedEntries = _gastosPorCategoria.entries.toList();
    sortedEntries.sort((a, b) => b.value.compareTo(a.value));
    
    // CORREÇÃO: Calcula o total real dos gastos por categoria
    double totalGasto = _gastosPorCategoria.values.reduce((a, b) => a + b);
    
    return Container(
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
            children: [
              Icon(Icons.pie_chart, color: Colors.green, size: 24),
              SizedBox(width: 12),
              Text(
                'Gastos por Categoria',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...sortedEntries.take(5).map((entry) {
            // CORREÇÃO: Verifica se totalGasto > 0 para evitar divisão por zero
            double percentual = totalGasto > 0 ? (entry.value / totalGasto) * 100 : 0;
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      Text(
                        'R\$ ${entry.value.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentual / 100,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      minHeight: 6,
                    ),
                  ),
                  Text(
                    '${percentual.toStringAsFixed(1)}% do total',
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildGraficoGastosPorCartao() {
    if (_gastosPorCartao.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Column(
          children: [
            Icon(Icons.credit_card, color: Colors.orange, size: 24),
            SizedBox(height: 12),
            Text(
              'Gastos por Cartão',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Nenhum dado disponível',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    
    List<MapEntry<String, double>> sortedEntries = _gastosPorCartao.entries.toList();
    sortedEntries.sort((a, b) => b.value.compareTo(a.value));
    
    List<Color> cores = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    
    return Container(
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
            children: [
              Icon(Icons.credit_card, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Text(
                'Gastos por Cartão',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...sortedEntries.map((entry) {
            int index = sortedEntries.indexOf(entry);
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cores[index % cores.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
                  Text(
                    'R\$ ${entry.value.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildCardsResumo() {
    double percentualConsorcio = _parcelasTotaisConsorcio > 0
        ? (_parcelasPagasConsorcio / _parcelasTotaisConsorcio) * 100
        : 0;
    
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade900,
                  Colors.green.shade800,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consórcio',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                SizedBox(height: 8),
                Text(
                  'R\$ ${_valorParcelaConsorcio.toStringAsFixed(2)}/mês',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$_parcelasPagasConsorcio/$_parcelasTotaisConsorcio parcelas',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentualConsorcio / 100,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.orange.shade900,
                  Colors.orange.shade800,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket Médio',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                SizedBox(height: 8),
                Text(
                  'R\$ ${_mediaGastoMes.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Por compra',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildUltimasCompras() {
    if (_comprasRecentes.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.shopping_cart_outlined, color: Colors.grey[600], size: 48),
              SizedBox(height: 12),
              Text(
                'Nenhuma compra recente',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
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
            children: [
              Icon(Icons.history, color: Colors.blue, size: 24),
              SizedBox(width: 12),
              Text(
                'Últimas Compras',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _comprasRecentes.length,
            itemBuilder: (context, index) {
              final compra = _comprasRecentes[index];
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.shopping_bag, color: Colors.blue, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            compra['cartaoNome'] ?? 'Cartão',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (compra['observacao'] != null && compra['observacao'].isNotEmpty)
                            Text(
                              compra['observacao'],
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          if (compra['categoria'] != null && compra['categoria'].isNotEmpty)
                            Text(
                              compra['categoria'],
                              style: TextStyle(color: Colors.grey[500], fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R\$ ${(compra['valorTotal'] ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (compra['tipo'] == 'credito')
                          Text(
                            '${compra['parcelas']}x',
                            style: TextStyle(color: Colors.grey[500], fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}