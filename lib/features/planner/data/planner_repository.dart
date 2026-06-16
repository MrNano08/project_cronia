import '../domain/planning_result.dart';

class PlannerRepository {
  Future<PlanningResult> createPlan(String userInput) async {
    return PlanningResult(
      id: '',
      planContent: '',
      createdAt: DateTime.now(),
    );
  }

  Future<List<PlanningResult>> getAllPlans() async {
    return [];
  }
}
