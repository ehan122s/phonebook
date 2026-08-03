class Activity {
  const Activity({
    required this.id,
    required this.title,
    required this.activityDate,
    required this.village,
    required this.district,
    required this.regency,
    required this.categoryName,
    required this.participantCount,
    this.categoryId,
    this.location,
    this.latitude,
    this.longitude,
    this.farmerGroup,
    this.material,
    this.objective,
    this.result,
    this.obstacle,
    this.followUp,
    this.notes,
    this.status,
    this.creatorName,
  });

  final String id;
  final String title;
  final DateTime activityDate;
  final String village;
  final String district;
  final String regency;
  final String categoryName;
  final int participantCount;
  final String? categoryId;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? farmerGroup;
  final String? material;
  final String? objective;
  final String? result;
  final String? obstacle;
  final String? followUp;
  final String? notes;
  final String? status;
  final String? creatorName;

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
    id: map['id'] as String,
    title: map['title'] as String,
    activityDate: DateTime.parse(map['activity_date'] as String),
    village: map['village'] as String,
    district: map['district'] as String,
    regency: map['regency'] as String,
    categoryName: (map['categories'] as Map?)?['name'] as String? ?? '-',
    participantCount: map['participant_count'] as int? ?? 0,
    categoryId: map['category_id'] as String?,
    location: map['location'] as String?,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    farmerGroup: map['farmer_group'] as String?,
    material: map['material'] as String?,
    objective: map['objective'] as String?,
    result: map['result'] as String?,
    obstacle: map['obstacle'] as String?,
    followUp: map['follow_up'] as String?,
    notes: map['notes'] as String?,
    status: map['status'] as String?,
    creatorName: (map['profiles'] as Map?)?['full_name'] as String?,
  );

  Map<String, dynamic> toPayload() => {
    'category_id': categoryId,
    'title': title,
<<<<<<< HEAD
    'activity_date': activityDate.toIso8601String(),
=======
    'activity_date': activityDate.toIso8601String().substring(0, 10),
>>>>>>> 09f3f7672af38f1586915ec910e76884d1a96584
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'village': village,
    'district': district,
    'regency': regency,
    'farmer_group': farmerGroup,
    'participant_count': participantCount,
    'material': material,
    'objective': objective,
    'result': result,
    'obstacle': obstacle,
    'follow_up': followUp,
    'notes': notes,
  };
}
