@tool
class_name SilhouetteOutlineEffect
extends CompositorEffect
## Screen-space silhouette outline for the main camera — no second camera, no SubViewport.
## Highlighted objects stamp stencil bit0 (see SilhouetteHighlighter); this effect copies that
## stenciled region into a mask using the hardware stencil TEST (not a stencil sample, which
## Godot doesn't reliably expose), then inks a clean, gap-free outline into the HDR colour
## buffer before glow runs. Runs at POST_TRANSPARENT because the stencil is written by
## transparent (material_overlay) passes.
##
## Technique adapted from dmlary/godot-stencil-based-outline-compositor-effect (MIT), minus the
## jump-flood — a direct dilation is enough for a thin outline.

## Outline colour. HDR (energy > 1) so it blooms when glow is enabled.
@export var outline_color := Color(0.6, 0.85, 1.0) * 2.0
## Outline thickness in pixels.
@export_range(1, 16) var thickness: int = 2
## Stencil bit that marks "an object to outline" (bit0 by default).
@export var stencil_mask: int = 1
@export var stencil_reference: int = 1
## Phase-1 debug: tint the masked object instead of drawing the outline (verifies the mask).
@export var debug_show_mask: bool = false

var _rd: RenderingDevice

# stencil-copy (raster) pipeline
var _mask_shader: RID
var _mask_pipeline: RID
var _mask_framebuffer: RID

# compose (compute) pipeline
var _compose_shader: RID
var _compose_pipeline: RID

# fullscreen triangle
var _vertex_format: int
var _vertex_buffer: RID
var _vertex_array: RID

var _mask_texture: RID
var _color_texture: RID
var _depth_texture: RID
var _resolution := Vector2i(1, 1)
var _dirty := true

const _SHADER_DIRECTORY := "res://systems/rendering/silhouette_outline/shaders/"

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	# Fullscreen triangle (CCW so its front faces the camera — the stencil test uses front ops).
	var vertex_attribute := RDVertexAttribute.new()
	vertex_attribute.location = 0
	vertex_attribute.format = RenderingDevice.DATA_FORMAT_R32G32B32_SFLOAT
	vertex_attribute.stride = 4 * 3
	_vertex_format = _rd.vertex_format_create([vertex_attribute])
	var vertices := PackedVector3Array([Vector3(-1, -1, 0), Vector3(3, -1, 0), Vector3(-1, 3, 0)])
	var vbytes := vertices.to_byte_array()
	_vertex_buffer = _rd.vertex_buffer_create(vbytes.size(), vbytes)
	_vertex_array = _rd.vertex_array_create(3, _vertex_format, [_vertex_buffer])

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		if _mask_shader.is_valid():
			_rd.free_rid(_mask_shader)
		if _compose_shader.is_valid():
			_rd.free_rid(_compose_shader)
		if _mask_texture.is_valid():
			_rd.free_rid(_mask_texture)
		if _vertex_buffer.is_valid():
			_rd.free_rid(_vertex_buffer)

func _load_spirv(file: String) -> RDShaderSPIRV:
	var shader_file: RDShaderFile = ResourceLoader.load(_SHADER_DIRECTORY + file)
	return shader_file.get_spirv()

func _build_mask_texture() -> void:
	var fmt := RDTextureFormat.new()
	fmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	fmt.width = _resolution.x
	fmt.height = _resolution.y
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = (RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT)
	var old := _mask_texture
	_mask_texture = _rd.texture_create(fmt, RDTextureView.new())
	if old.is_valid():
		_rd.free_rid(old)

func _build_mask_pipeline() -> void:
	if _mask_shader.is_valid():
		_rd.free_rid(_mask_shader)
	_mask_shader = _rd.shader_create_from_spirv(_load_spirv("outline_mask.glsl"))

	var attachments: Array[RDAttachmentFormat] = []
	var mask_fmt := _rd.texture_get_format(_mask_texture)
	var a0 := RDAttachmentFormat.new()
	a0.format = mask_fmt.format
	a0.usage_flags = mask_fmt.usage_bits
	a0.samples = RenderingDevice.TEXTURE_SAMPLES_1
	attachments.push_back(a0)
	var depth_fmt := _rd.texture_get_format(_depth_texture)
	var a1 := RDAttachmentFormat.new()
	a1.format = depth_fmt.format
	a1.usage_flags = depth_fmt.usage_bits
	a1.samples = RenderingDevice.TEXTURE_SAMPLES_1
	attachments.push_back(a1)
	var fb_format := _rd.framebuffer_format_create(attachments)
	_mask_framebuffer = _rd.framebuffer_create([_mask_texture, _depth_texture], fb_format)

	# Only the stencil test gates fragments; depth test/write stay off so we never touch the
	# scene depth, and STENCIL_OP_KEEP + write_mask 0 means we never touch the stencil (read-only).
	var ds := RDPipelineDepthStencilState.new()
	ds.enable_stencil = true
	ds.front_op_compare = RenderingDevice.COMPARE_OP_EQUAL
	ds.front_op_compare_mask = stencil_mask
	ds.front_op_reference = stencil_reference
	ds.front_op_write_mask = 0
	ds.front_op_fail = RenderingDevice.STENCIL_OP_KEEP
	ds.front_op_pass = RenderingDevice.STENCIL_OP_KEEP
	ds.front_op_depth_fail = RenderingDevice.STENCIL_OP_KEEP

	var blend := RDPipelineColorBlendState.new()
	blend.attachments.push_back(RDPipelineColorBlendStateAttachment.new())

	_mask_pipeline = _rd.render_pipeline_create(
		_mask_shader, fb_format, _vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
		RDPipelineRasterizationState.new(), RDPipelineMultisampleState.new(), ds, blend)

func _build_compose_pipeline() -> void:
	if _compose_shader.is_valid():
		_rd.free_rid(_compose_shader)
	_compose_shader = _rd.shader_create_from_spirv(_load_spirv("outline_compose.glsl"))
	_compose_pipeline = _rd.compute_pipeline_create(_compose_shader)

func _render_callback(p_type: int, p_render_data: RenderData) -> void:
	if _rd == null or p_type != effect_callback_type:
		return
	var buffers := p_render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	var rebuild := _dirty
	if _resolution != size:
		_resolution = size
		rebuild = true
	var color_texture := buffers.get_color_layer(0)
	if color_texture != _color_texture:
		_color_texture = color_texture
		rebuild = true
	var depth_texture := buffers.get_depth_layer(0)
	if depth_texture != _depth_texture:
		_depth_texture = depth_texture
		rebuild = true

	if rebuild:
		_dirty = false
		_build_mask_texture()
		_build_mask_pipeline()
		_build_compose_pipeline()

	# Pass 1 — copy the stenciled region into the mask via the hardware stencil test.
	var draw_list := _rd.draw_list_begin(_mask_framebuffer,
		RenderingDevice.DRAW_CLEAR_COLOR_0, [Color(0, 0, 0, 0)], 1.0, 0, Rect2(),
		RenderingDevice.OPAQUE_PASS)
	_rd.draw_list_bind_render_pipeline(draw_list, _mask_pipeline)
	_rd.draw_list_bind_vertex_array(draw_list, _vertex_array)
	_rd.draw_list_draw(draw_list, false, 1)
	_rd.draw_list_end()

	# Pass 2 — compose the outline (or debug tint) into the colour buffer.
	var color_uniform := RDUniform.new()
	color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	color_uniform.binding = 0
	color_uniform.add_id(_color_texture)
	var mask_uniform := RDUniform.new()
	mask_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	mask_uniform.binding = 1
	mask_uniform.add_id(_mask_texture)
	var uniform_set := UniformSetCacheRD.get_cache(_compose_shader, 0, [color_uniform, mask_uniform])

	var pc := PackedByteArray()
	pc.resize(32)
	pc.encode_float(0, outline_color.r)
	pc.encode_float(4, outline_color.g)
	pc.encode_float(8, outline_color.b)
	pc.encode_float(12, outline_color.a)
	pc.encode_s32(16, _resolution.x)
	pc.encode_s32(20, _resolution.y)
	pc.encode_s32(24, thickness)
	pc.encode_s32(28, 1 if debug_show_mask else 0)

	@warning_ignore("integer_division")
	var x_groups := (_resolution.x - 1) / 8 + 1
	@warning_ignore("integer_division")
	var y_groups := (_resolution.y - 1) / 8 + 1
	var compute_list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(compute_list, _compose_pipeline)
	_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	_rd.compute_list_set_push_constant(compute_list, pc, pc.size())
	_rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
	_rd.compute_list_end()
