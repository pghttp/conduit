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

alter table conduit.user owner to :owner_role;


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

alter table conduit.article owner to :owner_role;


create table if not exists conduit.favorite (
    id          integer not null generated always as identity primary key,
    article_id  integer not null references conduit.article(id) on delete cascade,
    user_id     integer not null references conduit.user(id) on delete cascade,
    constraint unique_favorite unique(article_id, user_id)    
);

alter table conduit.favorite owner to :owner_role;


create table if not exists conduit.follow (
    id          integer not null generated always as identity primary key,
    user_id     integer not null references conduit.user(id) on delete cascade,
    following   integer not null references conduit.user(id) on delete cascade,
    constraint unique_follow unique(user_id, following),
    check (user_id <> following)
);

alter table conduit.follow owner to :owner_role;


create table if not exists conduit.tag(
    id          integer not null generated always as identity primary key,
    tag         text not null unique
);

alter table conduit.tag owner to :owner_role;


create table if not exists conduit.article_tag(
    article_id integer not null references conduit.article(id) on delete cascade,
    tag_id      integer not null references conduit.tag(id) on delete cascade,
    constraint unique_article_tag unique (article_id, tag_id)
);

alter table conduit.article_tag owner to :owner_role;


create table if not exists conduit.comment (
    id          integer not null generated always as identity primary key,
    body        text not null,
    article_id  integer not null references conduit.article(id) on delete cascade,
    user_id     integer not null references conduit.user(id) on delete cascade,
    created_at  timestamp not null default now(),
    updated_at  timestamp not null default now()
);

alter table conduit.comment owner to :owner_role;


