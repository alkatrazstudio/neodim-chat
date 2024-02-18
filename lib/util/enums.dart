// SPDX-License-Identifier: GPL-3.0-only
// 🄯 2024, Alexey Parfenov <zxed@alkatrazstudio.net>

extension EnumValues<T extends Enum> on List<T> {
  T? byNameOrNull(String name) {
    try {
      return byName(name);
    } catch (_) {
      return null;
    }
  }

  T byNameOrFirst(String name) {
    return byNameOrNull(name) ?? first;
  }
}
