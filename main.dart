
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SubirFotoPage(),
  ));
}

class SubirFotoPage extends StatefulWidget {
  const SubirFotoPage({super.key});

  @override
  State<SubirFotoPage> createState() => _SubirFotoPageState();
}

class _SubirFotoPageState extends State<SubirFotoPage> {

  // Variable para guardar la imagen seleccionada
  XFile? _imagen;

  // Controlador para la descripción
  final TextEditingController _descripcionController =
      TextEditingController();

  // Objeto para seleccionar imágenes
  final ImagePicker _picker = ImagePicker();

  bool _subiendo = false;

  // Dirección de la API para Flutter Web
  final String apiUrl = "http://127.0.0.1:8000/fotos";

  // Método para seleccionar una fotografía
  Future<void> _tomarFoto() async {

    final XFile? foto = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (foto != null) {
      setState(() {
        _imagen = foto;
      });
    }
  }

  // Método para subir la fotografía a la API
  Future<void> _subirAApi() async {

    if (_imagen == null ||
        _descripcionController.text.trim().isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Por favor selecciona una foto y escribe una descripción"
          ),
        ),
      );

      return;
    }

    setState(() {
      _subiendo = true;
    });

    try {

      // Leer la imagen como bytes
      final bytes = await _imagen!.readAsBytes();

      // Crear la petición POST
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      // Agregar la descripción
      request.fields['descripcion'] =
          _descripcionController.text.trim();

      // Agregar la imagen
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: _imagen!.name,
        ),
      );

      // Enviar la petición
      var response = await request.send();

      if (response.statusCode == 200) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Foto subida correctamente"),
          ),
        );

        setState(() {
          _imagen = null;
          _descripcionController.clear();
        });

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error al subir: ${response.statusCode}"
            ),
          ),
        );
      }

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error de conexión: $e"),
        ),
      );

    } finally {

      setState(() {
        _subiendo = false;
      });

    }
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Subir Foto"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Column(
          children: [

            const SizedBox(height: 10),

            // Mostrar imagen seleccionada
            _imagen == null
                ? const Text(
                    "No hay imagen seleccionada",
                    style: TextStyle(fontSize: 16),
                  )
                : FutureBuilder(
                    future: _imagen!.readAsBytes(),
                    builder: (context, snapshot) {

                      if (snapshot.hasData) {
                        return Image.memory(
                          snapshot.data!,
                          height: 200,
                          fit: BoxFit.cover,
                        );
                      }

                      return const CircularProgressIndicator();
                    },
                  ),

            const SizedBox(height: 20),

            // Campo para escribir la descripción
            TextField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: "Descripción",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Botón para seleccionar fotografía
            ElevatedButton(
              onPressed: _tomarFoto,
              child: const Text("Seleccionar Foto"),
            ),

            const SizedBox(height: 10),

            // Botón para subir fotografía
            _subiendo
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _subirAApi,
                    child: const Text("Subir a API"),
                  ),

          ],
        ),
      ),
    );
  }
}
