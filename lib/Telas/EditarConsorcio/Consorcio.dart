import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditarConsorcioScreen extends StatefulWidget {
  @override
  _EditarConsorcioScreenState createState() => _EditarConsorcioScreenState();
}

class _EditarConsorcioScreenState extends State<EditarConsorcioScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  
  late TextEditingController _valorParcelaController;
  late TextEditingController _parcelasPagasController;
  late TextEditingController _parcelasTotaisController;
  late TextEditingController _valorTotalController;
  
  // Novos controladores para data de início
  late TextEditingController _mesInicioController;
  late TextEditingController _anoInicioController;
  
  DateTime? _dataInicio;
  DateTime? _dataTermino;
  
  bool _isLoading = true;
  String _consorcioId = '';
  
  // Lista de meses
  final List<String> _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];
  
  @override
  void initState() {
    super.initState();
    _valorParcelaController = TextEditingController();
    _parcelasPagasController = TextEditingController();
    _parcelasTotaisController = TextEditingController();
    _valorTotalController = TextEditingController();
    _mesInicioController = TextEditingController();
    _anoInicioController = TextEditingController();
    
    _carregarDadosConsorcio();
  }
  
  @override
  void dispose() {
    _valorParcelaController.dispose();
    _parcelasPagasController.dispose();
    _parcelasTotaisController.dispose();
    _valorTotalController.dispose();
    _mesInicioController.dispose();
    _anoInicioController.dispose();
    super.dispose();
  }
  
  void _calcularDataTermino() {
    if (_dataInicio != null && _parcelasTotaisController.text.isNotEmpty) {
      int totalParcelas = int.tryParse(_parcelasTotaisController.text) ?? 0;
      if (totalParcelas > 0) {
        // Subtrai as parcelas já pagas para saber quantas faltam
        int parcelasRestantes = totalParcelas - (int.tryParse(_parcelasPagasController.text) ?? 0);
        _dataTermino = DateTime(
          _dataInicio!.year,
          _dataInicio!.month + parcelasRestantes,
        );
        
        // Ajusta o ano se passar de dezembro
        while (_dataTermino!.month > 12) {
          _dataTermino = DateTime(
            _dataTermino!.year + 1,
            _dataTermino!.month - 12,
          );
        }
        
        setState(() {});
      }
    }
  }
  
  void _atualizarDataInicio() {
    if (_mesInicioController.text.isNotEmpty && _anoInicioController.text.isNotEmpty) {
      int mes = _meses.indexOf(_mesInicioController.text) + 1;
      int ano = int.tryParse(_anoInicioController.text) ?? DateTime.now().year;
      
      _dataInicio = DateTime(ano, mes);
      _calcularDataTermino();
    }
  }
  
  Future<void> _carregarDadosConsorcio() async {
    setState(() => _isLoading = true);
    
    try {
      final querySnapshot = await firestore
          .collection('consorcio')
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        _consorcioId = doc.id;
        final data = doc.data();
        
        _valorParcelaController.text = (data['valorParcela'] ?? 850.0).toString();
        _parcelasPagasController.text = (data['parcelasPagas'] ?? 12).toString();
        _parcelasTotaisController.text = (data['parcelasTotais'] ?? 60).toString();
        _valorTotalController.text = (data['valorTotal'] ?? 50000.0).toString();
        
        // Carrega data de início
        if (data['dataInicio'] != null) {
          Timestamp timestamp = data['dataInicio'];
          _dataInicio = timestamp.toDate();
          _mesInicioController.text = _meses[_dataInicio!.month - 1];
          _anoInicioController.text = _dataInicio!.year.toString();
          _calcularDataTermino();
        } else if (data['mesInicio'] != null && data['anoInicio'] != null) {
          _mesInicioController.text = data['mesInicio'];
          _anoInicioController.text = data['anoInicio'].toString();
          _atualizarDataInicio();
        }
      } else {
        // Valores padrão
        _valorParcelaController.text = '850.00';
        _parcelasPagasController.text = '12';
        _parcelasTotaisController.text = '60';
        _valorTotalController.text = '50000.00';
        
        // Data início padrão: mês atual
        DateTime now = DateTime.now();
        _dataInicio = DateTime(now.year, now.month);
        _mesInicioController.text = _meses[now.month - 1];
        _anoInicioController.text = now.year.toString();
        _calcularDataTermino();
      }
    } catch (e) {
      print('Erro ao carregar consórcio: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _salvarAlteracoes() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final valorParcela = double.parse(_valorParcelaController.text);
        final parcelasPagas = int.parse(_parcelasPagasController.text);
        final parcelasTotais = int.parse(_parcelasTotaisController.text);
        final valorTotal = double.parse(_valorTotalController.text);
        
        final Map<String, dynamic> dados = {
          'valorParcela': valorParcela,
          'parcelasPagas': parcelasPagas,
          'parcelasTotais': parcelasTotais,
          'valorTotal': valorTotal,
          'mesInicio': _mesInicioController.text,
          'anoInicio': int.parse(_anoInicioController.text),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        if (_dataInicio != null) {
          dados['dataInicio'] = Timestamp.fromDate(_dataInicio!);
        }
        
        if (_dataTermino != null) {
          dados['dataTermino'] = Timestamp.fromDate(_dataTermino!);
        }
        
        await firestore.collection('consorcio').doc(_consorcioId).set(
          dados,
          SetOptions(merge: true),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dados do consórcio salvos com sucesso!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        Navigator.pop(context);
      } catch (e) {
        print('Erro ao salvar: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      setState(() => _isLoading = false);
    }
  }
  
  void _selecionarMesInicio() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 300,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Selecione o mês de início',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _meses.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        _meses[index],
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setState(() {
                          _mesInicioController.text = _meses[index];
                          _atualizarDataInicio();
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _selecionarAnoInicio() {
    int anoAtual = DateTime.now().year;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 300,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Selecione o ano de início',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    int ano = anoAtual - 5 + index;
                    return ListTile(
                      title: Text(
                        ano.toString(),
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        setState(() {
                          _anoInicioController.text = ano.toString();
                          _atualizarDataInicio();
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  String _formatarData(DateTime? data) {
    if (data == null) return 'Não definido';
    return '${_meses[data.month - 1]} ${data.year}';
  }
  
  // ===== MÉTODOS PARA PRÓXIMA PARCELA =====
  String _calcularProximaParcela() {
    final pagas = int.tryParse(_parcelasPagasController.text) ?? 0;
    final totais = int.tryParse(_parcelasTotaisController.text) ?? 0;
    
    if (pagas >= totais) {
      return 'CONCLUÍDO';
    }
    
    return '${pagas + 1}ª parcela';
  }
  
  String _calcularValorProximaParcela() {
    final valorParcela = double.tryParse(_valorParcelaController.text) ?? 0;
    return 'R\$ ${valorParcela.toStringAsFixed(2)}';
  }
  
  String _calcularDataProximaParcela() {
    final pagas = int.tryParse(_parcelasPagasController.text) ?? 0;
    final totais = int.tryParse(_parcelasTotaisController.text) ?? 0;
    
    if (_dataInicio == null || pagas >= totais) {
      return '---';
    }
    
    // Calcula a data da próxima parcela
    DateTime dataProxima = DateTime(
      _dataInicio!.year,
      _dataInicio!.month + pagas,
    );
    
    // Ajusta o ano se passar de dezembro
    while (dataProxima.month > 12) {
      dataProxima = DateTime(
        dataProxima.year + 1,
        dataProxima.month - 12,
      );
    }
    
    return '${_meses[dataProxima.month - 1]} ${dataProxima.year}';
  }
  
  int _calcularParcelasRestantes() {
    final pagas = int.tryParse(_parcelasPagasController.text) ?? 0;
    final totais = int.tryParse(_parcelasTotaisController.text) ?? 0;
    return totais - pagas;
  }
  
  double _calcularProgresso() {
    final pagas = int.tryParse(_parcelasPagasController.text) ?? 0;
    final totais = int.tryParse(_parcelasTotaisController.text) ?? 1;
    return pagas / totais;
  }
  
  double _calcularPercentual() {
    return _calcularProgresso() * 100;
  }
  
  double _calcularValorPago() {
    final pagas = int.tryParse(_parcelasPagasController.text) ?? 0;
    final valorParcela = double.tryParse(_valorParcelaController.text) ?? 0;
    return pagas * valorParcela;
  }
  
  double _calcularSaldoDevedor() {
    final valorTotal = double.tryParse(_valorTotalController.text) ?? 0;
    return valorTotal - _calcularValorPago();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        title: Text(
          'Editar Consórcio',
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
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
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
                            Colors.green.shade900,
                            Colors.green.shade800,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.people_alt, size: 48, color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'Consórcio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Edite as informações do seu consórcio',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 30),
                    
                    // ===== SEÇÃO: DATA DE INÍCIO =====
                    Text(
                      'Período do Consórcio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Mês de início
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _selecionarMesInicio,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[800]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_month, color: Colors.green, size: 20),
                                      SizedBox(width: 12),
                                      Text(
                                        _mesInicioController.text.isEmpty ? 'Mês' : _mesInicioController.text,
                                        style: TextStyle(
                                          color: _mesInicioController.text.isEmpty ? Colors.grey[500] : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.arrow_drop_down, color: Colors.green),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _selecionarAnoInicio,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[800]!),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, color: Colors.green, size: 20),
                                      SizedBox(width: 12),
                                      Text(
                                        _anoInicioController.text.isEmpty ? 'Ano' : _anoInicioController.text,
                                        style: TextStyle(
                                          color: _anoInicioController.text.isEmpty ? Colors.grey[500] : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.arrow_drop_down, color: Colors.green),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24),
                    
                    // ===== INFORMAÇÕES FINANCEIRAS =====
                    Text(
                      'Informações Financeiras',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Valor da parcela
                    _buildInputField(
                      controller: _valorParcelaController,
                      label: 'Valor da Parcela',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calcularDataTermino(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe o valor da parcela';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Valor inválido';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Parcelas pagas
                    _buildInputField(
                      controller: _parcelasPagasController,
                      label: 'Parcelas Pagas',
                      icon: Icons.check_circle,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calcularDataTermino(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe quantas parcelas já foram pagas';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Número inválido';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Total de parcelas
                    _buildInputField(
                      controller: _parcelasTotaisController,
                      label: 'Total de Parcelas',
                      icon: Icons.receipt_long,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calcularDataTermino(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe o total de parcelas';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Número inválido';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Valor total do consórcio
                    _buildInputField(
                      controller: _valorTotalController,
                      label: 'Valor Total do Consórcio',
                      icon: Icons.currency_bitcoin,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Informe o valor total';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Valor inválido';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 30),
                    
                    // ===== PROGRESSO E PREVISÃO =====
                    Text(
                      'Progresso e Previsão',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Column(
                        children: [
                          // ===== NOVO CARD: PRÓXIMA PARCELA =====
                          if (_calcularParcelasRestantes() > 0) ...[
                            Container(
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.withOpacity(0.2),
                                    Colors.blue.withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.trending_up, color: Colors.blue, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Próxima Parcela',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _calcularProximaParcela(),
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Valor:',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                      ),
                                      Text(
                                        _calcularValorProximaParcela(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Vencimento:',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                      ),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, color: Colors.orange, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            _calcularDataProximaParcela(),
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Divider(color: Colors.grey[800], height: 8),
                            SizedBox(height: 8),
                          ],
                          
                          // Se concluiu
                          if (_calcularParcelasRestantes() == 0) ...[
                            Container(
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    'CONSÓRCIO CONCLUÍDO!',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          // Data de início
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.play_circle, color: Colors.green, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Início:',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                              Text(
                                _formatarData(_dataInicio),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 12),
                          
                          // Data de término (calculada)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.flag, color: Colors.orange, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Previsão de Término:',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                              Text(
                                _formatarData(_dataTermino),
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          
                          Divider(color: Colors.grey[800], height: 24),
                          
                          // Barra de progresso
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progresso',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              Text(
                                '${_calcularPercentual().toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: _calcularProgresso(),
                              backgroundColor: Colors.grey[800],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                              minHeight: 8,
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // Valores
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Valor já pago:',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              Text(
                                'R\$ ${_calcularValorPago().toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Saldo devedor:',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              Text(
                                'R\$ ${_calcularSaldoDevedor().toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Parcelas restantes:',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              Text(
                                '${_calcularParcelasRestantes()}',
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.white),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[800]!),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blueAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}