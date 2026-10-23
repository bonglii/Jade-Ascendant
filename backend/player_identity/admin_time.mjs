// Presentation boundary: datetime-local fields always mean WIB, regardless of
// the operator's browser timezone. APIs continue receiving Unix UTC seconds.
export function parseWib(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value)) throw Error('Isi tanggal dan jam dalam WIB.');
  const ms = Date.parse(value + ':00+07:00');
  if (!Number.isFinite(ms) || new Date(ms + 25200000).toISOString().slice(0, 16) !== value) throw Error('Tanggal atau jam tidak valid.');
  return ms / 1000;
}
export function inputWib(seconds) {
  if (!Number.isSafeInteger(seconds) || seconds < 0) throw Error('Waktu server tidak valid.');
  return new Date(seconds * 1000 + 25200000).toISOString().slice(0, 16);
}
export function formatWib(seconds) {
  if (!Number.isSafeInteger(seconds) || seconds < 0) return '—';
  return new Intl.DateTimeFormat('id-ID', {timeZone:'Asia/Jakarta', dateStyle:'medium', timeStyle:'short'}).format(new Date(seconds * 1000)) + ' WIB';
}
export function nextWeeklyReset(seconds) {
  if (!Number.isSafeInteger(seconds) || seconds < 0) throw Error('Waktu server tidak valid.');
  // Epoch Thursday; Monday 04:00 WIB is Sunday 21:00 UTC.
  const n = seconds + 60, week = 604800;
  return n + (week - (n + 270000) % week) % week;
}
export const adminTimeJS = `const StudioTime=(()=>{${parseWib.toString()}\n${inputWib.toString()}\n${formatWib.toString()}\n${nextWeeklyReset.toString()}\nreturn Object.freeze({parseWib,inputWib,formatWib,nextWeeklyReset});})();`;
export const adminClockJS = `function updateStudioClock(){if(document.visibilityState==='hidden')return;const value=StudioTime.formatWib(Math.floor(Date.now()/1000));document.querySelectorAll('[data-studio-clock]').forEach(n=>{if(n.textContent!==value)n.textContent=value;});}updateStudioClock();setInterval(updateStudioClock,60000);document.addEventListener('visibilitychange',updateStudioClock);`;
