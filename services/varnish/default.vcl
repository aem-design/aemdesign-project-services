vcl 4.1;

# Stands in for Adobe's managed CDN on the local stack.
#
# Adobe's CDN for AEMaaCS is Fastly, and Fastly's ESI is VCL ESI - which is
# Varnish ESI: the same engine, the same include/comment/remove subset, and the
# same refusal to process a gzipped body. So Varnish is the faithful local
# emulator, and it needs no application code.
#
# What this is NOT: it does not reproduce Adobe's 256-fragment ceiling, their
# purge API, or their surrogate-key indexing. It answers one question - does the
# page we emit actually assemble - which is the one thing the local stack could
# not answer before.
#
# Topology:  traefik -> varnish -> dispatcher -> publish
# The dispatcher keeps its own hostname, unproxied, so a harness can see the
# same page both unassembled (dispatcher) and assembled (cdn) in one run.

backend dispatcher {
    .host = "dispatcher";
    .port = "80";
    .first_byte_timeout = 60s;
    .between_bytes_timeout = 60s;
}

sub vcl_recv {
    set req.backend_hint = dispatcher;

    # The dispatcher serves a different site per subdomain and routes on Host,
    # so the brand has to survive the hop: aemdesign.cdn.localhost must arrive
    # as aemdesign.dispatcher.localhost or its vhost will not match.
    #
    # These two literals must track CDN_HOST and DISPATCHER_HOST in .env.
    # Varnish does not expand environment variables in VCL, and templating the
    # file at container start would buy one substitution at the cost of an
    # entrypoint wrapper - not worth it for a local-only emulator.
    set req.http.X-Edge-Origin-Host = req.http.host;
    set req.http.host = regsub(req.http.host, "\.cdn\.localhost$", ".dispatcher.localhost");

    # Varnish cannot ESI-process a compressed body, which is the same constraint
    # Adobe documents as the no-gzip requirement on the vhost. Ask the backend
    # for plain text so the includes are visible to the parser.
    unset req.http.Accept-Encoding;

    # PURGE, so a harness can invalidate the way a purge-by-key would.
    # Local-only: there is deliberately no ACL here, and there must not be a
    # route to this container from anywhere but the local stack.
    if (req.method == "PURGE") {
        return (purge);
    }

    # Anything that is not a plain read is passed straight through. Returning
    # hash for every method would put POST and PUT through a cache lookup, which
    # is neither what Fastly does nor what we want a form post to hit.
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Deliberately NOT falling through to the builtin: the builtin passes any
    # request carrying a Cookie or Authorization header, and an edge cache in
    # front of published AEM pages is expected to serve anonymous HTML from
    # cache regardless of whatever cookies the browser is carrying.
    return (hash);
}

sub vcl_backend_response {
    # Only turn ESI on where the origin said to. The dispatcher sets x-aem-esi
    # for paths its vhost scopes ESI to, which is exactly the gate Adobe's CDN
    # uses - honouring it here means a path that would not assemble in
    # production does not silently assemble locally either.
    if (beresp.http.x-aem-esi == "on") {
        set beresp.do_esi = true;
    }

    # Never store a gzipped copy of something we have to parse.
    set beresp.do_gzip = false;

    # An origin that said no-store means it. This sub returns before the builtin
    # vcl_backend_response runs, so the builtin's no-store handling never fires
    # and the TTL floor below would otherwise cache a no-store response for 10s.
    if (beresp.http.Cache-Control ~ "(?i)(no-store|private)") {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
        return (deliver);
    }

    # A short floor so a snippet change shows up in a test run without waiting.
    # Adobe's TTL comes from the origin's Cache-Control; this only applies when
    # the backend gave us nothing to go on.
    if (beresp.ttl <= 0s) {
        set beresp.ttl = 10s;
        set beresp.uncacheable = false;
    }

    return (deliver);
}

sub vcl_deliver {
    # Make hit/miss legible to a harness. Adobe's CDN exposes the same
    # distinction through Age and its own headers.
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
    set resp.http.X-Cache-Hits = obj.hits;
    set resp.http.X-Edge = "varnish";

    # Send redirects back to the CDN host, not the dispatcher.
    #
    # The dispatcher builds Location from the Host header it was given, which we
    # rewrote to .dispatcher.localhost on the way in. Left alone, a visitor who
    # hits any redirecting URL is bounced off the CDN and onto the dispatcher -
    # where ESI is not assembled - and the page silently loses its includes.
    # That is the worst kind of failure here: it looks like the CDN did not
    # work, when in fact the visitor was never on it.
    #
    # It also forces https: traefik terminates TLS, so the dispatcher believes
    # the request was plain http and says so in Location.
    if (resp.http.Location) {
        set resp.http.Location = regsub(resp.http.Location,
            "^https?://([^/]+)\.dispatcher\.localhost", "https://\1.cdn.localhost");
    }

    # An assembled page must not advertise an ESI capability downstream; the
    # includes are already gone by this point.
    unset resp.http.x-aem-esi;
    return (deliver);
}
