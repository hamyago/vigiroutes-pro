# Script de correction automatique — vigiroutesPro
# Lance depuis : C:\Users\YAS\AUTOSOS\vigiroutesPro

# ── 1. Corriger api_service.dart ─────────────────────────────────────────────
$apiFile = "lib\core\services\api_service.dart"
$content = Get-Content $apiFile -Raw

# Supprimer l'import flutter_secure_storage
$content = $content -replace "import 'package:flutter_secure_storage/flutter_secure_storage\.dart';", "import 'package:shared_preferences/shared_preferences.dart';"

# Supprimer la déclaration _storage
$content = $content -replace "\s*final _storage = const FlutterSecureStorage\(\);", ""

# Corriger saveToken
$content = $content -replace "Future<void> saveToken\(String token\) =>\s*_storage\.write\(key: 'sanctum_token', value: token\);", "Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sanctum_token', token);
  }"

# Corriger clearToken
$content = $content -replace "Future<void> clearToken\(\) =>\s*_storage\.delete\(key: 'sanctum_token'\);", "Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sanctum_token');
  }"

# Ajouter updateProvider avant la dernière accolade
if ($content -notmatch "updateProvider") {
    $content = $content -replace "}\s*$", "
  Future<Map<String,dynamic>> updateProvider(Map<String,dynamic> data) async {
    final res = await patch('/provider/me', data: data);
    return res.data as Map<String,dynamic>;
  }
}"
}

[System.IO.File]::WriteAllText("$PWD\$apiFile", $content, [System.Text.Encoding]::UTF8)
Write-Host "✓ api_service.dart corrigé" -ForegroundColor Green

# ── 2. Corriger provider_profile_screen.dart ─────────────────────────────────
$profileFile = "lib\features\profile\screens\provider_profile_screen.dart"
$content = Get-Content $profileFile -Raw

$content = $content -replace "auth\.currentUserId", "''"
$content = $content -replace "auth\.provider\?\.id \?\? auth\.currentUserId", "auth.provider?.id ?? ''"

[System.IO.File]::WriteAllText("$PWD\$profileFile", $content, [System.Text.Encoding]::UTF8)
Write-Host "✓ provider_profile_screen.dart corrigé" -ForegroundColor Green

Write-Host ""
Write-Host "Corrections terminées ! Lance maintenant :" -ForegroundColor Cyan
Write-Host "flutter build apk --release --no-tree-shake-icons --android-skip-build-dependency-validation" -ForegroundColor Yellow
