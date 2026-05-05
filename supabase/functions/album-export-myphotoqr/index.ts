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

    // If the request is authenticated and the user owns the album, allow export
    // even when guest downloads are disabled (admin export).
    const authHeader = req.headers.get("authorization") ??
      req.headers.get("Authorization") ?? "";
    const bearerToken = authHeader.toLowerCase().startsWith("bearer ")
      ? authHeader.slice(7).trim()
      : null;

    let requestUserId: string | null = null;
    if (bearerToken && bearerToken.length > 20) {
      try {
        // With service-role key, we can validate a user JWT.
        const { data } = await adminSupabase.auth.getUser(bearerToken);
        requestUserId = data?.user?.id ?? null;
      } catch (_) {
        requestUserId = null;
      }
    }

    const { data: albumSettings, error: settingsError } = await adminSupabase
      .from("album_settings")
      .select("allow_guest_downloads")
      .eq("album_id", albumId)
      .maybeSingle();
    if (settingsError) throw settingsError;

    const { data: album, error: albumError } = await adminSupabase
      .from("albums")
      .select(
        "id, slug, title, guest_access_code_enabled, visibility, user_id, cover_image_url, banner_image_url",
      )
      .eq("id", albumId)
      .single();
    if (albumError) throw albumError;

    const isOwner = requestUserId != null && album.user_id === requestUserId;

    if (!albumSettings?.allow_guest_downloads && !isOwner) {
      return json({ error: "Downloads are disabled for this album." }, 403);
    }

    const codeProtected = album.guest_access_code_enabled === true ||
      (album.visibility?.toString() ?? "") === "code_protected";

    if (codeProtected && !isOwner) {
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
      let mediaQuery = adminSupabase
        .from("media_uploads")
        .select(
          "id, type, file_url, original_file_name, file_extension, file_size_bytes, created_at, status, is_hidden",
        )
        .eq("album_id", albumId)
        .in("type", ["photo", "video", "audio"])
        .eq("is_hidden", false)
        .order("created_at", { ascending: true });
      if (!isOwner) mediaQuery = mediaQuery.eq("status", "approved");

      const { data: mediaRows, error: mediaError } = await mediaQuery;
      if (mediaError) throw mediaError;

      const mediaItems = (mediaRows ?? []) as Array<Record<string, unknown>>;

      let noteItems: Array<Record<string, unknown>> = [];
      let notesQuery = adminSupabase
        .from("notes")
        .select("id, message, created_at, status, is_hidden")
        .eq("album_id", albumId)
        .eq("is_hidden", false)
        .order("created_at", { ascending: true });
      if (!isOwner) notesQuery = notesQuery.eq("status", "approved");
      const { data: notesRows, error: notesError } = await notesQuery;
      if (notesError) throw notesError;
      noteItems = (notesRows ?? []) as Array<Record<string, unknown>>;

      const totalItems = mediaItems.length + noteItems.length;

      if (totalItems === 0) {
        return json({ error: "No content found to export." }, 400);
      }

      if (totalItems > MAX_FILES) {
        return json(
          { error: `Too many files to export (${totalItems}).` },
          413,
        );
      }

      const totalBytes = mediaItems.reduce((sum, item) => {
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

      let index = 0;

      const coverUrl = album.cover_image_url?.toString();
      if (coverUrl && coverUrl.trim().length > 0) {
        const ext = sanitizeExt(guessExtFromUrl(coverUrl) || "jpg");
        const res = await fetch(coverUrl);
        if (res.ok) {
          const bytes = new Uint8Array(await res.arrayBuffer());
          zip.file(`branding/cover.${ext}`, bytes);
          index++;
        }
      }

      const bannerUrl = album.banner_image_url?.toString();
      if (bannerUrl && bannerUrl.trim().length > 0) {
        const ext = sanitizeExt(guessExtFromUrl(bannerUrl) || "jpg");
        const res = await fetch(bannerUrl);
        if (res.ok) {
          const bytes = new Uint8Array(await res.arrayBuffer());
          zip.file(`branding/banner.${ext}`, bytes);
          index++;
        }
      }

      for (let i = 0; i < mediaItems.length; i++) {
        const item = mediaItems[i];
        const id = item.id?.toString() ?? `${i}`;
        const type = item.type?.toString() ?? "file";
        const fileUrl = item.file_url?.toString();
        if (!fileUrl) continue;

        const createdAt = item.created_at?.toString() ?? "";
        const ts = createdAt ? createdAt.replace(/[:.]/g, "-") : `${i}`;
        const status = (item.status?.toString() ?? "").trim().toLowerCase();
        const statusTag = status && status !== "approved" ? `_${status}` : "";

        const ext = sanitizeExt(
          item.file_extension?.toString() ?? guessExtFromUrl(fileUrl),
        );

        const baseName = sanitizeFileName(
          item.original_file_name?.toString() ?? `${type}_${id}.${ext}`,
        );

        const folder = type === "video"
          ? "videos"
          : type === "audio"
          ? "audios"
          : "photos";
        const name =
          `${folder}/${String(index + 1).padStart(3, "0")}_${ts}${statusTag}_${baseName}`;

        const res = await fetch(fileUrl);
        if (!res.ok) {
          throw new Error(`Failed to fetch file ${id}`);
        }
        const bytes = new Uint8Array(await res.arrayBuffer());
        zip.file(name, bytes);
        index++;
      }

      for (let i = 0; i < noteItems.length; i++) {
        const note = noteItems[i];
        const id = note.id?.toString() ?? `${i}`;
        const createdAt = note.created_at?.toString() ?? "";
        const ts = createdAt ? createdAt.replace(/[:.]/g, "-") : `${i}`;
        const status = (note.status?.toString() ?? "").trim().toLowerCase();
        const statusTag = status && status !== "approved" ? `_${status}` : "";
        const message = note.message?.toString() ?? "";
        const baseName = sanitizeFileName(`note_${id}.txt`);
        const name =
          `notes/${String(index + 1).padStart(3, "0")}_${ts}${statusTag}_${baseName}`;

        const body = [
          `Album: ${album.title ?? album.slug ?? albumId}`,
          `Created at: ${createdAt}`,
          `Status: ${status || "approved"}`,
          "",
          message,
        ].join("\n");

        zip.file(name, body);
        index++;
      }

      const totalFiles = index;
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
        total_files: totalFiles,
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
