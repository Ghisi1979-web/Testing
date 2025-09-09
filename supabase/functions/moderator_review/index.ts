import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient } from "../_shared/client.ts";

serve(async (req) => {
  try {
    const { target, id, decision, reason, actor_user_id } = await req.json();
    if (!['media','journal'].includes(target)) throw new Error('Invalid target');
    if (!['approve','reject','flag'].includes(decision)) throw new Error('Invalid decision');
    const supabase = getServiceClient();

    if (target === 'media') {
      const status = decision === 'approve' ? 'approved' : decision === 'reject' ? 'flagged' : 'flagged';
      const { error: updErr } = await supabase
        .from('media_assets')
        .update({ status })
        .eq('id', id);
      if (updErr) throw updErr;
    } else if (target === 'journal') {
      // For journal: reject -> approved (unpublish) handled by revoke_publish function
    }

    await supabase.from('moderation_events').insert({
      target_type: target === 'media' ? 'media' : 'journal',
      target_id: id,
      actor_user_id,
      decision,
      reason,
    });

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 400 });
  }
});

