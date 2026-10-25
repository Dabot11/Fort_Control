"""Prepare the supplied Fortress Crossbow GLB for the game with Blender 4.3+.

blender --background --threads 4 --python tools/assets/prepare_tower.py -- \
    --source /path/to/original_tower.glb --output assets/models/tower/crossbow.glb

This is an offline authoring tool. Blender is not required to run/import the game.
The original GLB is deliberately kept outside the repository.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import tempfile

import bpy
import bmesh
from mathutils import Matrix, Vector


def split_at_height(source, name, keep_top):
    """Cut the baked mesh through its narrow rotating mount, preserving UVs."""
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    bpy.context.scene.collection.objects.link(obj)
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.bisect_plane(
        mesh,
        geom=list(mesh.verts) + list(mesh.edges) + list(mesh.faces),
        dist=0.00001,
        plane_co=Vector((0, 0, 0.26)),
        plane_no=Vector((0, 0, 1)),
        clear_inner=keep_top,
        clear_outer=not keep_top,
    )
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    return obj


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.source))
    source = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
    bpy.ops.object.select_all(action='DESELECT')
    source.select_set(True)
    bpy.context.view_layer.objects.active = source
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    original_triangles = sum(len(poly.vertices) - 2 for poly in source.data.polygons)
    modifier = source.modifiers.new('MobileGeometry', 'DECIMATE')
    modifier.ratio = min(1.0, 16000 / original_triangles)
    bpy.ops.object.modifier_apply(modifier=modifier.name)

    # glTF Y-up is converted to Blender Z-up on import. The source's base is
    # slightly off-center; normalize the foundation, not the asymmetric bow.
    scale = 0.72
    center = Vector((-0.01, -0.06, -0.9218689799308777))
    pivot_height = (0.26 - center.z) * scale
    base = split_at_height(source, 'TowerBase', False)
    head = split_at_height(source, 'CrossbowArms', True)
    for vertex in base.data.vertices:
        vertex.co = (vertex.co - center) * scale
    # The authored bolt points diagonally (+X,-Y); align it to Blender +Y,
    # which exports as Godot -Z. Only the weapon rotates, never the building.
    yaw_correction = Matrix.Rotation(math.radians(122.0), 4, 'Z')
    for vertex in head.data.vertices:
        position = (vertex.co - center) * scale
        position.z -= pivot_height
        vertex.co = yaw_correction @ position
    bpy.data.objects.remove(source, do_unlink=True)
    root = bpy.data.objects.new('CrossbowModel', None)
    bpy.context.scene.collection.objects.link(root)
    base.parent = root
    pivot = bpy.data.objects.new('AimHead', None)
    bpy.context.scene.collection.objects.link(pivot)
    pivot.parent = root
    pivot.location.z = pivot_height
    head.parent = pivot
    muzzle = bpy.data.objects.new('Muzzle', None)
    bpy.context.scene.collection.objects.link(muzzle)
    muzzle.parent = pivot
    muzzle.location = (0.0, 0.64, 0.36)
    muzzle.empty_display_type = 'ARROWS'

    # Bake smaller embedded textures in Blender; no runtime image processing.
    # Save and reload to avoid the exporter reusing the original packed bytes.
    with tempfile.TemporaryDirectory(prefix='fort_tower_') as folder:
        images = [image for image in bpy.data.images if image.type == 'IMAGE']
        for index, image in enumerate(images):
            # Embedded glTF images may be lazy until the pixel buffer is read.
            if not image.has_data:
                _ = image.pixels[0]
            if image.packed_file:
                image.unpack(method='REMOVE')
            width, height = image.size
            ratio = min(1.0, 1024 / max(width, height))
            image.scale(round(width * ratio), round(height * ratio))
            image.file_format = 'JPEG'
            image.filepath_raw = str(Path(folder) / f'tower_texture_{index}.jpg')
            image.save()
            image.reload()
            image.pack()
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.export_scene.gltf(
            filepath=str(args.output),
            export_format='GLB',
            use_selection=True,
            export_animations=False,
            export_cameras=False,
            export_lights=False,
            export_normals=True,
            export_tangents=True,
            export_image_format='JPEG',
            export_jpeg_quality=85,
        )
    triangles = sum(sum(len(p.vertices) - 2 for p in obj.data.polygons) for obj in [base, head])
    print(json.dumps({
        'source_sha256': hashlib.sha256(args.source.read_bytes()).hexdigest(),
        'source_bytes': args.source.stat().st_size,
        'source_triangles': original_triangles,
        'output_bytes': args.output.stat().st_size,
        'output_triangles': triangles,
        'texture_maximum': 1024,
        'scale': scale,
        'pivot_height': pivot_height,
        'muzzle_height': pivot_height + 0.36,
        'muzzle_forward': 0.64,
    }, indent=2))


if __name__ == '__main__':
    main()
