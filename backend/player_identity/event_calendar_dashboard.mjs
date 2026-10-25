export const eventCalendarHTML=`<section class="card event-calendar-guide"><details><summary>Aturan &amp; jadwal event</summary><ol><li>Hanya satu event terbatas aktif: Dragon Odyssey atau Heavenly Trials. Daily Trials, login harian, dan progres realm tetap berjalan sendiri.</li><li>Semua jadwal memakai WIB. Odyssey memesan 14 hari bermain dan 3 hari masa klaim. Heavenly Trials berulang sampai dinonaktifkan atau diganti rotasi berikutnya.</li><li>Nonaktif berarti event disembunyikan dari game; aksi baru, iklan, dan shop event ditutup setelah sinkronisasi. Progres, hadiah yang sudah diperoleh, dan pemulihan transaksi tetap disimpan.</li><li>Untuk mengganti event, nonaktifkan yang lama lebih dahulu. Server menolak jadwal bertumpuk, termasuk dua penyimpanan bersamaan. Jadwal terbit yang sudah dipakai player tidak direset dari form ini.</li></ol></details><p id="event-calendar-status" role="status">Memeriksa jadwal event…</p><div id="event-calendar-slots"></div><button type="button" id="event-calendar-retry" hidden>Periksa lagi</button></section>`;
export const eventCalendarJS=String.raw`
let calendarReading=false,calendarAgain=false;
async function refreshEventCalendar(force=false){
 if(calendarReading){if(force===true)calendarAgain=true;return;}calendarReading=true;
 const status=document.getElementById('event-calendar-status'),slots=document.getElementById('event-calendar-slots'),retry=document.getElementById('event-calendar-retry');
 retry.hidden=true;
 const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),12000);
 try{
  const response=await fetch('/admin/api/event-calendar',{credentials:'same-origin',cache:'no-store',signal:controller.signal});
  if(!response.ok)throw Error('Kalender belum dapat diperiksa. Form dan jadwal tidak diubah.');
  const data=await response.json();if(data.version!==1||!Array.isArray(data.slots)||!Array.isArray(data.conflicts))throw Error('Respons kalender belum tersedia.');
  slots.replaceChildren();
  for(const row of data.slots){const p=document.createElement('p');p.className='small muted';p.textContent=(row.kind==='odyssey'?'Dragon Odyssey':'Heavenly Trials')+' · '+row.id+' · '+StudioTime.formatWib(row.starts_at)+' → '+(row.ends_at?StudioTime.formatWib(row.ends_at):'berulang sampai dinonaktifkan');slots.append(p);}
  status.textContent=data.conflicts.length?'Ada jadwal bertumpuk. Nonaktifkan salah satu; jangan menghapus progres player.':data.slots.length?'Jadwal tidak bertumpuk.':'Tidak ada event terbatas aktif atau terjadwal.';
 }catch(error){status.textContent=error.message;retry.hidden=false;}finally{clearTimeout(timer);calendarReading=false;if(calendarAgain){calendarAgain=false;refreshEventCalendar();}}
}
document.getElementById('event-calendar-retry').onclick=()=>refreshEventCalendar();
`;
