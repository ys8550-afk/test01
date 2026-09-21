-- 게시판 테이블 (Supabase 대시보드 > SQL Editor 에서 실행하세요)
-- 여러 번 실행해도 안전합니다. 이미 실행한 적이 있어도 그대로 다시 실행하면 수정/댓글 기능이 추가됩니다.

-- ============ 게시글 ============
create table if not exists public.posts (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  author      text not null check (char_length(author) between 1 and 40),
  title       text not null check (char_length(title) between 1 and 100),
  content     text not null check (char_length(content) between 1 and 2000),
  created_at  timestamptz not null default now()
);

-- 글 수정 시각 (수정한 적 없으면 null)
alter table public.posts add column if not exists updated_at timestamptz;

create index if not exists posts_created_at_idx on public.posts (created_at desc, id desc);

alter table public.posts enable row level security;

-- 누구나 읽기
drop policy if exists "posts are public" on public.posts;
create policy "posts are public"
  on public.posts for select
  to anon, authenticated
  using (true);

-- 로그인한 사용자만 본인 명의로 작성
drop policy if exists "users insert own posts" on public.posts;
create policy "users insert own posts"
  on public.posts for insert
  to authenticated
  with check (auth.uid() = user_id);

-- 본인 글만 수정
drop policy if exists "users update own posts" on public.posts;
create policy "users update own posts"
  on public.posts for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 본인 글만 삭제
drop policy if exists "users delete own posts" on public.posts;
create policy "users delete own posts"
  on public.posts for delete
  to authenticated
  using (auth.uid() = user_id);

-- 수정 시 updated_at 자동 기록
create or replace function public.set_posts_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at
  before update on public.posts
  for each row execute function public.set_posts_updated_at();

-- ============ 댓글 ============
create table if not exists public.comments (
  id          bigint generated always as identity primary key,
  post_id     bigint not null references public.posts(id) on delete cascade,
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  author      text not null check (char_length(author) between 1 and 40),
  content     text not null check (char_length(content) between 1 and 500),
  created_at  timestamptz not null default now()
);

create index if not exists comments_post_idx on public.comments (post_id, created_at, id);

alter table public.comments enable row level security;

-- 누구나 읽기
drop policy if exists "comments are public" on public.comments;
create policy "comments are public"
  on public.comments for select
  to anon, authenticated
  using (true);

-- 로그인한 사용자만 본인 명의로 작성
drop policy if exists "users insert own comments" on public.comments;
create policy "users insert own comments"
  on public.comments for insert
  to authenticated
  with check (auth.uid() = user_id);

-- 본인 댓글만 삭제 (게시글이 삭제되면 댓글도 함께 삭제됩니다)
drop policy if exists "users delete own comments" on public.comments;
create policy "users delete own comments"
  on public.comments for delete
  to authenticated
  using (auth.uid() = user_id);
