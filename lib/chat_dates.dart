DateTime? messageDate(Map<String, dynamic> message) {
  final value =
      message['createdAt'] ?? message['created_date'] ?? message['timestamp'];
  if (value is DateTime) return value.toLocal();
  return value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

bool sameChatDay(DateTime? first, DateTime? second) =>
    first != null &&
    second != null &&
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String chatDateLabel(DateTime date, {DateTime? now}) {
  final today = (now ?? DateTime.now()).toLocal();
  if (sameChatDay(date, today)) return 'Today';
  if (sameChatDay(date, DateTime(today.year, today.month, today.day - 1)))
    return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

String messageTimeLabel(Map<String, dynamic> message) {
  final date = messageDate(message);
  if (date == null) return '';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
}
