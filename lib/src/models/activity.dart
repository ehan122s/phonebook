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
    this.isPendingSync = false, // BARU — true kalau ini masih di antrian offline
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

  /// BARU — true kalau kegiatan ini masih tersimpan lokal (belum berhasil
  /// dikirim ke Supabase). ID-nya akan berupa "local_<timestamp>", bukan
  /// UUID asli dari database.
  final bool isPendingSync;

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
        id: map['id'] as String,
        title: map['title'] as String,
        activityDate: DateTime.parse(map['activity_date'] as String),
        village: map['village'] as String? ?? '',
        district: map['district'] as String? ?? '',
        regency: map['regency'] as String? ?? '',
        categoryName: (map['categories'] as Map?)?['name'] as String? ??
            (map['isPendingSync'] == true ? 'Menunggu sinkronisasi' : '-'),
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
        isPendingSync: map['isPendingSync'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'activity_date': activityDate.toIso8601String(),
        'village': village,
        'district': district,
        'regency': regency,
        'participant_count': participantCount,
        'category_id': categoryId,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'farmer_group': farmerGroup,
        'material': material,
        'objective': objective,
        'result': result,
        'obstacle': obstacle,
        'follow_up': followUp,
        'notes': notes,
        'status': status,
      };

  Map<String, dynamic> toPayload() => {
        'category_id': categoryId,
        'title': title,
        'activity_date': activityDate.toIso8601String(),
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

  Activity copyWith({
    String? id,
    String? title,
    DateTime? activityDate,
    String? village,
    String? district,
    String? regency,
    String? categoryName,
    int? participantCount,
    String? categoryId,
    String? location,
    double? latitude,
    double? longitude,
    String? farmerGroup,
    String? material,
    String? objective,
    String? result,
    String? obstacle,
    String? followUp,
    String? notes,
    String? status,
    String? creatorName,
    bool? isPendingSync,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      activityDate: activityDate ?? this.activityDate,
      village: village ?? this.village,
      district: district ?? this.district,
      regency: regency ?? this.regency,
      categoryName: categoryName ?? this.categoryName,
      participantCount: participantCount ?? this.participantCount,
      categoryId: categoryId ?? this.categoryId,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      farmerGroup: farmerGroup ?? this.farmerGroup,
      material: material ?? this.material,
      objective: objective ?? this.objective,
      result: result ?? this.result,
      obstacle: obstacle ?? this.obstacle,
      followUp: followUp ?? this.followUp,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      creatorName: creatorName ?? this.creatorName,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }
}