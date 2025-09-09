import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient } from "../_shared/client.ts";

serve(async (req) => {
  try {
    const { post_id, visibility } = await req.json();
    if (!['coach','community'].includes(visibility)) throw new Error('Invalid visibility');
    const supabase = getServiceClient();

    const { data: post, error } = await supabase
      .from("journal_entries")
      .select("id, state")
      .eq("id", post_id)
      .single();
    if (error || !post) throw error ?? new Error("Post not found");
    if (post.state !== "approved") throw new Error("Post not approved");

    // All media must be approved
    const { data: media, error: jmErr } = await supabase
      .from("journal_media")
      .select("media_assets(status)")
      .eq("journal_id", post_id);
    if (jmErr) throw jmErr;
    const allApproved = (media ?? []).every((m: any) => m.media_assets?.status === 'approved');
    if (!allApproved) throw new Error('All media must be approved');

    const { error: updErr } = await supabase
      .from("journal_entries")
      .update({ state: "published", visibility })
      .eq("id", post_id);
    if (updErr) throw updErr;

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 400 });
  }
});

