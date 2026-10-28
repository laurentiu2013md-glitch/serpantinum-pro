import QtQuick
import "../"

// A small procedural sky, repainted only while the weather surface is on screen.
Item {
    id: sky
    property real backgroundOpacity: 0.5
    property real moonOpacity: 0.98
    property bool animate: true
    property real phase: 0
    readonly property int currentHour: { const tick = DateTime.time; return new Date().getHours(); }
    property bool daytime: Weather.data.is_day !== undefined && Date.now() / 1000 - Number(Weather.data.fetched_at || 0) < 5400
        ? Number(Weather.data.is_day) === 1 : currentHour >= 6 && currentHour < 19
    property string condition: {
        const code = Number(Weather.data.current_code);
        if (Weather.data.current_code !== undefined) {
            if (code >= 95) return "storm";
            if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
            if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "rain";
            if (code === 45 || code === 48) return "fog";
            if (code === 0) return "clear";
            return "cloudy";
        }
        const icon = Weather.currentIcon;
        if (icon === "\uf0e7") return "storm";
        if (icon === "\uf2dc") return "snow";
        if (icon === "󰖗") return "rain";
        if (icon === "󰖑") return "fog";
        if (icon === "\uf185" || icon === "\uf186") return "clear";
        return "cloudy";
    }
    readonly property string sceneName: (daytime ? "day-" : "night-") + condition
    readonly property bool moving: visible && animate && !Motion.reduced && !GameMode.enabled
    onConditionChanged: { scene.requestPaint(); celestial.requestPaint(); }
    onDaytimeChanged: { scene.requestPaint(); celestial.requestPaint(); }
    onVisibleChanged: if (visible) scene.requestPaint()
    Timer {
        interval: 50
        running: sky.moving
        repeat: true
        onTriggered: { sky.phase += 0.05; scene.requestPaint(); }
    }
    Canvas {
        id: scene
        anchors.fill: parent
        opacity: sky.backgroundOpacity
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            if (width <= 0 || height <= 0) return;
            const c = getContext("2d"), w = width, h = height, t = sky.phase;
            c.reset();
            const wet = sky.condition === "rain" || sky.condition === "storm";
            const mist = sky.condition === "fog";
            const night = !sky.daytime;
            const gradient = c.createLinearGradient(0, 0, 0, h);
            gradient.addColorStop(0, wet ? "#111b35" : night ? "#030821" : "#174f79");
            gradient.addColorStop(0.55, wet ? "#24394d" : night ? "#0a1747" : "#327ca1");
            gradient.addColorStop(1, wet ? "#142538" : night ? "#14295b" : "#569ab0");
            c.fillStyle = gradient; c.fillRect(0, 0, w, h);
            // Stable stars with a slow twinkle; there is no random per-frame flicker.
            if (night && !wet && !mist) {
                for (let i = 0; i < 88; ++i) {
                    const x = ((i * 137.51 + 37) % 997) / 997 * w;
                    const y = ((i * 73.33 + 19) % 601) / 601 * h * 0.88;
                    c.fillStyle = "rgba(230,239,255," + (0.18 + 0.46 * (0.5 + 0.5 * Math.sin(t * 0.6 + i))) + ")";
                    c.beginPath(); c.arc(x, y, i % 9 === 0 ? 1.25 : 0.65, 0, Math.PI * 2); c.fill();
                }
            }
            // An occasional faint shooting star passes behind the clouds.
            if (night && !wet && !mist && sky.moving && t % 27 < 1.4) {
                const progress = (t % 27) / 1.4;
                c.strokeStyle = "rgba(231,239,255," + Math.sin(progress * Math.PI) * .52 + ")";
                c.lineWidth = 1.2;
                c.beginPath(); c.moveTo(w*.88-progress*62, h*.1+progress*40);
                c.lineTo(w*.88-progress*62+18, h*.1+progress*40-13); c.stroke();
            }
            // Soft elliptical wisps move at several depths like the reference sky.
            const bands = sky.condition === "clear" ? 3 : mist ? 7 : 6;
            for(let layer=0;layer<bands;++layer) {
                for(let i=0;i<7;++i) {
                    const drift=t*(3+layer*1.7);
                    const x=((i*w*.21+layer*w*.13+drift)%(w*1.7))-w*.35;
                    const y=h*(.095+layer*.072)+Math.sin(i*.9+layer*.7+t*.035)*h*.034;
                    c.save();c.translate(x,y);c.scale(w*(.14+(i%3)*.035),h*(mist ? .055 : .012+(layer%3)*.006));
                    const cloud=c.createRadialGradient(0,0,0,0,0,1);
                    const tone=wet ? "106,131,159" : night ? "192,205,241" : "223,237,245";
                    cloud.addColorStop(0,"rgba("+tone+","+(wet ? .22 : mist ? .18 : .34)+")");
                    cloud.addColorStop(.4,"rgba("+tone+",0.15)");cloud.addColorStop(1,"rgba("+tone+",0)");
                    c.fillStyle=cloud;c.beginPath();c.arc(0,0,1,0,Math.PI*2);c.fill();c.restore();
                }
            }
            if(wet) {
                c.lineWidth=1;c.strokeStyle="rgba(194,220,245,.34)";
                for(let i=0;i<42;++i) {
                    const x=((i*91.7-t*34)%(w+70)+w+70)%(w+70)-35;
                    const y=(i*53.1+t*(135+i%5*15))%(h+40)-20;
                    c.beginPath();c.moveTo(x,y);c.lineTo(x-5,y+18);c.stroke();
                }
            }
            if(sky.condition==="snow") {
                c.fillStyle="rgba(233,244,255,.7)";
                for(let i=0;i<35;++i) {
                    const x=(i*109.3+Math.sin(t*.4+i)*16)%w;
                    const y=(i*47.9+t*(12+i%4*4))%(h+8)-4;
                    c.beginPath();c.arc(x,y,1+i%3*.55,0,Math.PI*2);c.fill();
                }
            }
            if(sky.condition==="storm" && sky.moving && Math.sin(t*.47)>.998) {
                c.strokeStyle="rgba(218,228,255,.65)";c.lineWidth=2;c.beginPath();
                c.moveTo(w*.75,22);c.lineTo(w*.68,h*.19);c.lineTo(w*.73,h*.18);c.lineTo(w*.65,h*.35);c.stroke();
            }
            // A quiet lower field keeps calendar labels readable over the scene.
            const shade=c.createLinearGradient(0,0,0,h);
            shade.addColorStop(0,"rgba(2,8,25,.03)");shade.addColorStop(.4,"rgba(3,10,30,.16)");shade.addColorStop(1,"rgba(3,10,30,.35)");
            c.fillStyle=shade;c.fillRect(0,0,w,h);
        }
    }
    Canvas {
        id: celestial
        anchors.fill: parent
        opacity: sky.moonOpacity
        visible: ["rain", "storm", "fog"].indexOf(sky.condition) === -1
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            if (width <= 0 || height <= 0) return;
            const c = getContext("2d"), w = width, h = height, night = !sky.daytime;
            // Keep the moon inset; the larger daytime sun peeks past the right edge.
            const r = night ? Math.min(32, w * .055) : Math.min(64, w * .11);
            const x = night ? w * .64 : w - r * .8;
            const y = night ? Math.min(h * .20, 100) : Math.max(r + 12, Math.min(h * .20, 100));
            c.reset();
            const glow = c.createRadialGradient(x,y,r*.6,x,y,r*3.3);
            glow.addColorStop(0,night ? "rgba(235,243,255,.65)" : "rgba(255,230,155,.6)");
            glow.addColorStop(.35,night ? "rgba(210,224,255,.17)" : "rgba(255,224,151,.13)");
            glow.addColorStop(1,"rgba(210,225,255,0)");
            c.fillStyle=glow;c.fillRect(x-r*3.4,y-r*3.4,r*6.8,r*6.8);
            const orb=c.createRadialGradient(x-r*.3,y-r*.35,1,x,y,r);
            orb.addColorStop(0,night ? "#ffffff" : "#fffbed");
            orb.addColorStop(.7,night ? "#f5f8ff" : "#fff2b8");
            orb.addColorStop(1,night ? "#dce6f5" : "#efcb72");
            c.fillStyle=orb;c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fill();
            if(night) {
                // Irregular, softly feathered lunar maria rather than dark stamped circles.
                for(let i=0;i<20;++i) {
                    const a=i*2.39996, rr=r*(.13+(i%5)*.135);
                    const px=x+Math.cos(a)*rr,py=y+Math.sin(a)*rr;
                    const size=r*(.07+(i%4)*.045);
                    const mark=c.createRadialGradient(px,py,0,px,py,size);
                    mark.addColorStop(0,"rgba(104,124,154,.18)");
                    mark.addColorStop(.6,"rgba(117,135,161,.09)");
                    mark.addColorStop(1,"rgba(133,149,171,0)");
                    c.fillStyle=mark;c.beginPath();c.arc(px,py,size,0,Math.PI*2);c.fill();
                }
                c.strokeStyle="rgba(255,255,255,.65)";c.lineWidth=.8;
                c.beginPath();c.arc(x,y,r-.5,0,Math.PI*2);c.stroke();
            }
        }
    }

}
