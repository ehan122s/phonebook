import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' }

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  const token = request.headers.get('Authorization') ?? ''
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { data: { user } } = await admin.auth.getUser(token.replace('Bearer ', ''))
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders })
  const { activity_id, format } = await request.json()
  if (!activity_id || !['pdf', 'docx'].includes(format)) return Response.json({ error: 'Invalid report request' }, { status: 400, headers: corsHeaders })
  const { data: activity, error } = await admin.from('activities').select('*, profiles(full_name, nip), categories(name), activity_photos(*)').eq('id', activity_id).single()
  if (error || !activity) return Response.json({ error: 'Activity not found' }, { status: 404, headers: corsHeaders })
  const { data: profile } = await admin.from('profiles').select('role').eq('id', user.id).single()
  if (activity.user_id !== user.id && profile?.role !== 'admin') return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders })
  const content = `LAPORAN KEGIATAN PENYULUHAN\n\nJudul: ${activity.title}\nTanggal: ${activity.activity_date}\nLokasi: ${activity.location ?? '-'}\nDesa: ${activity.village}\nKecamatan: ${activity.district}\nKabupaten: ${activity.regency}\n\nMateri: ${activity.material ?? '-'}\nTujuan: ${activity.objective ?? '-'}\nHasil: ${activity.result ?? '-'}\nKendala: ${activity.obstacle ?? '-'}\nTindak lanjut: ${activity.follow_up ?? '-'}\n\nPenyuluh: ${activity.profiles?.full_name ?? '-'}`
  // The function stores a text report payload. Replace this renderer with a DOCX/PDF service in production.
  const path = `${activity_id}/${crypto.randomUUID()}.${format === 'pdf' ? 'txt' : 'txt'}`
  await admin.storage.from('generated-reports').upload(path, new Blob([content], { type: 'text/plain' }))
  const { data: report } = await admin.from('generated_reports').insert({ activity_id, format, file_path: path, created_by: user.id }).select().single()
  const { data: signed } = await admin.storage.from('generated-reports').createSignedUrl(path, 3600)
  return Response.json({ report, download_url: signed?.signedUrl }, { headers: corsHeaders })
})
