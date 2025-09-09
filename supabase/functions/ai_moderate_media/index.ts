import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient } from "../_shared/client.ts";

serve(async (req) => {
  try {
    const { asset_id, detected_tier, labels, score } = await req.json();
    if (!['soft','explicit'].includes(detected_tier)) throw new Error('Invalid detected_tier');
    const supabase = getServiceClient();

    const { data: asset, error } = await supabase
      .from('media_assets')
      .select('id, declared_tier')
      .eq('id', asset_id)
      .single();
    if (error || !asset) throw error ?? new Error('Asset not found');

    const status = asset.declared_tier === detected_tier ? 'approved' : 'flagged';

    const { error: updErr } = await supabase
      .from('media_assets')
      .update({ detected_tier, labels, score, status })
      .eq('id', asset_id);
    if (updErr) throw updErr;

    return new Response(JSON.stringify({ ok: true, status }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 400 });
  }
});

