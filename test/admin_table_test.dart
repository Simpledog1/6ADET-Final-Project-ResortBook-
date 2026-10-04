import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/widgets/admin_table.dart';

void main() {
  group('AdminPagination.pageItems', () {
    test('no pages gives no items', () {
      expect(AdminPagination.pageItems(0, 0), isEmpty);
    });

    test('up to 7 pages are all shown', () {
      expect(AdminPagination.pageItems(0, 1), [0]);
      expect(AdminPagination.pageItems(3, 7), [0, 1, 2, 3, 4, 5, 6]);
    });

    test('first page of many: 1 2 … last', () {
      expect(AdminPagination.pageItems(0, 10), [0, 1, null, 9]);
    });

    test('middle page: 1 … around current … last', () {
      expect(AdminPagination.pageItems(4, 10), [0, null, 3, 4, 5, null, 9]);
    });

    test('pages next to the edges do not add a gap', () {
      expect(AdminPagination.pageItems(1, 10), [0, 1, 2, null, 9]);
      expect(AdminPagination.pageItems(8, 10), [0, null, 7, 8, 9]);
    });

    test('last page: 1 … second-last last', () {
      expect(AdminPagination.pageItems(9, 10), [0, null, 8, 9]);
    });

    test('out-of-range pages are clamped', () {
      expect(AdminPagination.pageItems(-3, 10), [0, 1, null, 9]);
      expect(AdminPagination.pageItems(42, 10), [0, null, 8, 9]);
    });
  });
}
