export const PUBLIC_API = 'https://chega-junto-api.onrender.com';
export function apiOrigin(value) {
  const url = new URL(value);
  if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error('Configure uma origem válida para a API.');
  return url.origin;
}

export function createApi(base, fetcher = fetch, {mode='operator', onUnauthorized=()=>{}} = {}) {
  const origin = apiOrigin(base);
  if (!['operator','simulator'].includes(mode)) throw new Error('Modo de portal inválido.');
  if (mode === 'simulator' && !['localhost','127.0.0.1','[::1]'].includes(new URL(origin).hostname)) throw new Error('Simulador exige API local.');
  let token = null, generation = 0;
  const pending = new Set();
  function logout() {
    token = null; generation++;
    for (const controller of pending) controller.abort();
    pending.clear();
  }
  async function request(method, path, body, query = {}, publicRequest = false) {
    if (mode === 'operator' && !publicRequest && !token) throw new Error('Entre com sua conta de operador.');
    const requestGeneration = generation;
    const url = new URL(`/api/v1/${mode}${path}`, origin);
    for (const [key, value] of Object.entries(query)) if (value !== '' && value != null) url.searchParams.set(key, value);
    const controller = new AbortController();
    pending.add(controller);
    const timer = setTimeout(() => controller.abort(), 30000);
    try {
      const response = await fetcher(url, {method, signal:controller.signal, credentials:'omit', redirect:'error', cache:'no-store', headers:{Accept:'application/json', ...(mode === 'simulator' ? {'X-Simulator-Request':'local'} : (publicRequest ? {} : {Authorization:`Bearer ${token}`})), ...(body === undefined ? {} : {'Content-Type':'application/json'})}, ...(body === undefined ? {} : {body:JSON.stringify(body)})});
      if (requestGeneration !== generation) throw new Error('Sessão encerrada. Entre novamente.');
      if (response.status === 401 && mode === 'operator' && !publicRequest) {
        logout(); onUnauthorized();
        throw new Error('Sua sessão expirou. Entre novamente.');
      }
      const data = await response.json();
      if (requestGeneration !== generation) throw new Error('Sessão encerrada. Entre novamente.');
      if (!response.ok) {
        const messages = {401:'E-mail ou senha inválidos.',404:'Recurso não encontrado ou portal desabilitado.',403:'Acesso não permitido.',409:'Conflito ao salvar. Atualize os dados e confira o status.',422:'Dados inválidos. Confira os campos e limites.',503:'Serviço temporariamente indisponível.'};
        throw new Error(messages[response.status] ?? 'Não foi possível concluir a operação.');
      }
      return data;
    } catch (error) {
      if (error instanceof TypeError || error.name === 'AbortError' || error instanceof SyntaxError) throw new Error(publicRequest ? 'Não foi possível entrar. Verifique a conexão e tente novamente.' : (method === 'GET' ? 'Não foi possível carregar. Verifique a API e tente atualizar.' : 'Não foi possível confirmar o salvamento. Atualize a lista antes de repetir.'));
      throw error;
    } finally { clearTimeout(timer); pending.delete(controller); }
  }
  return {
    async login(email,password) {
      if (mode !== 'operator') throw new Error('Login indisponível no simulador local.');
      logout();
      const data = await request('POST','/auth/login',{email:email.trim().toLowerCase(),password},{},true);
      if (typeof data.access_token !== 'string' || data.token_type !== 'bearer' || !data.operator) throw new Error('Resposta de autenticação inválida.');
      token = data.access_token;
      return data.operator;
    },
    me:()=>request('GET','/auth/me'),
    logout,
    isAuthenticated:()=>mode === 'simulator' || token !== null,
    search:email => request('GET','/users/search',undefined,{email:email.trim().toLowerCase()}),
    list:filters => request('GET','/appointments',undefined,filters),
    facilities:filters => request('GET','/facilities',undefined,filters),
    detail:id => request('GET',`/appointments/${encodeURIComponent(id)}`),
    create:body => request('POST','/appointments',body),
    edit:(id,body) => request('PATCH',`/appointments/${encodeURIComponent(id)}`,body),
    cancel:id => request('POST',`/appointments/${encodeURIComponent(id)}/cancel`),
  };
}

export const createSimulatorApi = (base,fetcher=fetch) => createApi(base,fetcher,{mode:'simulator'});
