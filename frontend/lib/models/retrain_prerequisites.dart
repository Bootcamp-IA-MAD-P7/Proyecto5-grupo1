/// Eligibility for POST /admin/retrain (RF-45).
class RetrainPrerequisites {
  final int feedbackRecords;
  final int minFeedbackRecords;
  final int recommendedFeedbackRecords;
  final bool eligible;
  final String message;

  const RetrainPrerequisites({
    required this.feedbackRecords,
    required this.minFeedbackRecords,
    required this.recommendedFeedbackRecords,
    required this.eligible,
    required this.message,
  });

  factory RetrainPrerequisites.fromJson(Map<String, dynamic> json) {
    return RetrainPrerequisites(
      feedbackRecords: (json['feedbackRecords'] as num?)?.toInt() ?? 0,
      minFeedbackRecords: (json['minFeedbackRecords'] as num?)?.toInt() ?? 5,
      recommendedFeedbackRecords:
          (json['recommendedFeedbackRecords'] as num?)?.toInt() ?? 10,
      eligible: json['eligible'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}
