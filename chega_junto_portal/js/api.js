export function apiOrigin(value) {
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error('Configure uma origem válida para a API.');
  return url.origin;
}

export function createApi(base, fetcher = fetch) {
  const origin = apiOrigin(base);
  async function request(method, path, body, query = {}) {
    const url = new URL(`/api/v1/simulator${path}`, origin);
    for (const [key, value] of Object.entries(query)) if (value !== '' && value != null) url.searchParams.set(key, value);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 30000);
    try {
      const response = await fetcher(url, { method, signal: controller.signal, credentials:'omit', redirect:'error', headers: { Accept:'application/json', 'X-Simulator-Request':'local', ...(body === undefined ? {} : {'Content-Type':'application/json'}) }, ...(body === undefined ? {} : {body:JSON.stringify(body)}) });
      const data = await response.json();
      if (!response.ok) {
        const messages = {404:'Recurso não encontrado ou simulador desabilitado.',403:'Acesso permitido somente no PC local e na origem do portal.',409:'Conflito ao salvar. Atualize os dados e confira o status.',422:'Dados inválidos. Confira os campos e limites.',503:'Serviço temporariamente indisponível.'};
        throw new Error(messages[response.status] ?? 'Não foi possível concluir a operação.');
      }
      return data;
    } catch (error) {
      if (error instanceof TypeError || error.name === 'AbortError' || error instanceof SyntaxError) throw new Error(method === 'GET' ? 'Não foi possível carregar. Verifique a API e tente atualizar.' : 'Não foi possível confirmar o salvamento. Atualize a lista antes de repetir.');
      throw error;
    } finally { clearTimeout(timer); }
  }
  return {
    search:email => request('GET','/users/search',undefined,{email:email.trim().toLowerCase()}),
    list:filters => request('GET','/appointments',undefined,filters),
    facilities:filters => request('GET','/facilities',undefined,filters),
    detail:id => request('GET',`/appointments/${encodeURIComponent(id)}`),
    create:body => request('POST','/appointments',body),
    edit:(id,body) => request('PATCH',`/appointments/${encodeURIComponent(id)}`,body),
    cancel:id => request('POST',`/appointments/${encodeURIComponent(id)}/cancel`),
  };
}
