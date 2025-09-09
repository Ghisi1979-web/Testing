import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient, assertPairApproval } from "../_shared/client.ts";

serve(async (req) => {
  try {
    const { post_id, actor_id } = await req.json();
    const supabase = getServiceClient();
    const { data: post, error } = await supabase
      .from("journal_entries")
      .select("id, author_id, pair_id, state")
      .eq("id", post_id)
      .single();
    if (error || !post) throw error ?? new Error("Post not found");
    if (post.state !== "pending") throw new Error("Post not pending");

    assertPairApproval(actor_id, post.author_id, post.pair_id);

    const { error: updErr } = await supabase
      .from("journal_entries")
      .update({ state: "approved" })
      .eq("id", post_id);
    if (updErr) throw updErr;

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 400 });
  }
});

