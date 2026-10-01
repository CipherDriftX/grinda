"""The supporting cast around Steppie. Same canvas (400 x 460), same rig groups,
same primitives, so the app renders and animates all of them with one view.

- Dash, the cheetah pacer: the ghost on your track. Rival energy, never mean.
- Shelly, the tortoise: keeper of Steppie Shields. Slow and steady, has your back.
- Pip, the sparrow: the messenger. Every nudge and reminder arrives with Pip.
- Bo, the bear: keeper of the Vault. Guards every cent you stake.
"""
import math
from geom import Builder, capsule, circle, curve, ellipse, mirror, move, poly, rrect, scale, soft_star, taper
import steppie

INK = "#0E1116"
WHITE = "#FFFFFF"
COBALT = "#1F4FD8"
VOLT = "#C8F03C"
BLUSH = "#FF8F6B"
MOUTH = "#5A1E14"
TONGUE = "#FF6F61"

CAST = ["dash", "shelly", "pip", "bo"]
MOODS = ["happy", "cheer", "worried", "wink"]


def eyes(b, l, r, rx, ry, mood, lid_color, look=(2, 2)):
    if mood == "worried":
        look = (-3, 3)
    for side, (ex, ey) in (("L", l), ("R", r)):
        if mood == "wink" and side == "R":
            b.add("eyeR", "lidR", curve((ex - rx * 0.7, ey + 4), (ex - rx * 0.3, ey - 8), (ex + rx * 0.3, ey - 8), (ex + rx * 0.7, ey + 4)), stroke=INK, width=5.5)
            continue
        g = f"eye{side}"
        b.add(g, f"white{side}", ellipse(ex, ey, rx, ry), fill=WHITE)
        b.add(g, f"pupil{side}", ellipse(ex + look[0], ey + look[1], rx * 0.66, ry * 0.68), fill=INK)
        b.add(g, f"glint{side}", ellipse(ex + look[0] + rx * 0.24, ey + look[1] - ry * 0.27, rx * 0.26, rx * 0.26), fill=WHITE)
        b.add(g, f"glint2{side}", ellipse(ex + look[0] - rx * 0.22, ey + look[1] + ry * 0.3, rx * 0.11, rx * 0.11), fill=WHITE)
        if mood in ("happy", "cheer"):
            b.add(g, f"lid{side}", f"M{ex-rx-3},{ey+ry*0.78} C{ex-rx*0.5},{ey+ry*0.48} {ex+rx*0.5},{ey+ry*0.48} {ex+rx+3},{ey+ry*0.78} L{ex+rx+3},{ey+ry+4} L{ex-rx-3},{ey+ry+4} Z", fill=lid_color)


def mouth(b, cx, top, mood, w=16):
    if mood in ("happy", "wink"):
        h = 13
        b.add("mouth", "mouthOpen", f"M{cx-w},{top} C{cx-w*0.5},{top+4} {cx+w*0.5},{top+4} {cx+w},{top} C{cx+w},{top+h*0.75} {cx+w*0.55},{top+h} {cx},{top+h} C{cx-w*0.55},{top+h} {cx-w},{top+h*0.75} {cx-w},{top} Z", fill=MOUTH)
        b.add("mouth", "tongue", ellipse(cx, top + h * 0.78, w * 0.55, h * 0.24), fill=TONGUE)
    elif mood == "cheer":
        h = 24; w = w * 1.2
        b.add("mouth", "mouthOpen", f"M{cx-w},{top} C{cx-w*0.5},{top+5} {cx+w*0.5},{top+5} {cx+w},{top} C{cx+w},{top+h*0.75} {cx+w*0.55},{top+h} {cx},{top+h} C{cx-w*0.55},{top+h} {cx-w},{top+h*0.75} {cx-w},{top} Z", fill=MOUTH)
        b.add("mouth", "tongue", ellipse(cx, top + h * 0.76, w * 0.55, h * 0.24), fill=TONGUE)
    else:
        b.add("mouth", "mouth", curve((cx - 12, top + 10), (cx - 5, top + 3), (cx + 5, top + 3), (cx + 12, top + 10)), stroke=MOUTH, width=4.5)


def brows(b, l, r, mood, color, dy=-38, half=16):
    tilt = {"worried": -6, "cheer": 2, "happy": 3, "wink": 3}[mood]
    for i, (ex, ey) in enumerate((l, r)):
        s = -1 if i == 0 else 1
        x1, x2 = ex - half, ex + half
        y_in, y_out = ey + dy + (tilt if mood == "worried" else 0), ey + dy - (0 if mood == "worried" else tilt)
        if i == 0:
            b.add("brows", f"brow{i}", capsule(x1, y_out, x2, y_in, 4), fill=color)
        else:
            b.add("brows", f"brow{i}", capsule(x1, y_in, x2, y_out, 4), fill=color)


# --------------------------------------------------------------------------- Dash
def dash(mood="happy"):
    b = Builder()
    fur, shade, light, spot, muzzle = "#F7C548", "#E2A92E", "#FFDE85", "#3B2A1A", "#FFF4DC"
    purple, purpleDeep = "#7C5CFF", "#5B3FE0"
    b.add("shadow", "shadow", ellipse(200, 450, 84, 8), fill=INK, opacity=0.16)
    # long spotted tail with a black tip
    b.add("tail", "tail", curve((232, 330), (300, 340), (336, 300), (330, 238)), stroke=fur, width=14)
    for i, (x, y) in enumerate(((286, 334), (318, 314), (333, 282))):
        b.add("tail", f"tailSpot{i}", ellipse(x, y, 4.5, 4.5), fill=spot)
    b.add("tail", "tailTip", capsule(331, 252, 330, 232, 7.5), fill=spot)
    # legs + purple trainers
    for side, hip in (("L", (180, 346)), ("R", (220, 346))):
        ankle = (hip[0] + (-10 if side == "L" else 10), 408)
        g = f"leg{side}"
        b.add(g, f"leg{side}", taper(hip[0], hip[1], ankle[0], ankle[1], 15, 12), fill=fur)
        b.add(g, f"legSpot{side}", ellipse(ankle[0] + (4 if side == "L" else -4), 384, 3.5, 4.5), fill=spot)
        steppie.shoe(b, g, side, dict(mid=WHITE, upper=purple, shade=purpleDeep, stripe=VOLT, sole=INK, lace=WHITE))
    # lean torso, purple pacer singlet
    b.add("body", "torso", "M200,230 C232,230 250,244 252,264 L256,322 C256,338 232,346 200,346 C168,346 144,338 144,322 L148,264 C150,244 168,230 200,230 Z", fill=fur)
    b.add("body", "singlet", "M164,236 C178,250 222,250 236,236 C246,240 250,250 250,264 L252,326 C252,336 232,342 200,342 C168,342 148,336 148,326 L150,264 C150,250 154,240 164,236 Z", fill=purple)
    b.add("body", "singletShade", "M234,240 C246,246 250,254 250,266 L252,326 C252,334 244,338 234,340 C242,318 244,278 234,240 Z", fill=purpleDeep, opacity=0.8)
    b.add("body", "bib", rrect(170, 268, 60, 46, 6), fill="#F4F6F8")
    b.add("body", "bibBand", "M170,305 L230,305 L230,308 C230,311.3 227.3,314 224,314 L176,314 C172.7,314 170,311.3 170,308 Z", fill=purple)
    # a pacer's flag on the bib: two stride slashes
    b.add("body", "bibMark1", poly((184, 298), (192, 298), (202, 276), (194, 276)), fill=purple)
    b.add("body", "bibMark2", poly((198, 298), (206, 298), (216, 276), (208, 276)), fill=purple)
    b.add("body", "shorts", "M146,322 L254,322 L260,356 C261,361 258,364 253,364 L210,364 L200,348 L190,364 L147,364 C142,364 139,361 140,356 Z", fill=INK)
    b.add("body", "shortsStripe", poly((250, 334), (255, 334), (260, 360), (255, 362)), fill=purple)
    for side, sh in (("L", (154, 258)), ("R", (246, 258))):
        sgn = -1 if side == "L" else 1
        hand = (sh[0] + 8 * sgn, sh[1] + 60)
        g = f"arm{side}"
        b.add(g, f"arm{side}", taper(sh[0], sh[1], hand[0], hand[1], 14, 12), fill=fur)
        b.add(g, f"armSpot{side}", ellipse(sh[0] + 4 * sgn, sh[1] + 26, 3.5, 4), fill=spot)
        b.add(g, f"paw{side}", ellipse(hand[0], hand[1] + 6, 16, 15), fill=fur)
        b.add(g, f"pawShade{side}", ellipse(hand[0] + 2 * sgn, hand[1] + 10, 11, 8), fill=shade, opacity=0.7)
    # head: wide cheeks with fluff, small round ears, tear marks
    hc = (200, 150)
    for ex in (132, 268):
        b.add("head", f"ear{ex}", ellipse(ex, 84, 22, 20), fill=fur)
        b.add("head", f"earIn{ex}", ellipse(ex, 87, 12, 10), fill=spot)
    b.add("head", "cheekFluffL", poly((112, 176), (88, 196), (108, 198), (96, 214), (124, 206)), fill=fur)
    b.add("head", "cheekFluffR", mirror(poly((112, 176), (88, 196), (108, 198), (96, 214), (124, 206))), fill=fur)
    b.add("head", "face", "M200,74 C262,74 296,112 296,160 C296,212 254,240 200,240 C146,240 104,212 104,160 C104,112 138,74 200,74 Z", fill=fur)
    b.add("head", "faceLight", ellipse(162, 112, 34, 18), fill=light, opacity=0.7)
    b.add("head", "faceShade", "M108,180 C118,218 154,240 200,240 C246,240 282,218 292,180 C276,214 244,228 200,228 C156,228 124,214 108,180 Z", fill=shade, opacity=0.5)
    for i, (x, y, r) in enumerate(((186, 96, 4), (204, 90, 3.5), (220, 98, 4), (196, 108, 3), (128, 150, 4), (120, 166, 3.5), (272, 150, 4), (280, 166, 3.5), (140, 136, 3), (262, 136, 3))):
        b.add("head", f"spot{i}", ellipse(x, y, r, r * 1.1), fill=spot)
    b.add("head", "muzzleL", ellipse(184, 200, 24, 19), fill=muzzle)
    b.add("head", "muzzleR", ellipse(216, 200, 24, 19), fill=muzzle)
    b.add("head", "chin", ellipse(200, 218, 14, 9), fill=muzzle)
    b.add("head", "tearL", curve((170, 176), (168, 190), (172, 202), (180, 210)), stroke=spot, width=5)
    b.add("head", "tearR", curve((230, 176), (232, 190), (228, 202), (220, 210)), stroke=spot, width=5)
    b.add("head", "nose", "M200,198 C192,198 184,190 187,184 C189,180 195,179 200,179 C205,179 211,180 213,184 C216,190 208,198 200,198 Z", fill="#2B1A10")
    b.add("head", "noseGlint", ellipse(195, 184, 4, 2.2), fill=WHITE, opacity=0.5)
    b.add("head", "headband", "M118,118 C150,98 250,98 282,118 L280,130 C248,112 152,112 120,130 Z", fill=purple)
    b.add("head", "headbandStripe", poly((236, 104), (244, 106), (240, 120), (232, 118)), fill=VOLT)
    eyes(b, (166, 158), (234, 158), 23, 26, mood, fur, look=(4, 1))
    brows(b, (166, 158), (234, 158), mood, spot, dy=-34, half=15)
    mouth(b, 200, 206, mood, 15)
    return b.parts


# --------------------------------------------------------------------------- Shelly
def shelly(mood="happy"):
    b = Builder()
    skin, skinShade, shell, shellLight, shellDeep, rim = "#9EDB8B", "#7CC56A", "#2E9E6B", "#45B983", "#1F7A52", "#E8D9A8"
    b.add("shadow", "shadow", ellipse(200, 450, 120, 9), fill=INK, opacity=0.16)
    # stubby feet
    for side, x in (("L", 140), ("R", 260)):
        g = f"leg{side}"
        b.add(g, f"foot{side}", ellipse(x, 424, 34, 24), fill=skin)
        b.add(g, f"footShade{side}", ellipse(x, 434, 28, 12), fill=skinShade, opacity=0.6)
        for k in (-14, 0, 14):
            b.add(g, f"nail{side}{k}", ellipse(x + k, 444, 6, 4), fill=WHITE, opacity=0.9)
    b.add("tail", "tail", poly((300, 396), (334, 404), (300, 412)), fill=skin)
    # shell: a dome with plates; the centre plate is the Steppie Shield
    b.add("body", "shellRim", "M70,388 C70,300 126,236 200,236 C274,236 330,300 330,388 C330,404 300,414 200,414 C100,414 70,404 70,388 Z", fill=shellDeep)
    b.add("body", "shell", "M80,382 C80,302 132,246 200,246 C268,246 320,302 320,382 C320,394 292,402 200,402 C108,402 80,394 80,382 Z", fill=shell)
    for i, (x, y, rx, ry) in enumerate(((116, 340, 26, 30), (284, 340, 26, 30), (150, 282, 28, 22), (250, 282, 28, 22), (128, 382, 24, 12), (272, 382, 24, 12))):
        b.add("body", f"plate{i}", ellipse(x, y, rx, ry), fill=shellLight)
    b.add("body", "shellGloss", "M118,296 C130,270 156,254 184,250 C162,262 144,280 134,304 Z", fill=WHITE, opacity=0.25)
    b.add("body", "underRim", "M74,392 C74,402 104,416 200,416 C296,416 326,402 326,392 C306,404 270,408 200,408 C130,408 94,404 74,392 Z", fill=rim)
    # the Shield emblem
    b.add("body", "shield", "M200,272 C222,282 240,284 254,282 L254,322 C254,350 232,370 200,382 C168,370 146,350 146,322 L146,282 C160,284 178,282 200,272 Z", fill=WHITE)
    b.add("body", "shieldInner", "M200,282 C218,290 232,292 244,291 L244,322 C244,344 226,360 200,370 C174,360 156,344 156,322 L156,291 C168,292 182,290 200,282 Z", fill=COBALT)
    b.add("body", "shieldCheck", curve((176, 324), (184, 332), (190, 338), (194, 342)), stroke=VOLT, width=9)
    b.add("body", "shieldCheck2", curve((194, 342), (206, 326), (216, 312), (226, 302)), stroke=VOLT, width=9)
    # arms poking out of the shell
    for side, sh in (("L", (96, 300)), ("R", (304, 300))):
        sgn = -1 if side == "L" else 1
        hand = (sh[0] + 20 * sgn, sh[1] + 38)
        g = f"arm{side}"
        b.add(g, f"arm{side}", taper(sh[0], sh[1], hand[0], hand[1], 16, 14), fill=skin)
        b.add(g, f"paw{side}", ellipse(hand[0], hand[1] + 4, 16, 15), fill=skin)
        b.add(g, f"pawShade{side}", ellipse(hand[0] + 3 * sgn, hand[1] + 8, 10, 7), fill=skinShade, opacity=0.7)
    # head + neck
    b.add("head", "neck", capsule(200, 226, 200, 262, 40), fill=skin)
    b.add("head", "neckShade", capsule(218, 236, 218, 258, 12), fill=skinShade, opacity=0.5)
    n0 = len(b.parts)
    b.add("head", "face", "M200,70 C252,70 284,104 284,148 C284,194 248,222 200,222 C152,222 116,194 116,148 C116,104 148,70 200,70 Z", fill=skin)
    b.add("head", "faceLight", ellipse(166, 102, 30, 16), fill="#C2EDB4", opacity=0.8)
    b.add("head", "faceShade", "M120,166 C130,200 160,222 200,222 C240,222 270,200 280,166 C266,198 238,212 200,212 C162,212 134,198 120,166 Z", fill=skinShade, opacity=0.55)
    b.add("head", "cheekL", ellipse(138, 182, 14, 9), fill=BLUSH, opacity=0.55)
    b.add("head", "cheekR", ellipse(262, 182, 14, 9), fill=BLUSH, opacity=0.55)
    b.add("head", "nostrils", ellipse(194, 176, 2.4, 2) + " " + ellipse(206, 176, 2.4, 2), fill=skinShade)
    eyes(b, (168, 146), (232, 146), 21, 24, mood, skin)
    # round reading glasses: wise, a bit nerdy
    for i, x in enumerate((168, 232)):
        b.add("brows", f"lens{i}", ellipse(x, 148, 30, 30), stroke="#6B4A2B", width=5)
    b.add("brows", "bridge", curve((198, 146), (199, 141), (201, 141), (202, 146)), stroke="#6B4A2B", width=5)
    mouth(b, 200, 188, mood, 14)
    for p in b.parts[n0:]:
        p["d"] = move(p["d"], 0, 26)
    return b.parts


# --------------------------------------------------------------------------- Pip
def pip(mood="happy"):
    b = Builder()
    blue, blueDeep, blueLight, belly, beak, beakShade = "#5B8CFF", "#3F6BE0", "#86ABFF", "#FFF3E0", "#FF9A3C", "#E07A1E"
    b.add("shadow", "shadow", ellipse(200, 450, 70, 7), fill=INK, opacity=0.16)
    # tail feathers behind
    b.add("tail", "tail", "M262,330 C300,320 330,300 342,276 C330,310 316,330 296,346 C318,340 332,330 340,320 C326,350 296,366 262,360 Z", fill=blueDeep)
    # legs
    for side, x in (("L", 176), ("R", 224)):
        g = f"leg{side}"
        b.add(g, f"shin{side}", capsule(x, 384, x, 436, 4.5), fill=beakShade)
        for k in (-12, 0, 12):
            b.add(g, f"toe{side}{k}", capsule(x, 438, x + k, 446, 4), fill=beakShade)
    # round body
    b.add("body", "body", ellipse(200, 270, 128, 130), fill=blue)
    b.add("body", "bodyShade", "M86,300 C96,360 144,400 200,400 C256,400 304,360 314,300 C296,350 254,380 200,380 C146,380 104,350 86,300 Z", fill=blueDeep, opacity=0.55)
    b.add("body", "gloss", "M118,196 C134,170 162,152 192,148 C166,166 148,186 140,210 Z", fill=WHITE, opacity=0.3)
    b.add("body", "belly", ellipse(200, 316, 82, 72), fill=belly)
    # messenger satchel: strap across, bag on the hip with a letter peeking out
    b.add("body", "strap", "M98,250 L108,240 L292,342 L284,352 Z", fill="#8A5A34")
    b.add("body", "bag", rrect(252, 322, 70, 54, 10), fill="#A86F42")
    b.add("body", "letter", poly((262, 328), (312, 328), (312, 346), (262, 346)), fill=WHITE)
    b.add("body", "letterFold", poly((262, 328), (287, 340), (312, 328)), fill="#DCE3EE")
    b.add("body", "bagFlap", "M252,338 L322,338 L322,332 C322,326 318,322 312,322 L262,322 C256,322 252,326 252,332 Z", fill="#8A5A34")
    b.add("body", "buckle", rrect(281, 334, 12, 10, 2), fill=VOLT)
    # wings (rig groups flap about the shoulders)
    b.add("armL", "wingL", "M96,252 C64,262 50,296 58,330 C70,318 82,314 92,318 C84,330 82,342 86,352 C104,334 116,306 112,272 Z", fill=blueDeep)
    b.add("armR", "wingR", mirror("M96,252 C64,262 50,296 58,330 C70,318 82,314 92,318 C84,330 82,342 86,352 C104,334 116,306 112,272 Z"), fill=blueDeep)
    # face (the head is the top of the body ball)
    b.add("head", "tuft", "M188,146 C180,118 186,98 200,86 C198,104 202,116 208,126 C214,108 228,98 244,98 C230,110 224,124 222,142 Z", fill=blueDeep)
    b.add("head", "cap", "M136,176 C140,140 168,122 200,122 C232,122 260,140 264,176 Z", fill=VOLT)
    b.add("head", "capBrim", "M222,170 C246,166 276,170 296,180 C292,186 284,188 264,186 L222,182 Z", fill=COBALT)
    b.add("head", "capButton", ellipse(200, 124, 8, 5), fill=COBALT)
    b.add("head", "capStripe", poly((214, 130), (222, 130), (210, 174), (202, 174)), fill=COBALT)
    b.add("head", "cheekL", ellipse(134, 236, 14, 9), fill=BLUSH, opacity=0.6)
    b.add("head", "cheekR", ellipse(266, 236, 14, 9), fill=BLUSH, opacity=0.6)
    eyes(b, (164, 206), (236, 206), 24, 28, mood, blue)
    brows(b, (164, 206), (236, 206), mood, blueDeep, dy=-40, half=14)
    # beak: open when cheering
    if mood == "cheer":
        b.add("mouth", "beakTop", "M178,236 C186,226 214,226 222,236 C214,244 186,244 178,236 Z", fill=beak)
        b.add("mouth", "beakOpen", "M182,242 C190,262 210,262 218,242 C210,248 190,248 182,242 Z", fill=MOUTH)
        b.add("mouth", "beakLow", "M184,246 C190,268 210,268 216,246 C210,262 190,262 184,246 Z", fill=beakShade)
    else:
        b.add("mouth", "beakTop", "M176,236 C186,224 214,224 224,236 C214,252 206,262 200,264 C194,262 186,252 176,236 Z", fill=beak)
        b.add("mouth", "beakLine", curve((182, 242), (192, 248), (208, 248), (218, 242)), stroke=beakShade, width=3)
    return b.parts


# --------------------------------------------------------------------------- Bo
def bo(mood="happy"):
    b = Builder()
    fur, shade, light, muzzle, nose = "#A87452", "#8A5A3C", "#C48E6A", "#E8C9A0", "#2B1A10"
    gold, goldDeep = "#FFC83D", "#E0A21E"
    b.add("shadow", "shadow", ellipse(200, 450, 110, 9), fill=INK, opacity=0.16)
    for side, x in (("L", 152), ("R", 248)):
        g = f"leg{side}"
        b.add(g, f"leg{side}", capsule(x, 380, x, 420, 30), fill=fur)
        b.add(g, f"foot{side}", ellipse(x, 430, 38, 20), fill=shade)
        b.add(g, f"pad{side}", ellipse(x, 434, 20, 9), fill=muzzle, opacity=0.8)
    b.add("tail", "tail", ellipse(300, 380, 16, 14), fill=fur)
    # chunky body in a cobalt vault-keeper vest with a gold lock badge
    b.add("body", "body", ellipse(200, 330, 112, 100), fill=fur)
    b.add("body", "belly", ellipse(200, 350, 66, 62), fill=muzzle)
    b.add("body", "vestL", "M112,280 C128,250 160,236 184,234 L184,420 C150,420 112,404 100,372 C96,340 100,304 112,280 Z", fill=COBALT)
    b.add("body", "vestR", mirror("M112,280 C128,250 160,236 184,234 L184,420 C150,420 112,404 100,372 C96,340 100,304 112,280 Z"), fill=COBALT)
    b.add("body", "vestPipingL", curve((184, 236), (184, 300), (184, 360), (184, 418)), stroke=VOLT, width=4)
    b.add("body", "vestPipingR", curve((216, 236), (216, 300), (216, 360), (216, 418)), stroke=VOLT, width=4)
    b.add("body", "badge", ellipse(146, 300, 20, 20), fill=gold)
    b.add("body", "badgeRing", ellipse(146, 300, 15, 15), fill=goldDeep)
    b.add("body", "keyhole", ellipse(146, 296, 5, 5) + " " + poly((143, 298), (149, 298), (151, 310), (141, 310)), fill=INK)
    for side, sh in (("L", (106, 286)), ("R", (294, 286))):
        sgn = -1 if side == "L" else 1
        hand = (sh[0] + 12 * sgn, sh[1] + 68)
        g = f"arm{side}"
        b.add(g, f"arm{side}", taper(sh[0], sh[1], hand[0], hand[1], 24, 20), fill=fur)
        b.add(g, f"paw{side}", ellipse(hand[0], hand[1] + 8, 24, 22), fill=fur)
        b.add(g, f"pawPad{side}", ellipse(hand[0], hand[1] + 12, 12, 9), fill=muzzle, opacity=0.85)
    # head with a security cap
    for ex in (122, 278):
        b.add("head", f"ear{ex}", ellipse(ex, 86, 30, 28), fill=fur)
        b.add("head", f"earIn{ex}", ellipse(ex, 90, 17, 15), fill=shade)
    b.add("head", "face", "M200,70 C262,70 300,112 300,160 C300,214 258,246 200,246 C142,246 100,214 100,160 C100,112 138,70 200,70 Z", fill=fur)
    b.add("head", "faceLight", ellipse(160, 120, 32, 16), fill=light, opacity=0.7)
    b.add("head", "faceShade", "M104,180 C114,222 152,246 200,246 C248,246 286,222 296,180 C280,218 246,234 200,234 C154,234 120,218 104,180 Z", fill=shade, opacity=0.5)
    b.add("head", "muzzle", ellipse(200, 200, 46, 36), fill=muzzle)
    b.add("head", "cheekL", ellipse(130, 192, 15, 9), fill=BLUSH, opacity=0.5)
    b.add("head", "cheekR", ellipse(270, 192, 15, 9), fill=BLUSH, opacity=0.5)
    b.add("head", "nose", "M200,196 C188,196 180,186 184,179 C187,175 194,174 200,174 C206,174 213,175 216,179 C220,186 212,196 200,196 Z", fill=nose)
    b.add("head", "noseGlint", ellipse(194, 180, 4.5, 2.4), fill=WHITE, opacity=0.5)
    b.add("head", "cap", "M112,124 C116,82 156,58 200,58 C244,58 284,82 288,124 Z", fill=COBALT)
    b.add("head", "capBand", "M110,118 L290,118 L290,130 L110,130 Z", fill="#1638A8")
    b.add("head", "capBrim", "M120,128 C160,140 240,140 280,128 C276,142 240,152 200,152 C160,152 124,142 120,128 Z", fill=INK)
    b.add("head", "capBadge", "M200,76 C208,80 214,81 220,80 L220,96 C220,106 211,113 200,117 C189,113 180,106 180,96 L180,80 C186,81 192,80 200,76 Z", fill=gold)
    b.add("head", "capBadgeMark", poly((194, 106), (199, 106), (206, 88), (201, 88)), fill=COBALT)
    eyes(b, (164, 162), (236, 162), 21, 24, mood, fur)
    brows(b, (164, 162), (236, 162), mood, shade, dy=-30, half=14)
    mouth(b, 200, 210, mood, 14)
    return b.parts


BUILDERS = {"dash": dash, "shelly": shelly, "pip": pip, "bo": bo}

PIVOTS = {
    "dash": dict(neck=(200, 236), shoulderL=(154, 258), shoulderR=(246, 258), hipL=(180, 346), hipR=(220, 346), tail=(232, 330), eyeY=158),
    "shelly": dict(neck=(200, 262), shoulderL=(96, 300), shoulderR=(304, 300), hipL=(140, 424), hipR=(260, 424), tail=(300, 404), eyeY=172),
    "pip": dict(neck=(200, 300), shoulderL=(104, 262), shoulderR=(296, 262), hipL=(176, 384), hipR=(224, 384), tail=(262, 340), eyeY=206),
    "bo": dict(neck=(200, 250), shoulderL=(106, 286), shoulderR=(294, 286), hipL=(152, 380), hipR=(248, 380), tail=(300, 380), eyeY=162),
}

DRAW = ["shadow", "tail", "legL", "legR", "body", "armL", "armR", "head", "eyeL", "eyeR", "brows", "mouth"]


def svg_group(who, mood="happy", tx=0, ty=0, scale_=1.0, arms=(0, 0)):
    from geom import el
    ps = BUILDERS[who](mood)
    pv = PIVOTS[who]
    groups = {}
    for p in ps:
        groups.setdefault(p["group"], []).append(p)
    out = []
    for g in DRAW:
        if g not in groups:
            continue
        body = "".join(el(p) for p in groups[g])
        if g == "armL" and arms[0]:
            body = f'<g transform="rotate({arms[0]} {pv["shoulderL"][0]} {pv["shoulderL"][1]})">{body}</g>'
        if g == "armR" and arms[1]:
            body = f'<g transform="rotate({arms[1]} {pv["shoulderR"][0]} {pv["shoulderR"][1]})">{body}</g>'
        out.append(body)
    return f'<g transform="translate({tx} {ty}) scale({scale_})">{"".join(out)}</g>'
