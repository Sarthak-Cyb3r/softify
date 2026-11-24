import { Env } from './types';

export async function handleGetCharts(env: Env): Promise<Response> {
  // If static asset fetcher is bound, serve static pre-rendered home_shelves.json
  if (env.ASSETS) {
    const assetResp = await env.ASSETS.fetch('https://softify.local/home_shelves.json');
    if (assetResp.status === 200) {
      return new Response(assetResp.body, {
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=3600, stale-while-revalidate=86400'
        }
      });
    }
  }

  // Fallback default snapshot
  const fallback = {
    shelves: [
      { id: 'jump_back_in', title: 'Jump Back In', items: [] },
      { id: 'top_charts', title: 'Top Charts', items: [] },
      { id: 'trending', title: 'Trending Songs', items: [] }
    ],
    updatedAt: Date.now()
  };

  return new Response(JSON.stringify(fallback), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=3600, stale-while-revalidate=86400'
    }
  });
}
