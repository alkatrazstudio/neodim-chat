// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

extension EnumValues<T extends Enum> on List<T> {
  T byNameOrFirst(String name) {
    try {
      return byName(name);
    } on Exception catch (_) {
      return first;
    }
  }
}
