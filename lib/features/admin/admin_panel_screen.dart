import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 관리자(엄마) 전용. 가족 외에 다른 가구를 보거나 통계를 볼 수 있는
/// placeholder. 실제 데이터는 백엔드(Supabase + RLS) 연결 후.
class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  static const routeName = '/admin';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 패널')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppTheme.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '관리자 권한으로 로그인하셨어요. 실제 데이터 연결은 곧 만들어요.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '예시 사용자',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ..._mockUsers.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UserRow(name: u['name']!, role: u['role']!, members: u['members']!),
            ),
          ),
        ],
      ),
    );
  }

  // TODO(supabase): replace mock list with real users query through admin
  // Edge Function once backend + RLS are wired.
  static const _mockUsers = [
    {'name': '김엄마', 'role': '관리자', 'members': '4명'},
    {'name': '박엄마', 'role': '관리자', 'members': '3명'},
    {'name': '이혼자', 'role': '솔로', 'members': '1명'},
  ];
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.name,
    required this.role,
    required this.members,
  });

  final String name;
  final String role;
  final String members;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.cream,
            child: Icon(Icons.person, color: AppTheme.subtle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$role · 가족 $members',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
