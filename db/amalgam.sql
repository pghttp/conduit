create extension if not exists unaccent;

create schema if not exists acl authorization "t_db_conduit.pghttp.app_db_owner";
create schema if not exists conduit authorization "t_db_conduit.pghttp.app_db_owner";
create schema if not exists conduit_public authorization "t_db_conduit.pghttp.app_db_owner";
create schema if not exists paging authorization "t_db_conduit.pghttp.app_db_owner";

grant usage on schema acl to "t_db_conduit.pghttp.app_db_access";
grant usage on schema conduit to "t_db_conduit.pghttp.app_db_access";
grant usage on schema paging to "t_db_conduit.pghttp.app_db_access";
grant usage on schema conduit_public to "t_db_conduit.pghttp.app_db_access";
grant usage on schema conduit_public to "t_db_conduit.pghttp.app_db_public";

grant execute on all functions in schema conduit_public to "t_db_conduit.pghttp.app_db_public";
-- From https://www.kdobson.net/2019/ultimate-postgresql-slug-function/
-- We're removing ~ as well since we use that to number duplicate slugs.
-- Removing it before renumbering avoids weird cases like 'name~1~2~3~'
-- Sadly it also removes '~name' but we can live without that.
create or replace function public.slugify("value" text)
returns text
language sql strict immutable
return (
  -- removes accents (diacritic signs) from a given string --
  with "unaccented" as (
    select unaccent("value") as "value"
  ),
  -- lowercases the string
  "lowercase" as (
    select lower("value") as "value"
    from "unaccented"
  ),
  -- remove single and double quotes
  "removed_quotes" as (
    select regexp_replace("value", '[''"]+', '', 'gi') as "value"
    from "lowercase"
  ),
  -- replaces anything that's not a letter, number, hyphen('-'), underscore('_'), or reserved/unwise IRI character with a hyphen('-')
  -- reserved    = ";" | "/" | "?" | ":" | "@" | "&" | "=" | "+" | "$" | ","
  -- unwise      = "{" | "}" | "|" | "\" | "^" | "[" | "]" | "`"
  --
  -- We're also removing a ~ (since it is part of our slug numbering) and '(' and ')' since they look ugly in slugs.
  "hyphenated" as (
    select regexp_replace("value", '[-\s;/?:@&=+$,\{\}\|\\^\[\]()`%#\<\>_~]+', '-', 'gi') as "value"
    from "removed_quotes"
  ),
  -- trims hyphens('-') if they exist on the head or tail of the string
  "trimmed" as (
    select regexp_replace(regexp_replace("value", '\-+$', ''), '^\-', '') as "value"
    from "hyphenated"
  )
  select "value" from "trimmed");

alter function public.slugify owner to "t_db_conduit.pghttp.app_db_owner";
create or replace function acl.active_user()
returns int
language sql stable leakproof
return
(select
   case when id ~ E'^[[:xdigit:]]$' then id::int
        else null::int
    end
   from current_setting('conduit.user', true) cs(id));

alter function acl.active_user() owner to "t_db_conduit.pghttp.app_db_owner";


create or replace function paging.offset(p_page int, p_page_size int)
returns int
language sql strict immutable
return
    (p_page - 1) * p_page_size;
    
alter function paging.offset owner to "t_db_conduit.pghttp.app_db_owner";

-- row_number() returns bigint, which cannot be automatically cast to int
create or replace function paging.page_no(p_row bigint, p_page_size int)
returns int
language sql strict immutable
return 
    ceiling(p_row::float/p_page_size)::int;

alter function paging.page_no owner to "t_db_conduit.pghttp.app_db_owner";


create or replace function paging.safe_page(p_nat int, p_default int)
returns int as
$$
begin
if p_default is null or p_default < 1 then
    raise  'Default must be non-null and larger than 0';
end if;
return case
         when coalesce(p_nat, p_default) < 1 then p_default
         else coalesce(p_nat, p_default)
       end;
end;
$$ language plpgsql stable;

alter function paging.safe_page owner to "t_db_conduit.pghttp.app_db_owner";
create type conduit.author_profile as (
    username text,
    image_url text,
    bio text,
    followed_by int
);

alter type conduit.author_profile owner to "t_db_conduit.pghttp.app_db_owner";


create table if not exists conduit.user (
    id          integer not null generated always as identity primary key,
    username    text not null unique,
    email       text unique,                -- don't want to collect emails
    password    text not null,
    bio         text,
    image       text,
    created_at  timestamp not null default now(),
    updated_at  timestamp
);

alter table conduit.user owner to "t_db_conduit.pghttp.app_db_owner";


create table if not exists conduit.article (
    id          integer not null generated always as identity primary key,
    title       text not null,
    slug        text generated always as (slugify(title)) stored unique,
    abstract    text not null,
    body        text,
    user_id     integer not null references conduit.user(id) on delete cascade,
    created_at  timestamp not null default now(),
    updated_at  timestamp not null default now()
);

alter table conduit.article owner to "t_db_conduit.pghttp.app_db_owner";


create table if not exists conduit.favorite (
    id          integer not null generated always as identity primary key,
    article_id  integer not null references conduit.article(id) on delete cascade,
    user_id     integer not null references conduit.user(id) on delete cascade,
    constraint unique_favorite unique(article_id, user_id)    
);

alter table conduit.favorite owner to "t_db_conduit.pghttp.app_db_owner";


create table if not exists conduit.follow (
    id          integer not null generated always as identity primary key,
    user_id     integer not null references conduit.user(id) on delete cascade,
    following   integer not null references conduit.user(id) on delete cascade,
    constraint unique_follow unique(user_id, following),
    check (user_id <> following)
);

alter table conduit.follow owner to "t_db_conduit.pghttp.app_db_owner";


create table if not exists conduit.tag(
    id          integer not null generated always as identity primary key,
    tag         text not null unique
);

alter table conduit.tag owner to "t_db_conduit.pghttp.app_db_owner";


create table if not exists conduit.article_tag(
    article_id integer not null references conduit.article(id) on delete cascade,
    tag_id      integer not null references conduit.tag(id) on delete cascade,
    constraint unique_article_tag unique (article_id, tag_id)
);

alter table conduit.article_tag owner to "t_db_conduit.pghttp.app_db_owner";


create table if not exists conduit.comment (
    id          integer not null generated always as identity primary key,
    body        text not null,
    article_id  integer not null references conduit.article(id) on delete cascade,
    user_id     integer not null references conduit.user(id) on delete cascade,
    created_at  timestamp not null default now(),
    updated_at  timestamp not null default now()
);

alter table conduit.comment owner to "t_db_conduit.pghttp.app_db_owner";



create or replace function conduit_public.articles_by_time()
returns table (
    slug            text,
    title           text,
    abstract        text,
    tags            text[],
    updated_at      timestamp,
    favorites_count int,
    author          record
    )
language sql stable leakproof security definer
begin atomic
 select a.slug,
     a.title,
     a.abstract,
     (select array_agg(t.tag) as array_agg
            from (conduit.article_tag at
              join conduit.tag t on t.id = at.tag_id)
           where (at.article_id = a.id)) as tags,
     a.updated_at,
     0 as favorites_count,
     row(u.username, u.image) as author
    from conduit.article a
      join conduit.user u on u.id = a.user_id
   order by a.updated_at desc, a.id asc;
end;

alter function conduit_public.articles_by_time() owner to "t_db_conduit.pghttp.app_db_owner";


create or replace function conduit_public.articles_by_time_paged(p_page int, p_page_size int)
returns table (
    slug            text,
    title           text,
    abstract        text,
    tags            text[],
    updated_at      timestamp,
    favorites_count int,
    author          record
    )
language sql stable leakproof security definer
begin atomic
    select slug
         , title
         , abstract
         , tags
         , updated_at
         , favorites_count
         , author
      from conduit_public.articles_by_time() with ordinality
     where ordinality > paging.offset(p_page, p_page_size)
     order by ordinality
     limit p_page_size;
end;

alter function conduit_public.articles_by_time_paged(int, int) owner to "t_db_conduit.pghttp.app_db_owner";


create or replace function conduit_public.articles_by_time_paging_info(p_page_size int)
returns table (item_count int, page_size int, page_count int)
language sql stable leakproof
begin atomic
select count(*)::int item_count
     , p_page_size
     , ceiling(count(*)::float/p_page_size)::int as page_count
  from conduit_public.articles_by_time();
end;

alter function conduit_public.articles_by_time_paging_info(int) owner to "t_db_conduit.pghttp.app_db_owner";

--======

create or replace function conduit_public.articles_by_tags_all(p_tags text[])
returns table (
    slug            text,
    title           text,
    abstract        text,
    tags            text[],
    updated_at      timestamp,
    favorites_count int,
    author          record
    )
language sql stable leakproof security definer
begin atomic
with tagged(id, tags) as (
    select a.id, array_agg(t.tag) 
      from conduit.article a
         , conduit.tag t
         , conduit.article_tag at
     where a.id = at.article_id 
       and at.tag_id = t.id
     group by a.id
    )
    select a.slug,
           a.title,
           a.abstract,
           t.tags,
           a.updated_at,
           0 as favorites_count,
           row(u.username, u.image) as author
      from conduit.article a
      join conduit.user u on u.id = a.user_id
      join tagged t on t.id = a.id
     where t.tags @> p_tags
      order by a.updated_at desc, a.id asc;
end;

alter function conduit_public.articles_by_tags_all(text[]) owner to "t_db_conduit.pghttp.app_db_owner";

--@api 6:"^O.Y!4>8.f%YYdv3"
create or replace function conduit_public.articles_by_tags_all_paged(p_tags text[], p_page int, p_page_size int)
returns table (
    slug            text,
    title           text,
    abstract        text,
    tags            text[],
    updated_at      timestamp,
    favorites_count int,
    author          record
    )
language sql stable leakproof security definer
begin atomic
    select slug
         , title
         , abstract
         , tags
         , updated_at
         , favorites_count
         , author
      from conduit_public.articles_by_tags_all(p_tags) with ordinality
     where ordinality > paging.offset(p_page, p_page_size)
     order by ordinality
     limit p_page_size;
end;

alter function conduit_public.articles_by_tags_all_paged(text[], int, int) owner to "t_db_conduit.pghttp.app_db_owner";

--@api 6:"[@o-za2On$ &ZH3L"
create or replace function conduit_public.articles_by_tags_all_paging_info(p_tags text[], p_page_size int)
returns table (item_count int, page_size int, page_count int)
language sql stable leakproof
begin atomic
select count(*)::int item_count
     , p_page_size
     , ceiling(count(*)::float/p_page_size)::int as page_count
  from conduit_public.articles_by_tags_all(p_tags);
end;

alter function conduit_public.articles_by_tags_all_paging_info(text[], int) owner to "t_db_conduit.pghttp.app_db_owner";




--======

create or replace function conduit_public.articles_by_author(p_author text)
returns table (
    slug            text,
    title           text,
    abstract        text,
    tags            text[],
    updated_at      timestamp,
    favorites_count int,
    author          record
    )
language sql stable leakproof security definer
begin atomic
 select a.slug,
     a.title,
     a.abstract,
     (select array_agg(t.tag) as array_agg
            from (conduit.article_tag at
              join conduit.tag t on t.id = at.tag_id)
           where (at.article_id = a.id)) as tags,
     a.updated_at,
     0 as favorites_count,
     row(u.username, u.image) as author
    from conduit.article a
      join conduit.user u on u.id = a.user_id and u.username = p_author
   order by a.updated_at desc, a.id asc;
end;

alter function conduit_public.articles_by_author(text) owner to "t_db_conduit.pghttp.app_db_owner";


--@api 6:"nth?n?aPrmBR&)<j"
create or replace function conduit_public.articles_by_author_paged(p_author text, p_page int, p_page_size int)
returns table (
    slug            text,
    title           text,
    abstract        text,
    tags            text[],
    updated_at      timestamp,
    favorites_count int,
    author          record
    )
language sql stable leakproof security definer
begin atomic
    select slug
         , title
         , abstract
         , tags
         , updated_at
         , favorites_count
         , author
      from conduit_public.articles_by_author(p_author) with ordinality
     where ordinality > paging.offset(p_page, p_page_size)
     order by ordinality
     limit p_page_size;
end;

alter function conduit_public.articles_by_author_paged(text, int, int) owner to "t_db_conduit.pghttp.app_db_owner";


--@api 6:"$$gpk-UZE]C`)z=8"
create or replace function conduit_public.articles_by_author_paging_info(p_author text, p_page_size int)
returns table (item_count int, page_size int, page_count int)
language sql stable leakproof
begin atomic
select count(*)::int item_count
     , p_page_size
     , ceiling(count(*)::float/p_page_size)::int as page_count
  from conduit_public.articles_by_author(p_author);
end;

alter function conduit_public.articles_by_author_paging_info(text, int) owner to "t_db_conduit.pghttp.app_db_owner";

--======

--@api 6:"_S%MPr`>Y`iv[[zq"
create or replace function conduit_public.tags()
returns table (tag text, article_count int)
language sql stable leakproof security definer
begin atomic
   select tag
        , count(*)::int 
     from conduit.tag join conduit.article_tag on id = tag_id
 group by tag
   having count(*) > 0
 order by tag;
end;

alter function conduit_public.tags() owner to "t_db_conduit.pghttp.app_db_owner";

--======

--@api 6:"@z=CFZkkDZdvWPwr"
create or replace function conduit_public.article_by_slug(p_slug text)
returns table(
    slug text,
    title text,
    abstract text,
    body text,
    tags text[],
    updated_at timestamp,
    favorites_count int,
    author_profile conduit.author_profile
)
language sql stable security definer
begin atomic
  select a.slug
       , a.title
       , a.abstract
       , a.body
       ,(select array_agg(t.tag) as array_agg
           from conduit.article_tag at
           join conduit.tag t on t.id = at.tag_id
          where at.article_id = a.id) as tags
       , a.updated_at
       , (select count(*)::int from conduit.favorite f where f.article_id = a.id) as favorites_count
       , ( u.username
         , u.image
         , u.bio
         , (select count(*)::int from conduit.follow where user_id = a.user_id)
         )::conduit.author_profile as author
    from conduit.article a
    join conduit.user u on u.id = a.user_id
   where slug = p_slug;
end;

alter function conduit_public.article_by_slug(text) owner to "t_db_conduit.pghttp.app_db_owner";

insert into conduit.user(username, password)
values('dsimunic', 'plaintextpassword');

insert into conduit.article(user_id, title, abstract, body)
values(1, 'On Defaults', 'Defaults drive programming cultures', $$
It occurs to me that we always used the defaults we had within reach to convert from requests the browser knows how to send into requests the db server requires: from unixy text lines, to XML that Java and .NET proselytize, to JSON only because the parser was built into both the browser and Node. Server side, we went from inetd/CGI/Perl, then FCGI and ruby/php or WSGI/python; we developed full web servers in scripting languages to get rid of FCGI, then required a reverse proxy (nginx, haproxy, …) hops to make up for their slowness. Ditto for “cloud functions” and microservices. But we were always stuck accommodating the default parsers to feed the beast of the backend that increasingly did nothing more than forward database queries/replies.

Elm comes with elegant binary encoding/decoding in the standard library. It’s a textbook definition of visionary to create a nice default—before it has obvious applications—that elegantly nudges users towards new solutions.
$$);
