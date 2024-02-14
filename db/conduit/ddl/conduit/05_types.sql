create type conduit.author_profile as (
    username text,
    image_url text,
    bio text,
    followed_by int
);

alter type conduit.author_profile owner to :owner_role;

