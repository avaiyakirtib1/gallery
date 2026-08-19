import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vault_asset.dart';

/// Service to handle offline file storage and metadata for the Private Vault.
class VaultService {
  static const String _pinKey = 'secure_vault_pin_hash';
  static const String _indexFileName = 'vault_index.json';

  /// Returns the secure directory dedicated to the Private Vault.
  static Future<Directory> getVaultDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${appDir.path}/secure_vault');
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  /// Loads the metadata list of vaulted assets.
  static Future<List<VaultAsset>> loadVaultIndex() async {
    try {
      final vaultDir = await getVaultDirectory();
      final indexFile = File('${vaultDir.path}/$_indexFileName');
      if (!await indexFile.exists()) {
        return [];
      }
      final jsonString = await indexFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((item) => VaultAsset.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves the metadata list of vaulted assets.
  static Future<void> saveVaultIndex(List<VaultAsset> assets) async {
    try {
      final vaultDir = await getVaultDirectory();
      final indexFile = File('${vaultDir.path}/$_indexFileName');
      final jsonList = assets.map((a) => a.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(jsonList));
    } catch (_) {
      // Fail silently or handle error in UI
    }
  }

  /// Saves the PIN hash to SharedPreferences for vault authentication.
  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hashedPin = _hashPin(pin);
    await prefs.setString(_pinKey, hashedPin);
  }

  /// Verifies if the entered PIN matches the stored hash.
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_pinKey);
    if (storedHash == null) return false;
    return storedHash == _hashPin(pin);
  }

  /// Checks if the user has already configured a vault PIN.
  static Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinKey);
  }

  /// Wipes all vault data, files, and PIN.
  /// Used for security resets if the user forgets their PIN.
  static Future<void> clearVault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);

    final vaultDir = await getVaultDirectory();
    if (await vaultDir.exists()) {
      await vaultDir.delete(recursive: true);
    }
  }

  /// A basic custom hash algorithm for offline PIN masking without extra dependencies.
  static String _hashPin(String pin) {
    int hash = 7;
    for (int i = 0; i < pin.length; i++) {
      hash = hash * 31 + pin.codeUnitAt(i);
    }
    return hash.toRadixString(16);
  }
}
