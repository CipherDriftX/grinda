import math,sys
def gpath(cx,cy,L,r,gap_deg,bar):
    # horizontal stadium centerline; right semicircle center (cx+L/2), left (cx-L/2)
    xr=cx+L/2; xl=cx-L/2
    a=math.radians(gap_deg)  # start angle on right arc, measured up from +x
    sx=xr+r*math.cos(a); sy=cy-r*math.sin(a)
    d=f"M{sx:.1f},{sy:.1f} A{r},{r} 0 0 0 {xr:.1f},{cy-r:.1f}"
    if L>0: d+=f" L{xl:.1f},{cy-r:.1f}"
    d+=f" A{r},{r} 0 0 0 {xl:.1f},{cy+r:.1f}"
    if L>0: d+=f" L{xr:.1f},{cy+r:.1f}"
    d+=f" A{r},{r} 0 0 0 {xr+r:.1f},{cy:.1f} L{xr+r-bar:.1f},{cy:.1f}"
    return d
