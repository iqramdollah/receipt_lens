import '../../../core/database/app_database.dart';

enum ReceiptSort { newest, oldest, highest, lowest }

/// What the receipts list is currently narrowed down to.
class ReceiptFilter {
  const ReceiptFilter({
    this.query = '',
    this.categoryId,
    this.from,
    this.to,
    this.needsReviewOnly = false,
    this.sort = ReceiptSort.newest,
  });

  final String query;
  final int? categoryId;

  /// Inclusive days: a receipt from 23:59 on [to] still matches.
  final DateTime? from;
  final DateTime? to;
  final bool needsReviewOnly;
  final ReceiptSort sort;

  static const _keep = Object();

  bool get hasDates => from != null || to != null;

  /// Sorting alone does not count as filtering.
  bool get isActive =>
      query.trim().isNotEmpty ||
      categoryId != null ||
      hasDates ||
      needsReviewOnly;

  /// Pass null explicitly to clear [categoryId], [from] or [to].
  ReceiptFilter copyWith({
    String? query,
    Object? categoryId = _keep,
    Object? from = _keep,
    Object? to = _keep,
    bool? needsReviewOnly,
    ReceiptSort? sort,
  }) => ReceiptFilter(
    query: query ?? this.query,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as int?,
    from: identical(from, _keep) ? this.from : from as DateTime?,
    to: identical(to, _keep) ? this.to : to as DateTime?,
    needsReviewOnly: needsReviewOnly ?? this.needsReviewOnly,
    sort: sort ?? this.sort,
  );

  List<Receipt> apply(Iterable<Receipt> receipts) {
    final q = query.trim().toLowerCase();
    final start = from == null
        ? null
        : DateTime(from!.year, from!.month, from!.day);
    final endExclusive = to == null
        ? null
        : DateTime(to!.year, to!.month, to!.day + 1);

    final result = receipts.where((r) {
      if (categoryId != null && r.categoryId != categoryId) return false;
      if (needsReviewOnly && !r.needsReview) return false;
      if (start != null && r.purchasedAt.isBefore(start)) return false;
      if (endExclusive != null && !r.purchasedAt.isBefore(endExclusive)) {
        return false;
      }
      if (q.isNotEmpty &&
          !r.merchant.toLowerCase().contains(q) &&
          !r.rawText.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    int byNewest(Receipt a, Receipt b) {
      final c = b.purchasedAt.compareTo(a.purchasedAt);
      return c != 0 ? c : b.id.compareTo(a.id);
    }

    final Comparator<Receipt> compare = switch (sort) {
      ReceiptSort.newest => byNewest,
      ReceiptSort.oldest => (a, b) => byNewest(b, a),
      ReceiptSort.highest => (a, b) {
        final c = b.totalSen.compareTo(a.totalSen);
        return c != 0 ? c : byNewest(a, b);
      },
      ReceiptSort.lowest => (a, b) {
        final c = a.totalSen.compareTo(b.totalSen);
        return c != 0 ? c : byNewest(a, b);
      },
    };
    result.sort(compare);
    return result;
  }
}
