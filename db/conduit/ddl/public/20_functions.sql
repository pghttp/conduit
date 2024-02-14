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

alter function public.slugify owner to :owner_role;