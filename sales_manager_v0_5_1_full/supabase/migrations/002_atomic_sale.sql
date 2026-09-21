-- Atomic sale transaction.
-- The client sends item product IDs + quantities + unit prices.
create or replace function public.create_sale(
  p_business_id uuid,
  p_customer_id uuid default null,
  p_items jsonb default '[]'::jsonb,
  p_discount numeric default 0,
  p_tax numeric default 0,
  p_paid numeric default 0,
  p_payment_method text default 'cash',
  p_note text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  sale_id uuid;
  subtotal numeric(14,2) := 0;
  total numeric(14,2) := 0;
  item jsonb;
  pid uuid;
  qty numeric;
  unit_price numeric(14,2);
  product_stock numeric;
  item_total numeric(14,2);
  inv bigint;
begin
  if uid is null or not public.is_business_member(p_business_id) then
    raise exception 'Not authorized';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'Sale must contain at least one item';
  end if;

  for item in select * from jsonb_array_elements(p_items)
  loop
    pid := (item->>'product_id')::uuid;
    qty := (item->>'quantity')::numeric;
    unit_price := (item->>'unit_price')::numeric;

    if qty <= 0 then raise exception 'Invalid quantity'; end if;
    if unit_price < 0 then raise exception 'Invalid price'; end if;

    select stock into product_stock
    from public.products
    where id = pid and business_id = p_business_id and is_active = true
    for update;

    if not found then raise exception 'Product not found'; end if;
    if product_stock < qty then
      raise exception 'Insufficient stock for product %', pid;
    end if;

    item_total := round(qty * unit_price, 2);
    subtotal := subtotal + item_total;
  end loop;

  total := greatest(0, round(subtotal - coalesce(p_discount,0) + coalesce(p_tax,0), 2));

  if p_paid < 0 or p_paid > total then
    raise exception 'Invalid paid amount';
  end if;

  insert into public.sales(
    business_id, customer_id, cashier_id, subtotal, discount, tax,
    total, paid, payment_method, status, note
  ) values (
    p_business_id, p_customer_id, uid, subtotal, coalesce(p_discount,0),
    coalesce(p_tax,0), total, p_paid, p_payment_method, 'completed', p_note
  ) returning id, invoice_number into sale_id, inv;

  for item in select * from jsonb_array_elements(p_items)
  loop
    pid := (item->>'product_id')::uuid;
    qty := (item->>'quantity')::numeric;
    unit_price := (item->>'unit_price')::numeric;
    item_total := round(qty * unit_price, 2);

    insert into public.sale_items(sale_id, product_id, quantity, unit_price, total)
    values (sale_id, pid, qty, unit_price, item_total);

    update public.products
    set stock = stock - qty, updated_at = now()
    where id = pid;

    insert into public.stock_movements(
      business_id, product_id, user_id, movement_type, quantity, reference_id
    ) values (
      p_business_id, pid, uid, 'sale', -qty, sale_id
    );
  end loop;

  if p_customer_id is not null and p_paid < total then
    update public.customers
    set balance = balance + (total - p_paid)
    where id = p_customer_id and business_id = p_business_id;
  end if;

  return jsonb_build_object(
    'id', sale_id,
    'invoice_number', inv,
    'subtotal', subtotal,
    'discount', coalesce(p_discount,0),
    'tax', coalesce(p_tax,0),
    'total', total,
    'paid', p_paid,
    'due', total - p_paid
  );
end;
$$;

revoke all on function public.create_sale(uuid,uuid,jsonb,numeric,numeric,numeric,text,text) from public;
grant execute on function public.create_sale(uuid,uuid,jsonb,numeric,numeric,numeric,text,text) to authenticated;
