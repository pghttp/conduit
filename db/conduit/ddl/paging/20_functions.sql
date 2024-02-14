create or replace function paging.offset(p_page int, p_page_size int)
returns int
language sql strict immutable
return
    (p_page - 1) * p_page_size;
    
alter function paging.offset owner to :owner_role;

-- row_number() returns bigint, which cannot be automatically cast to int
create or replace function paging.page_no(p_row bigint, p_page_size int)
returns int
language sql strict immutable
return 
    ceiling(p_row::float/p_page_size)::int;

alter function paging.page_no owner to :owner_role;


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

alter function paging.safe_page owner to :owner_role;