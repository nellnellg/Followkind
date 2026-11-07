export type Update = {id:string; volunteer:string; volunteer_id?:string; visit_id:string; date:string; hours:number; family:string; message:string; status:string; photo?:string};
export type Need = {id:string; title:string; family_reference:string; status:string};
export function validateHours(value:string) {
  if (!value.trim()) return 'Enter the time you spent.';
  const n=Number(value);
  if (!Number.isFinite(n)||n<=0||n>24) return 'Enter a number greater than 0 and no more than 24.';
  if (Math.abs(n*100-Math.round(n*100))>0.000001) return 'Use no more than two decimal places.';
  return '';
}
export function summarize(updates:Update[], needs:Need[], start:string,end:string) {
  const confirmed=updates.filter(u=>u.status==='confirmed'&&u.date>=start&&u.date<=end);
  return {hours:Math.round(confirmed.reduce((sum,u)=>sum+Number(u.hours),0)*100)/100,visits:new Set(confirmed.map(u=>u.visit_id)).size,volunteers:new Set(confirmed.map(u=>u.volunteer_id||u.volunteer)).size,pending:updates.filter(u=>u.status!=='confirmed'&&u.date>=start&&u.date<=end).reduce((sum,u)=>sum+Number(u.hours),0),open:needs.filter(n=>n.status!=='resolved').length,resolved:needs.filter(n=>n.status==='resolved').length};
}
export function weekRange(date=new Date()) { const day=new Date(date.getFullYear(),date.getMonth(),date.getDate());day.setDate(day.getDate()-((day.getDay()+6)%7));const local=(d:Date)=>[d.getFullYear(),String(d.getMonth()+1).padStart(2,'0'),String(d.getDate()).padStart(2,'0')].join('-');const end=new Date(day);end.setDate(end.getDate()+6);return {start:local(day),end:local(end)}; }
export function csvCell(v:unknown) {const s=String(v??'');return '"'+(/^[\s]*[=+@-]/.test(s)?"'"+s:s).replaceAll('"','""')+'"';}
