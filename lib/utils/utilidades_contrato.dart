// lib/utils/utilidades_contrato.dart

/// Obtiene un código de 3 letras para una categoría de servicio.
///
/// Convierte el string de la categoría a un código estandarizado.
/// Si la categoría no se encuentra, devuelve 'OTR' por defecto.
String getCodigoCategoria(String categoriaCompleta) {
  switch (categoriaCompleta.toLowerCase()) {
    case 'plomería': return 'PLO';
    case 'gasista': return 'GAS';
    case 'carpintería': return 'CAR';
    case 'pintor': return 'PIN';
    case 'albañil': return 'ALB';
    case 'electricista': return 'ELE';
    case 'refrigeración': return 'REF';
    case 'arquitectura y construcción': return 'A&C';
    case 'técnicos': return 'TEC';
    case 'jardinería': return 'JAR';
    case 'seguridad': return 'SEG';
    case 'mantenimiento': return 'MAN';
    case 'transporte y logística': return 'T&L';
    case 'herrería': return 'HER';
    case 'cerrajero': return 'CER';
    case 'limpieza': return 'LIM';
    case 'control de plagas': return 'PLA';
    case 'soldador': return 'SOL';
    case 'mecánico': return 'MEC';
    case 'cuidado de mascotas': return 'MAS';
    case 'cuidado de niños': return 'NIÑ';
    case 'cuidado de adultos': return 'ADU';
    case 'otros': return 'OTR';
    default: return 'OTR';
  }
}

/// Obtiene un código de 2 letras para un país.
///
/// Convierte el string del país a su código ISO 3166-1 alfa-2.
/// Si el país no se encuentra, devuelve 'LAT' por defecto.
String getCodigoPais(String paisCompleto) {
  // Normalizamos el input para evitar problemas con mayúsculas o acentos.
  final paisNormalizado = paisCompleto.toLowerCase().replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u');
  
  switch (paisNormalizado) {
    case 'argentina': return 'AR';
    case 'brasil': return 'BR';
    case 'uruguay': return 'UY';
    case 'chile': return 'CL';
    case 'paraguay': return 'PY'; // Añadido como ejemplo
    case 'bolivia': return 'BO'; // Añadido como ejemplo
    // Puedes añadir los 6 países que necesites aquí
    default: return 'LAT'; // Un código genérico para Latinoamérica si no coincide
  }
}