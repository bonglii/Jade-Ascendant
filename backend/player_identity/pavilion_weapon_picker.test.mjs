import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {adminTimeJS} from './admin_time.mjs';
import {pavilionJS,pavilionHTML} from './pavilion_dashboard.mjs';
import {FEATURED_CATALOG,normalizeDocument,BASE_RATES} from './pavilion.mjs';
class Element {
 constructor(tag='div'){this.tag=tag;this.children=[];this.value='';this.hidden=false;this.dataset={};}
 append(...nodes){this.children.push(...nodes);}
 replaceChildren(...nodes){this.children=[...nodes];}
 setAttribute(k,v){this[k]=v;}
}
function fixture(){
 const nodes=new Map();const $=id=>{if(!nodes.has(id))nodes.set(id,new Element());return nodes.get(id);};
 const context=vm.createContext({$,document:{createElement:tag=>new Element(tag),querySelector:()=>new Element()},catalog:FEATURED_CATALOG});
 vm.runInContext(adminTimeJS+pavilionJS,context);
 vm.runInContext("bannerState={catalog};bannerPicked=new Set(['jade_binding_chain']);bannerReview={keep:true};bannerRequest={keep:true};",context);
 return {context,$,paint(){vm.runInContext('paintBannerPicks()',context);},picked(){return vm.runInContext('[...bannerPicked]',context);}};
}
test('dashboard Legendary catalog contains the five supported weapons without the retired bell',()=>{
 const weapons=FEATURED_CATALOG.filter(x=>x.slot==='armament');
 assert.deepEqual(weapons.map(x=>x.id).sort(),['celestial_returning_glaive','jade_binding_chain','nine_heavens_star_sword','sunfire_dragon_jian','void_piercer_spear']);
 assert(pavilionHTML.includes('banner-category'));
});
test('weapon category shows weapons without hiding existing chosen state',()=>{
 const f=fixture();f.$('banner-category').value='weapon';f.paint();
 assert.equal(f.$('banner-selection').children.length,5);
 assert(f.$('banner-selection').children.some(x=>x['aria-pressed']==='true'));
 assert.equal(f.picked()[0],'jade_binding_chain');
});
test('set category excludes weapons and does not discard a selected weapon',()=>{
 const f=fixture();f.$('banner-category').value='set';f.paint();
 assert.equal(f.$('banner-selection').children.length,FEATURED_CATALOG.filter(x=>x.slot!=='armament').length);
 assert.equal(f.picked()[0],'jade_binding_chain');
});
test('search filters names inside the selected category',()=>{
 const f=fixture();f.$('banner-category').value='weapon';f.$('banner-search').value='glaive';f.paint();
 assert.equal(f.$('banner-selection').children.length,1);
 assert.equal(f.$('banner-selection').children[0].children[1].textContent,'Celestial Returning Glaive');
});
test('view-only category/search input preserves an already reviewed publish document',()=>{
 const f=fixture();f.$('banner-form').oninput({target:{id:'banner-category'}});f.$('banner-form').oninput({target:{id:'banner-search'}});
 assert.equal(vm.runInContext('bannerReview.keep&&bannerRequest.keep',f.context),true);
});
test('backend accepts weapon featured banners with existing schedule/rate validation',()=>{
 const banner={id:'a'.repeat(32),title:'Weapon',subtitle:'Legendary armory',artwork:'sanctum',featured:['jade_binding_chain','celestial_returning_glaive'],rates:{...BASE_RATES},starts_at:1000,ends_at:4600,enabled:true};
 assert.deepEqual(normalizeDocument({banners:[banner]}).banners[0].featured,banner.featured);
});
