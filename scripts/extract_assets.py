import os
import shutil
import numpy as np
from PIL import Image

src_path = os.path.join('assets', 'mockup and logo.png')
if not os.path.exists(src_path):
    print(f'ERROR: {src_path} not found!')
    exit(1)

src_img = Image.open(src_path)
print(f'Loaded source image: {src_path} ({src_img.width}x{src_img.height})')

out_dir = os.path.join('assets', 'extracted')
os.makedirs(out_dir, exist_ok=True)

# Helper function to create transparent matte for dark artwork on light background
def make_transparent_matte(img_crop, bg_color=(251.0, 252.0, 252.0), fg_threshold=180):
    arr = np.array(img_crop).astype(float)
    bg = np.array(bg_color)
    
    # Estimate foreground color from darkest pixels
    diff = np.linalg.norm(arr - bg, axis=2)
    dark_mask = diff > fg_threshold
    if dark_mask.sum() == 0:
        dark_mask = diff > (diff.max() * 0.7)
    fg_mean = arr[dark_mask].mean(axis=0)
    
    bg_lum = bg.mean()
    fg_lum = fg_mean.mean()
    pixel_lum = arr.mean(axis=2)
    
    # Calculate alpha based on luminance difference
    denom = max(bg_lum - fg_lum, 1.0)
    alpha = (bg_lum - pixel_lum) / denom
    alpha = np.clip(alpha, 0.0, 1.0)
    
    # Smooth cutoff for background noise
    alpha[alpha < 0.03] = 0.0
    
    # Recover unmultiplied color
    recovered = np.zeros_like(arr)
    mask = alpha > 0.03
    recovered[mask] = (arr[mask] - (1.0 - alpha[mask, None]) * bg) / alpha[mask, None]
    recovered[~mask] = fg_mean
    recovered = np.clip(recovered, 0, 255)
    
    rgba = np.dstack([recovered, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(rgba, 'RGBA')

# Helper function to create transparent matte for white artwork on dark background
def make_white_transparent_matte(img_crop, bg_color=(0.0, 0.0, 0.0)):
    arr = np.array(img_crop).astype(float)
    bg = np.array(bg_color)
    
    # Foreground is white (255, 255, 255)
    fg_mean = np.array([255.0, 255.0, 255.0])
    
    bg_lum = bg.mean()
    fg_lum = fg_mean.mean()
    pixel_lum = arr.mean(axis=2)
    
    denom = max(fg_lum - bg_lum, 1.0)
    alpha = (pixel_lum - bg_lum) / denom
    alpha = np.clip(alpha, 0.0, 1.0)
    
    alpha[alpha < 0.05] = 0.0
    
    recovered = np.zeros_like(arr)
    mask = alpha > 0.05
    recovered[mask] = (arr[mask] - (1.0 - alpha[mask, None]) * bg) / alpha[mask, None]
    recovered[~mask] = fg_mean
    recovered = np.clip(recovered, 0, 255)
    
    rgba = np.dstack([recovered, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(rgba, 'RGBA')

results = []

def save_asset(name, image, desc):
    extracted_path = os.path.join(out_dir, name)
    root_path = os.path.join('assets', name)
    image.save(extracted_path, 'WEBP', lossless=True)
    # Also copy to assets root
    shutil.copyfile(extracted_path, root_path)
    w, h = image.size
    results.append({
        'filename': name,
        'dimensions': f'{w}x{h} px',
        'format': 'WebP (Lossless)',
        'mode': image.mode,
        'description': desc
    })
    print(f'[OK] Exported {name} ({w}x{h}, {image.mode}) - {desc}')

# -------------------------------------------------------------
# 1. PRIMARY LOGO
# -------------------------------------------------------------
crop_primary = src_img.crop((66, 87, 306, 299))
save_asset('devdeck-logo-primary-solid.webp', crop_primary, 'Primary brand icon (on original light canvas)')
trans_primary = make_transparent_matte(crop_primary)
save_asset('devdeck-logo-primary.webp', trans_primary, 'Primary brand icon (transparent background)')

# -------------------------------------------------------------
# 2. LOGO VARIATIONS
# -------------------------------------------------------------
# Icon Only
crop_icon = src_img.crop((399, 122, 488, 204))
trans_icon = make_transparent_matte(crop_icon)
save_asset('devdeck-logo-icon.webp', trans_icon, 'Logo variation: Icon only (transparent background)')

# Horizontal Lockup (Icon + DevDeck + Tagline)
crop_horiz = src_img.crop((523, 119, 870, 198))
save_asset('devdeck-logo-horizontal-solid.webp', crop_horiz, 'Logo variation: Horizontal lockup (on canvas)')
trans_horiz = make_transparent_matte(crop_horiz)
save_asset('devdeck-logo-horizontal.webp', trans_horiz, 'Logo variation: Horizontal lockup (transparent background)')

# Stacked Lockup (Icon on top of DevDeck + Tagline)
crop_stacked = src_img.crop((933, 73, 1097, 224))
save_asset('devdeck-logo-stacked-solid.webp', crop_stacked, 'Logo variation: Stacked lockup (on canvas)')
trans_stacked = make_transparent_matte(crop_stacked)
save_asset('devdeck-logo-stacked.webp', trans_stacked, 'Logo variation: Stacked lockup (transparent background)')

# Standalone Wordmark (DevDeck + Tagline)
crop_wordmark = src_img.crop((618, 122, 870, 195))
trans_wordmark = make_transparent_matte(crop_wordmark)
save_asset('devdeck-logo-wordmark.webp', trans_wordmark, 'Logo wordmark with tagline (transparent background)')

# Title only 'DevDeck'
crop_title = src_img.crop((618, 122, 870, 180))
trans_title = make_transparent_matte(crop_title)
save_asset('devdeck-logo-wordmark-title-only.webp', trans_title, 'DevDeck bold title wordmark only (transparent background)')

# -------------------------------------------------------------
# 3. WHITE / INVERTED LOGO (FOR DARK BACKGROUNDS)
# -------------------------------------------------------------
# Extract from Dark Mode App Icon
crop_white_icon = src_img.crop((1376, 106, 1472, 196))
# Estimate dark background inside dark icon
bg_dark = np.array(crop_white_icon).astype(float)[:5, :5].mean(axis=(0, 1))
trans_white = make_white_transparent_matte(crop_white_icon, bg_color=bg_dark)
save_asset('devdeck-logo-white-inverted.webp', trans_white, 'Crisp white brand icon mark (transparent background, for dark mode)')

# -------------------------------------------------------------
# 4. APP ICON PREVIEWS (MOCKUPS & SQUIRCLES)
# -------------------------------------------------------------
# Light Mode App Icon (with shadow)
crop_app_light = src_img.crop((1145, 68, 1323, 241))
save_asset('devdeck-mockup-app-icon-light.webp', crop_app_light, 'App icon preview: Light mode (with elevation drop shadow)')

# Dark Mode App Icon (with shadow)
crop_app_dark = src_img.crop((1331, 68, 1508, 241))
save_asset('devdeck-mockup-app-icon-dark.webp', crop_app_dark, 'App icon preview: Dark mode (with elevation drop shadow)')

# Combined App Icon Preview card (both side by side)
crop_app_both = src_img.crop((1140, 65, 1512, 275))
save_asset('devdeck-mockup-app-icon.webp', crop_app_both, 'App icon presentation: Light & Dark mode side-by-side with labels')

# -------------------------------------------------------------
# 5. LOGO USAGE ON BACKGROUND CARDS
# -------------------------------------------------------------
save_asset('devdeck-background-card-white.webp', src_img.crop((984, 381, 1123, 511)), 'Logo on white background card')
save_asset('devdeck-background-card-light-gray.webp', src_img.crop((1112, 381, 1247, 511)), 'Logo on light gray background card')
save_asset('devdeck-background-card-dark-gray.webp', src_img.crop((1252, 381, 1384, 511)), 'Logo on dark gray background card')
save_asset('devdeck-background-card-black.webp', src_img.crop((1368, 381, 1504, 511)), 'Logo on solid black background card')

# -------------------------------------------------------------
# 6. SCALE PREVIEW STRIPS
# -------------------------------------------------------------
crop_scales = src_img.crop((35, 375, 645, 495))
save_asset('devdeck-icon-sizes-preview.webp', crop_scales, 'Icon sizes real scale preview strip (512px down to 16px)')

crop_favicon = src_img.crop((705, 375, 915, 495))
save_asset('devdeck-favicon-preview.webp', crop_favicon, 'Favicon real scale preview strip (32px, 24px, 16px)')

# -------------------------------------------------------------
# 7. CONTEXTUAL DEVICE MOCKUPS
# -------------------------------------------------------------
# Mobile Android Mockup
crop_mobile = src_img.crop((16, 583, 404, 942))
save_asset('devdeck-mockup-mobile-android.webp', crop_mobile, 'Android smartphone home screen mockup with DevDeck and app grid')

# Desktop Windows 11 Mockup
crop_desktop = src_img.crop((423, 583, 867, 942))
save_asset('devdeck-mockup-desktop-windows.webp', crop_desktop, 'Windows 11 desktop mockup with wallpaper, desktop shortcut, and pinned taskbar icon')

# In-App Usage Sidebar Mockup
crop_in_app = src_img.crop((888, 583, 1164, 942))
save_asset('devdeck-mockup-in-app-ui.webp', crop_in_app, 'DevDeck desktop in-app dark theme sidebar command center mockup')

# Browser Tab & Branding Mockup
crop_browser = src_img.crop((1181, 583, 1535, 942))
save_asset('devdeck-mockup-browser-branding.webp', crop_browser, 'Web browser window mockup with devdeck.app URL, tab, and stacked logo')

# -------------------------------------------------------------
# 8. FULL BRAND BOARD PRESENTATION MOCKUP
# -------------------------------------------------------------
save_asset('devdeck-mockup-brand-board.webp', src_img, 'Complete DevDeck master brand board and design system presentation')

print(f'\nTotal extracted assets: {len(results)}')
