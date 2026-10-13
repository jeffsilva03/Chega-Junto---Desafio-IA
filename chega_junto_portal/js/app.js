import {createApi, PUBLIC_API} from './api.js';
import {filtersFrom, localParts, payloadFrom, statuses, withLoading} from './domain.js';

const $ = selector => document.querySelector(selector);
const form = $('#appointment-form');
let api, patient = null, editorPatient = null, editingId = null, offset = 0, listGeneration = 0, editorGeneration = 0;
let busy = false;

function element(tag, text, className) {
  const node = document.createElement(tag);
  if (text != null) node.textContent = text;
  if (className) node.className = className;
  return node;
}
function icon(name) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg','svg');
  svg.classList.add('icon'); svg.setAttribute('aria-hidden','true');
  const use = document.createElementNS('http://www.w3.org/2000/svg','use');
  use.setAttribute('href',`assets/icons.svg#${name}`); svg.append(use);
  return svg;
}
function message(text, error = false) {
  const node = $('#message');
  $('#message-text').textContent = text;
  $('#message-icon').replaceChildren(icon(error ? 'close' : 'check'));
  node.className = error ? 'toast error' : 'toast';
  node.hidden = false;
}
function patientCard(node, user) {
  node.replaceChildren();
  const avatar = element('span',null,'avatar'); avatar.setAttribute('aria-hidden','true'); avatar.append(icon('user'));
  const info = element('div',null,'patient-info');
  info.append(element('small','Paciente','patient-caption'),element('strong',user.full_name),element('small',user.email ?? 'E-mail não informado'));
  const state = element('span',null,'patient-state');
  state.append(element('span',user.is_active ? 'Cadastro ativo' : 'Cadastro inativo',`badge ${user.is_active ? 'active' : 'cancelled'}`));
  node.append(avatar,info,state);
  node.hidden = false;
}
function values(target) { return Object.fromEntries(new FormData(target)); }
function closeEditor() {
  if (busy) return;
  editorGeneration++;
  $('#editor').hidden = true;
  editingId = null;
  $('#new-appointment').focus();
}
function addItem(item = {}, readOnly = false) {
  const row = element('div',null,'checklist-row');
  if (item.id) row.dataset.id = item.id;
  const description = element('input');
  description.value = item.title ?? '';
  description.placeholder = 'Descrição do documento ou preparo';
  description.maxLength = 200;
  description.required = true;
  description.setAttribute('aria-label','Descrição do item');
  const required = element('select');
  required.setAttribute('aria-label','Obrigatoriedade do item');
  for (const [value,label] of [['true','Obrigatório'],['false','Opcional']]) {
    const option = element('option',label); option.value=value; required.append(option);
  }
  required.value = String(item.is_required ?? false);
  const remove = element('button',null,'icon-button'); remove.append(icon('trash'));
  remove.type='button'; remove.setAttribute('aria-label','Remover item'); remove.onclick=()=>row.remove();
  row.append(icon('file'),description,required,remove);
  if (readOnly) { description.readOnly=true; required.disabled=true; remove.hidden=true; }
  $('#checklist').append(row);
}
function showEditor(record = null, view = false) {
  editorGeneration++;
  form.reset();
  $('#checklist').replaceChildren();
  editingId = record?.id ?? null;
  const user = record?.patient ?? patient;
  editorPatient = user;
  patientCard($('#editor-patient'),user);
  const readOnly = view || (record && record.status !== 'scheduled');
  $('#appointment-fields').disabled = Boolean(readOnly);
  $('#save').hidden = Boolean(readOnly);
  $('#add-item').hidden = Boolean(readOnly);
  $('#editor-title').textContent = record ? (readOnly ? 'Visualizar consulta' : 'Editar consulta') : 'Nova consulta';
  $('#dismiss').textContent = readOnly ? 'Fechar' : 'Cancelar';
  $('#editor-status').hidden = !record;
  $('#editor-status').textContent = record ? `Status: ${statuses[record.status]}. ${readOnly ? 'Somente leitura.' : ''}` : '';
  if (record) {
    const local = localParts(record.scheduled_at);
    for (const [key,value] of Object.entries({specialty:record.specialty,professional_name:record.professional_name,facility_id:record.facility.id,...local,instructions:record.instructions.join('\n')})) form.elements.namedItem(key).value=value;
    form.elements.namedItem('type').value=record.type;
    // Uma unidade desativada permanece legível no detalhe, sem permitir novos vínculos.
    const select=form.elements.namedItem('facility_id');
    if (!select.value) { const option=element('option',`${record.facility.name} (inativa)`); option.value=record.facility.id; select.append(option); select.value=option.value; }
    record.checklist.forEach(item=>addItem(item,readOnly));
  }
  updateInstructionsCount();
  $('#editor').hidden=false;
  $('#editor-title').tabIndex=-1;
  $('#editor-title').focus();
}
async function loadList() {
  const generation=++listGeneration;
  $('#list-section').setAttribute('aria-busy','true');
  $('#previous').disabled=true; $('#next').disabled=true;
  try {
    const result=await api.list(filtersFrom(values($('#filter-form')),offset));
    if (generation !== listGeneration) return;
    for (const [id,field] of [['specialty-options','specialty'],['professional-options','professional_name']]) {
      const suggestions=$(`#${id}`);
      suggestions.replaceChildren(...[...new Set(result.items.map(record=>record[field]))].sort().map(value=>{
        const option=element('option'); option.value=value; return option;
      }));
    }
    const body=$('#appointments'); body.replaceChildren();
    if (!result.items.length) { const row=element('tr'); const cell=element('td','Nenhum agendamento encontrado.'); cell.colSpan=8; row.append(cell); body.append(row); }
    for (const record of result.items) {
      const local=localParts(record.scheduled_at);
      const row=element('tr');
      for (const text of [record.patient.full_name,record.specialty,record.professional_name,record.facility.name,local.date.split('-').reverse().join('/'),local.time]) row.append(element('td',text));
      const status=element('td'); status.append(element('span',statuses[record.status],`badge ${record.status}`)); row.append(status);
      const actions=element('td'); const group=element('div',null,'row-actions');
      for (const [label,action] of [['Visualizar',()=>openRecord(record.id,true)],...(record.status === 'scheduled' ? [['Editar',()=>openRecord(record.id,false)],['Cancelar',()=>cancelRecord(record)]] : [])]) {
        const button=element('button',null,label === 'Cancelar' ? 'link-button cancel-action' : 'link-button'); button.type='button';
        button.append(icon({Visualizar:'eye',Editar:'edit',Cancelar:'ban'}[label]),element('span',label));
        button.onclick=()=>withLoading(button,action).catch(error=>message(error.message,true));
        group.append(button);
      }
      actions.append(group); row.append(actions); body.append(row);
    }
    const {total,limit}=result.pagination;
    $('#page-info').textContent=total ? `Mostrando ${offset+1} a ${Math.min(offset+limit,total)} de ${total} agendamentos` : 'Nenhum agendamento';
    $('#page-number').textContent=String(Math.floor(offset/limit)+1);
    $('#previous').disabled=offset===0; $('#next').disabled=offset+limit>=total;
  } catch (error) {
    if (generation === listGeneration) {
      message(error.message,true);
      const cell=element('td','Não foi possível atualizar. Use Atualizar lista.'); cell.colSpan=8;
      const row=element('tr'); row.append(cell); $('#appointments').replaceChildren(row);
    }
  } finally { if (generation === listGeneration) $('#list-section').setAttribute('aria-busy','false'); }
}
async function openRecord(id,view) {
  if (busy) return;
  const generation=++editorGeneration;
  const record=await api.detail(id);
  if (generation === editorGeneration) showEditor(record,view);
}
async function cancelRecord(record) {
  if (busy) return;
  const dialog=$('#cancel-dialog');
  if (dialog.open) return;
  $('#cancel-description').textContent=`${record.patient.full_name} • ${record.specialty} • ${localParts(record.scheduled_at).date.split('-').reverse().join('/')}`;
  dialog.returnValue='back'; dialog.showModal();
  const result=await new Promise(resolve=>dialog.addEventListener('close',()=>resolve(dialog.returnValue),{once:true}));
  if (result !== 'confirm') return;
  busy=true;
  try {
    await api.cancel(record.id);
    message('Consulta cancelada com sucesso.');
    if (editingId === record.id) { busy=false; closeEditor(); }
    await loadList();
  } finally { busy=false; }
}
$('#search-form').onsubmit=event=>{
  event.preventDefault();
  const button=event.currentTarget.querySelector('button');
  const email=$('#email').value;
  patient=null; $('#patient-result').hidden=true;
  withLoading(button,async()=>{
    const result=await api.search(email);
    if ($('#email').value !== email) return;
    patient=result; patientCard($('#patient-result'),patient);
  }).catch(error=>message(error.message,true));
};
$('#email').oninput=()=>{ patient=null; $('#patient-result').hidden=true; };
$('#new-appointment').onclick=()=>{
  if (busy) return;
  if (!patient?.is_active) { message('Localize um usuário ativo pelo e-mail antes de cadastrar.',true); $('#email').focus(); return; }
  showEditor();
};
$('#close-editor').onclick=closeEditor; $('#dismiss').onclick=closeEditor;
$('#dismiss-message').onclick=()=>{ $('#message').hidden=true; };
function updateInstructionsCount() {
  const input=form.elements.namedItem('instructions');
  $('#instructions-count').textContent=`${input.value.length}/${input.maxLength}`;
}
form.elements.namedItem('instructions').oninput=updateInstructionsCount;
$('#add-item').onclick=()=>{ if ($('#checklist').children.length < 200) addItem(); else message('Limite de 200 itens por consulta.',true); };
let filterTimer;
function applyFilters() { clearTimeout(filterTimer); offset=0; loadList(); }
$('#filter-form').onsubmit=event=>{ event.preventDefault(); applyFilters(); };
$('#filter-form').onchange=applyFilters;
$('#filter-form').oninput=event=>{
  if (!['patient','specialty'].includes(event.target.name)) return;
  clearTimeout(filterTimer); filterTimer=setTimeout(applyFilters,400);
};
$('#clear-filters').onclick=()=>{ $('#filter-form').reset(); applyFilters(); };
$('#previous').onclick=()=>{ offset=Math.max(0,offset-20); loadList(); };
$('#next').onclick=()=>{ offset+=20; loadList(); };
$('#reload').onclick=()=>loadList();
form.onsubmit=event=>{
  event.preventDefault();
  if (busy) return;
  try {
    const items=[...$('#checklist').children].map(row=>({id:row.dataset.id,description:row.querySelector('input').value,required:row.querySelector('select').value==='true'}));
    const payload=payloadFrom(values(form),items,editorPatient,editingId!==null);
    const id=editingId;
    busy=true; $('#appointment-fields').disabled=true;
    withLoading($('#save'),async()=>{
      const record=id ? await api.edit(id,payload) : await api.create(payload);
      busy=false; closeEditor();
      message(id ? 'Consulta atualizada com sucesso.' : 'Consulta cadastrada com sucesso.');
      offset=0;
      await loadList();
      return record;
    }).catch(error=>message(error.message,true)).finally(()=>{ busy=false; $('#appointment-fields').disabled=false; });
  } catch(error) { message(error.message,true); }
};

function showLogin(text='') {
  api?.logout();
  listGeneration++; editorGeneration++; clearTimeout(filterTimer);
  patient=null; editorPatient=null; editingId=null; offset=0; busy=false;
  $('#login-screen').hidden=false; $('.workspace').hidden=true;
  $('#operator-identity').hidden=true; $('#logout').hidden=true;
  $('#operator-name').textContent='';
  $('#appointment-form').reset(); $('#search-form').reset(); $('#filter-form').reset();
  $('#login-form').reset(); $('#editor').hidden=true;
  $('#patient-result').replaceChildren(); $('#patient-result').hidden=true;
  $('#editor-patient').replaceChildren(); $('#checklist').replaceChildren();
  $('#appointments').replaceChildren(); $('#page-info').textContent='';
  $('#specialty-options').replaceChildren(); $('#professional-options').replaceChildren();
  $('#cancel-description').textContent='';
  if ($('#cancel-dialog').open) $('#cancel-dialog').close('back');
  $('#message').hidden=true; $('#message-text').textContent='';
  $('#login-error').textContent=text; $('#login-error').hidden=!text;
  $('#login-form').elements.namedItem('email').focus();
}

async function loadDashboard(identity) {
  $('#new-appointment').disabled=true;
  const controls=[...document.querySelectorAll('#search-form button,#filter-form button,.pagination button')];
  controls.forEach(control=>control.disabled=true);
  $('#operator-name').textContent=identity.full_name;
  $('#operator-identity').hidden=false;
  $('#logout').hidden=portalMode === 'simulator';
  $('#login-screen').hidden=true; $('.workspace').hidden=false;
  for (const select of document.querySelectorAll('.facility-select')) {
    while (select.options.length>1) select.remove(1);
  }
  let page=0;
  while (true) {
    const result=await api.facilities({limit:100,offset:page});
    for (const facility of result.items) for (const select of document.querySelectorAll('.facility-select')) {
      const option=element('option',`${facility.name} — ${facility.address_text}`); option.value=facility.id; select.append(option);
    }
    page+=result.items.length;
    if (page>=result.pagination.total) break;
    if (!result.items.length || page>100000) throw new Error('Não foi possível carregar as unidades.');
  }
  $('#new-appointment').disabled=false;
  controls.forEach(control=>control.disabled=false);
  await loadList();
}

let portalMode='operator';
$('#logout').onclick=()=>showLogin();
$('#login-form').onsubmit=event=>{
  event.preventDefault();
  if ($('#login-submit').disabled) return;
  const loginForm=event.currentTarget;
  $('#login-error').hidden=true;
  withLoading($('#login-submit'),async()=>{
    const email=loginForm.elements.namedItem('email').value;
    let password=loginForm.elements.namedItem('password').value;
    const pending=api.login(email,password);
    loginForm.elements.namedItem('password').value=''; password=null;
    await pending;
    const identity=await api.me();
    loginForm.reset();
    await loadDashboard(identity);
  }).catch(error=>showLogin(error.message));
};
async function start() {
  const local=['127.0.0.1','localhost','[::1]'].includes(location.hostname);
  let config={apiBaseUrl:PUBLIC_API,mode:'operator'};
  if (local) {
    const response=await fetch('./config.json',{cache:'no-store'});
    if (!response.ok) throw new Error('Inicie o portal com serve.py e configure --api-base.');
    config=await response.json();
  }
  portalMode=config.mode ?? 'operator';
  api=createApi(config.apiBaseUrl,fetch,{mode:portalMode,onUnauthorized:()=>showLogin('Sua sessão expirou. Entre novamente.')});
  $('#login-submit').disabled=false;
  if (portalMode === 'simulator') await loadDashboard({full_name:'Simulador local'});
}
start().catch(error=>{
  $('#login-error').textContent=error.message ?? 'Não foi possível iniciar o portal.';
  $('#login-error').hidden=false;
});
