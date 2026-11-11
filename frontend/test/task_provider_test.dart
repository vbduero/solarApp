// Solar-Grow - Pruebas de TaskProvider sin red (MockClient de package:http)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_grow/providers/task_provider.dart';

Map<String, dynamic> taskJson({
  int id = 5,
  required DateTime dueDate,
  String status = 'Pendiente',
  int daysOverdue = 0,
}) {
  return {
    'id': id,
    'plant_id': 7,
    'plant_name': 'Echeveria',
    'plant_image': null,
    'plant_location': 'Balcon',
    'task_type': 'Regar',
    'status': status,
    'description': null,
    'due_date': dueDate.toUtc().toIso8601String(),
    'completed_at': null,
    'days_overdue': daysOverdue,
    'is_auto_generated': false,
    'created_at': DateTime.now().toUtc().toIso8601String(),
  };
}

http.Response jsonResponse(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Future<T> withApi<T>(
  Future<http.Response> Function(http.Request request) handler,
  Future<T> Function() action,
) {
  return http.runWithClient(action, () => MockClient(handler));
}

void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  final future = today.add(const Duration(days: 2));

  group('createTask', () {
    test('envía POST a /api/tasks/ con el body exacto', () async {
      late http.Request sent;
      final provider = TaskProvider();

      final created = await withApi(
        (request) async {
          sent = request;
          return jsonResponse(taskJson(dueDate: future));
        },
        () => provider.createTask(
          plantId: 7,
          taskType: 'Podar',
          dueDate: future,
          description: '  Quitar hojas secas  ',
        ),
      );

      expect(created, isTrue);
      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/tasks/');
      expect(jsonDecode(sent.body), {
        'plant_id': 7,
        'task_type': 'Podar',
        'due_date': future.toUtc().toIso8601String(),
        'description': 'Quitar hojas secas',
      });
      expect((jsonDecode(sent.body) as Map)['due_date'], endsWith('Z'));
    });

    test('no envía description cuando es null', () async {
      late http.Request sent;

      await withApi(
        (request) async {
          sent = request;
          return jsonResponse(taskJson(dueDate: future));
        },
        () => TaskProvider().createTask(
          plantId: 7,
          taskType: 'Regar',
          dueDate: future,
        ),
      );

      expect(
        (jsonDecode(sent.body) as Map).containsKey('description'),
        isFalse,
      );
    });

    test('una tarea que vence hoy queda en todayTasks', () async {
      final provider = TaskProvider();

      await withApi(
        (_) async => jsonResponse(taskJson(dueDate: today)),
        () =>
            provider.createTask(plantId: 7, taskType: 'Regar', dueDate: today),
      );

      expect(provider.todayTasks.map((t) => t.id), [5]);
      expect(provider.upcomingTasks, isEmpty);
    });

    test(
      'una tarea futura queda en upcomingTasks, ordenada por fecha',
      () async {
        final provider = TaskProvider();
        final later = future.add(const Duration(days: 3));

        await withApi(
          (request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final dueDate = DateTime.parse(body['due_date']);
            return jsonResponse(
              taskJson(id: dueDate == later.toUtc() ? 1 : 2, dueDate: dueDate),
            );
          },
          () async {
            await provider.createTask(
              plantId: 7,
              taskType: 'Regar',
              dueDate: later,
            );
            await provider.createTask(
              plantId: 7,
              taskType: 'Regar',
              dueDate: future,
            );
          },
        );

        expect(provider.upcomingTasks.map((t) => t.id), [2, 1]);
        expect(provider.todayTasks, isEmpty);
      },
    );

    test('si el API falla devuelve false y no cambia las listas', () async {
      final provider = TaskProvider();

      final created = await withApi(
        (_) async =>
            jsonResponse({'detail': 'Planta no encontrada'}, status: 404),
        () =>
            provider.createTask(plantId: 7, taskType: 'Regar', dueDate: today),
      );

      expect(created, isFalse);
      expect(provider.todayTasks, isEmpty);
      expect(provider.upcomingTasks, isEmpty);
      expect(provider.isLoading, isFalse);
    });
  });

  group('completeTask', () {
    final yesterday = today.subtract(const Duration(days: 1));

    test('envía PATCH a /api/tasks/5, sin doble barra', () async {
      late http.Request sent;

      await withApi((request) async {
        sent = request;
        return jsonResponse(taskJson(dueDate: today, status: 'Completada'));
      }, () => TaskProvider().completeTask(5));

      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/api/tasks/5');
      expect(jsonDecode(sent.body), {'status': 'Completada'});
    });

    test('una tarea atrasada completada deja de estar atrasada', () async {
      final provider = TaskProvider();

      await withApi(
        (request) async {
          if (request.method == 'GET') {
            return jsonResponse([
              taskJson(dueDate: yesterday, status: 'Atrasada', daysOverdue: 1),
            ]);
          }
          return jsonResponse(
            taskJson(dueDate: yesterday, status: 'Completada'),
          );
        },
        () async {
          await provider.loadTodayTasks();
          expect(provider.todayTasks.single.isOverdue, isTrue);
          expect(await provider.completeTask(5), isTrue);
        },
      );

      expect(provider.todayTasks.single.isCompleted, isTrue);
      expect(provider.todayTasks.single.isOverdue, isFalse);
    });

    test('también actualiza una tarea de upcomingTasks', () async {
      final provider = TaskProvider();

      await withApi(
        (request) async {
          if (request.method == 'GET') {
            return jsonResponse([taskJson(dueDate: future)]);
          }
          return jsonResponse(taskJson(dueDate: future, status: 'Completada'));
        },
        () async {
          await provider.loadUpcomingTasks();
          await provider.completeTask(5);
        },
      );

      expect(provider.upcomingTasks.single.isCompleted, isTrue);
    });

    test('si el API falla devuelve false y no cambia la tarea', () async {
      final provider = TaskProvider();

      final completed = await withApi(
        (request) async {
          if (request.method == 'GET') {
            return jsonResponse([taskJson(dueDate: today)]);
          }
          return jsonResponse({'detail': 'Tarea no encontrada'}, status: 404);
        },
        () async {
          await provider.loadTodayTasks();
          return provider.completeTask(5);
        },
      );

      expect(completed, isFalse);
      expect(provider.todayTasks.single.isCompleted, isFalse);
    });
  });
}
