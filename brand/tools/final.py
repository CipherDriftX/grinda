import math, sys
sys.path.insert(0,'.')
from gen import gpath
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
COBALT="#1F4FD8"; INK="#0E1116"; WHITE="#FFFFFF"; VOLT="#C8F03C"
L,R,G,BAR,SW=300,210,42,190,150
# symbol geometry in its own box: width L+2R+SW, height 2R+SW
W=L+2*R+SW; H=2*R+SW
def symbol_path(ox,oy,scale=1.0):
    return gpath(ox+W*scale/2, oy+H*scale/2, L*scale, R*scale, G, BAR*scale)
def sym_el(ox,oy,scale,color):
    return f'<path d="{symbol_path(ox,oy,scale)}" fill="none" stroke="{color}" stroke-width="{SW*scale:.2f}" stroke-linejoin="miter" stroke-miterlimit="10"/>'
# wordmark
f=TTFont("../fonts/GrindaWide-Black.ttf"); gs=f.getGlyphSet(); cmap=f.getBestCmap(); upm=f['head'].unitsPerEm
capH=f['OS/2'].sCapHeight
def word(text,track=0.04):
    x=0; parts=[]
    for ch in text:
        gn=cmap[ord(ch)]; pen=SVGPathPen(gs)
        tp=TransformPen(pen,(1,0,0,-1,x,capH)); gs[gn].draw(tp)
        parts.append(pen.getCommands()); x+=gs[gn].width+track*upm
    return " ".join(parts), x-track*upm, capH
wd,ww,wh=word("GRINDA")
def svg(w,h,body,bg=None):
    b=f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{b}{body}</svg>\n'
out={}
# symbol alone
for name,c in [("symbol-cobalt",COBALT),("symbol-ink",INK),("symbol-white",WHITE)]:
    out[name]=svg(W,H,sym_el(0,0,1,c))
# wordmark alone, scaled so cap height = 400
s=400/wh
out["wordmark-ink"]=svg(round(ww*s),400,f'<path transform="scale({s:.5f})" d="{wd}" fill="{INK}"/>')
out["wordmark-white"]=svg(round(ww*s),400,f'<path transform="scale({s:.5f})" d="{wd}" fill="{WHITE}"/>')
# horizontal lockup: symbol height = 1.0 * H ; wordmark cap height = 0.5*H ; gap = 0.35*H
def lockup(symc,wc,bg=None,pad=0):
    sh=H; ch=0.46*sh; gap=0.34*sh; sc=ch/wh
    w=W+gap+ww*sc+2*pad; h=sh+2*pad
    body=sym_el(pad,pad,1,symc)+f'<path transform="translate({pad+W+gap:.1f},{pad+(sh-ch)/2:.1f}) scale({sc:.5f})" d="{wd}" fill="{wc}"/>'
    return svg(round(w),round(h),body,bg)
out["lockup-ink"]=lockup(COBALT,INK)
out["lockup-white"]=lockup(WHITE,WHITE)
out["lockup-on-cobalt"]=lockup(WHITE,WHITE,COBALT,pad=220)
# app icons 1024: symbol width = 0.70*1024
def icon(bg,fg,grad=None):
    sc=0.70*1024/W; ox=(1024-W*sc)/2; oy=(1024-H*sc)/2
    defs=""; fill=bg
    if grad:
        defs=f'<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{grad[0]}"/><stop offset="1" stop-color="{grad[1]}"/></linearGradient></defs>'; fill="url(#g)"
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{defs}<rect width="1024" height="1024" fill="{fill}"/>{sym_el(ox,oy,sc,fg)}</svg>\n'
out["appicon"]=icon(COBALT,WHITE,("#2B5CE8","#1A44C6"))
out["appicon-dark"]=icon(INK,"#3D6BFF",("#161A22","#0B0D12"))
out["appicon-tinted"]=icon("#000000","#FFFFFF")  # system tints grayscale
for k,v in out.items(): open(f"{k}.svg","w").write(v)
print(W,H,list(out))
