#!/usr/bin/env bash
# Hard newlines separate these cases; each long printf is a single paragraph.
printf '%s\n' '--- Natural Persian / Arabic word spaces ---'
printf '%s\n' 'سلام دنیا، این یک آزمایش است.' 'بسم الله الرحمن الرحیم — سلام دنیا این یک آزمایش است' 'می‌خواهم کتاب‌ها را جابه‌جا کنم؛ عدد ۱۲۳ و 123.'
printf '\n%s\n' '--- Mixed runs, punctuation and digits ---'
printf '%s\n' 'فایل config.json را در پوشهٔ /etc/nginx ویرایش کن (123)؛ سپس command --help.' 'English (فارسی) 42! => columns remain logical'
printf '\n%s\n' '--- Soft wrap: paragraph context must survive ---'
printf '%s\n' 'فارسی شروع می‌شود و سپس (English words 123 that continue across a soft wrapped physical row: one two three four five six seven eight nine ten) و بعد دوباره فارسی تا انتهای پاراگراف ادامه دارد.'
printf '%s\n' 'English paragraph with فارسی در وسط جمله and a long continuation (123) with punctuation; next soft-wrapped row must retain the English paragraph direction, نه جهت مستقل هر ردیف.'
printf '\n%s\n' '--- Long words / ZWNJ / marks ---'
printf '%s\n' 'مستعمرهنشینانمستعمرهنشینانمستعمرهنشینانمستعمرهنشینانمستعمرهنشینانمستعمرهنشینانمستعمرهنشینان' 'بِسْمِ اللّهِ الرَّحْمٰنِ الرَّحِيمِ — می‌خواهم، نمی‌شود، کتاب‌ها'
