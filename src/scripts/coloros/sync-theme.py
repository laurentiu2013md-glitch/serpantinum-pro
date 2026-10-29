#!/usr/bin/env python3
"""Write user-owned GTK3/GTK4/Qt6 palettes from the current Matugen accents."""
from pathlib import Path
import json,configparser,subprocess,os
HOME=Path.home()
def write(path,text):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    if path.exists() and path.read_text()==text:return
    temp=path.with_name(path.name+'.coloros-tmp');temp.write_text(text);temp.replace(path)
def main():
    source=HOME/'.local/state/serpantinum/qs_matugen_colors.json'
    c=json.loads(source.read_text()); raw=c.get('base','#252830')
    settings=HOME/'.config/serpantinum/settings.json'
    mode=json.loads(settings.read_text()).get('theme',{}).get('mode') if settings.exists() else None
    grayMode=mode=='gray'
    light=mode=='light' or (mode not in ['dark','gray'] and sum(int(raw[i:i+2],16)*w for i,w in [(1,.2126),(3,.7152),(5,.0722)])>153)
    n=dict(zip(['base','mantle','crust','surface0','surface1','surface2','text','subtext0'],
        ['#e6e8ec','#dde0e5','#d4d8df','#f0f1f4','#d7dce3','#c3cbd5','#1b1f28','#505866'] if light else
        ['#252830','#20232a','#191c22','#30343e','#3d4350','#505967','#ffffff','#ffffff']))
    if grayMode:
        n.update(dict(zip(['base','mantle','crust','surface0','surface1','surface2','text','subtext0'],
                          ['#808080','#787878','#707070','#888888','#949494','#a0a0a0','#101010','#181818'])))
    accent=c.get('mauve',c.get('blue','#725188'));onaccent='#ffffff' if sum(int(accent[i:i+2],16)*w for i,w in [(1,.2126),(3,.7152),(5,.0722)])<140 else '#181b22'
    if not light: onaccent='#ffffff'
    defs={'accent_color':accent,'accent_bg_color':accent,'accent_fg_color':onaccent,
        'window_bg_color':n['base'],'window_fg_color':n['text'],'view_bg_color':n['surface0'],'view_fg_color':n['text'],
        'headerbar_bg_color':n['mantle'],'headerbar_fg_color':n['text'],'headerbar_backdrop_color':n['base'],
        'headerbar_border_color':n['surface2'],'popover_bg_color':n['surface0'],'popover_fg_color':n['text'],
        'dialog_bg_color':n['base'],'dialog_fg_color':n['text'],'card_bg_color':n['surface0'],'card_fg_color':n['text'],
        'sidebar_bg_color':n['mantle'],'sidebar_backdrop_color':n['base'],'sidebar_fg_color':n['text'],
        'secondary_sidebar_bg_color':n['crust'],'secondary_sidebar_fg_color':n['text'],
        'error_color':c.get('red','#ba1a1a'),'error_bg_color':c.get('red','#ba1a1a'),'error_fg_color':'#ffffff',
        'borders':n['surface2'],'theme_bg_color':n['base'],'theme_fg_color':n['text'],'theme_base_color':n['surface0'],
        'theme_text_color':n['text'],'theme_selected_bg_color':accent,'theme_selected_fg_color':onaccent}
    css='/* ColorOS user palette: generated; accents from Matugen. */\n'+''.join(f'@define-color {k} {v};\n' for k,v in defs.items())
    for v in [3,4]:
        directory=HOME/f'.config/gtk-{v}.0'
        extra=''
        if v==4:extra='\n:root {\n'+''.join(f'  --{k.replace("_","-")}: @{k};\n' for k in defs if not k.startswith('theme_'))+'}\n'
        write(directory/'coloros-colors.css',css+extra)
        usercss=directory/'gtk.css';original=usercss.read_text() if usercss.exists() else ''
        line="@import 'coloros-colors.css';"
        if line not in original:write(usercss,original+'\n'+line+'\n')
        settings=configparser.ConfigParser(interpolation=None);settings.optionxform=str
        settings.read(directory/'settings.ini');settings.setdefault('Settings',{})
        settings['Settings']['gtk-application-prefer-dark-theme']='false' if light else 'true'
        import io
        out=io.StringIO();settings.write(out,space_around_delimiters=False);write(directory/'settings.ini',out.getvalue())
    palette=[n['text'],n['surface0'],n['surface0'],n['surface2'],n['surface1'],n['mantle'],n['text'],n['text'],n['text'],n['surface0'],n['base'],n['mantle'],accent,onaccent,accent,c.get('pink',accent),n['surface0'],n['text'],n['surface0'],n['text'],('#80000000' if light else '#ffffffff')]
    rgba=lambda value: '#ff'+value[1:] if len(value)==7 else value
    colors=', '.join(map(rgba,palette));disabled=palette.copy()
    for i in [0,6,8,13,19]:disabled[i]=n['subtext0']
    scheme='[ColorScheme]\nactive_colors='+colors+'\ninactive_colors='+colors+'\ndisabled_colors='+', '.join(map(rgba,disabled))+'\n'
    schemefile=HOME/'.config/qt6ct/colors/ColorOS.conf';write(schemefile,scheme)
    config=HOME/'.config/qt6ct/qt6ct.conf';qt=configparser.ConfigParser(interpolation=None);qt.optionxform=str;qt.read(config);qt.setdefault('Appearance',{})
    qt['Appearance'].update({'style':'Breeze','custom_palette':'true','color_scheme_path':str(schemefile),'icon_theme':'Serpantinum-Matugen','standard_dialogs':'default'})
    import io
    out=io.StringIO();qt.write(out,space_around_delimiters=False);write(config,out.getvalue())
    # Nautilus uses Kitty's configured gray and native background opacity.
    import re
    kitty=HOME/'.config/kitty'
    kittycolors=(kitty/'colors.conf').read_text() if (kitty/'colors.conf').exists() else ''
    kittyconfig=(kitty/'kitty.conf').read_text() if (kitty/'kitty.conf').exists() else ''
    bg=re.search(r'^background\s+(#[0-9a-fA-F]{6})\b',kittycolors,re.M)
    opacity=re.search(r'^background_opacity\s+([0-9.]+)',kittyconfig,re.M)
    gray=bg.group(1) if bg else '#b3b3b3'
    amount=max(0,min(1,float(opacity.group(1)))) if opacity else .5
    foreground='#101010' if light or grayMode else '#ffffff'
    write(HOME/'.config/gtk-4.0/nautilus-colors.css',
        '/* Match Kitty gray/opacity; keep dark-mode labels white. */\n'
        +f'@define-color nautilus_bg alpha({gray}, {amount});\n'
        +f'@define-color nautilus_fg {foreground};\n')
    stylesheet=Path(__file__).with_name('nautilus.css')
    if stylesheet.exists():
        write(HOME/'.config/gtk-4.0/coloros-nautilus.css',stylesheet.read_text())
        usercss=HOME/'.config/gtk-4.0/gtk.css'
        original=usercss.read_text() if usercss.exists() else ''
        line="@import 'coloros-nautilus.css';"
        if line not in original:write(usercss,original.rstrip()+'\n'+line+'\n')
    # Keep terminal text white in dark mode without changing its gray background.
    if kittyconfig:
        line='include ~/.config/kitty/coloros-text.conf'
        if line not in kittyconfig: write(kitty/'kitty.conf',kittyconfig.rstrip()+'\n'+line+'\n')
        write(kitty/'coloros-text.conf','foreground '+foreground+'\n')
        subprocess.run(['pkill','-SIGUSR1','-x','kitty'],capture_output=True)
    # GNOME's preference is also consumed by libadwaita and portals.
    subprocess.run(['gsettings','set','org.gnome.desktop.interface','color-scheme','prefer-light' if light else 'prefer-dark'],capture_output=True)
    print(json.dumps({'mode':'gray' if grayMode else 'light' if light else 'dark','accent':accent,'gtk':[3,4],'qt6':'Breeze/qt6ct'}))
if __name__=='__main__':main()
