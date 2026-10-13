import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import {createApi, PUBLIC_API} from '../js/api.js';

const identity={id:'1',full_name:'Operador Fictício',email:'operator@example.test'};
const response=(data,status=200)=>({ok:status<400,status,json:async()=>data});
const session=()=>({access_token:randomBytes(32).toString('base64url'),token_type:'bearer',operator:identity});

test('login público normaliza email e só retorna identidade; token fica no cliente em memória',async()=>{
  const calls=[], issued=session();
  const api=createApi(PUBLIC_API,async(url,options)=>{calls.push({url,options});return response(url.pathname.endsWith('/login') ? issued : identity);});
  assert.equal(api.isAuthenticated(),false);
  assert.deepEqual(await api.login(' OPERATOR@EXAMPLE.TEST ','senha-ficticia-de-teste'),identity);
  assert.equal(api.isAuthenticated(),true);
  assert.equal(calls[0].url.pathname,'/api/v1/operator/auth/login');
  assert.equal(JSON.parse(calls[0].options.body).email,'operator@example.test');
  assert.equal(calls[0].options.headers.Authorization,undefined);
  assert.deepEqual(await api.me(),identity);
  assert.equal(calls[1].options.headers.Authorization,`Bearer ${issued.access_token}`);
  assert.equal(calls[1].options.credentials,'omit');
  assert.equal(calls[1].options.cache,'no-store');
  assert.equal(Object.hasOwn(api,'token'),false);
});

test('sessão ausente, reload lógico e logout bloqueiam operações sem fazer request',async()=>{
  let calls=0;
  const fetcher=async()=>{calls++;return response(session());};
  const api=createApi(PUBLIC_API,fetcher);
  await assert.rejects(api.list({}),/Entre/); assert.equal(calls,0);
  await api.login(identity.email,'senha-ficticia-de-teste');
  const fresh=createApi(PUBLIC_API,fetcher);
  await assert.rejects(fresh.me(),/Entre/);
  api.logout(); assert.equal(api.isAuthenticated(),false);
  await assert.rejects(api.search('a@example.test'),/Entre/); assert.equal(calls,1);
});

test('401 protegido limpa sessão e avisa interface mesmo sem corpo JSON',async()=>{
  let notified=0;
  const api=createApi(PUBLIC_API,async(url)=>url.pathname.endsWith('/login') ? response(session()) : {status:401,ok:false,json:async()=>{throw new SyntaxError();}}, {onUnauthorized:()=>notified++});
  await api.login(identity.email,'senha-ficticia-de-teste');
  await assert.rejects(api.me(),/expirou/);
  assert.equal(notified,1); assert.equal(api.isAuthenticated(),false);
});

test('senha incorreta e email desconhecido têm o mesmo erro sanitizado',async()=>{
  const api=createApi(PUBLIC_API,async()=>response({error:{message:'PRIVATE_SENTINEL'}},401));
  await assert.rejects(api.login(identity.email,'senha-ficticia-de-teste'),/^Error: E-mail ou senha inválidos\.$/);
  assert.equal(api.isAuthenticated(),false);
});

test('resposta login inválida não autentica',async()=>{
  const api=createApi(PUBLIC_API,async()=>response({operator:identity}));
  await assert.rejects(api.login(identity.email,'senha-ficticia-de-teste'),/inválida/);
  assert.equal(api.isAuthenticated(),false);
});

test('modo público cobre busca, filtros e CRUD somente em operator com Bearer',async()=>{
  const calls=[];
  const api=createApi(PUBLIC_API,async(url,options)=>{calls.push({url,options});return response(url.pathname.endsWith('/login') ? session() : {items:[]});});
  await api.login(identity.email,'senha-ficticia-de-teste');
  await api.search(' A+B@EXAMPLE.TEST '); await api.facilities({limit:100}); await api.list({status:'scheduled',patient:'% & teste'});
  await api.create({user_id:'2',checklist:[]}); await api.detail('9'); await api.edit('9',{specialty:'Teste'}); await api.cancel('9');
  assert.equal(calls[1].url.searchParams.get('email'),'a+b@example.test');
  assert.equal(calls[3].url.searchParams.get('patient'),'% & teste');
  assert.deepEqual(calls.slice(1).map(call=>call.options.method),['GET','GET','GET','POST','GET','PATCH','POST']);
  for (const {url,options} of calls.slice(1)) {
    assert.ok(url.pathname.startsWith('/api/v1/operator/'));
    assert.ok(options.headers.Authorization.startsWith('Bearer '));
    assert.equal(options.headers['X-Simulator-Request'],undefined);
  }
  assert.equal(calls.at(-1).url.pathname,'/api/v1/operator/appointments/9/cancel');
});

test('resposta tardia de leitura não retorna dados após logout',async()=>{
  let release;
  const api=createApi(PUBLIC_API,async(url)=>url.pathname.endsWith('/login') ? response(session()) : new Promise(resolve=>{release=()=>resolve(response({items:['privado']}));}));
  await api.login(identity.email,'senha-ficticia-de-teste');
  const pending=api.list({}); api.logout(); release();
  await assert.rejects(pending,/Sessão encerrada/);
});

test('login em andamento não restaura sessão depois de logout',async()=>{
  let release;
  const api=createApi(PUBLIC_API,async()=>new Promise(resolve=>{release=()=>resolve(response(session()));}));
  const pending=api.login(identity.email,'senha-ficticia-de-teste'); api.logout(); release();
  await assert.rejects(pending,/Sessão encerrada/); assert.equal(api.isAuthenticated(),false);
});

test('escrita falha não é repetida automaticamente no modo público',async()=>{
  let writes=0;
  const api=createApi(PUBLIC_API,async(url)=>{if(url.pathname.endsWith('/login')) return response(session()); writes++; throw new TypeError('network');});
  await api.login(identity.email,'senha-ficticia-de-teste');
  await assert.rejects(api.create({}),/Atualize a lista antes de repetir/); assert.equal(writes,1);
});

test('tela login tem aviso, labels, erro acessível e nenhum cadastro público',async()=>{
  const html=await readFile(new URL('../index.html',import.meta.url),'utf8');
  assert.match(html,/AMBIENTE DEMONSTRATIVO — SISTEMA NÃO OFICIAL/);
  assert.match(html,/id="login-form"/); assert.match(html,/autocomplete="username"/);
  assert.match(html,/autocomplete="current-password"/); assert.match(html,/id="login-error" role="alert"/);
  assert.match(html,/name="password"[^>]*minlength="8"[^>]*maxlength="128"/);
  assert.doesNotMatch(html,/Criar conta|operator\/register/);
});

test('frontend não persiste sessão em storage, cookie ou arquivo',async()=>{
  for(const file of ['api.js','app.js']) {
    const source=await readFile(new URL(`../js/${file}`,import.meta.url),'utf8');
    assert.doesNotMatch(source,/localStorage|sessionStorage|indexedDB|document\.cookie/);
  }
  assert.equal(PUBLIC_API,'https://chega-junto-api.onrender.com');
});
