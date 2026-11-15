export default {
    async fetch(request, env) {
        const url = new URL(request.url);

        if (url.pathname === '/test') {
            const result = await CheckAndPost(env);
            return new Response(JSON.stringify(result), {
                headers: { 'content-type': 'application/json' },
            });
        }

        if (request.method !== 'POST') {
            return new Response('Umber user counter is running.', { status: 200 });
        }

        if (url.pathname !== '/ping') {
            return new Response('Not found', { status: 404 });
        }

        let body;

        try {
            body = await request.json();
        } catch (error) {
            return new Response('Bad request', { status: 400 });
        }

        const id = typeof body.id === 'string' ? body.id.slice(0, 64) : null;
        const event = body.event === 'left' ? 'left' : 'ping';

        if (!id) {
            return new Response('Bad request', { status: 400 });
        }

        const now = Date.now();

        if (event === 'left') {
            await env.DB.prepare('DELETE FROM sessions WHERE id = ?').bind(id).run();
        } else {
            await env.DB.prepare(
                'INSERT INTO sessions (id, last_seen) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET last_seen = excluded.last_seen'
            ).bind(id, now).run();
        }

        const row = await env.DB.prepare(
            'SELECT COUNT(*) AS n FROM sessions WHERE last_seen > ?'
        ).bind(now - 12 * 60 * 1000).first();

        return new Response(JSON.stringify({ count: row.n }), {
            headers: { 'content-type': 'application/json' },
        });
    },

    async scheduled(controller, env) {
        await CheckAndPost(env);
    },
};

async function CheckAndPost(env) {
    const Result = { dbReady: !!env.DB, webhookSet: !!env.DISCORD_WEBHOOK };

    if (!Result.dbReady) {
        return { ...Result, error: 'DB binding is missing' };
    }

    const now = Date.now();

    const row = await env.DB.prepare(
        'SELECT COUNT(*) AS n FROM sessions WHERE last_seen > ?'
    ).bind(now - 12 * 60 * 1000).first();

    const count = row.n;
    Result.count = count;

    const meta = await env.DB.prepare(
        "SELECT value FROM meta WHERE key = 'last_count'"
    ).first();

    if (meta && meta.value === String(count)) {
        return { ...Result, posted: false, reason: 'count unchanged' };
    }

    if (!Result.webhookSet) {
        return { ...Result, posted: false, reason: 'DISCORD_WEBHOOK secret is missing' };
    }

    const response = await fetch(env.DISCORD_WEBHOOK, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
            username: 'Umber',
            content: `The amount of users currently using the script right now is: ${count}`,
        }),
    });

    Result.webhookStatus = response.status;

    if (response.ok) {
        await env.DB.prepare(
            "INSERT INTO meta (key, value) VALUES ('last_count', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value"
        ).bind(String(count)).run();
        Result.posted = true;
    } else {
        Result.posted = false;
        Result.error = 'webhook rejected the message';
    }

    return Result;
}
