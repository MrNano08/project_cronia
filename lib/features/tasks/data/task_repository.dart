import '../domain/task.dart';

class TaskRepository {
  Future<List<Task>> getAllTasks() async {
    return [];
  }

  Future<Task?> getTaskById(String id) async {
    return null;
  }

  Future<void> createTask(Task task) async {
    // Create task
  }

  Future<void> updateTask(Task task) async {
    // Update task
  }

  Future<void> deleteTask(String id) async {
    // Delete task
  }
}
