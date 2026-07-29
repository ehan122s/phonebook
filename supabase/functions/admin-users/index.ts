import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' }

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  const token = request.headers.get('Authorization') ?? ''
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { data: { user } } = await admin.auth.getUser(token.replace('Bearer ', ''))
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401, headers: corsHeaders })
  const { data: caller } = await admin.from('profiles').select('role').eq('id', user.id).single()
  if (caller?.role !== 'admin') return Response.json({ error: 'Forbidden' }, { status: 403, headers: corsHeaders })
  const body = await request.json()
  if (body.action === 'create') {
    const { data, error } = await admin.auth.admin.createUser({
      email: body.email,
      password: body.password,
      email_confirm: true,
      user_metadata: { full_name: body.full_name, role: 'admin' },
    })
    if (error) return Response.json({ error: error.message }, { status: 400, headers: corsHeaders })

    await admin.from('profiles').upsert(
      { id: data.user.id, full_name: body.full_name, role: 'admin' },
      { onConflict: 'id' }
    )

    return Response.json({ user: data.user }, { headers: corsHeaders })
  }
  if (body.action === 'delete' && body.user_id && body.user_id !== user.id) {
    const { error } = await admin.auth.admin.deleteUser(body.user_id)
    if (error) return Response.json({ error: error.message }, { status: 400, headers: corsHeaders })
    return Response.json({ ok: true }, { headers: corsHeaders })
  }
  return Response.json({ error: 'Invalid action' }, { status: 400, headers: corsHeaders })
})
