import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

// URL de conexión con FastAPI
const String baseUrl = "http://localhost:8000";

// --- APLICACIÓN PRINCIPAL ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pase de Lista GPS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
    );
  }
}

// --- PANTALLA DE LOGIN Y REGISTRO ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _isLoading = false;

  // Método para iniciar sesión o registrar un usuario
  Future<void> _authenticate(String endpoint) async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": _userController.text.trim(),
          "password": _passController.text.trim(),
        }),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AttendanceScreen(userId: data['user_id']),
          ),
        );
      } else {
        _showMessage(data['detail'] ?? 'Error de autenticación');
      }
    } catch (e) {
      _showMessage('Error de conexión con el servidor');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Mostrar mensajes en pantalla
  void _showMessage(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // Liberar los controladores
  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso al Sistema')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: 'Usuario',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
              ),
            ),

            const SizedBox(height: 24),

            if (_isLoading)
              const CircularProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _authenticate('login'),
                    child: const Text('Iniciar Sesión'),
                  ),

                  OutlinedButton(
                    onPressed: () => _authenticate('register'),
                    child: const Text('Registrarse'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// --- PANTALLA PRINCIPAL DE ASISTENCIA ---
class AttendanceScreen extends StatefulWidget {
  final int userId;

  const AttendanceScreen({super.key, required this.userId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _address = "";

  bool _isLoading = false;

  // Lista donde se guardan las asistencias consultadas
  List<dynamic> _history = [];

  bool _isLoadingHistory = false;

  // Consultar el historial de asistencias
  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/${widget.userId}/'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (!mounted) return;

        setState(() {
          _history = data;
        });
      } else {
        _showError('No se pudo cargar el historial');
      }
    } catch (e) {
      _showError('Error al consultar el historial: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  // Cargar el historial al entrar a la pantalla
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // Obtener la ubicación actual del dispositivo
  Future<Position> _determinePosition() async {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Los servicios de ubicación están desactivados.',
      );
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw Exception('Permisos de ubicación denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Permisos denegados permanentemente.',
      );
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Registrar una nueva asistencia
  Future<void> _registerAttendance() async {
    setState(() => _isLoading = true);

    try {
      Position position = await _determinePosition();

      final response = await http.post(
        Uri.parse('$baseUrl/attendance/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": widget.userId,
          "latitude": position.latitude,
          "longitude": position.longitude,
        }),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        if (!mounted) return;

        setState(() {
          _address = data['address'];
        });

        // Actualizar el historial después del registro
        await _loadHistory();
      } else {
        _showError(
          data['detail'] ?? 'No se pudo registrar la asistencia',
        );
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Mostrar mensajes de error
  void _showError(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF1FB),

      appBar: AppBar(
        title: const Text('Registro de Asistencia'),
        backgroundColor: const Color(0xFF28589C),
        foregroundColor: Colors.white,
      ),

      // Permite desplazarse cuando hay muchas asistencias
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [

              // Botón para registrar asistencia
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : _registerAttendance,
                icon: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                ),
                label: Text(
                  _isLoading
                      ? 'Obteniendo ubicación...'
                      : 'Registrar asistencia',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF23478A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Mostrar la dirección de la última asistencia
              if (_address.isNotEmpty)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "📍 $_address",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 25),

              // Título del historial
              const Text(
                'Historial de asistencias',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF23478A),
                ),
              ),

              const SizedBox(height: 12),

              // Botón para actualizar el historial
              TextButton.icon(
                onPressed: _isLoadingHistory
                    ? null
                    : _loadHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar historial'),
              ),

              const SizedBox(height: 8),

              // Mostrar indicador mientras se consulta la información
              if (_isLoadingHistory)
                const CircularProgressIndicator()

              // Mostrar mensaje si no existen asistencias
              else if (_history.isEmpty)
                const Text(
                  'Todavía no tienes asistencias registradas.',
                  textAlign: TextAlign.center,
                )

              // Mostrar la lista de asistencias
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: Color(0xFF28589C),
                        ),

                        title: Text(
                          item['address'] ??
                              'Dirección no disponible',
                        ),

                        subtitle: Text(
                          'Fecha: ${item['created_at']}\n'
                          'Latitud: ${item['latitude']}\n'
                          'Longitud: ${item['longitude']}',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
