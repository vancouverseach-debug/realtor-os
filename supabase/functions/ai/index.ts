// Realtor OS AI proxy. Holds the Anthropic key server-side so it never
// appears in the public page. Only a signed-in Realtor OS user can call it.
// Accepts an optional list of files (PDFs or images) for Claude to read.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const IMAGE_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  // Check the caller is signed in.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: userData, error: userErr } = await supabase.auth.getUser(token);
  if (userErr || !userData?.user) return json({ error: { message: "Not signed in" } }, 401);

  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) return json({ error: { message: "ANTHROPIC_API_KEY secret is not set" } }, 500);

  try {
    const { prompt, maxTokens = 500, files = [] } = await req.json();
    if (typeof prompt !== "string" || !prompt.trim()) {
      return json({ error: { message: "Missing prompt" } }, 400);
    }

    // Optional attachments: [{ media_type: "application/pdf" | "image/png" | ..., data: base64 }]
    const blocks: unknown[] = [];
    for (const f of (Array.isArray(files) ? files : []).slice(0, 3)) {
      if (!f || typeof f.data !== "string") continue;
      if (f.media_type === "application/pdf") {
        blocks.push({ type: "document", source: { type: "base64", media_type: "application/pdf", data: f.data } });
      } else if (IMAGE_TYPES.includes(f.media_type)) {
        blocks.push({ type: "image", source: { type: "base64", media_type: f.media_type, data: f.data } });
      }
    }
    blocks.push({ type: "text", text: prompt });

    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: Math.min(Number(maxTokens) || 500, 4000),
        messages: [{ role: "user", content: blocks }],
      }),
    });
    return json(await res.json(), res.status);
  } catch (e) {
    return json({ error: { message: String(e) } }, 500);
  }
});
