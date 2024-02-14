create or replace function acl.active_user()
returns int
language sql stable leakproof
return
(select
   case when id ~ E'^[[:xdigit:]]$' then id::int
        else null::int
    end
   from current_setting('conduit.user', true) cs(id));

alter function acl.active_user() owner to :owner_role;

