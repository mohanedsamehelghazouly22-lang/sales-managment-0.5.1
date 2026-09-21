# 005 — Complete sales system (applied directly on Supabase)

Applied as four migrations on the live project:

- 005a_complete_system_schema — sale_items.unit_cost, sales.cancelled_*, purchases.invoice_number/payment_method/note,
  tables `payments` and `notifications`, indexes, realtime publication, view `operations_log`
- 005b_complete_system_functions — create_sale (server-side pricing for cashiers, cost snapshot, credit limit),
  cancel_sale, create_purchase, cancel_purchase, adjust_stock, receive_customer_payment, pay_supplier,
  report_profit, report_top_products, report_customers
- 005c_notification_triggers — tg_notify() + triggers on sales/products/customers/suppliers/purchases/expenses/payments
- 005d_revoke_anon_execute — revoke anon EXECUTE on create_business / is_business_member

To export the exact SQL into the repo: `supabase db pull` (Supabase CLI), or read
`supabase_migrations.schema_migrations` in the SQL editor.
