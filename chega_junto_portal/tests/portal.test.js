import test from 'node:test';
import assert from 'node:assert/strict';
import {apiOrigin,createApi} from '../js/api.js';
import {filtersFrom,localParts,payloadFrom,toInstant,withLoading} from '../js/domain.js';

const base='http://localhost:8000';
const fields={specialty:' Clínica Geral ',professional_name:'Dra. Ana Teste',facility_id:'18446744073709551615',type:'consultation',date:'2026-10-20',time:'09:30',instructions:' Chegar antes.\n\nTrazer documento.'};
const patient={id:'18446744073709551615',is_active:true};

test('configuração contém somente origem HTTP sem credenciais',()=>{
  assert.equal(apiOrigin(base),base);
  for (const value of ['file:///api','http://u:senha@localhost','http://localhost/api','http://localhost?token=x','http://localhost#x']) assert.throws(()=>apiOrigin(value));
});
test('horário de São Paulo independe do timezone do navegador',()=>{
  assert.equal(toInstant('2026-10-20','09:30'),'2026-10-20T12:30:00.000Z');
  assert.deepEqual(localParts('2026-10-21T02:30:00Z'),{date:'2026-10-20',time:'23:30'});
  assert.equal(toInstant('2018-01-10','09:30'),'2018-01-10T11:30:00.000Z');
});
test('parsing rejeita data/hora inválidas e horário inexistente no DST',()=>{
  for (const [date,time] of [['2026-02-30','09:00'],['2026-10-20','25:00'],['','09:00'],['2018-11-04','00:30']]) assert.throws(()=>toInstant(date,time));
});
test('filtros de dia são enviados como limites civis e paginação',()=>{
  assert.deepEqual(filtersFrom({date:'2026-10-20',patient:' Ana ',status:'scheduled'},20),{patient:'Ana',facility_id:'',specialty:'',status:'scheduled',from:'2026-10-20',to:'2026-10-20',limit:20,offset:20});
  assert.equal(filtersFrom({}).offset,0);
});
test('submit conserva IDs como string, required e checklist vazio',()=>{
  const payload=payloadFrom(fields,[{description:' Documento ',required:true}],patient);
  assert.equal(payload.user_id,patient.id); assert.equal(payload.facility_id,fields.facility_id);
  assert.equal(payload.specialty,'Clínica Geral'); assert.deepEqual(payload.instructions,['Chegar antes.','Trazer documento.']);
  assert.deepEqual(payload.checklist,[{description:'Documento',required:true}]);
  assert.deepEqual(payloadFrom(fields,[],patient).checklist,[]);
});
test('PATCH não envia user_id e conserva IDs de itens existentes',()=>{
  const payload=payloadFrom(fields,[{id:'99',description:'Documento',required:false}],null,true);
  assert.equal('user_id' in payload,false); assert.equal(payload.checklist[0].id,'99');
});
test('submit recusa paciente ausente/inativo e campos obrigatórios',()=>{
  assert.throws(()=>payloadFrom(fields,[],null));
  assert.throws(()=>payloadFrom(fields,[],{...patient,is_active:false}));
  assert.throws(()=>payloadFrom({...fields,specialty:' '},[],patient));
});
test('API busca e filtros usam URLSearchParams e header local não secreto',async()=>{
  const calls=[];
  const api=createApi(base,async(url,options)=>{calls.push({url,options});return {ok:true,json:async()=>({id:patient.id})};});
  assert.equal((await api.search(' A+B@EXAMPLE.TEST ')).id,patient.id);
  assert.equal(calls[0].url.searchParams.get('email'),'a+b@example.test');
  assert.equal(calls[0].options.headers['X-Simulator-Request'],'local');
  assert.equal(calls[0].options.credentials,'omit');
  await api.list({patient:'% & João',limit:20,offset:20,facility_id:''});
  assert.equal(calls[1].url.searchParams.get('patient'),'% & João');
  assert.equal(calls[1].url.searchParams.has('facility_id'),false);
});
test('create, edit, detail, facilities e cancel usam métodos corretos sem DELETE',async()=>{
  const calls=[];
  const api=createApi(base,async(url,options)=>{calls.push({url,options});return {ok:true,json:async()=>({status:'cancelled'})};});
  await api.create({user_id:patient.id}); await api.edit('9',{specialty:'Teste'}); await api.detail('9'); await api.facilities({limit:100}); await api.cancel('9');
  assert.deepEqual(calls.map(c=>c.options.method),['POST','PATCH','GET','GET','POST']);
  assert.equal(calls[4].url.pathname,'/api/v1/simulator/appointments/9/cancel');
  assert.equal(calls[4].options.body,undefined);
  assert.equal(JSON.parse(calls[0].options.body).user_id,patient.id);
});
for (const status of [403,404,409,422,500,503]) test(`erro HTTP ${status} é sanitizado`,async()=>{
  const api=createApi(base,async()=>({ok:false,status,json:async()=>({error:{message:'PRIVATE_SENTINEL'}})}));
  await assert.rejects(api.list({}),error=>!error.message.includes('PRIVATE_SENTINEL'));
});
test('falha de rede não repete POST e informa resultado incerto',async()=>{
  let calls=0; const api=createApi(base,async()=>{calls++;throw new TypeError('network');});
  await assert.rejects(api.create({}),/Atualize a lista antes de repetir/); assert.equal(calls,1);
});
test('resposta inválida e abort são tratados',async()=>{
  for (const error of [new SyntaxError('invalid'),Object.assign(new Error('timeout'),{name:'AbortError'})]) {
    const api=createApi(base,async()=>{throw error;});
    await assert.rejects(api.list({}),/Verifique a API/);
  }
});
test('loading começa antes da chamada e sempre termina, inclusive falha',async()=>{
  const node={disabled:false,attributes:{},setAttribute(key,value){this.attributes[key]=value;}};
  await withLoading(node,async()=>{assert.equal(node.disabled,true);assert.equal(node.attributes['aria-busy'],'true');});
  assert.equal(node.disabled,false);
  await assert.rejects(withLoading(node,async()=>{throw new Error('failure');}));
  assert.equal(node.disabled,false);assert.equal(node.attributes['aria-busy'],'false');
});
