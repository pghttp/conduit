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

alter function conduit_public.articles_by_time() owner to :owner_role;


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

alter function conduit_public.articles_by_time_paged(int, int) owner to :owner_role;


create or replace function conduit_public.articles_by_time_paging_info(p_page_size int)
returns table (item_count int, page_size int, page_count int)
language sql stable leakproof
begin atomic
select count(*)::int item_count
     , p_page_size
     , ceiling(count(*)::float/p_page_size)::int as page_count
  from conduit_public.articles_by_time();
end;

alter function conduit_public.articles_by_time_paging_info(int) owner to :owner_role;

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

alter function conduit_public.articles_by_tags_all(text[]) owner to :owner_role;

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

alter function conduit_public.articles_by_tags_all_paged(text[], int, int) owner to :owner_role;

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

alter function conduit_public.articles_by_tags_all_paging_info(text[], int) owner to :owner_role;




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

alter function conduit_public.articles_by_author(text) owner to :owner_role;


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

alter function conduit_public.articles_by_author_paged(text, int, int) owner to :owner_role;


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

alter function conduit_public.articles_by_author_paging_info(text, int) owner to :owner_role;

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

alter function conduit_public.tags() owner to :owner_role;

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

alter function conduit_public.article_by_slug(text) owner to :owner_role;
