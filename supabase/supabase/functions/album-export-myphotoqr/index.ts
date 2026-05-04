import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import JSZip from "npm:jszip@3.10.1";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const EXPORT_BUCKET = Deno.env.get("ALBUM_EXPORT_BUCKET") ?? "album-media";
const MAX_FILES = 300;
const MAX_TOTAL_BYTES = 250 * 1024 * 1024; // 250MB

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }

    const body = await req.json();
    const mode = body.mode;

    if (mode !== "create_export") {
      return json({ error: "Unsupported mode" }, 400);
    }

    const albumId = body.album_id?.toString();
    const guestCode = body.guest_code?.toString();

    if (!albumId) {
      return json({ error: "Missing album_id" }, 400);
    }

    const adminSupabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: albumSettings, error: settingsError } = await adminSupabase
      .from("album_settings")
      .select("allow_guest_downloads")
      .eq("album_id", albumId)
      .maybeSingle();
    if (settingsError) throw settingsError;

    if (!albumSettings?.allow_guest_downloads) {
      return json({ error: "Downloads are disabled for this album." }, 403);
    }

    const { data: album, error: albumError } = await adminSupabase
      .from("albums")
      .select("id, slug, title, guest_access_code_enabled, visibility")
      .eq("id", albumId)
      .single();
    if (albumError) throw albumError;

    const codeProtected = album.guest_access_code_enabled === true ||
      (album.visibility?.toString() ?? "") === "code_protected";

    if (codeProtected) {
      if (!guestCode || guestCode.trim().length < 4) {
        return json({ error: "Access code required." }, 401);
      }

      const ok = await adminSupabase.rpc("verify_guest_access_code", {
        album_uuid: albumId,
        code: guestCode.trim(),
      });

      if (ok.error) throw ok.error;
      if (ok.data !== true) {
        return json({ error: "Incorrect access code." }, 401);
      }
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + 1000 * 60 * 60 * 24); // 24h

    const { data: exportRow, error: exportError } = await adminSupabase
      .from("download_exports")
      .insert({
        album_id: albumId,
        user_id: null,
        status: "pending",
        requested_at: now.toISOString(),
        expires_at: expiresAt.toISOString(),
      })
      .select("id")
      .single();
    if (exportError) throw exportError;

    const exportId = exportRow.id as string;

    try {
      const { data: mediaRows, error: mediaError } = await adminSupabase
        .from("media_uploads")
        .select(
          "id, type, file_url, original_file_name, file_extension, file_size_bytes, created_at, status, is_hidden",
        )
        .eq("album_id", albumId)
        .in("type", ["photo", "video"])
        .eq("status", "approved")
        .eq("is_hidden", false)
        .order("created_at", { ascending: true });
      if (mediaError) throw mediaError;

      const items = (mediaRows ?? []) as Array<Record<string, unknown>>;

      if (items.length === 0) {
        return json({ error: "No photos or videos found to export." }, 400);
      }

      if (items.length > MAX_FILES) {
        return json(
          { error: `Too many files to export (${items.length}).` },
          413,
        );
      }

      const totalBytes = items.reduce((sum, item) => {
        const n = Number(item.file_size_bytes ?? 0);
        return sum + (Number.isFinite(n) ? n : 0);
      }, 0);

      if (totalBytes > MAX_TOTAL_BYTES) {
        return json(
          { error: "Album is too large to export as a single ZIP." },
          413,
        );
      }

      const zip = new JSZip();

      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const id = item.id?.toString() ?? `${i}`;
        const type = item.type?.toString() ?? "file";
        const fileUrl = item.file_url?.toString();
        if (!fileUrl) continue;

        const createdAt = item.created_at?.toString() ?? "";
        const ts = createdAt ? createdAt.replace(/[:.]/g, "-") : `${i}`;

        const ext = sanitizeExt(
          item.file_extension?.toString() ?? guessExtFromUrl(fileUrl),
        );

        const baseName = sanitizeFileName(
          item.original_file_name?.toString() ?? `${type}_${id}.${ext}`,
        );

        const folder = type === "video" ? "videos" : "photos";
        const name = `${folder}/${String(i + 1).padStart(3, "0")}_${ts}_${baseName}`;

        const res = await fetch(fileUrl);
        if (!res.ok) {
          throw new Error(`Failed to fetch file ${id}`);
        }
        const bytes = new Uint8Array(await res.arrayBuffer());
        zip.file(name, bytes);
      }

      const zipBytes = await zip.generateAsync({ type: "uint8array" });
      const storagePath = `exports/${albumId}/${exportId}.zip`;

      const upload = await adminSupabase.storage
        .from(EXPORT_BUCKET)
        .upload(storagePath, zipBytes, {
          contentType: "application/zip",
          upsert: true,
        });

      if (upload.error) throw upload.error;

      const publicUrl = adminSupabase.storage
        .from(EXPORT_BUCKET)
        .getPublicUrl(storagePath).data.publicUrl;

      await adminSupabase.from("download_exports").update({
        zip_url: publicUrl,
        storage_path: storagePath,
        status: "completed",
        completed_at: new Date().toISOString(),
        file_size_bytes: zipBytes.byteLength,
        total_files: items.length,
        updated_at: new Date().toISOString(),
      }).eq("id", exportId);

      return json({ status: "completed", export_id: exportId, url: publicUrl }, 200);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      await adminSupabase.from("download_exports").update({
        status: "failed",
        processing_error: message,
        updated_at: new Date().toISOString(),
      }).eq("id", exportId);
      throw error;
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message || "Unexpected error" }, 500);
  }
});

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function sanitizeFileName(value: string) {
  const v = (value ?? "").trim();
  const cleaned = v.replace(/[^\w.\-() ]+/g, "_");
  return cleaned.length > 0 ? cleaned : "file";
}

function sanitizeExt(value: string) {
  const v = (value ?? "").trim().toLowerCase().replace(/^\./, "");
  if (!v) return "bin";
  if (v.length > 10) return "bin";
  return v.replace(/[^a-z0-9]+/g, "");
}

function guessExtFromUrl(url: string) {
  const m = url.toLowerCase().match(/\.([a-z0-9]{2,6})(\?|$)/);
  return m?.[1] ?? "";
}

