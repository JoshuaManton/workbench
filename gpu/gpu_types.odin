package gpu

using import "core:math"
      import rt "core:runtime"

using import "../types"

      import odingl "../external/gl"



Vertex2D :: struct {
	position: Vec2,
	tex_coord: Vec2,
	color: Colorf,
}

Vertex3D :: struct {
	position: Vec3,
	tex_coord: Vec3,
	color: Colorf,
	normal: Vec3,
}



Mesh_Info :: struct {
	name : string,

	vao: VAO,
	vbo: VBO,
	ibo: EBO,
	vertex_type: ^rt.Type_Info,

	index_count:  int,
	vertex_count: int,
}

MeshID :: distinct i64;



Draw_Mode :: enum u32 {
	Points    = odingl.POINTS,
	Lines     = odingl.LINES,
	Triangles = odingl.TRIANGLES,
}

Clear_Flags :: enum u32 {
    Color_Buffer   = odingl.COLOR_BUFFER_BIT,
    Depth_Buffer   = odingl.DEPTH_BUFFER_BIT,
    Stencil_Buffer = odingl.STENCIL_BUFFER_BIT,
}

Capabilities :: enum u32 {
    Blend                       = odingl.BLEND,
    Clip_Distance0              = odingl.CLIP_DISTANCE0,
    Clip_Distance1              = odingl.CLIP_DISTANCE1,
    Clip_Distance3              = odingl.CLIP_DISTANCE3,
    Clip_Distance2              = odingl.CLIP_DISTANCE2,
    Clip_Distance4              = odingl.CLIP_DISTANCE4,
    Clip_Distance5              = odingl.CLIP_DISTANCE5,
    Clip_Distance6              = odingl.CLIP_DISTANCE6,
    Clip_Distance7              = odingl.CLIP_DISTANCE7,
    Color_Logic_Op              = odingl.COLOR_LOGIC_OP,
    Cull_Face                   = odingl.CULL_FACE,
    Debug_Output                = odingl.DEBUG_OUTPUT,
    Debug_Output_Synchronous    = odingl.DEBUG_OUTPUT_SYNCHRONOUS,
    Depth_Clamp                 = odingl.DEPTH_CLAMP,
    Depth_Test                  = odingl.DEPTH_TEST,
    Dither                      = odingl.DITHER,
    Framebuffer_SRGB            = odingl.FRAMEBUFFER_SRGB,
    Line_Smooth                 = odingl.LINE_SMOOTH,
    Multisample                 = odingl.MULTISAMPLE,
    Polygon_Offset_Fill         = odingl.POLYGON_OFFSET_FILL,
    Polygon_Offset_Line         = odingl.POLYGON_OFFSET_LINE,
    Polygon_Offset_Point        = odingl.POLYGON_OFFSET_POINT,
    Polygon_Smooth              = odingl.POLYGON_SMOOTH,
    Primitive_Restart           = odingl.PRIMITIVE_RESTART,
    Primitive_RestartFixedIndex = odingl.PRIMITIVE_RESTART_FIXED_INDEX,
    Rasterizer_Discard          = odingl.RASTERIZER_DISCARD,
    Sample_Alpha_To_Coverage    = odingl.SAMPLE_ALPHA_TO_COVERAGE,
    Sample_Alpha_To_One         = odingl.SAMPLE_ALPHA_TO_ONE,
    Sample_Coverage             = odingl.SAMPLE_COVERAGE,
    Sample_Shading              = odingl.SAMPLE_SHADING,
    Sample_Mask                 = odingl.SAMPLE_MASK,
    Scissor_Test                = odingl.SCISSOR_TEST,
    Stencil_Test                = odingl.STENCIL_TEST,
    Texture_Cube_Map_Seamless   = odingl.TEXTURE_CUBE_MAP_SEAMLESS,
    Program_Point_Size          = odingl.PROGRAM_POINT_SIZE,
}

Blend_Factors :: enum u32 {
    Zero                     = odingl.ZERO,
    One                      = odingl.ONE,
    Src_Color                = odingl.SRC_COLOR,
    One_Minus_Src_Color      = odingl.ONE_MINUS_SRC_COLOR,
    Dst_Color                = odingl.DST_COLOR,
    One_Minus_Dst_Color      = odingl.ONE_MINUS_DST_COLOR,
    Src_Alpha                = odingl.SRC_ALPHA,
    One_Minus_Src_Alpha      = odingl.ONE_MINUS_SRC_ALPHA,
    Dst_Alpha                = odingl.DST_ALPHA,
    One_Minus_Dst_Alpha      = odingl.ONE_MINUS_DST_ALPHA,
    Constant_Color           = odingl.CONSTANT_COLOR,
    One_Minus_Constant_Color = odingl.ONE_MINUS_CONSTANT_COLOR,
    Constant_Alpha           = odingl.CONSTANT_ALPHA,
    One_Minus_Constant_Alpha = odingl.ONE_MINUS_CONSTANT_ALPHA,
}