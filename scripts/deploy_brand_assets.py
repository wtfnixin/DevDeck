import os
import sys
from PIL import Image, ImageDraw

# Anchor all operations to project root regardless of current working directory
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def resolve_path(*paths):
    return os.path.join(PROJECT_ROOT, *paths)

def create_app_icon(size, padding_ratio=0.18, corner_radius_ratio=0.22):
    """Creates a high-res rounded dark tile icon with the DevDeck icon mark centered."""
    icon_path = resolve_path('assets', 'extracted', 'devdeck-logo-icon.webp')
    if not os.path.exists(icon_path):
        icon_path = resolve_path('assets', 'devdeck-logo-icon.webp')
        
    with Image.open(icon_path) as im:
        icon_mark = im.convert('RGBA')
    
    # Target canvas
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    radius = int(size * corner_radius_ratio)
    # Background squircle with dark brand color (#171B1E)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, fill=(23, 27, 30, 255))
    
    # Calculate inner icon size
    inner_max = int(size * (1.0 - 2 * padding_ratio))
    w, h = icon_mark.size
    aspect = w / h
    if aspect > 1:
        new_w = inner_max
        new_h = int(inner_max / aspect)
    else:
        new_h = inner_max
        new_w = int(inner_max * aspect)
        
    scaled_icon = icon_mark.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    offset_x = (size - new_w) // 2
    offset_y = (size - new_h) // 2
    img.alpha_composite(scaled_icon, (offset_x, offset_y))
    return img

def create_foreground_icon(size, padding_ratio=0.25):
    """Creates transparent foreground icon for Android adaptive icon."""
    icon_path = resolve_path('assets', 'extracted', 'devdeck-logo-icon.webp')
    if not os.path.exists(icon_path):
        icon_path = resolve_path('assets', 'devdeck-logo-icon.webp')
        
    with Image.open(icon_path) as im:
        icon_mark = im.convert('RGBA')
        
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    inner_max = int(size * (1.0 - 2 * padding_ratio))
    w, h = icon_mark.size
    aspect = w / h
    if aspect > 1:
        new_w = inner_max
        new_h = int(inner_max / aspect)
    else:
        new_h = inner_max
        new_w = int(inner_max * aspect)
        
    scaled_icon = icon_mark.resize((new_w, new_h), Image.Resampling.LANCZOS)
    offset_x = (size - new_w) // 2
    offset_y = (size - new_h) // 2
    img.alpha_composite(scaled_icon, (offset_x, offset_y))
    return img

def main():
    print("[Deploy] Deploying brand assets across all project targets...")
    print(f"         Project root: {PROJECT_ROOT}")
    
    # 1. Desktop Agent assets
    print("1. Updating Desktop Agent public icons...")
    desktop_public = resolve_path('desktop-agent', 'public')
    os.makedirs(desktop_public, exist_ok=True)
    
    # Desktop icon (512x512)
    desktop_icon = create_app_icon(512)
    desktop_icon.save(os.path.join(desktop_public, 'icon.png'), 'PNG')
    
    # Copy active brand icon to desktop public
    icon_src = resolve_path('assets', 'extracted', 'devdeck-logo-icon.webp')
    if not os.path.exists(icon_src):
        icon_src = resolve_path('assets', 'devdeck-logo-icon.webp')
    if os.path.exists(icon_src):
        dst = os.path.join(desktop_public, 'devdeck-logo-icon.webp')
        with open(icon_src, 'rb') as f_in, open(dst, 'wb') as f_out:
            f_out.write(f_in.read())
            
    # 2. Web icons
    print("2. Updating Web icons & favicons...")
    web_dir = resolve_path('web')
    web_icons = resolve_path('web', 'icons')
    os.makedirs(web_icons, exist_ok=True)
    
    # Web favicon (64x64) and PWA icons
    create_app_icon(64, padding_ratio=0.15).save(os.path.join(web_dir, 'favicon.png'), 'PNG')
    create_app_icon(192).save(os.path.join(web_icons, 'Icon-192.png'), 'PNG')
    create_app_icon(512).save(os.path.join(web_icons, 'Icon-512.png'), 'PNG')
    create_app_icon(192, padding_ratio=0.28, corner_radius_ratio=0).save(os.path.join(web_icons, 'Icon-maskable-192.png'), 'PNG')
    create_app_icon(512, padding_ratio=0.28, corner_radius_ratio=0).save(os.path.join(web_icons, 'Icon-maskable-512.png'), 'PNG')
    
    # 3. Flutter / Android app_icon.png
    print("3. Updating assets/app_icon.png...")
    app_icon_1024 = create_app_icon(1024)
    app_icon_1024.save(resolve_path('assets', 'app_icon.png'), 'PNG')
    
    # 4. Android native mipmap and drawable launcher icons
    print("4. Updating Android mipmap launcher icons...")
    android_res = resolve_path('android', 'app', 'src', 'main', 'res')
    mipmap_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    
    for folder, size in mipmap_sizes.items():
        folder_path = os.path.join(android_res, folder)
        if os.path.exists(folder_path):
            icon_img = create_app_icon(size)
            icon_img.save(os.path.join(folder_path, 'ic_launcher.png'), 'PNG')
            
    # Android adaptive icon foregrounds
    drawable_sizes = {
        'drawable-mdpi': 108,
        'drawable-hdpi': 162,
        'drawable-xhdpi': 216,
        'drawable-xxhdpi': 324,
        'drawable-xxxhdpi': 432,
    }
    for folder, size in drawable_sizes.items():
        folder_path = os.path.join(android_res, folder)
        if os.path.exists(folder_path):
            fg_img = create_foreground_icon(size)
            fg_img.save(os.path.join(folder_path, 'ic_launcher_foreground.png'), 'PNG')
            
    print("[OK] All icons and logos successfully deployed!")

if __name__ == '__main__':
    main()
