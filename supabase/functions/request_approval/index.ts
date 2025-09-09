// deno run with Supabase Edge Runtime
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient } from "../_shared/client.ts";

serve(async (req) => {
  try {
    const { post_id } = await req.json();
    const supabase = getServiceClient();

    const { data: post, error } = await supabase
      .from("journal_entries")
      .select("id, author_id, pair_id, state")
      .eq("id", post_id)
      .single();
    if (error || !post) throw error ?? new Error("Post not found");
    if (post.state !== "draft") throw new Error("Only draft can be submitted");

    const { error: updErr } = await supabase
      .from("journal_entries")
      .update({ state: "pending" })
      .eq("id", post_id);
    if (updErr) throw updErr;

    // Queue all attached media for AI review
    const { data: media, error: jmErr } = await supabase
      .from("journal_media")
      .select("media_id")
      .eq("journal_id", post_id);
    if (jmErr) throw jmErr;
    if (media && media.length > 0) {
      const ids = media.map((m) => m.media_id);
      const { error: mediaUpdErr } = await supabase
        .from("media_assets")
        .update({ status: "queued_ai" })
        .in("id", ids);
      if (mediaUpdErr) throw mediaUpdErr;
    }

    // TODO: send notification to partner via Realtime or Notifier
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 400 });
  }
});

