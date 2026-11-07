# UTF-8 BOM is added by the package build for Windows PowerShell 5.1.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Write-Host 'rtlTerminal - Persian / mixed-direction rendering test' -ForegroundColor Cyan
Write-Host 'سلام دنیا، این یک آزمایش است.'
Write-Host 'فایل config.json را در پوشه C:\Users\Test ویرایش کن'
Write-Host 'می‌خواهم کتاب‌ها را جابه‌جا کنم؛ فاصله و نیم‌فاصله'
Write-Host 'one two سه چهار پنج six 123 (abc)'
Write-Host ('این یک پاراگراف طولانی برای آزمایش شکست سطر و جهت متن است. ' * 8)
Write-Host '(abc) پس از تغییر اندازه پنجره، اتصال حروف و فاصله‌ها را بررسی کن.'
Write-Host ''
Write-Host 'Check shaping, normal word spaces, wrap/resize, selection and copy/paste.'
Write-Host 'Rendering test only: visual-arrow editing is NOT enabled in PowerShell.'
