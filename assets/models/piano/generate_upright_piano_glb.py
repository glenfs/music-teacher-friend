#!/usr/bin/env python3
"""Generate a compact Godot-ready upright piano GLB asset.

The asset is intentionally procedural so dimensions, materials, and key naming
can be adjusted without a DCC dependency. Key nodes follow the app's piano bank
mapping: index 1 is A0 / MIDI 21, index 40 is C4 / MIDI 60.
"""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path
from typing import Iterable


OUTPUT_PATH = Path(__file__).with_name("upright_piano.glb")
BASE_MIDI = 21
KEY_COUNT = 88
NOTE_NAMES = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
BLACK_PITCH_CLASSES = {1, 3, 6, 8, 10}


def hex_to_linear_rgba(hex_color: str, alpha: float = 1.0) -> list[float]:
    value = hex_color.strip().lstrip("#")
    red = int(value[0:2], 16) / 255.0
    green = int(value[2:4], 16) / 255.0
    blue = int(value[4:6], 16) / 255.0

    def convert(channel: float) -> float:
        if channel <= 0.04045:
            return channel / 12.92
        return ((channel + 0.055) / 1.055) ** 2.4

    return [convert(red), convert(green), convert(blue), alpha]


def midi_to_note_name(midi: int) -> str:
    return f"{NOTE_NAMES[midi % 12]}{midi // 12 - 1}"


def align4(blob: bytearray) -> None:
    while len(blob) % 4:
        blob.append(0)


def pack_floats(values: Iterable[float]) -> bytes:
    values = list(values)
    return struct.pack(f"<{len(values)}f", *values)


def pack_ushort(values: Iterable[int]) -> bytes:
    values = list(values)
    return struct.pack(f"<{len(values)}H", *values)


def cube_geometry() -> tuple[list[float], list[float], list[int]]:
    positions = [
        -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5,
        0.5, -0.5, -0.5, -0.5, -0.5, -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5,
        -0.5, -0.5, -0.5, -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5, -0.5,
        0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5,
        -0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, -0.5, -0.5, 0.5, -0.5,
        -0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, -0.5, 0.5, -0.5, -0.5, 0.5,
    ]
    normals = [
        0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1,
        0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1,
        -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0,
        1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0,
        0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0,
        0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0,
    ]
    indices = [
        0, 1, 2, 0, 2, 3,
        4, 5, 6, 4, 6, 7,
        8, 9, 10, 8, 10, 11,
        12, 13, 14, 12, 14, 15,
        16, 17, 18, 16, 18, 19,
        20, 21, 22, 20, 22, 23,
    ]
    return positions, normals, indices


def cylinder_geometry(segments: int = 18) -> tuple[list[float], list[float], list[int]]:
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []

    for index in range(segments):
        angle = index / segments * math.tau
        x = math.cos(angle) * 0.5
        z = math.sin(angle) * 0.5
        positions.extend([x, -0.5, z, x, 0.5, z])
        normals.extend([math.cos(angle), 0, math.sin(angle)] * 2)

    for index in range(segments):
        next_index = (index + 1) % segments
        bottom = index * 2
        top = bottom + 1
        next_bottom = next_index * 2
        next_top = next_bottom + 1
        indices.extend([bottom, next_bottom, top, top, next_bottom, next_top])

    top_center = len(positions) // 3
    positions.extend([0, 0.5, 0])
    normals.extend([0, 1, 0])
    bottom_center = len(positions) // 3
    positions.extend([0, -0.5, 0])
    normals.extend([0, -1, 0])

    for index in range(segments):
        next_index = (index + 1) % segments
        indices.extend([top_center, index * 2 + 1, next_index * 2 + 1])
        indices.extend([bottom_center, next_index * 2, index * 2])

    return positions, normals, indices


class GlbBuilder:
    def __init__(self) -> None:
        self.binary = bytearray()
        self.buffer_views: list[dict] = []
        self.accessors: list[dict] = []
        self.materials: list[dict] = []
        self.meshes: list[dict] = []
        self.nodes: list[dict] = []
        self.root_children: list[int] = []
        self.geometry_accessors: dict[str, tuple[int, int, int]] = {}
        self.material_indices: dict[str, int] = {}
        self.mesh_indices: dict[tuple[str, str], int] = {}

    def add_buffer_view(self, data: bytes, target: int) -> int:
        align4(self.binary)
        offset = len(self.binary)
        self.binary.extend(data)
        view_index = len(self.buffer_views)
        self.buffer_views.append(
            {"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target}
        )
        return view_index

    def add_accessor(
        self,
        view_index: int,
        component_type: int,
        count: int,
        accessor_type: str,
        minimum: list[float] | None = None,
        maximum: list[float] | None = None,
    ) -> int:
        accessor: dict = {
            "bufferView": view_index,
            "componentType": component_type,
            "count": count,
            "type": accessor_type,
        }
        if minimum is not None:
            accessor["min"] = minimum
        if maximum is not None:
            accessor["max"] = maximum
        accessor_index = len(self.accessors)
        self.accessors.append(accessor)
        return accessor_index

    def add_geometry(self, name: str, positions: list[float], normals: list[float], indices: list[int]) -> None:
        position_view = self.add_buffer_view(pack_floats(positions), 34962)
        normal_view = self.add_buffer_view(pack_floats(normals), 34962)
        index_view = self.add_buffer_view(pack_ushort(indices), 34963)

        grouped_positions = list(zip(*(iter(positions),) * 3))
        minimum = [min(axis) for axis in zip(*grouped_positions)]
        maximum = [max(axis) for axis in zip(*grouped_positions)]

        position_accessor = self.add_accessor(position_view, 5126, len(grouped_positions), "VEC3", minimum, maximum)
        normal_accessor = self.add_accessor(normal_view, 5126, len(normals) // 3, "VEC3")
        index_accessor = self.add_accessor(index_view, 5123, len(indices), "SCALAR")
        self.geometry_accessors[name] = (position_accessor, normal_accessor, index_accessor)

    def add_material(self, name: str, color: str, roughness: float = 0.74, metallic: float = 0.0) -> int:
        material_index = len(self.materials)
        self.material_indices[name] = material_index
        self.materials.append(
            {
                "name": name,
                "pbrMetallicRoughness": {
                    "baseColorFactor": hex_to_linear_rgba(color),
                    "metallicFactor": metallic,
                    "roughnessFactor": roughness,
                },
            }
        )
        return material_index

    def get_mesh(self, geometry_name: str, material_name: str) -> int:
        key = (geometry_name, material_name)
        if key in self.mesh_indices:
            return self.mesh_indices[key]

        position_accessor, normal_accessor, index_accessor = self.geometry_accessors[geometry_name]
        mesh_index = len(self.meshes)
        self.mesh_indices[key] = mesh_index
        self.meshes.append(
            {
                "name": f"{geometry_name}_{material_name}",
                "primitives": [
                    {
                        "attributes": {"POSITION": position_accessor, "NORMAL": normal_accessor},
                        "indices": index_accessor,
                        "material": self.material_indices[material_name],
                    }
                ],
            }
        )
        return mesh_index

    def add_node(
        self,
        name: str,
        geometry_name: str,
        material_name: str,
        translation: tuple[float, float, float],
        scale: tuple[float, float, float],
        rotation: tuple[float, float, float, float] | None = None,
    ) -> int:
        node: dict = {
            "name": name,
            "mesh": self.get_mesh(geometry_name, material_name),
            "translation": [round(value, 5) for value in translation],
            "scale": [round(value, 5) for value in scale],
        }
        if rotation is not None:
            node["rotation"] = [round(value, 6) for value in rotation]
        node_index = len(self.nodes)
        self.nodes.append(node)
        self.root_children.append(node_index)
        return node_index

    def build(self) -> dict:
        root_index = len(self.nodes)
        self.nodes.append({"name": "upright_piano", "children": self.root_children})
        align4(self.binary)
        return {
            "asset": {"version": "2.0", "generator": "musiced procedural piano asset generator"},
            "scene": 0,
            "scenes": [{"name": "upright_piano_scene", "nodes": [root_index]}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "materials": self.materials,
            "buffers": [{"byteLength": len(self.binary)}],
            "bufferViews": self.buffer_views,
            "accessors": self.accessors,
        }

    def write_glb(self, path: Path) -> None:
        gltf = self.build()
        json_blob = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        while len(json_blob) % 4:
            json_blob += b" "

        total_length = 12 + 8 + len(json_blob) + 8 + len(self.binary)
        header = struct.pack("<III", 0x46546C67, 2, total_length)
        json_chunk = struct.pack("<I4s", len(json_blob), b"JSON") + json_blob
        bin_chunk = struct.pack("<I4s", len(self.binary), b"BIN\x00") + self.binary
        path.write_bytes(header + json_chunk + bin_chunk)


def add_case(builder: GlbBuilder) -> None:
    cube = "cube"
    builder.add_node("body_back_panel", cube, "polished_charcoal", (0, 1.58, 0.38), (7.45, 2.22, 0.34))
    builder.add_node("body_keybed", cube, "polished_charcoal", (0, 1.0, -0.42), (7.55, 0.24, 1.25))
    builder.add_node("front_apron", cube, "polished_charcoal", (0, 0.68, -0.92), (7.55, 0.66, 0.18))
    builder.add_node("top_lid", cube, "walnut_trim", (0, 2.78, 0.18), (7.75, 0.16, 0.86))
    builder.add_node("left_side_cheek", cube, "walnut_trim", (-3.92, 1.52, -0.24), (0.24, 2.55, 1.55))
    builder.add_node("right_side_cheek", cube, "walnut_trim", (3.92, 1.52, -0.24), (0.24, 2.55, 1.55))
    builder.add_node("fallboard", cube, "walnut_trim", (0, 1.34, -0.72), (7.1, 0.35, 0.18))
    builder.add_node("red_felt_strip", cube, "felt_red", (0, 1.13, -0.425), (7.04, 0.018, 0.035))
    builder.add_node("music_stand", cube, "polished_charcoal", (0, 2.22, -0.05), (2.2, 0.95, 0.08), (0.21644, 0, 0, 0.976296))
    builder.add_node("music_ledge", cube, "walnut_trim", (0, 1.77, -0.27), (2.45, 0.12, 0.22))
    builder.add_node("sheet_music_page", cube, "sheet_music", (0, 2.25, -0.12), (1.24, 0.76, 0.025), (0.21644, 0, 0, 0.976296))
    for x in (-3.28, 3.28):
        builder.add_node(f"front_leg_{x:+.1f}", cube, "polished_charcoal", (x, 0.11, -0.77), (0.32, 1.18, 0.32))
        builder.add_node(f"rear_leg_{x:+.1f}", cube, "polished_charcoal", (x, 0.17, 0.28), (0.28, 1.3, 0.28))
        builder.add_node(f"front_foot_pad_{x:+.1f}", "cylinder", "walnut_trim", (x, -0.52, -0.77), (0.44, 0.08, 0.44))
        builder.add_node(f"rear_foot_pad_{x:+.1f}", "cylinder", "walnut_trim", (x, -0.52, 0.28), (0.38, 0.08, 0.38))
    builder.add_node("pedal_rail", cube, "walnut_trim", (0, 0.16, -0.53), (1.08, 0.14, 0.18))
    for index, x in enumerate((-0.34, 0.0, 0.34), start=1):
        builder.add_node(f"brass_pedal_pivot_{index}", "cylinder", "brass", (x, 0.07, -0.58), (0.18, 0.08, 0.18))
        builder.add_node(f"brass_pedal_{index}", cube, "brass", (x, -0.04, -0.82), (0.18, 0.055, 0.52))


def add_keyboard(builder: GlbBuilder) -> None:
    total_width = 6.95
    white_keys = 52
    white_width = total_width / white_keys
    left_edge = -total_width / 2.0
    white_index = 0

    builder.add_node("keyboard_shadow_gap", "cube", "shadow_gap", (0, 1.035, -0.78), (7.02, 0.045, 0.82))

    for sample_index in range(1, KEY_COUNT + 1):
        midi = BASE_MIDI + sample_index - 1
        note_name = midi_to_note_name(midi)
        pitch_class = midi % 12
        is_black = pitch_class in BLACK_PITCH_CLASSES
        key_name = f"key_{sample_index:03d}_{note_name}_midi{midi}"

        if is_black:
            x = left_edge + white_index * white_width
            builder.add_node(
                key_name,
                "cube",
                "ebony_key",
                (x, 1.16, -0.72),
                (white_width * 0.58, 0.16, 0.48),
            )
            continue

        x = left_edge + white_index * white_width + white_width * 0.5
        builder.add_node(
            key_name,
            "cube",
            "ivory_key",
            (x, 1.09, -0.64),
            (white_width * 0.92, 0.075, 0.82),
        )
        white_index += 1


def create_model() -> GlbBuilder:
    builder = GlbBuilder()
    builder.add_geometry("cube", *cube_geometry())
    builder.add_geometry("cylinder", *cylinder_geometry())

    builder.add_material("polished_charcoal", "#111217", roughness=0.52)
    builder.add_material("walnut_trim", "#5d3824", roughness=0.68)
    builder.add_material("ivory_key", "#f5f0df", roughness=0.82)
    builder.add_material("ebony_key", "#060608", roughness=0.55)
    builder.add_material("brass", "#c49a3a", roughness=0.38, metallic=0.45)
    builder.add_material("felt_red", "#8a1d2b", roughness=0.9)
    builder.add_material("shadow_gap", "#202229", roughness=0.95)
    builder.add_material("sheet_music", "#eee6cf", roughness=0.86)

    add_case(builder)
    add_keyboard(builder)
    return builder


def main() -> None:
    builder = create_model()
    builder.write_glb(OUTPUT_PATH)
    print(f"Wrote {OUTPUT_PATH} ({OUTPUT_PATH.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
