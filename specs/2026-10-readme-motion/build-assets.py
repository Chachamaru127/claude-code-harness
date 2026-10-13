#!/usr/bin/env python3
"""Build the SVG source, poster and GitHub GIF from one 12-second timeline."""
from pathlib import Path
import io, copy, subprocess, xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/images/readme'
OUT.mkdir(parents=True, exist_ok=True)
TIMES = [0, 0.16, 0.32, 0.82, 1]
MOTION = [(-10,20,-7),(0,-12,5),(12,20,-5)]
LABELS = {
 'ja': {'pain':['AIに頼んだ','その後が、見えない'],'result':['仕事の流れが見える','結果を見て、判断できる'],'stages':['計画','実装と検査','別担当の点検'],'sub':['やることを決める','直して、確かめる','見落としを探す'],'decision':'最後は、あなたが判断','title':'散らばった作業が計画、実装と検査、別担当の点検へ整い、最後に利用者へ判断が返る'},
 'en': {'pain':['You asked the AI','Now you chase the work'],'result':['See the work take shape','Judge the result'],'stages':['Plan','Build and test','Separate review'],'sub':['Define the outcome','Change it. Check it.','Look for missed issues'],'decision':'You make the final call','title':'Scattered work aligns into a plan, implementation and tests, and a separate review before the user makes the final decision'}
}

def source(lang):
 d=LABELS[lang]
 cards=[]
 for i,x in enumerate([35,265,495]):
  dx,dy,angle=MOTION[i]
  values=f'{dx} {dy};{dx/2} {dy/2};0 0;0 0;{dx} {dy}'
  rotate=f'{angle} 95 67;{angle/2} 95 67;0 95 67;0 95 67;{angle} 95 67'
  icon=['<path d="M70 25h36l13 13v25H70z M106 25v14h13 M80 47h25 M80 55h18"/>','<path d="m79 31-12 12 12 12 m32-24 12 12-12 12 m-9-28-11 32"/>','<circle cx="93" cy="41" r="14"/><path d="m104 52 13 13 m-28-24 4 4 7-8"/>'][i]
  cards.append(f'''<g transform="translate({x},160)"><g id="card-{i}"><animateTransform attributeName="transform" type="translate" dur="12s" repeatCount="indefinite" values="{values}" keyTimes="0;.16;.32;.82;1"/><g id="tilt-{i}"><animateTransform attributeName="transform" type="rotate" dur="12s" repeatCount="indefinite" values="{rotate}" keyTimes="0;.16;.32;.82;1"/><rect x="0" y="5" width="190" height="134" rx="20" fill="#ece8e1" opacity=".55"/><rect width="190" height="134" rx="20" fill="white" stroke="#e5ded5"/><g fill="none" stroke="#f67847" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">{icon}</g><text x="95" y="91" text-anchor="middle" font-size="{25 if lang=='ja' else 21}" font-weight="700">{d['stages'][i]}</text><text x="95" y="115" text-anchor="middle" class="sub">{d['sub'][i]}</text></g></g></g>''')
 return f'''<svg xmlns="http://www.w3.org/2000/svg" width="720" height="390" viewBox="0 0 720 390" role="img" aria-labelledby="title desc">
<title id="title">{d['title']}</title><desc id="desc">Concept illustration, not a live project status. 12-second loop. Reduced-motion shows the settled work path.</desc>
<defs><radialGradient id="warm"><stop stop-color="#ffe7d9"/><stop offset="1" stop-color="#fff"/></radialGradient><linearGradient id="line"><stop stop-color="#e8d8cb"/><stop offset=".55" stop-color="#f67847"/><stop offset="1" stop-color="#e8d8cb"/></linearGradient></defs>
<style>text{{font-family:system-ui,-apple-system,'Hiragino Sans','Noto Sans CJK JP',sans-serif;fill:#1b1b22}}.sub{{font-size:14px;fill:#706b66}}.reduced{{display:none}}@media(prefers-reduced-motion:reduce){{.moving{{display:none}}.reduced{{display:inline}}}} </style>
<rect width="720" height="390" rx="28" fill="#fcfbf9"/><ellipse cx="670" cy="330" rx="210" ry="170" fill="url(#warm)" opacity=".7"/>
<g class="moving"><g id="pain" opacity="0"><animate attributeName="opacity" values="1;1;0;0;1;1" keyTimes="0;.2;.22;.86;.88;1" dur="12s" repeatCount="indefinite"/><text x="35" y="64" font-size="35" font-weight="700">{d['pain'][0]}</text><text x="35" y="108" font-size="35" font-weight="700">{d['pain'][1]}</text></g><g id="result" opacity="1"><animate attributeName="opacity" values="0;0;1;1;0;0" keyTimes="0;.24;.26;.82;.84;1" dur="12s" repeatCount="indefinite"/><text x="35" y="64" font-size="35" font-weight="700">{d['result'][0]}</text><text x="35" y="108" font-size="35" font-weight="700">{d['result'][1]}</text></g></g>
<g class="reduced"><text x="35" y="64" font-size="35" font-weight="700">{d['result'][0]}</text><text x="35" y="108" font-size="35" font-weight="700">{d['result'][1]}</text></g>
<path d="M220 227H500" stroke="#e6dfd7" stroke-width="2" fill="none"/>
<path id="flow" d="M220 227H500" stroke="url(#line)" stroke-width="4" fill="none" stroke-dasharray="280" stroke-dashoffset="0"><animate attributeName="stroke-dashoffset" values="280;280;0;0;280" keyTimes="0;.16;.4;.82;1" dur="12s" repeatCount="indefinite"/></path>
<g class="moving"><circle id="pulse" cy="227" cx="220" r="6" fill="#f67847" opacity="0"><animate attributeName="cx" values="220;220;500;500;220" keyTimes="0;.32;.62;.82;1" dur="12s" repeatCount="indefinite"/><animate attributeName="opacity" values="0;0;1;1;0;0" keyTimes="0;.31;.34;.59;.65;1" dur="12s" repeatCount="indefinite"/></circle></g>
{''.join(cards)}
<path id="decision-link" d="M590 297v16" fill="none" stroke="#edb39a" stroke-width="2" opacity="1"><animate attributeName="opacity" values="0;0;1;1;0;0" keyTimes="0;.34;.4;.78;.82;1" dur="12s" repeatCount="indefinite"/></path>
<g id="decision" opacity="1"><animate attributeName="opacity" values=".35;.35;1;1;.35" keyTimes="0;.45;.65;.82;1" dur="12s" repeatCount="indefinite"/><rect x="443" y="317" width="241" height="44" rx="22" fill="#fff0e7" stroke="#f0cbb8"/><text x="563.5" y="345" text-anchor="middle" font-size="18" font-weight="600">{d['decision']}</text></g>
</svg>'''

NS={'s':'http://www.w3.org/2000/svg'}
ET.register_namespace('',NS['s'])
def lerp(t,keys,vals):
 for i in range(len(keys)-1):
  if t<=keys[i+1]:
   p=max(0,(t-keys[i])/(keys[i+1]-keys[i]));return vals[i]+p*(vals[i+1]-vals[i])
 return vals[-1]
def frame(svg,t):
 p=(t%12)/12;r=ET.fromstring(svg)
 for parent in r.iter():
  for child in list(parent):
   if child.tag.endswith(('animate','animateTransform')):parent.remove(child)
 ids={e.get('id'):e for e in r.iter() if e.get('id')}
 for i,(dx,dy,a) in enumerate(MOTION):
  factor=lerp(p,TIMES,[1,.5,0,0,1]);ids[f'card-{i}'].set('transform',f'translate({dx*factor},{dy*factor})');ids[f'tilt-{i}'].set('transform',f'rotate({a*factor} 95 67)')
 pain=lerp(p,[0,.2,.22,.86,.88,1],[1,1,0,0,1,1]);result=lerp(p,[0,.24,.26,.82,.84,1],[0,0,1,1,0,0]);ids['pain'].set('opacity',str(pain));ids['result'].set('opacity',str(result))
 ids['flow'].set('stroke-dashoffset',str(lerp(p,[0,.16,.4,.82,1],[280,280,0,0,280])))
 ids['pulse'].set('cx',str(lerp(p,[0,.32,.62,.82,1],[220,220,500,500,220])))
 ids['pulse'].set('opacity',str(lerp(p,[0,.31,.34,.59,.65,1],[0,0,1,1,0,0])))
 ids['decision-link'].set('opacity',str(lerp(p,[0,.34,.4,.78,.82,1],[0,0,1,1,0,0])))
 ids['decision'].set('opacity',str(lerp(p,[0,.45,.65,.82,1],[.35,.35,1,1,.35])))
 return ET.tostring(r,encoding='unicode')

def accessible(svg):
 r=ET.fromstring(svg)
 static=ET.fromstring(frame(svg,8))
 moving=ET.Element('{'+NS['s']+'}g', {'class':'motion-scene'})
 still=ET.Element('{'+NS['s']+'}g', {'class':'static-scene'})
 for e in list(r):
  if e.tag.rsplit('}',1)[-1] not in ['title','desc','defs','style']:
   r.remove(e);moving.append(e)
 for e in list(static):
  if e.tag.rsplit('}',1)[-1] in ['title','desc','defs','style']:continue
  if e.get('class')=='reduced':continue
  for child in e.iter():
   child.attrib.pop('id',None)
   if child.get('class') in ['moving','reduced']:child.attrib.pop('class',None)
  still.append(e)
 r.append(moving);r.append(still)
 style=ET.SubElement(r,'{'+NS['s']+'}style')
 style.text='.static-scene{display:none}@media(prefers-reduced-motion:reduce){.motion-scene{display:none}.static-scene{display:inline}}'
 return ET.tostring(r,encoding='unicode')

for lang in ['en','ja']:
 svg=source(lang);(OUT/f'hero-motion-{lang}.svg').write_text(accessible(svg))
 (OUT/f'hero-motion-{lang}-poster.svg').write_text(frame(svg,8))
 frames=[]
 for n in range(144):
  png=subprocess.run(['rsvg-convert','--width','720','--height','390'],input=frame(svg,n/12).encode(),stdout=subprocess.PIPE,check=True).stdout
  frames.append(Image.open(io.BytesIO(png)).convert('RGB').quantize(colors=128))
 frames[0].save(OUT/f'hero-motion-{lang}.gif',save_all=True,append_images=frames[1:],duration=[80,80,90]*48,loop=0,optimize=True,disposal=2)
 print(lang,len(frames),'frames', (OUT/f'hero-motion-{lang}.gif').stat().st_size,'bytes',flush=True)
