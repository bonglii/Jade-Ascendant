// Shared presentation only; no auth, session, API or event authority changes.
export const studioStyle=`
:root{--bg:#061c1b;--panel:#0b2b29;--line:#9b87464d;--gold:#e8cb88;--jade:#96e4c4;--ink:#f5ecd3;--text:#f5ecd3;--soft:#b2cabe;--muted:#b2cabe;color-scheme:dark}
body{background:radial-gradient(ellipse at 12% 0,#21655a70,transparent 45%),radial-gradient(ellipse at 90% 5%,#c4a85918,transparent 40%),linear-gradient(160deg,#061c1b,#071f22);font-variant-numeric:tabular-nums}
.wrap,body>main{max-width:1260px;margin:auto}header{gap:22px}h1,h2{letter-spacing:.015em}h1{color:#fae7b3;text-shadow:0 2px 18px #b8ba6033}
.card,.metric,dialog{border:1px solid #a08a4c70;box-shadow:inset 0 1px #e8d69722,0 18px 50px #00131155;background:linear-gradient(140deg,#164139ee,#0b2928f5);border-radius:20px}
.card{position:relative;overflow:hidden}.card:before{content:'';position:absolute;height:1px;top:0;left:8%;right:8%;background:linear-gradient(90deg,transparent,#ffe5a5aa,transparent);pointer-events:none}
.tabs,nav{padding:12px;border:1px solid #9b874644;border-radius:14px;background:#061f1c99;box-shadow:inset 0 1px #fff1}
.tabs{position:sticky;top:8px;z-index:4;backdrop-filter:blur(16px)}.tabs button{border-radius:10px;min-height:44px}
button{min-height:44px;border-radius:12px;border-color:#b59a5c80;background:linear-gradient(#23584c,#133e34);box-shadow:inset 0 1px #d7f7d633,0 2px 5px #00190f44;transition:background .15s,transform .15s}
button:active:enabled{transform:translateY(1px)}button:hover:enabled{background:linear-gradient(#347461,#215346)}button.primary{background:linear-gradient(#fae3a8,#cead69);color:#102d27;border-color:#ffe6ad;box-shadow:inset 0 1px #fff7d8,0 3px 12px #c9aa4c22}
button:disabled{cursor:default}.metric strong,.metric b{font-size:clamp(21px,3vw,30px);color:var(--gold)}
input:not([type=checkbox]),select,textarea{background:#071f1fe0!important;border:1px solid #718b655e!important;border-radius:11px!important;box-shadow:inset 0 2px 8px #00140f55;color:#f5ecd3!important}input:focus,select:focus,textarea:focus{outline:2px solid #87e3c0;outline-offset:3px}
.table-wrap{border:1px solid #ad995b33;border-radius:12px}thead{background:#082924}tbody tr:hover{background:#86e9be0a}td,th{font-variant-numeric:tabular-nums}
.note,.notice{border-radius:12px;background:#092c27;color:#c7dfcc}.badge,.reward,.status{border-radius:10px}.seal{background:radial-gradient(circle at 35% 25%,#387b66,#103a32);box-shadow:inset 0 0 0 4px #092c26,inset 0 0 0 5px #bba56388,0 3px 14px #00130e66}
::-webkit-scrollbar{height:7px;width:7px}::-webkit-scrollbar-thumb{background:#7a9c7766;border-radius:8px}summary{min-height:36px;align-content:center}
@media(max-width:600px){.tabs{position:static;display:flex;overflow:auto;flex-wrap:nowrap}.tabs button{white-space:nowrap}.metrics{grid-template-columns:repeat(2,minmax(0,1fr))}.metric{padding:12px}.card{border-radius:16px}.row.actions button{flex:1 1 140px}.clock strong{font-size:18px}}
@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important;transition:none!important;animation:none!important}}
/* JADE ADMIN PRESENTATION POLISH V1: visual-only, no event authority */
#studio .studio-nav{gap:8px;padding:10px 12px;scrollbar-width:thin;scrollbar-color:#b8a16688 transparent;scroll-padding-inline:14px;align-items:stretch}
#studio .studio-nav>a,#studio .studio-nav>button{display:inline-flex;flex:0 0 auto;align-items:center;justify-content:center;min-height:46px;padding:10px 15px;line-height:1.25;white-space:nowrap;font-size:13px;font-weight:650;text-decoration:none;color:#d9e8da;border:1px solid transparent;border-radius:10px;background:transparent;box-shadow:none}
#studio .studio-nav>a:hover,#studio .studio-nav>button:hover:enabled{color:#ffebbe;border-color:#b1a36b77;background:#21493e}
#studio .studio-nav>button.active{background:linear-gradient(140deg,#ffe3a0,#c2a15d);border-color:#f4dfaf;color:#102a24;box-shadow:0 3px 12px #0004}
#studio .studio-nav>a:focus-visible,#studio .studio-nav>button:focus-visible{outline:2px solid #b5efd6;outline-offset:2px}
#studio [data-view]{min-width:0}#studio [data-view] .grid>*{min-width:0}
#studio .card{overflow:visible}#studio .card-head{margin-bottom:18px}#studio .card h2{line-height:1.32}#studio .card p{overflow-wrap:anywhere}
#studio .actions{align-items:center}#studio .actions>button{min-height:46px}#studio label{line-height:1.4}
#studio .table-wrap{max-width:100%;overscroll-behavior-x:contain;scrollbar-width:thin}
#studio table th{background:#102d27;position:sticky;top:0;z-index:1}#studio table td{vertical-align:top}
#studio input:not([type=checkbox]),#studio select,#studio textarea{min-width:0;max-width:100%;font-size:15px}
#studio [data-view="announcements"] .announcement-grid,#studio [data-view="pavilion"] .banner-layout{align-items:start}
#studio [data-view="announcements"] .announcement-preview{position:sticky;top:92px;outline:1px solid #f0d59a33;outline-offset:-8px}
#studio [data-view="announcements"] .announcement-preview .announcement-copy{line-height:1.65}
#studio [data-view="announcements"] .announcement-item{padding:18px 2px}
#studio [data-view="announcements"] .announcement-item strong{overflow-wrap:anywhere}
#studio [data-view="pavilion"] .banner-preview{position:sticky;top:92px;overflow:hidden}
#studio [data-view="pavilion"] .banner-pick{min-width:0;min-height:116px;justify-content:center;line-height:1.35;overflow-wrap:anywhere}
#studio [data-view="pavilion"] .banner-pick:focus-visible{outline:2px solid #f4dd9a;outline-offset:1px}
#studio [data-view="pavilion"] .banner-selection{scrollbar-width:thin;scrollbar-color:#bba56d88 transparent}
#studio [data-view="pavilion"] .banner-rates>div{min-width:0}
#studio [data-view="pavilion"] .banner-featured figure{min-width:88px;overflow-wrap:anywhere}
body>main .layout>*{min-width:0}body>main .card{overflow:visible}body>main .card h2{line-height:1.27}
body>main .schedule{border-color:#987f5177;box-shadow:inset 0 1px #fff1}
body>main .metric{min-width:0;display:flex;gap:3px 8px;align-items:baseline;flex-wrap:wrap}
body>main .metric span{line-height:1.5}body>main .switch{min-height:62px}
body>main .actions>button{min-height:46px}body>main input:not([type=checkbox]){min-width:0}
body>main .notice{line-height:1.6}body>main dialog{box-shadow:0 28px 90px #000a}
@media(max-width:940px){#studio [data-view="pavilion"] .banner-layout,#studio [data-view="announcements"] .announcement-grid{grid-template-columns:minmax(0,1fr)}#studio [data-view="announcements"] .announcement-preview,#studio [data-view="pavilion"] .banner-preview{position:static}}
@media(max-width:760px){#studio .studio-nav{position:relative;top:auto;padding:8px;gap:5px;border-radius:12px}#studio .studio-nav>a,#studio .studio-nav>button{min-height:44px;font-size:12px;padding:9px 12px}#studio .row.between{align-items:flex-start}#studio .card{padding:18px}#studio .actions>button{flex:1 1 145px}#studio [data-view="pavilion"] .banner-selection{grid-template-columns:repeat(2,minmax(0,1fr))}#studio [data-view="pavilion"] .banner-rates{grid-template-columns:repeat(2,minmax(0,1fr))}body>main .layout{grid-template-columns:1fr}body>main header{display:flex;flex-direction:column;align-items:flex-start;gap:16px}body>main .clock{text-align:left;margin-top:0}body>main .metrics{grid-template-columns:repeat(2,minmax(0,1fr))}body>main .card{padding:19px}}
@media(max-width:450px){#studio [data-view="announcements"] .row>label{flex:1 1 100%}#studio [data-view="announcements"] .announcement-preview{padding:16px}#studio [data-view="pavilion"] .banner-preview{padding:17px}#studio [data-view="pavilion"] .banner-art{margin:-17px -17px 14px}#studio .metrics{grid-template-columns:repeat(2,minmax(0,1fr))}body>main .metrics{grid-template-columns:repeat(2,minmax(0,1fr))}body>main .metric{padding:12px}body>main .milestones{grid-template-columns:1fr}body>main .reward{flex-wrap:wrap}body>main .actions>button{flex:1 1 100%}}
@media(prefers-reduced-motion:reduce){#studio *,body>main *{scroll-behavior:auto!important;animation:none!important;transition:none!important}}
`;
