import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';

class FileService {
  static const String _fileName = 'tasks.json';

  // Get the local file path
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Get reference to the file
  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  // Save tasks to file
  static Future<void> saveTasks(List<Task> tasks) async {
    try {
      final file = await _localFile;
      
      // Convert List<Task> to List<Map<String, dynamic>>
      List<Map<String, dynamic>> tasksJson = 
          tasks.map((task) => task.toJson()).toList();
      
      // Encode to JSON string with pretty printing
      String jsonString = const JsonEncoder.withIndent('  ').encode(tasksJson);
      
      // Write to file
      await file.writeAsString(jsonString);
      print('Tasks saved to: ${file.path}');
    } catch (e) {
      print('Error saving tasks: $e');
      rethrow;
    }
  }

  // Load tasks from file
  static Future<List<Task>> loadTasks() async {
    try {
      final file = await _localFile;
      
      // Check if file exists
      if (!await file.exists()) {
        print('Tasks file does not exist yet');
        return [];
      }
      
      // Read file contents
      String contents = await file.readAsString();
      
      // Decode JSON string to List<dynamic>
      List<dynamic> tasksJson = json.decode(contents);
      
      // Convert to List<Task>
      List<Task> tasks = tasksJson.map((json) => Task.fromJson(json)).toList();
      
      print('Loaded ${tasks.length} tasks from: ${file.path}');
      return tasks;
    } catch (e) {
      print('Error loading tasks: $e');
      return [];
    }
  }

  // Delete the tasks file (for testing/reset)
  static Future<void> deleteTasksFile() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
        print('Tasks file deleted');
      }
    } catch (e) {
      print('Error deleting tasks file: $e');
      rethrow;
    }
  }

  // Get file info
  static Future<Map<String, dynamic>> getFileInfo() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final stat = await file.stat();
        return {
          'path': file.path,
          'size': stat.size,
          'modified': stat.modified,
        };
      }
      return {'error': 'File does not exist'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}