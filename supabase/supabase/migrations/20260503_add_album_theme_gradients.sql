-- Adds support for solid/gradient theme colors on albums.
-- Keep existing `theme_color` and `theme_background_color` as solid fallbacks.

alter table public.albums
  add column if not exists theme_color_mode text not null default 'solid'
    check (theme_color_mode in ('solid', 'gradient')),
  add column if not exists theme_color_gradient jsonb,
  add column if not exists theme_background_mode text not null default 'solid'
    check (theme_background_mode in ('solid', 'gradient')),
  add column if not exists theme_background_gradient jsonb;

