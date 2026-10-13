import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../data/categories_api.dart';
import '../models/user_category.dart';

final categoriesApiProvider = Provider<CategoriesApi>((ref) => CategoriesApi(ref.watch(apiClientProvider)));

/// The user's categories, A–Z: the one list behind the transaction sheet,
/// the Transactions filter, and the budget and goal sheets (QA pass 1).
final categoriesProvider = FutureProvider.autoDispose<List<UserCategory>>((ref) {
  return ref.watch(categoriesApiProvider).list();
});

/// Names to offer in a picker. [kind] puts that kind first, then the rest,
/// so an income can still go under a spending category if that's how the
/// user files it. [include] keeps a value that's already set, even when
/// the list hasn't loaded (or doesn't have it). Until the list loads, the
/// stock [commonCategories] stand in.
List<String> categoryChoices(
  List<UserCategory>? categories, {
  CategoryKind? kind,
  String? include,
}) {
  final names = <String>[];
  if (categories == null) {
    names.addAll(commonCategories);
  } else {
    final first = kind == null ? categories : categories.where((c) => c.kind == kind);
    final rest = kind == null ? const <UserCategory>[] : categories.where((c) => c.kind != kind);
    names
      ..addAll(first.map((c) => c.name))
      ..addAll(rest.map((c) => c.name));
  }
  if (include != null && include.trim().isNotEmpty && !names.any((n) => n.toLowerCase() == include.toLowerCase())) {
    names.insert(0, include);
  }
  return names;
}
