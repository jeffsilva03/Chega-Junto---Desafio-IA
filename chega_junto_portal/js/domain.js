export const statuses = {scheduled:'Agendada',cancelled:'Cancelada',completed:'Concluída'};
const format = new Intl.DateTimeFormat('sv-SE',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'});

export function localParts(instant) {
  const parts = Object.fromEntries(format.formatToParts(new Date(instant)).map(p => [p.type,p.value]));
  return {date:`${parts.year}-${parts.month}-${parts.day}`,time:`${parts.hour}:${parts.minute}`};
}

export function toInstant(date, time) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !/^\d{2}:\d{2}$/.test(time)) throw new Error('Informe data e horário válidos.');
  const wall = Date.parse(`${date}T${time}:00Z`);
  if (!Number.isFinite(wall) || new Date(wall).toISOString().slice(0,16) !== `${date}T${time}`) throw new Error('Informe data e horário válidos.');
  let value = wall;
  for (let i=0;i<3;i++) {
    const parts=localParts(value);
    value += wall - Date.parse(`${parts.date}T${parts.time}:00Z`);
  }
  const parts=localParts(value);
  if (parts.date !== date || parts.time !== time) throw new Error('Esse horário não existe no fuso da consulta.');
  return new Date(value).toISOString();
}

export function filtersFrom(values, offset = 0) {
  return {patient:values.patient?.trim() ?? '',facility_id:values.facility_id ?? '',specialty:values.specialty?.trim() ?? '',status:values.status ?? '',...(values.date ? {from:values.date,to:values.date} : {}),limit:20,offset};
}

export function payloadFrom(values, items, patient, editing = false) {
  if (!editing && (!patient || !patient.is_active)) throw new Error('Localize um usuário ativo antes de cadastrar.');
  if (!values.specialty.trim() || !values.professional_name.trim() || !values.facility_id) throw new Error('Preencha os campos obrigatórios.');
  return {...(editing ? {} : {user_id:patient.id}),specialty:values.specialty.trim(),professional_name:values.professional_name.trim(),facility_id:values.facility_id,type:values.type,scheduled_at:toInstant(values.date,values.time),instructions:values.instructions.split('\n').map(s=>s.trim()).filter(Boolean),checklist:items.map(item=>({... (item.id ? {id:item.id} : {}),description:item.description.trim(),required:item.required}))};
}

export async function withLoading(element, action) {
  element.disabled = true;
  element.setAttribute('aria-busy','true');
  try { return await action(); }
  finally { element.disabled = false; element.setAttribute('aria-busy','false'); }
}
