# Sales Manager — v0.2 Backend Foundation

## ماذا أضيف في هذه المرحلة؟
- Supabase Auth لتسجيل الدخول.
- PostgreSQL schema احترافي متعدد الشركات/الحسابات.
- Row Level Security (RLS).
- Products / Customers / Suppliers / Sales / Purchases / Expenses / Stock Movements.
- Realtime على المنتجات والعملاء والمبيعات وحركة المخزون.
- Flutter service جاهز للاتصال بالسحابة.
- Login screen.
- التطبيق يظل يعمل بوضع Demo إذا لم تمرر بيانات Supabase.

## إعداد Supabase
1. أنشئ مشروعًا جديدًا في Supabase.
2. افتح SQL Editor.
3. انسخ محتوى `supabase/migrations/001_initial_schema.sql` وشغّله.
4. أنشئ مستخدمًا من Authentication.
5. شغّل التطبيق بمتغيرات البناء:

### Android / Windows
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY

أو ضع المتغيرات في إعدادات CI/CD.

> لا تضع service_role key داخل تطبيق Android أو Windows.

## ملاحظات
Realtime يحتاج أن تكون الجداول المقصودة ضمن publication، والـSQL في هذا الإصدار يضيف الجداول الرئيسية لذلك.
RLS مفعل على الجداول الحساسة، وكل مستخدم لا يرى بيانات شركة إلا إذا كان عضوًا فيها.

## الخطوة التالية
- شاشة إنشاء الشركة لأول مرة.
- اختيار الشركة/الفرع.
- CRUD حقيقي للمنتجات والعملاء.
- إنشاء فاتورة Atomic Transaction مع تحديث المخزون.
- Offline queue + local database ثم Sync.
- Barcode + printers.

## v0.3 — التنفيذ الحقيقي
- اختيار/إنشاء النشاط بعد تسجيل الدخول.
- CRUD حقيقي للمنتجات على PostgreSQL.
- Realtime للمنتجات.
- إنشاء فاتورة Atomic Transaction عبر RPC مع خصم المخزون وتسجيل حركة المخزون وتحديث مديونية العميل.
- تشغيل التطبيق بدون Supabase يظل Demo.

شغّل ملفات SQL بالترتيب: `001_initial_schema.sql` ثم `002_atomic_sale.sql`.

## v0.4 — شاشة نقطة البيع (POS)
- كتالوج منتجات حي من Supabase.
- بحث بالاسم/الباركود.
- سلة وتعديل كميات مع احترام المخزون.
- عميل + نقدي/بطاقة/تحويل/آجل.
- خصم ومدفوع ومتأخر.
- حفظ الفاتورة بعملية قاعدة بيانات Atomic وتحديث المخزون والمديونية.
- تحسينات تحقق على RPC في `003_sales_validation.sql`.

شغّل ملفات SQL بالترتيب: `001_initial_schema.sql` ثم `002_atomic_sale.sql` ثم `003_sales_validation.sql`.
