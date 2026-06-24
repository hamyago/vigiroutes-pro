// Copie de lib/core/services/api_service.dart de autosos-client
// Seule différence : loginUser → loginProvider
// Le reste est identique — en production, extraire dans un package partagé

export 'package:autosos_client/core/services/api_service.dart';
// Si les 2 apps sont dans des repos séparés, copier api_service.dart ici
// et remplacer la ligne loginUser par loginProvider dans _init()
