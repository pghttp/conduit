# elm-pghttp Conduit

This minimal demo app approximates the complexity level of the "RealWorld" Conduit sample. 

As of now, the code only replicates the public part: list or articles by time, tags, or author, 
as well as the article rendering. The features behind login are yet not part of this demo, until the elm-pghttp 
codegen works as expected.

This is an end-to-end, "full stack" example: one is expected to control the data, the server, and the client code.
This makes it architecturally different from "RealWorld" examples that expect talking to a JSON API under someone
else's control. Consequently, some architectural decisions are different, as are decisions pertaining to performance.

The scope of the explanations and understanding is also different for a frontend-only developer: here we are concerned
with the whole end-to-end system, and while knowledge of database design and SQL is not necessary, it is a part
of the consideration of this way of working, and now having that knowledge might make it harder to evaluate and 
understand the differences and benefits of elm-pghttp. The tooling will alleviate these concerns, but at present
it is not ready.

## Structure

From Elm perspective, the app is absolutely minimal, `Main.elm` does the vanilla Elm navigation with messages, and has "pages" defined
in the same file as views. No attempt is made to optimize the model and make it exemplary functional code at this stage. At present, the 
app does not even implement url parsing as it is not needed to demonstrate elm-pghttp.

There are three main sections of the project:

### `src/db/`

This folder contains all code-generated elm-pghttp code and is the main area of interest. (Note this is written by hand
as I'm still to pull the tooling and codegen from the existing prod code; but codegen will produce the similar code). Nothing
in this folder should be hand-coded. Ideally, for larger apps (those living and evolving over multi-year spans) one 
might even publish this as a module to add versioning and reduce programmers' cognitive load.

Getting into the code in this folder, some interesting points are:  

(a) Comparison to JSON parsing: parsers are positional; db column names are irrelevant and can change in the database. This is not 
a problem as the code is generated, and APIs normally never change once in production. (We have append-only policy for modified APIs and
depreciation for those no longer to be used: a deprecated api is deployed on the proxy, but no code is generated in the client library).

(b) postgres comoposite type parsing (cf `src/Db/Types.elm:articleDecoder`, and `authorProfileColumnDecoder` that corresponds to the 
postgres type in `db/conduit/ddl/conduit/05_types.sql` ). 

(c) Encoding array parameters: `articlesByTagsAll` encodes tag names as a postgres array and passes the binary-encoded packet 
directly to the postgres function that expects that array (`conduit_public.articles_by_tags_all`). Compare to using a classic 
text-protocol-based database driver, where one would go through serious contortions to encode an array parameter.

### `src/Postgres` 

Contains encoder/decoder code that will normally be part of the elm-pghttp package. This demo app includes it in the source to
help ease of understanding.

Note that most of this code was written six or so years ago. Some of the things could probably be simplified. It also
contains traces of exposed postgres error messages: at some point in the past we published detailed error messages, but
those contain too much information and are a security concern. Newer versions of the proxy do not pass the detailed errors
to the client, so this code might be somewhat simplified further. Please propose improvements.

Also note that not all decoders are binary--postgres protocol has the escape hatch of letting us select individual columns
as text-rendered, so we get back text as formatted by postgres instead of binary representation. (See how we return `updated_at` as
iso-formatted text string instead of binary timestamp). This is production code, and we probably didn't need all the other types as binary
so we never implemented them. But we'll certainly add those as part of this open source release.

### `Main.elm` 

This is the usual Elm code. The only elm-pghttp related calls are those starting with `Db.` and those are as any other when
working with http. In the final state, these will also be the only calls a frontend developer will be concerned with: the contents
of the `Postgres` folder will be in the package, and `src/Db` folder will be somehow hidden to reduce the cognitive overhead, or
at least marked as auto-generated (when code editing tools allow for such actions).

## Running

To run this, one needs:

1. The database (run with `./resetdb` to set it up, unless you have your own flow). 
2. pg-proxy: the Nginx module that frames pg protocol with http
3. Published Api: functions exposed from the database, from which elm-pghttp generates the `src/db` code.
3. Elm code in this repo.

pg-proxy is hosted in another repository in the pghttp organization. Consult the readme for installation and setup. This
is the part that needs to be set up only once per server or dev environment and can serve multiple databases. One will just
publish api files (3) to it.

The Api file is produced by tooling. This tooling is also hosted in its own repository under pghttp organization.

## API and Authentication

One application can support multiple APIs: in this demo, only the public api is generated (that is, calls that do
not require authentication). Arbitrarily, the endpoint on nginx side is called `_pq`, and the protected api is mounted
on `_q` location. These are encoded in `Db.Public.Endpoint.public` and `.user`.

These are "production APIs," those letting only predefined queries through. In addition, pghttp can also expose development API allowing
one to issue usual text or binay ad-hoc queries, and a DBA-API that allows one to connect with a Database owner password. These
should never be exposed on a production server. The tooling examples demonstrate the uses of these other API types. pg-proxy repository
goes into more detail about those.

The application assumes cookie authentication--this makes more sense than using something like JWT, since we're controlling
both ends of the communication, and there's no need to burden the programmer with handling the token. The browser takes care
of the cookies, and the web server knows what to do. That's not to say that once cannot implement any other auth method--that's down 
to chosen HTTP architecture and has nothing to do with elm-pghttp. That's one advantage of this method compared to similar inventions
like postgrest: HTTP concerns are isolated to HTTP and work as usual (including compression, content negotiaton, load balancing, etc),
while elm-pghttp deals with database concerns (and HTTP doesn't care about those at all).

Note that present demo code does not use any authentication--the parts hidden behind the login are not yet implemented. But when it happens,
it will use cookies.

## DB Design

The database design is arbitrary. The style used is a personal preference and is not inherent to pghttp. The api functionality is exposed
through functions--this is again a developer preference as it somewhat simplifies reasoning about the application and testing. The paging
code and the way paging information is obtained is also purely a stylistic choice. One could do that in different ways without having any
impact on pghttp.

We've separated the public and protected schema, as we want to emphasize the peformance concerns, which are different when exposing the database
to the public as opposed to named, authenticated users. (Frankly, I'd never expose the database content like this direclty to the public, but 
this is the demo, and the DoS concerns are out of scope). 

For example, the public listing of articles does not check for 'followed' flag, since obviously we can't identify the user. Another example is paging 
as a separate function, as there's no need to aimlessly count in every request for a page of 
articles or tags. (RealWorld API samples return the count on every request for a page of articles; likely because their API requests are expected to
be slow, or it is harder to request two pieces of data than parse a complex object). Considering the frequency of updates of a typical content site, 
one assumes that listing/reading will be 100x more frequent than the number of articles changing. 

There are other minor details, but none of these make a difference in such a small example; the goal is to hint at the fact 
that pghttp allows having multiple APIs that are separated along the lines of performance and security concerns, among others.

Despite having a public and non-public schema in the database, the mapping to pghttp APIs is not driven by schemas. One can expose functions and queries
from different schemas into an API. What is important that each API connects with relevant security privileges (as determined by roles `_db_owner`, `_db_access`, `_db_public`) to avoid security issues.