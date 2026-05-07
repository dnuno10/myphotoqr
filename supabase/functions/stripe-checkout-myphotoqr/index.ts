// supabase/functions/stripe-checkout/index.ts
// supabase/functions/stripe-checkout-myphotoqr/index.ts

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@16.12.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
});

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const requestMode = body.mode;

    if (requestMode === "create_album") {
      const priceId = body.price_id;
      const successUrl = body.success_url;
      const cancelUrl = body.cancel_url;
      const albumMeta = body.album;

      if (!priceId || !successUrl || !cancelUrl || !albumMeta) {
        return new Response(
          JSON.stringify({ error: "Missing required fields" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      const metadata: Record<string, string> = {
        supabase_user_id: user.id,
        ...albumMeta,
      };

      const session = await stripe.checkout.sessions.create({
        mode: "payment",
        line_items: [{ price: priceId, quantity: 1 }],
        success_url: successUrl,
        cancel_url: cancelUrl,
        client_reference_id: user.id,
        customer_email: user.email ?? undefined,
        metadata,
      });

      return new Response(JSON.stringify({ url: session.url }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (requestMode === "get_album_result") {
      const sessionId = body.session_id;
      if (!sessionId) {
        return new Response(JSON.stringify({ error: "Missing session_id" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const session = await stripe.checkout.sessions.retrieve(sessionId);

      const sessionUserId = session.metadata?.supabase_user_id;
      if (!sessionUserId || sessionUserId !== user.id) {
        return new Response(JSON.stringify({ error: "Unauthorized" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const paymentStatus = session.payment_status ?? "unpaid";
      if (paymentStatus !== "paid" && paymentStatus !== "no_payment_required") {
        return new Response(
          JSON.stringify({
            status: "pending",
            message: "Waiting for payment confirmation.",
          }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      const existingAlbumId = session.metadata?.album_id;
      if (existingAlbumId && existingAlbumId.length > 0) {
        return new Response(
          JSON.stringify({
            status: "paid",
            album_id: existingAlbumId,
            message: "Album created.",
          }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }

      const adminSupabase = createClient(supabaseUrl, serviceRoleKey);

      const albumTitle = session.metadata?.album_title ?? "Album";
      const albumEventType = session.metadata?.album_event_type ?? "other";
      const albumEventTypeLabelRaw =
        session.metadata?.album_event_type_label ?? "";
      const albumDescription = session.metadata?.album_description ?? null;
      const albumEventLocation = session.metadata?.album_event_location ?? null;
      const albumEventDate = session.metadata?.album_event_date ?? null;
      const albumThemeColor = session.metadata?.album_theme_color ?? "#111827";
      const albumThemeBgColor =
        session.metadata?.album_theme_background_color ?? "#ffffff";
      const albumThemeColorModeRaw =
        session.metadata?.album_theme_color_mode ?? "solid";
      const albumThemeBackgroundModeRaw =
        session.metadata?.album_theme_background_mode ?? "solid";
      const albumThemeColorGradientRaw =
        session.metadata?.album_theme_color_gradient ?? "";
      const albumThemeBackgroundGradientRaw =
        session.metadata?.album_theme_background_gradient ?? "";
      const albumThemeEmojiRaw = session.metadata?.album_theme_emoji ?? "";
      const codeProtected =
        (session.metadata?.album_code_protected ?? "false") === "true";
      const guestCodeHash = session.metadata?.album_guest_code_hash ?? null;

      const albumThemeColorMode = normalizeMode(albumThemeColorModeRaw);
      const albumThemeBackgroundMode = normalizeMode(albumThemeBackgroundModeRaw);
      const albumThemeColorGradient = albumThemeColorMode === "gradient"
        ? safeJsonParse(albumThemeColorGradientRaw)
        : null;
      const albumThemeBackgroundGradient = albumThemeBackgroundMode === "gradient"
        ? safeJsonParse(albumThemeBackgroundGradientRaw)
        : null;

      // Ensure app user row exists (same logic as AlbumService.getOrCreateCurrentUser).
      const { data: existingUser, error: existingUserError } = await adminSupabase
        .from("users")
        .select()
        .eq("auth_user_id", user.id)
        .maybeSingle();

      if (existingUserError) throw existingUserError;

      let appUser = existingUser;

      if (!appUser) {
        const { data: createdUser, error: createdUserError } = await adminSupabase
          .from("users")
          .insert({ auth_user_id: user.id, email: user.email })
          .select()
          .single();

        if (createdUserError) throw createdUserError;
        appUser = createdUser;
      }

      const slug = slugify(albumTitle);

      const insertPayload: Record<string, unknown> = {
        user_id: appUser.id,
        title: albumTitle.trim(),
        slug,
        description: albumDescription?.trim() ?? null,
        event_type: albumEventType,
        event_type_label:
          albumEventTypeLabelRaw.trim().length > 0
            ? albumEventTypeLabelRaw.trim()
            : null,
        event_date: albumEventDate,
        event_location: albumEventLocation?.trim() ?? null,
        theme_emoji:
          albumThemeEmojiRaw.trim().length > 0 ? albumThemeEmojiRaw.trim() : null,
        theme_color: albumThemeColor,
        theme_background_color: albumThemeBgColor,
        theme_color_mode: albumThemeColorMode,
        theme_color_gradient: albumThemeColorGradient,
        theme_background_mode: albumThemeBackgroundMode,
        theme_background_gradient: albumThemeBackgroundGradient,
        visibility: codeProtected ? "code_protected" : "public",
        guest_access_code_enabled: codeProtected,
        guest_access_code_hash: codeProtected ? guestCodeHash : null,
        guest_access_code_hint: codeProtected ? "Código requerido" : null,
        status: "active",
        upload_enabled: true,
        gallery_enabled: true,
      };

      const { data: insertedAlbum, error: insertedAlbumError } = await adminSupabase
        .from("albums")
        .insert(insertPayload)
        .select("id")
        .single();

      if (insertedAlbumError) throw insertedAlbumError;

      const albumId = insertedAlbum.id as string;

      await stripe.checkout.sessions.update(sessionId, {
        metadata: {
          ...(session.metadata ?? {}),
          album_id: albumId,
        },
      });

      return new Response(
        JSON.stringify({
          status: "paid",
          album_id: albumId,
          message: "Album created.",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(JSON.stringify({ error: "Unsupported mode" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return new Response(JSON.stringify({ error: message || "Unexpected error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function slugify(value: string) {
  const cleaned = value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-");

  const suffix = Math.floor(Math.random() * 99999).toString().padStart(5, "0");
  return `${cleaned.length === 0 ? "album" : cleaned}-${suffix}`;
}

function normalizeMode(value: string) {
  const normalized = value.toLowerCase().trim();
  return normalized === "gradient" ? "gradient" : "solid";
}

function safeJsonParse(raw: string) {
  const value = (raw ?? "").trim();
  if (!value) return null;
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}
