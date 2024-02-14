create extension if not exists unaccent;

create schema if not exists acl authorization :owner_role;
create schema if not exists conduit authorization :owner_role;
create schema if not exists conduit_public authorization :owner_role;
create schema if not exists paging authorization :owner_role;

grant usage on schema acl to :access_role;
grant usage on schema conduit to :access_role;
grant usage on schema paging to :access_role;
grant usage on schema conduit_public to :access_role;
grant usage on schema conduit_public to :public_role;

grant execute on all functions in schema conduit_public to :public_role;