alter table public.products add column if not exists image_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 3145728,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists product_images_select on storage.objects;
create policy product_images_select on storage.objects
for select to authenticated
using (case when bucket_id = 'product-images'
  then public.is_business_member(((storage.foldername(name))[1])::uuid)
  else false end);

drop policy if exists product_images_insert on storage.objects;
create policy product_images_insert on storage.objects
for insert to authenticated
with check (case when bucket_id = 'product-images'
  then public.is_business_member(((storage.foldername(name))[1])::uuid)
  else false end);

drop policy if exists product_images_update on storage.objects;
create policy product_images_update on storage.objects
for update to authenticated
using (case when bucket_id = 'product-images'
  then public.is_business_member(((storage.foldername(name))[1])::uuid)
  else false end);

drop policy if exists product_images_delete on storage.objects;
create policy product_images_delete on storage.objects
for delete to authenticated
using (case when bucket_id = 'product-images'
  then public.is_business_member(((storage.foldername(name))[1])::uuid)
  else false end);
