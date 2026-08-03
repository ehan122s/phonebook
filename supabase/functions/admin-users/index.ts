import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' }
const validRoles = ['admin', 'penyuluh'] as const

function invalidRequest(message: string) {
  return Response.json({ error: message }, { status: 400, headers: corsHeaders })
}

function isValidRole(role: unknown): role is typeof validRoles[number] {
  return typeof role === 'string' && validRoles.includes(role as typeof validRoles[number])
}

function isValidUserInput(body: Record<string, unknown>) {
  if (typeof body.full_name !== 'string' || body.full_name.trim().length === 0) {
    return 'Nama lengkap wajib diisi.'
  }
  if (!isValidRole(body.role)) return 'Peran pengguna tidak valid.'
  return null
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  const token = request.headers.get('Authorization') ?? ''
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { data: { user } } = await admin.auth.getUser(token.replace('Bearer ', ''))
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders })
  const { data: caller } = await admin.from('profiles').select('role').eq('id', user.id).single()
  if (caller?.role !== 'admin') return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders })
  const body = await request.json() as Record<string, unknown>
  if (body.action === 'create') {
    const validationError = isValidUserInput(body)
    if (validationError) return invalidRequest(validationError)
    if (typeof body.email !== 'string' || !body.email.includes('@')) {
      return invalidRequest('Email tidak valid.')
    }
    if (typeof body.password !== 'string' || body.password.length < 6) {
      return invalidRequest('Kata sandi minimal 6 karakter.')
    }
    const fullName = body.full_name as string
    const role = body.role as typeof validRoles[number]

    const { data, error } = await admin.auth.admin.createUser({
      email: body.email,
      password: body.password,
      email_confirm: true,
      user_metadata: { full_name: fullName.trim(), role },
    })
    if (error) return Response.json({ error: error.message }, { status: 400, headers: corsHeaders })

    const { error: profileError } = await admin.from('profiles').upsert(
      {
        id: data.user.id,
        full_name: fullName.trim(),
        nip: typeof body.nip === 'string' && body.nip.trim() ? body.nip.trim() : null,
        role,
      },
      { onConflict: 'id' }
    )
    if (profileError) {
      await admin.auth.admin.deleteUser(data.user.id)
      return Response.json({ error: profileError.message }, { status: 400, headers: corsHeaders })
    }

    return Response.json({ user: data.user }, { headers: corsHeaders })
  }
  if (body.action === 'update') {
    const validationError = isValidUserInput(body)
    if (validationError) return invalidRequest(validationError)
    if (typeof body.user_id !== 'string') return invalidRequest('ID pengguna tidak valid.')
    const fullName = body.full_name as string
    const role = body.role as typeof validRoles[number]

    const { data: targetUser, error: targetError } = await admin
      .from('profiles')
      .select('role')
      .eq('id', body.user_id)
      .maybeSingle()
    if (targetError || !targetUser) {
      return Response.json({ error: targetError?.message ?? 'Pengguna tidak ditemukan.' }, { status: 404, headers: corsHeaders })
    }
    if (body.user_id === user.id && role !== 'admin') {
      return invalidRequest('Admin tidak dapat menghapus akses admin dari akun sendiri.')
    }
    if (targetUser.role === 'admin' && role !== 'admin') {
      const { count, error: countError } = await admin
        .from('profiles')
        .select('*', { count: 'exact', head: true })
        .eq('role', 'admin')
      if (countError) return Response.json({ error: countError.message }, { status: 400, headers: corsHeaders })
      if ((count ?? 0) <= 1) return invalidRequest('Admin terakhir tidak dapat diubah menjadi penyuluh.')
    }

    const { error } = await admin
      .from('profiles')
      .update({
        full_name: fullName.trim(),
        nip: typeof body.nip === 'string' && body.nip.trim() ? body.nip.trim() : null,
        role,
      })
      .eq('id', body.user_id)
    if (error) return Response.json({ error: error.message }, { status: 400, headers: corsHeaders })
    return Response.json({ ok: true }, { headers: corsHeaders })
  }
  if (body.action === 'delete') {
    if (typeof body.user_id !== 'string') return invalidRequest('ID pengguna tidak valid.')
    if (body.user_id === user.id) return invalidRequest('Akun sendiri tidak dapat dihapus.')

    const { data: targetUser, error: targetError } = await admin
      .from('profiles')
      .select('role')
      .eq('id', body.user_id)
      .maybeSingle()
    if (targetError || !targetUser) {
      return Response.json({ error: targetError?.message ?? 'Pengguna tidak ditemukan.' }, { status: 404, headers: corsHeaders })
    }
    if (targetUser.role === 'admin') {
      const { count, error: countError } = await admin
        .from('profiles')
        .select('*', { count: 'exact', head: true })
        .eq('role', 'admin')
      if (countError) return Response.json({ error: countError.message }, { status: 400, headers: corsHeaders })
      if ((count ?? 0) <= 1) return invalidRequest('Admin terakhir tidak dapat dihapus.')
    }

    const { data: activities, error: activitiesError } = await admin
      .from('activities')
      .select('id')
      .eq('user_id', body.user_id)
    if (activitiesError) return Response.json({ error: activitiesError.message }, { status: 400, headers: corsHeaders })

    const activityIds = activities.map((activity) => activity.id)
    if (activityIds.length > 0) {
      const [{ data: documents, error: documentsError }, { data: photos, error: photosError }] = await Promise.all([
        admin.from('activity_documents').select('file_path').in('activity_id', activityIds),
        admin.from('activity_photos').select('file_path').in('activity_id', activityIds),
      ])
      if (documentsError || photosError) {
        return Response.json({ error: documentsError?.message ?? photosError?.message }, { status: 400, headers: corsHeaders })
      }

      const documentPaths = documents.map((document) => document.file_path)
      const photoPaths = photos.map((photo) => photo.file_path)
      if (documentPaths.length > 0) await admin.storage.from('activity-documents').remove(documentPaths)
      if (photoPaths.length > 0) await admin.storage.from('activity-photos').remove(photoPaths)

      const { error: deleteActivitiesError } = await admin.from('activities').delete().in('id', activityIds)
      if (deleteActivitiesError) return Response.json({ error: deleteActivitiesError.message }, { status: 400, headers: corsHeaders })
    }

    const { error } = await admin.auth.admin.deleteUser(body.user_id)
    if (error) return Response.json({ error: error.message }, { status: 400, headers: corsHeaders })
    return Response.json({ ok: true }, { headers: corsHeaders })
  }
  return Response.json({ error: 'Invalid action' }, { status: 400, headers: corsHeaders })
})
