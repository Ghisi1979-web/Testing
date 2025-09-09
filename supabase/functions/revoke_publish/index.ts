import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient } from "../_shared/client.ts";

serve(async (req) => {
  try {
    const { post_id } = await req.json();
    const supabase = getServiceClient();
    const { error } = await supabase
      .from('journal_entries')
      .update({ state: 'approved', visibility: 'pair' })
      .eq('id', post_id);
    if (error) throw error;
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 400 });
  }
});

