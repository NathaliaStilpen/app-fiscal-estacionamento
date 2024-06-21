import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/logo.jpg', // caminho para a imagem no pubspec.yaml
              height: 120.0,
            ),
            Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      hintText: 'CPF',
                      icon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 20.0),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Senha',
                      icon: Icon(Icons.lock),
                    ),
                  ),
                  SizedBox(height: 20.0),
                  ElevatedButton(
                    onPressed: () {
                      _loginPressed(context);
                    },
                    child: Text('Entrar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _loginPressed(BuildContext context) async {
    String cpf = _cpfController.text.trim();
    String password = _passwordController.text;

    if (cpf.isNotEmpty && password.isNotEmpty) {
      final response = await http.post(
        Uri.parse('http://localhost:5001/login_fiscal'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'cpf': cpf,
          'senha': password,
        }),
      );

      if (response.statusCode == 200) {
        // Obter todas as cidades disponíveis
        final citiesResponse = await http.get(Uri.parse('http://localhost:5001/all_cities'));
        if (citiesResponse.statusCode == 200) {
          List<String> cities = jsonDecode(citiesResponse.body).cast<String>();

          // Obter a primeira cidade e suas ruas
          if (cities.isNotEmpty) {
            final streetsResponse = await http.post(
              Uri.parse('http://localhost:5001/all_streets'),
              headers: <String, String>{
                'Content-Type': 'application/json; charset=UTF-8',
              },
              body: jsonEncode(<String, String>{
                'cidade': cities[0],
              }),
            );

            if (streetsResponse.statusCode == 200) {
              List<String> streets = jsonDecode(streetsResponse.body).cast<String>();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen(cities: cities, streets: streets)),
              );
              return;
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar cidades e ruas disponíveis'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CPF ou senha inválidos'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, preencha todos os campos'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

class HomeScreen extends StatefulWidget {
  final List<String> cities;
  final List<String> streets;

  HomeScreen({required this.cities, required this.streets});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedCity;
  String? _selectedStreet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Selecionar Cidade e Rua'),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _selectedCity,
                items: widget.cities.map((String city) {
                  return DropdownMenuItem<String>(
                    value: city,
                    child: Text(city),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedCity = value!;
                    _loadStreets(value!);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Selecione a cidade',
                  icon: Icon(Icons.location_city),
                ),
              ),
              SizedBox(height: 20.0),
              DropdownButtonFormField<String>(
                value: _selectedStreet,
                items: widget.streets.map((String street) {
                  return DropdownMenuItem<String>(
                    value: street,
                    child: Text(street),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedStreet = value!;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Selecione a rua',
                  icon: Icon(Icons.streetview),
                ),
              ),
              SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () {
                  _navigateToCarList(context);
                },
                child: Text('Confirmar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadStreets(String city) async {
    final response = await http.post(
      Uri.parse('http://localhost:5001/all_streets'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'cidade': city,
      }),
    );

    if (response.statusCode == 200) {
      List<String> streets = jsonDecode(response.body).cast<String>();
      setState(() {
        _selectedStreet = null; // Reset selected street
        widget.streets.clear(); // Clear the existing list
        widget.streets.addAll(streets); // Update with new streets
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar ruas da cidade selecionada'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _navigateToCarList(BuildContext context) async {
    if (_selectedCity != null && _selectedStreet != null) {
      // Obter todos os carros ativos na rua
      final activeSpotsResponse = await http.post(
        Uri.parse('http://localhost:5001/all_active_spots_per_street'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'cidade': _selectedCity!,
          'rua': _selectedStreet!,
        }),
      );

      List<dynamic> activeSpotsJson = [];
      if (activeSpotsResponse.statusCode == 200) {
        activeSpotsJson = jsonDecode(activeSpotsResponse.body);
      }

      // Obter todos os carros expirados na rua
      final expiredSpotsResponse = await http.post(
        Uri.parse('http://localhost:5001/all_expired_spots_per_street'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'cidade': _selectedCity!,
          'rua': _selectedStreet!,
        }),
      );

      List<dynamic> expiredSpotsJson = [];
      if (expiredSpotsResponse.statusCode == 200) {
        expiredSpotsJson = jsonDecode(expiredSpotsResponse.body);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CarListScreen(
            activeSpots: activeSpotsJson,
            expiredSpots: expiredSpotsJson,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, selecione a cidade e a rua'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

class CarListScreen extends StatefulWidget {
  final List<dynamic> activeSpots;
  final List<dynamic> expiredSpots;

  CarListScreen({required this.activeSpots, required this.expiredSpots});

  @override
  _CarListScreenState createState() => _CarListScreenState();
}

class _CarListScreenState extends State<CarListScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      setState(() {});
    });
  }

  Duration _calculateRemainingTime(String horaSaida) {
    DateTime now = DateTime.now();
    DateTime endTime = DateTime.parse(horaSaida);
    return endTime.difference(now);
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      duration = duration.abs();
      return '-${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _generatePdf(Map<String, dynamic> carInfo) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('Registro - Carro Expirado', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Placa do Carro: ${carInfo['placaDoCarro']}', style: pw.TextStyle(fontSize: 18)),
              pw.Text('Hora Entrada: ${carInfo['horaEntrada']}', style: pw.TextStyle(fontSize: 18)),
              pw.Text('Hora Saída: ${carInfo['horaSaida']}', style: pw.TextStyle(fontSize: 18)),
              pw.Text('Tempo Expirado: ${_formatDuration(_calculateRemainingTime(carInfo['horaSaida']))}', style: pw.TextStyle(fontSize: 18, color: PdfColors.red)),
            ],
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista de Carros'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Carros Ativos:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.activeSpots.length,
                itemBuilder: (context, index) {
                  Duration remainingTime = _calculateRemainingTime(widget.activeSpots[index]['horaSaida']);
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: Icon(Icons.directions_car, color: Colors.green),
                      title: Text(widget.activeSpots[index]['placaDoCarro']),
                      subtitle: Text(
                        'Hora Entrada: ${widget.activeSpots[index]['horaEntrada']}\nHora Saída: ${widget.activeSpots[index]['horaSaida']}',
                      ),
                      trailing: Text(
                        _formatDuration(remainingTime),
                        style: TextStyle(
                          color: remainingTime.isNegative ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Text(
              'Carros Expirados:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.expiredSpots.length,
                itemBuilder: (context, index) {
                  Duration remainingTime = _calculateRemainingTime(widget.expiredSpots[index]['horaSaida']);
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: Icon(Icons.directions_car, color: Colors.red),
                      title: Text(widget.expiredSpots[index]['placaDoCarro']),
                      subtitle: Text(
                        'Hora Entrada: ${widget.expiredSpots[index]['horaEntrada']}\nHora Saída: ${widget.expiredSpots[index]['horaSaida']}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDuration(remainingTime),
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              await _generatePdf(widget.expiredSpots[index]);
                            },
                            child: Text('Registro de Atraso'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
