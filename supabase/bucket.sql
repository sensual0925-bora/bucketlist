-- ============================================================
-- 우리들의 버킷리스트: Supabase 저장소
-- 로그인 없이 링크를 아는 사람은 누구나 보고 쓸 수 있습니다.
-- 대신 진짜 삭제는 막고, 지운 항목은 휴지통(deleted_at)에 남겨서 되살릴 수 있게 합니다.
-- 여러 번 실행해도 안전합니다.
-- ============================================================

-- 1) 버킷 항목
create table if not exists public.bucket_items (
  id          bigint      generated always as identity primary key,
  title       text        not null check (char_length(title) between 1 and 100),
  note        text        check (char_length(note) <= 1000),
  author      text        not null check (char_length(author) between 1 and 20),
  done        boolean     not null default false,
  done_at     date,                                     -- 달성한 날
  done_note   text        check (char_length(done_note) <= 1000),  -- 달성 후기
  photo_path  text        check (char_length(photo_path) <= 300),  -- 인증 사진 (Storage bucket-photos 안의 경로)
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz,                              -- 값이 있으면 휴지통
  deleted_by  text        check (char_length(deleted_by) <= 20)
);

-- 2) '나도 할래'
create table if not exists public.bucket_joins (
  item_id     bigint      not null references public.bucket_items (id) on delete cascade,
  name        text        not null check (char_length(name) between 1 and 20),
  created_at  timestamptz not null default now(),
  primary key (item_id, name)
);

-- 3) 댓글
create table if not exists public.bucket_comments (
  id          bigint      generated always as identity primary key,
  item_id     bigint      not null references public.bucket_items (id) on delete cascade,
  author      text        not null check (char_length(author) between 1 and 20),
  body        text        not null check (char_length(body) between 1 and 500),
  created_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists bucket_comments_item_idx on public.bucket_comments (item_id);

-- 4) 보안 규칙: 누구나 보기·쓰기, 진짜 삭제는 '나도 할래' 취소만 허용
alter table public.bucket_items    enable row level security;
alter table public.bucket_joins    enable row level security;
alter table public.bucket_comments enable row level security;

revoke all on public.bucket_items, public.bucket_joins, public.bucket_comments from anon, authenticated;

grant select, insert on public.bucket_items to anon, authenticated;
grant update (title, note, done, done_at, done_note, photo_path, deleted_at, deleted_by)
  on public.bucket_items to anon, authenticated;     -- 작성자·작성일은 못 바꿈

grant select, insert, delete on public.bucket_joins to anon, authenticated;

grant select, insert on public.bucket_comments to anon, authenticated;
grant update (deleted_at) on public.bucket_comments to anon, authenticated;

drop policy if exists "항목 보기"   on public.bucket_items;
drop policy if exists "항목 추가"   on public.bucket_items;
drop policy if exists "항목 수정"   on public.bucket_items;
create policy "항목 보기" on public.bucket_items for select to anon, authenticated using (true);
create policy "항목 추가" on public.bucket_items for insert to anon, authenticated with check (deleted_at is null);
create policy "항목 수정" on public.bucket_items for update to anon, authenticated using (true) with check (true);

drop policy if exists "함께하기 보기" on public.bucket_joins;
drop policy if exists "함께하기 추가" on public.bucket_joins;
drop policy if exists "함께하기 취소" on public.bucket_joins;
create policy "함께하기 보기" on public.bucket_joins for select to anon, authenticated using (true);
create policy "함께하기 추가" on public.bucket_joins for insert to anon, authenticated with check (true);
create policy "함께하기 취소" on public.bucket_joins for delete to anon, authenticated using (true);

drop policy if exists "댓글 보기" on public.bucket_comments;
drop policy if exists "댓글 쓰기" on public.bucket_comments;
drop policy if exists "댓글 지우기" on public.bucket_comments;
create policy "댓글 보기"   on public.bucket_comments for select to anon, authenticated using (true);
create policy "댓글 쓰기"   on public.bucket_comments for insert to anon, authenticated with check (deleted_at is null);
create policy "댓글 지우기" on public.bucket_comments for update to anon, authenticated using (true) with check (true);

-- 5) 인증 사진 저장소: 누구나 올리고 볼 수 있음 (5MB 이하 이미지만, 덮어쓰기·삭제 불가)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('bucket-photos', 'bucket-photos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "인증 사진 올리기" on storage.objects;
create policy "인증 사진 올리기" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'bucket-photos');

-- 6) 실시간 반영: 친구가 추가·체크·댓글을 달면 열려 있는 화면에 바로 보이게
do $$
declare t text;
begin
  foreach t in array array['bucket_items', 'bucket_joins', 'bucket_comments'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
-- 삭제 이벤트에 item_id 가 실려 오도록
alter table public.bucket_joins replica identity full;

-- 7) 일기장 꾸미기: 항목마다 이모티콘 스티커와 붙인 사진 (2026-10-02 추가)
alter table public.bucket_items add column if not exists emoji text check (char_length(emoji) <= 16);
alter table public.bucket_items add column if not exists cover_path text check (char_length(cover_path) <= 300);
grant update (emoji, cover_path) on public.bucket_items to anon, authenticated;
