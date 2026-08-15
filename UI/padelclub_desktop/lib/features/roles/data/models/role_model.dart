import 'package:padelclub_desktop/features/roles/domain/entities/role.dart';

class RoleModel extends Role {
  RoleModel({super.id, required super.name});

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(id: json['id'] as int?, name: json['name'] as String);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
