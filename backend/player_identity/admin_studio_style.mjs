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
`;
