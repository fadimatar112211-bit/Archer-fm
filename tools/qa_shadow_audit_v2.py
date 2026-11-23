#!/usr/bin/env python3
"""
Shadow Character QA Audit Script v2 - التصحيحات:
- أسماء الإطارات في JSON للأطلاس تكون بدون امتداد .png (هذا هو الشكل الطبيعي)
- سكريبت بلندر مصحح للإصدار 4.0.2
"""
import json
import os
import sys
from PIL import Image
from collections import defaultdict

BASE_DIR = "assets/heroes/shadow"
RENDER_DIR = os.path.join(BASE_DIR, "renders")
ATLAS_DIR = os.path.join(RENDER_DIR, "atlases")
MANIFEST_PATH = os.path.join(RENDER_DIR, "shadow_manifest.json")
BLEND_PATH = os.path.join(BASE_DIR, "source", "shadow_source.blend")

MOVEMENTS = ["idle", "walk", "run", "attack", "skill", "dodge", "hit", "death"]
DIRECTIONS = ["e", "n", "ne", "nw", "s", "se", "sw", "w"]

results = {
    "files_inspected": [],
    "png_tests": [],
    "atlas_tests": [],
    "manifest_tests": [],
    "blender_tests": [],
    "errors": [],
    "warnings": [],
    "summary": {},
}

def log_test(category, test_name, passed, detail=""):
    results[category].append({
        "test": test_name,
        "passed": passed,
        "detail": detail,
    })
    status = "PASS" if passed else "FAIL"
    print(f"  [{status}] {test_name}: {detail}")

def log_error(msg):
    results["errors"].append(msg)
    print(f"  [ERROR] {msg}")

def log_warning(msg):
    results["warnings"].append(msg)
    print(f"  [WARN]  {msg}")

# =========================================================================
# 1. فحص جميع ملفات PNG
# =========================================================================
print("\n" + "=" * 70)
print("المرحلة 1: فحص جميع ملفات PNG (8 حركات × 8 اتجاهات)")
print("=" * 70)

expected_frame_counts = {
    "idle": 5,
    "walk": 9,
    "run": 9,
    "attack": 7,
    "skill": 9,
    "dodge": 9,
    "hit": 5,
    "death": 9,
}

png_total = 0
png_passed = 0
png_failed = 0

for movement in MOVEMENTS:
    for direction in DIRECTIONS:
        movement_dir = os.path.join(RENDER_DIR, movement, direction)
        expected_count = expected_frame_counts.get(movement, 0)
        
        if not os.path.isdir(movement_dir):
            log_error(f"مجلد غير موجود: {movement_dir}")
            continue
        
        png_files = sorted([f for f in os.listdir(movement_dir) if f.endswith(".png")])
        actual_count = len(png_files)
        
        count_ok = actual_count == expected_count
        if not count_ok:
            log_error(f"{movement}_{direction}: عدد الإطارات {actual_count} != المتوقع {expected_count}")
            png_failed += 1
        else:
            png_passed += 1
        
        for idx, png_file in enumerate(png_files):
            png_total += 1
            png_path = os.path.join(movement_dir, png_file)
            
            expected_name = f"shadow_{movement}_{direction}_{idx:03d}.png"
            name_ok = png_file == expected_name
            if not name_ok:
                log_error(f"{png_path}: اسم الملف '{png_file}' != المتوقع '{expected_name}'")
                png_failed += 1
                continue
            
            try:
                with Image.open(png_path) as img:
                    img.load()
                    width, height = img.size
                    mode = img.mode
                    
                    dim_ok = width == 192 and height == 192
                    if not dim_ok:
                        log_error(f"{png_path}: الأبعاد {width}x{height} != 192x192")
                        png_failed += 1
                        continue
                    
                    has_alpha = mode in ("RGBA", "LA") or (mode == "P" and "transparency" in img.info)
                    if not has_alpha:
                        log_warning(f"{png_path}: لا قناة شفافة واضحة (mode={mode})")
                    
                    if mode == "RGBA":
                        alpha = img.getchannel("A")
                        extrema = alpha.getextrema()
                        if extrema[1] == 0:
                            log_warning(f"{png_path}: جميع بكسلات الشفافية = 0")
                    
                    png_passed += 1
                    
            except Exception as e:
                log_error(f"{png_path}: تعذر فتح الملف - {e}")
                png_failed += 1
        
        results["files_inspected"].append({
            "movement": movement,
            "direction": direction,
            "path": movement_dir,
            "expected_count": expected_count,
            "actual_count": actual_count,
            "count_match": count_ok,
        })

print(f"\nإجمالي ملفات PNG المفحوصة: {png_total}")
print(f"نجح: {png_passed} | فشل: {png_failed}")

# =========================================================================
# 2. فحص ملفات الأ틀اس (PNG + JSON)
# =========================================================================
print("\n" + "=" * 70)
print("المرحلة 2: فحص ملفات الأ틀اس (PNG و JSON)")
print("=" * 70)

atlas_total = 0
atlas_passed = 0
atlas_failed = 0

for movement in MOVEMENTS:
    for direction in DIRECTIONS:
        atlas_name = f"{movement}_{direction}"
        atlas_png = os.path.join(ATLAS_DIR, f"{atlas_name}.png")
        atlas_json = os.path.join(ATLAS_DIR, f"{atlas_name}.json")
        
        png_exists = os.path.isfile(atlas_png)
        json_exists = os.path.isfile(atlas_json)
        
        if not png_exists:
            log_error(f"أ틀اس PNG مفقود: {atlas_png}")
            atlas_failed += 1
            continue
        if not json_exists:
            log_error(f"أ틀اس JSON مفقود: {atlas_json}")
            atlas_failed += 1
            continue
        
        atlas_total += 2
        
        try:
            with Image.open(atlas_png) as atlas_img:
                atlas_img.load()
                aw, ah = atlas_img.size
                atlas_mode = atlas_img.mode
                atlas_has_alpha = atlas_mode in ("RGBA", "LA")
                
                if not atlas_has_alpha:
                    log_warning(f"{atlas_png}: لا قناة شفافة (mode={atlas_mode})")
                
                atlas_passed += 1
        except Exception as e:
            log_error(f"{atlas_png}: تعذر فتح - {e}")
            atlas_failed += 1
            continue
        
        try:
            with open(atlas_json, "r", encoding="utf-8") as f:
                atlas_meta = json.load(f)
            
            has_frames = "frames" in atlas_meta
            if not has_frames:
                log_error(f"{atlas_json}: حقل 'frames' مفقود")
                atlas_failed += 1
                continue
            
            frames = atlas_meta["frames"]
            frame_count_in_meta = len(frames)
            expected_png_count = expected_frame_counts.get(movement, 0)
            
            if frame_count_in_meta != expected_png_count:
                log_error(f"{atlas_json}: عدد الإطارات في metadata {frame_count_in_meta} != المتوقع {expected_png_count}")
                atlas_failed += 1
                continue
            
            frame_names_in_meta = []
            for frame_name, frame_data in frames.items():
                frame_names_in_meta.append(frame_name)
                
                required_frame_keys = {"frame", "sourceSize", "spriteSourceSize"}
                missing_keys = required_frame_keys - set(frame_data.keys())
                if missing_keys:
                    log_error(f"{atlas_json}: إطار '{frame_name}' يفتقر إلى حقول: {missing_keys}")
                    atlas_failed += 1
                
                rect = frame_data.get("frame", {})
                if "w" not in rect or "h" not in rect:
                    log_error(f"{atlas_json}: إطار '{frame_name}' يفتقر إلى أبعاد frame.rect")
                    atlas_failed += 1
            
            atlas_passed += 1
            
            # ملاحظة: أسماء الإطارات في JSON تكون بدون امتداد .png (مثل "shadow_idle_e_000")
            # لذلك نقارن مع الأسماء بدون الامتداد
            expected_frame_names_no_ext = [
                f"shadow_{movement}_{direction}_{i:03d}"
                for i in range(expected_png_count)
            ]
            
            missing_in_meta = set(expected_frame_names_no_ext) - set(frame_names_in_meta)
            extra_in_meta = set(frame_names_in_meta) - set(expected_frame_names_no_ext)
            
            if missing_in_meta:
                log_error(f"{atlas_json}: إطارات مفقودة في metadata: {sorted(missing_in_meta)}")
                atlas_failed += 1
            if extra_in_meta:
                log_warning(f"{atlas_json}: إطارات إضافية في metadata: {sorted(extra_in_meta)}")
            
        except json.JSONDecodeError as e:
            log_error(f"{atlas_json}: JSON غير صالح - {e}")
            atlas_failed += 1
        except Exception as e:
            log_error(f"{atlas_json}: خطأ غير متوقع - {e}")
            atlas_failed += 1

print(f"\nإجمالي ملفات الأ틀اس المفحوصة: {atlas_total}")
print(f"نجح: {atlas_passed} | فشل: {atlas_failed}")

# =========================================================================
# 3. فحص ملف manifest
# =========================================================================
print("\n" + "=" * 70)
print("المرحلة 3: فحص ملف shadow_manifest.json")
print("=" * 70)

manifest_errors = 0

try:
    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    
    required_top_keys = {"schema_version", "hero_id", "frame_size", "pivot", "atlases", "animations", "source"}
    missing_top = required_top_keys - set(manifest.keys())
    if missing_top:
        log_error(f"manifest: حقود أعلى مفقودة: {missing_top}")
        manifest_errors += 1
    
    if manifest.get("hero_id") != "shadow":
        log_error(f"manifest: hero_id = '{manifest.get('hero_id')}' != 'shadow'")
        manifest_errors += 1
    
    fs = manifest.get("frame_size", {})
    if fs.get("width") != 192 or fs.get("height") != 192:
        log_error(f"manifest: frame_size = {fs} != 192x192")
        manifest_errors += 1
    
    pivot = manifest.get("pivot", {})
    if pivot.get("x") != 0.5 or pivot.get("y") != 0.86:
        log_error(f"manifest: pivot = {pivot} != x:0.5, y:0.86")
        manifest_errors += 1
    
    anim_keys = set(manifest.get("animations", {}).keys())
    expected_anim_keys = set()
    for m in MOVEMENTS:
        for d in DIRECTIONS:
            expected_anim_keys.add(f"{m}_{d}")
    
    missing_anims = expected_anim_keys - anim_keys
    extra_anims = anim_keys - expected_anim_keys
    
    if missing_anims:
        log_error(f"manifest: حركات مفقودة: {sorted(missing_anims)}")
        manifest_errors += 1
    if extra_anims:
        log_warning(f"manifest: حركات إضافية: {sorted(extra_anims)}")
    
    for anim_key, anim_data in manifest.get("animations", {}).items():
        parts = anim_key.rsplit("_", 1)
        if len(parts) != 2:
            log_error(f"manifest: مفتاح أنيميشن غير صالح '{anim_key}'")
            manifest_errors += 1
            continue
        
        movement, direction = parts
        
        for req_key in ("loop", "frame_duration_ms", "frames", "events"):
            if req_key not in anim_data:
                log_error(f"manifest: أنيميشن '{anim_key}' يفتقر إلى '{req_key}'")
                manifest_errors += 1
        
        frames_list = anim_data.get("frames", [])
        expected_count = expected_frame_counts.get(movement, 0)
        if len(frames_list) != expected_count:
            log_error(f"manifest: أنيميشن '{anim_key}' يحتوي على {len(frames_list)} إطار != المتوقع {expected_count}")
            manifest_errors += 1
        
        expected_frame_names = [f"shadow_{movement}_{direction}_{i:03d}" for i in range(expected_count)]
        actual_frame_names = frames_list
        if actual_frame_names != expected_frame_names:
            log_error(f"manifest: أنيميشن '{anim_key}' تسلسل أسماء الإطارات غير متطابق")
            manifest_errors += 1
    
    manifest_atlases = manifest.get("atlases", [])
    actual_atlas_files = set()
    for m in MOVEMENTS:
        for d in DIRECTIONS:
            actual_atlas_files.add(f"atlases/{m}_{d}.png")
            actual_atlas_files.add(f"atlases/{m}_{d}.json")
    
    manifest_atlas_images = {a.get("image", "") for a in manifest_atlases}
    manifest_atlas_metas = {a.get("meta", "") for a in manifest_atlases}
    
    missing_from_manifest = actual_atlas_files - manifest_atlas_images - manifest_atlas_metas
    if missing_from_manifest:
        log_error(f"manifest: ملفات أ틀اس غير مدرجة: {sorted(missing_from_manifest)}")
        manifest_errors += 1
    
    if manifest_errors == 0:
        log_test("manifest_tests", "manifest الهيكل العام", True, "جميع الحقول الأساسية صحيحة")
    else:
        log_test("manifest_tests", "manifest الهيكل العام", False, f"{manifest_errors} خطأ")

except FileNotFoundError:
    log_error(f"manifest غير موجود: {MANIFEST_PATH}")
    manifest_errors = 1
except json.JSONDecodeError as e:
    log_error(f"manifest JSON غير صالح: {e}")
    manifest_errors = 1
except Exception as e:
    log_error(f"manifest خطأ غير متوقع: {e}")
    manifest_errors = 1

# =========================================================================
# 4. فحص ملف Blender (إذا كان متوفراً)
# =========================================================================
print("\n" + "=" * 70)
print("المرحلة 4: فحص ملف shadow_source.blend باستخدام Blender")
print("=" * 70)

BLENDER_AVAILABLE = os.path.isfile("/usr/bin/blender")
print(f"Blender متوفر: {BLENDER_AVAILABLE}")
print(f"مسار الملف: {BLEND_PATH}")
print(f"الملف موجود: {os.path.isfile(BLEND_PATH)}")

blender_result = {"available": BLENDER_AVAILABLE, "file_exists": os.path.isfile(BLEND_PATH), "inspected": False, "details": {}}

if BLENDER_AVAILABLE and os.path.isfile(BLEND_PATH):
    blender_check_script = '''
import bpy
import json
import sys

results = {}

bpy.ops.wm.open_mainfile(filepath=sys.argv[-1])

armatures = [obj for obj in bpy.data.objects if obj.type == 'ARMATURE']
results["armature_count"] = len(armatures)
results["armature_names"] = [obj.name for obj in armatures]

for arm_obj in armatures:
    arm = arm_obj.data
    results[f"armature_{arm_obj.name}_bones"] = len(arm.bones)
    results[f"armature_{arm_obj.name}_bone_names"] = [b.name for b in arm.bones]

meshes = [obj for obj in bpy.data.objects if obj.type == 'MESH']
results["mesh_count"] = len(meshes)
results["mesh_names"] = [obj.name for obj in meshes]

for mesh_obj in meshes:
    modifiers = [mod.type for mod in mesh_obj.modifiers]
    has_armature_mod = 'ARMATURE' in modifiers
    results[f"mesh_{mesh_obj.name}_has_armature_modifier"] = has_armature_mod
    results[f"mesh_{mesh_obj.name}_modifiers"] = modifiers

    if mesh_obj.vertex_groups:
        results[f"mesh_{mesh_obj.name}_vertex_groups"] = len(mesh_obj.vertex_groups)
        results[f"mesh_{mesh_obj.name}_vertex_group_names"] = [vg.name for vg in mesh_obj.vertex_groups]

actions = bpy.data.actions
results["action_count"] = len(actions)
results["action_names"] = [act.name for act in actions]

for act in actions:
    results[f"action_{act.name}_frame_range"] = [act.frame_range[0], act.frame_range[1]]
    results[f"action_{act.name}_fcurves"] = len(act.fcurves)

cameras = [obj for obj in bpy.data.objects if obj.type == 'CAMERA']
results["camera_count"] = len(cameras)
results["camera_names"] = [obj.name for obj in cameras]

print("BLENDER_QA_RESULT_START")
print(json.dumps(results, indent=2, default=str))
print("BLENDER_QA_RESULT_END")
'''

    script_path = "/tmp/opencode/blender_check_shadow_v2.py"
    with open(script_path, "w") as f:
        f.write(blender_check_script)

    import subprocess
    try:
        proc = subprocess.run(
            ["blender", "--background", "--python", script_path, BLEND_PATH],
            capture_output=True, text=True, timeout=120
        )
        output = proc.stdout
        
        start_marker = "BLENDER_QA_RESULT_START"
        end_marker = "BLENDER_QA_RESULT_END"
        
        if start_marker in output and end_marker in output:
            start_idx = output.index(start_marker) + len(start_marker)
            end_idx = output.index(end_marker)
            json_str = output[start_idx:end_idx].strip()
            blender_data = json.loads(json_str)
            blender_result["inspected"] = True
            blender_result["details"] = blender_data
            
            print(f"عدد ה Armatures: {blender_data.get('armature_count', 'N/A')}")
            print(f"أسماء ה Armatures: {blender_data.get('armature_names', 'N/A')}")
            print(f"عدد الميشات: {blender_data.get('mesh_count', 'N/A')}")
            print(f"أسماء الميشات: {blender_data.get('mesh_names', 'N/A')}")
            print(f"عدد الحركات (Actions): {blender_data.get('action_count', 'N/A')}")
            print(f"أسماء الحركات: {blender_data.get('action_names', 'N/A')}")
            print(f"عدد الكاميرات: {blender_data.get('camera_count', 'N/A')}")
            
            if blender_data.get("armature_count", 0) == 0:
                log_error("Blender: لا يوجد Armature في الملف")
            else:
                log_test("blender_tests", "وجود Armature", True, f"{blender_data['armature_count']} Armature(s)")
                for arm_obj in armatures if False else []:
                    pass
                # عرض تفاصيل العظام
                for key in blender_data:
                    if key.startswith("armature_") and key.endswith("_bones"):
                        arm_name = key.replace("armature_", "").replace("_bones", "")
                        print(f"  عظام {arm_name}: {blender_data[key]}")
                        bn_key = f"armature_{arm_name}_bone_names"
                        if bn_key in blender_data:
                            print(f"  أسماء العظام: {blender_data[bn_key]}")
            
            if blender_data.get("action_count", 0) == 0:
                log_error("Blender: لا توجد حركات محفوظة (Keyframes/Actions)")
            else:
                log_test("blender_tests", "وجود Keyframes/Actions", True, f"{blender_data['action_count']} Action(s)")
                for key in blender_data:
                    if key.startswith("action_") and key.endswith("_frame_range"):
                        act_name = key.replace("action_", "").replace("_frame_range", "")
                        fr = blender_data[key]
                        fc_key = f"action_{act_name}_fcurves"
                        print(f"  حركة '{act_name}': الإطار {fr[0]}->{fr[1]}, منحنيات {blender_data.get(fc_key, 'N/A')}")
            
            mesh_with_armature = sum(1 for k, v in blender_data.items() if k.startswith("mesh_") and k.endswith("_has_armature_modifier") and v)
            if mesh_with_armature == 0:
                log_warning("Blender: لا يوجد ميش مرتبط بالعظام عبر Armature Modifier")
            else:
                log_test("blender_tests", "ربط الميش بالعظام", True, f"{mesh_with_armature} ميش مرتبط")
            
        else:
            log_error("Blender: تعذر تحليل مخرجات الفحص")
            print(output[:3000] if output else "لا يوجد مخرج")
            
    except subprocess.TimeoutExpired:
        log_error("Blender: انتهت المهلة الزمنية (120 ثانية)")
    except Exception as e:
        log_error(f"Blender: خطأ غير متوقع - {e}")
else:
    if not BLENDER_AVAILABLE:
        log_warning("Blender غير متوفر في النظام - لا يمكن فحص shadow_source.blend")
    if not os.path.isfile(BLEND_PATH):
        log_error(f"ملف Blender غير موجود: {BLEND_PATH}")

results["blender"] = blender_result

# =========================================================================
# 5. إنشاء Contact Sheets
# =========================================================================
print("\n" + "=" * 70)
print("المرحلة 5: إنشاء Contact Sheets لمعاينة الحركات والاتجاهات")
print("=" * 70)

QA_DIR = "QA_shadow_audit"
CONTACT_DIR = os.path.join(QA_DIR, "contact_sheets")
os.makedirs(CONTACT_DIR, exist_ok=True)

contact_sheets_created = []

for movement in MOVEMENTS:
    direction_images = []
    direction_labels = []
    
    for direction in DIRECTIONS:
        movement_dir = os.path.join(RENDER_DIR, movement, direction)
        png_files = sorted([f for f in os.listdir(movement_dir) if f.endswith(".png")])
        
        if not png_files:
            continue
        
        first_frame = Image.open(os.path.join(movement_dir, png_files[0])).convert("RGBA")
        direction_images.append(first_frame)
        direction_labels.append(f"{movement}_{direction}")
    
    if not direction_images:
        continue
    
    img_w, img_h = direction_images[0].size
    sheet_w = img_w * 4 + 40
    sheet_h = img_h * 2 + 60
    
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (30, 30, 30, 255))
    
    for idx, (img, label) in enumerate(zip(direction_images, direction_labels)):
        row = idx // 4
        col = idx % 4
        x = 10 + col * (img_w + 10)
        y = 10 + row * (img_h + 40)
        sheet.paste(img, (x, y))
    
    sheet_path = os.path.join(CONTACT_DIR, f"contact_sheet_{movement}.png")
    sheet.save(sheet_path)
    contact_sheets_created.append(sheet_path)
    print(f"تم إنشاء: {sheet_path}")

all_frames = []
all_labels = []
for movement in MOVEMENTS:
    for direction in DIRECTIONS:
        movement_dir = os.path.join(RENDER_DIR, movement, direction)
        png_files = sorted([f for f in os.listdir(movement_dir) if f.endswith(".png")])
        if png_files:
            img = Image.open(os.path.join(movement_dir, png_files[0])).convert("RGBA")
            img.thumbnail((96, 96), Image.LANCZOS)
            all_frames.append(img)
            all_labels.append(f"{movement}_{direction}")

if all_frames:
    thumb_w, thumb_h = all_frames[0].size
    cols = 8
    rows = (len(all_frames) + cols - 1) // cols
    sheet_w = thumb_w * cols + 20
    sheet_h = thumb_h * rows + 40
    
    full_sheet = Image.new("RGBA", (sheet_w, sheet_h), (20, 20, 20, 255))
    
    for idx, (img, label) in enumerate(zip(all_frames, all_labels)):
        row = idx // cols
        col = idx % cols
        x = 10 + col * (thumb_w + 5)
        y = 10 + row * (thumb_h + 5)
        full_sheet.paste(img, (x, y))
    
    full_sheet_path = os.path.join(CONTACT_DIR, "contact_sheet_all_shadow.png")
    full_sheet.save(full_sheet_path)
    contact_sheets_created.append(full_sheet_path)
    print(f"تم إنشاء: {full_sheet_path}")

results["contact_sheets"] = contact_sheets_created

# =========================================================================
# 6. ملخص النتائج
# =========================================================================
print("\n" + "=" * 70)
print("المرحلة 6: ملخص نتائج التدقيق")
print("=" * 70)

total_png = png_passed + png_failed
total_atlas = atlas_passed + atlas_failed

results["summary"] = {
    "png_total": total_png,
    "png_passed": png_passed,
    "png_failed": png_failed,
    "atlas_total": total_atlas,
    "atlas_passed": atlas_passed,
    "atlas_failed": atlas_failed,
    "manifest_errors": manifest_errors,
    "blender_available": BLENDER_AVAILABLE,
    "blender_inspected": blender_result["inspected"],
    "contact_sheets_created": len(contact_sheets_created),
    "errors_count": len(results["errors"]),
    "warnings_count": len(results["warnings"]),
}

print(f"ملفات PNG: {png_passed}/{total_png} ناجحة")
print(f"ملفات أطلاس: {atlas_passed}/{total_atlas} ناجحة")
print(f"أخطاء manifest: {manifest_errors}")
print(f"فحص Blender: {'تم' if blender_result['inspected'] else 'غير متوفر/غير ممكن'}")
print(f"أوراق الاتصال: {len(contact_sheets_created)}")
print(f"الأخطاء الإجمالية: {len(results['errors'])}")
print(f"التحذيرات: {len(results['warnings'])}")

qa_json_path = os.path.join(QA_DIR, "qa_results.json")
with open(qa_json_path, "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, ensure_ascii=False, default=str)
print(f"\nتم حفظ نتائج التدقيق التفصيلية في: {qa_json_path}")

ready = (png_failed == 0 and atlas_failed == 0 and manifest_errors == 0)
print(f"\n{'='*70}")
print(f"تقييم الجاهزية للدمج: {'جاهز ✅' if ready else 'غير جاهز ❌'}")
print(f"{'='*70}")

print("\nتم completar التدقيق. النتائج في مجلد:", QA_DIR)