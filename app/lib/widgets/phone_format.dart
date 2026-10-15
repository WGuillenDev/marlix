/// `911` → `9-1-1`; `8002737869` → `800-273-7869`; `22257511` → `2225-7511`.
String formatPhone(String digits) => switch (digits.length) {
  3 => digits.split('').join('-'),
  8 => '${digits.substring(0, 4)}-${digits.substring(4)}',
  10 => '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}',
  _ => digits,
};
