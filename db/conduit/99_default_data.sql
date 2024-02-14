insert into conduit.user(username, password)
values('dsimunic', 'plaintextpassword');

insert into conduit.article(user_id, title, abstract, body)
values(1, 'On Defaults', 'Defaults drive programming cultures', $$
It occurs to me that we always used the defaults we had within reach to convert from requests the browser knows how to send into requests the db server requires: from unixy text lines, to XML that Java and .NET proselytize, to JSON only because the parser was built into both the browser and Node. Server side, we went from inetd/CGI/Perl, then FCGI and ruby/php or WSGI/python; we developed full web servers in scripting languages to get rid of FCGI, then required a reverse proxy (nginx, haproxy, …) hops to make up for their slowness. Ditto for “cloud functions” and microservices. But we were always stuck accommodating the default parsers to feed the beast of the backend that increasingly did nothing more than forward database queries/replies.

Elm comes with elegant binary encoding/decoding in the standard library. It’s a textbook definition of visionary to create a nice default—before it has obvious applications—that elegantly nudges users towards new solutions.
$$);
