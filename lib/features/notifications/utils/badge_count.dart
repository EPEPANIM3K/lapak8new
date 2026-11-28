String formatBadgeCount(int count) {
  if (count <= 0) return '0';
  if (count > 99) return '99+';
  return count.toString();
}
