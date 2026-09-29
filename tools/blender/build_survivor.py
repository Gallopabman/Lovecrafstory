# Arma el modelo del superviviente a partir de dos packs CC0 de Quaternius que
# comparten el esqueleto UE-mannequin de la Universal Animation Library:
#   - cabeza, ojos y cejas de "Universal Base Characters" (Superhero_Male)
#   - ropa de "Modular Character Outfits - Fantasy" (Male_Peasant, trae las manos)
# Uso: blender --background --factory-startup --python build_survivor.py -- <ubc.gltf> <outfit.gltf> <salida.glb>
import sys
import bpy

args = sys.argv[sys.argv.index("--") + 1:]
ubc_path, outfit_path, out_path = args

bpy.ops.wm.read_factory_settings(use_empty=True)

bpy.ops.import_scene.gltf(filepath=outfit_path)
outfit_objects = set(bpy.data.objects)
rig = next(o for o in outfit_objects if o.type == "ARMATURE")

bpy.ops.import_scene.gltf(filepath=ubc_path)
ubc_objects = set(bpy.data.objects) - outfit_objects
ubc_rig = next(o for o in ubc_objects if o.type == "ARMATURE")

# De la cabeza base solo queda el cuello y la cara (la ropa tapa el resto).
head = next(o for o in ubc_objects if o.type == "MESH" and o.name.lower().startswith("superhero"))
bpy.context.view_layer.objects.active = head
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
for v in head.data.vertices:
    world = head.matrix_world @ v.co
    v.select = not (world.z > 1.45 and abs(world.x) < 0.14)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.delete(type="VERT")
bpy.ops.object.mode_set(mode="OBJECT")

# Todo lo de la cabeza pasa al esqueleto de la ropa (mismos nombres de huesos).
for o in list(ubc_objects):
    if o.type == "MESH" and o.parent == ubc_rig:
        matrix = o.matrix_world.copy()
        o.parent = rig
        o.matrix_world = matrix
        for mod in o.modifiers:
            if mod.type == "ARMATURE":
                mod.object = rig

# Afuera: el esqueleto duplicado y las esferas de referencia de los packs.
for o in list(bpy.data.objects):
    if o == ubc_rig or (o.type == "MESH" and o.name.startswith("Icosphere")):
        bpy.data.objects.remove(o, do_unlink=True)

rig.name = "Survivor"

# Look PS1: solo importa el color, a 256 px; normales y rugosidad quedan de 4x4.
for image in bpy.data.images:
    if image.size[0] == 0:
        continue
    lowres = any(k in image.name for k in ("Normal", "Roughness", "Metallic", "ORM"))
    image.scale(4, 4) if lowres else image.scale(256, 256)
    image.pack()
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", use_selection=True,
    export_animations=False, export_skins=True, export_yup=True, export_image_format="JPEG")
print("EXPORTADO", out_path, [o.name for o in bpy.data.objects])
