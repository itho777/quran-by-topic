import os
from PIL import Image

brain_dir = r"C:\Users\waverider\.gemini\antigravity\brain\ed5c4b9a-6f2d-4fee-af8f-648f5e59f428"
assets_dir = r"C:\Users\waverider\.gemini\antigravity\scratch\tafseer_id\assets\images"
os.makedirs(assets_dir, exist_ok=True)

# Path to original uploaded images
img1_path = os.path.join(brain_dir, "media__1783480401400.png")
img2_path = os.path.join(brain_dir, "media__1783480401411.png")

def make_transparent(img_path, target_bg_color, output_name):
    # Load image and convert to RGBA
    img = Image.open(img_path).convert("RGBA")
    datas = img.getdata()
    
    new_data = []
    # target_bg_color is either 'black' (for dark logo) or 'white' (for light logo)
    for item in datas:
        r, g, b, a = item
        # If it's very close to black or white, make it transparent
        if target_bg_color == 'black':
            # black background: check if R, G, B are all very low
            if r < 30 and g < 30 and b < 30:
                new_data.append((0, 0, 0, 0))
            else:
                new_data.append(item)
        elif target_bg_color == 'white':
            # white background: check if R, G, B are all very high
            if r > 225 and g > 225 and b > 225:
                new_data.append((255, 255, 255, 0))
            else:
                new_data.append(item)
                
    img.putdata(new_data)
    
    # Crop to content bounding box (non-transparent pixels)
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
        
    out_path = os.path.join(assets_dir, output_name)
    img.save(out_path, "PNG")
    print(f"Saved {output_name} with size {img.size} at {out_path}")

# Let's inspect the first image to see if it is the black background one
im1 = Image.open(img1_path)
pixel = im1.getpixel((0, 0))
print(f"Image 1 top-left pixel: {pixel}")
if sum(pixel[:3]) < 100:
    # It's dark
    make_transparent(img1_path, 'black', 'logo_dark.png')
    make_transparent(img2_path, 'white', 'logo_light.png')
else:
    make_transparent(img1_path, 'white', 'logo_light.png')
    make_transparent(img2_path, 'black', 'logo_dark.png')
