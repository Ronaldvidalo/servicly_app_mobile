import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoMensaje { texto, imagen, audio, video, presupuesto, noSoportado,documento }

class Mensaje {
  final String id;
  final String idAutor;
  final Timestamp timestamp;
  final String? texto;
  final String? urlContenido;
  final Duration? mediaDuration;
  final String? idPresupuesto;
  final TipoMensaje tipo;
  final bool visto; // <-- CAMPO AÑADIDO

  Mensaje({
    required this.id,
    required this.idAutor,
    required this.timestamp,
    this.texto,
    this.urlContenido,
    this.mediaDuration,
    this.idPresupuesto,
    required this.tipo,
    required this.visto, // <-- CAMPO AÑADIDO
  });

  factory Mensaje.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final tipoStr = data['tipo'] as String?;
    TipoMensaje tipo;
    switch (tipoStr) {
      case 'texto': tipo = TipoMensaje.texto; break;
      case 'imagen': tipo = TipoMensaje.imagen; break;
      case 'audio': tipo = TipoMensaje.audio; break;
      case 'video': tipo = TipoMensaje.video; break;
      case 'presupuesto': tipo = TipoMensaje.presupuesto; break;
      default: tipo = TipoMensaje.noSoportado;
    }

    return Mensaje(
      id: doc.id,
      idAutor: data['idAutor'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      texto: data['texto'],
      urlContenido: data['urlContenido'],
      mediaDuration: data.containsKey('mediaDuration')
          ? Duration(seconds: data['mediaDuration'])
          : null,
      idPresupuesto: data['idPresupuesto'],
      tipo: tipo,
      visto: data['visto'] ?? false, // <-- CAMPO AÑADIDO
    );
  }
}