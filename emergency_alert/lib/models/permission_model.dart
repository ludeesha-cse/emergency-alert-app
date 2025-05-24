import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Model class to represent a single permission with its metadata
class PermissionModel {
  final String name;
  final String description;
  final IconData icon;
  final Permission permission;
  final Function requestPermission;

  /// Creates a new permission model
  const PermissionModel({
    required this.name,
    required this.description,
    required this.icon,
    required this.permission,
    required this.requestPermission,
  });
}
