-- Jalankan sendiri setelah tidak ada query lain aktif pada SQL Editor.
-- Migration kecil ini memperbaiki profil akun agar dashboard tidak berhenti di loading.
do $$
begin
  create policy "profiles self insert" on public.profiles
    for insert with check (id = auth.uid() and role = 'penyuluh');
exception
  when duplicate_object then null;
end;
$$;
