import '../../transactions/models/transaction.dart';

/// One of the user's own categories (`backend/app/categories/`). `kind`
/// says which transaction type's picker lists it.
class UserCategory {
  const UserCategory({required this.id, required this.name, required this.kind});

  final String id;
  final String name;
  final CategoryKind kind;

  factory UserCategory.fromJson(Map<String, dynamic> json) => UserCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: json['kind'] == 'income' ? CategoryKind.income : CategoryKind.expense,
      );
}

enum CategoryKind {
  expense,
  income;

  /// Income categories for income; spending ones for everything else
  /// (a transfer is filed like spending).
  static CategoryKind of(TransactionType type) =>
      type == TransactionType.income ? CategoryKind.income : CategoryKind.expense;
}
