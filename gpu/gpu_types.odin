package gpu

using import "core:fmt"
      import rt "core:runtime"

using import "../math"
using import "../types"
using import "../logging"

      import odingl "../external/gl"

//
// Models and Meshes
//

Model :: struct {
	name: string,
    meshes: [dynamic]Mesh,
}

Mesh :: struct {
    vao: VAO,
    vbo: VBO,
    ibo: EBO,
    vertex_type: ^rt.Type_Info,

    index_count:  int,
    vertex_count: int,

	skin: Skinned_Mesh,
}

Skinned_Mesh :: struct {
	bones: []Bone,
    nodes: [dynamic]Node,
	name_mapping: map[string]int,
	global_inverse: Mat4,

    parent_node: ^Node, // points into array above
}

Node :: struct {
    name: string,
    local_transform: Mat4,

    parent: ^Node,
    children: [dynamic]^Node,
}

Vertex2D :: struct {
	position: Vec2,
	tex_coord: Vec2,
	color: Colorf,
}

Vertex3D :: struct {
	position: Vec3,
	tex_coord: Vec3, // todo(josh): should this be a Vec2?
	color: Colorf,
	normal: Vec3,

	bone_indicies: [BONES_PER_VERTEX]u32,
	bone_weights: [BONES_PER_VERTEX]f32,
}

Bone :: struct {
	offset: Mat4,
	name: string,
}

Draw_Mode :: enum u32 {
	Points       = odingl.POINTS,
    Lines        = odingl.LINES,
    Line_Loop    = odingl.LINE_LOOP,
	Line_Strip   = odingl.LINE_STRIP,
    Triangles    = odingl.TRIANGLES,
	Triangle_Fan = odingl.TRIANGLE_FAN,
}

Draw_Elements_Type :: enum i32 {
    Unsigned_Byte  = odingl.UNSIGNED_BYTE,
    Unsigned_Short = odingl.UNSIGNED_SHORT,
    Unsigned_Int   = odingl.UNSIGNED_INT,
}

Buffer_Data_Usage :: enum i32 {
    Stream_Draw                         = odingl.STREAM_DRAW,
    Stream_Read                         = odingl.STREAM_READ,
    Stream_Copy                         = odingl.STREAM_COPY,
    Static_Draw                         = odingl.STATIC_DRAW,
    Static_Read                         = odingl.STATIC_READ,
    Static_Copy                         = odingl.STATIC_COPY,
    Dynamic_Draw                        = odingl.DYNAMIC_DRAW,
    Dynamic_Read                        = odingl.DYNAMIC_READ,
    Dynamic_Copy                        = odingl.DYNAMIC_COPY,
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

Framebuffer_Options :: enum u32 {
    Attachment_Object_Type           = odingl.FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE,
    Attachment_Object_Name           = odingl.FRAMEBUFFER_ATTACHMENT_OBJECT_NAME,
    Attachment_Texture_Level         = odingl.FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL,
    Attachment_Texture_Cube_Map_Face = odingl.FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE,
    Attachment_Texture_Layer         = odingl.FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER,
    Complete                         = odingl.FRAMEBUFFER_COMPLETE,
    Incomplete_Attachment            = odingl.FRAMEBUFFER_INCOMPLETE_ATTACHMENT,
    Incomplete_Missing_Attachment    = odingl.FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT,
    Incomplete_Draw_Buffer           = odingl.FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER,
    Incomplete_Read_Buffer           = odingl.FRAMEBUFFER_INCOMPLETE_READ_BUFFER,
    Unsupported                      = odingl.FRAMEBUFFER_UNSUPPORTED,
}

Framebuffer_Attachment :: enum u32 {
    Depth_Stencil = odingl.DEPTH_STENCIL_ATTACHMENT,
    Depth         = odingl.DEPTH_ATTACHMENT,
    Stencil       = odingl.STENCIL_ATTACHMENT,
    Color0       = odingl.COLOR_ATTACHMENT0,
    Color1       = odingl.COLOR_ATTACHMENT1,
    Color2       = odingl.COLOR_ATTACHMENT2,
    Color3       = odingl.COLOR_ATTACHMENT3,
    Color4       = odingl.COLOR_ATTACHMENT4,
    Color5       = odingl.COLOR_ATTACHMENT5,
    Color6       = odingl.COLOR_ATTACHMENT6,
    Color7       = odingl.COLOR_ATTACHMENT7,
    Color8       = odingl.COLOR_ATTACHMENT8,
    Color9       = odingl.COLOR_ATTACHMENT9,
    Color10      = odingl.COLOR_ATTACHMENT10,
    Color11      = odingl.COLOR_ATTACHMENT11,
    Color12      = odingl.COLOR_ATTACHMENT12,
    Color13      = odingl.COLOR_ATTACHMENT13,
    Color14      = odingl.COLOR_ATTACHMENT14,
    Color15      = odingl.COLOR_ATTACHMENT15,
    Color16      = odingl.COLOR_ATTACHMENT16,
    Color17      = odingl.COLOR_ATTACHMENT17,
    Color18      = odingl.COLOR_ATTACHMENT18,
    Color19      = odingl.COLOR_ATTACHMENT19,
    Color20      = odingl.COLOR_ATTACHMENT20,
    Color21      = odingl.COLOR_ATTACHMENT21,
    Color22      = odingl.COLOR_ATTACHMENT22,
    Color23      = odingl.COLOR_ATTACHMENT23,
    Color24      = odingl.COLOR_ATTACHMENT24,
    Color25      = odingl.COLOR_ATTACHMENT25,
    Color26      = odingl.COLOR_ATTACHMENT26,
    Color27      = odingl.COLOR_ATTACHMENT27,
    Color28      = odingl.COLOR_ATTACHMENT28,
    Color29      = odingl.COLOR_ATTACHMENT29,
    Color30      = odingl.COLOR_ATTACHMENT30,
    Color31      = odingl.COLOR_ATTACHMENT31,
}

Renderbuffer_Storage :: enum u32 {
    Depth24_Stencil8 = odingl.DEPTH24_STENCIL8,
}

Texture_Target :: enum i32 {
    Texture1D = odingl.TEXTURE_1D,
    Texture2D = odingl.TEXTURE_2D,
    Texture3D = odingl.TEXTURE_3D,

    Texture1D_Array             = odingl.TEXTURE_1D_ARRAY,
    Texture2D_Array             = odingl.TEXTURE_2D_ARRAY,
    Texture_Cube_Map_Array      = odingl.TEXTURE_CUBE_MAP_ARRAY,
    Texture2D_Multisample_Array = odingl.TEXTURE_2D_MULTISAMPLE_ARRAY,

    Texture_Rectangle     = odingl.TEXTURE_RECTANGLE,
    Texture_CubeMap       = odingl.TEXTURE_CUBE_MAP,
    Texture2D_Multisample = odingl.TEXTURE_2D_MULTISAMPLE,
    Texture_Buffer        = odingl.TEXTURE_BUFFER,
}

Internal_Color_Format :: enum i32 {
    //Base
    Depth_Component                    = odingl.DEPTH_COMPONENT,
    Depth_Stencil                      = odingl.DEPTH_STENCIL,
    RED                                = odingl.RED,
    RG                                 = odingl.RG,
    RGB                                = odingl.RGB,
    RGBA                               = odingl.RGBA,

    //Sized
    R8                                 = odingl.R8,
    R8_SNORM                           = odingl.R8_SNORM,
    R16                                = odingl.R16,
    R16_SNORM                          = odingl.R16_SNORM,
    RG8                                = odingl.RG8,
    RG8_SNORM                          = odingl.RG8_SNORM,
    RG16                               = odingl.RG16,
    RG16_SNORM                         = odingl.RG16_SNORM,
    R3_G3_B2                           = odingl.R3_G3_B2,
    RGB4                               = odingl.RGB4,
    RGB5                               = odingl.RGB5,
    RGB8                               = odingl.RGB8,
    RGB8_SNORM                         = odingl.RGB8_SNORM,
    RGB10                              = odingl.RGB10,
    RGB12                              = odingl.RGB12,
    RGB16_SNORM                        = odingl.RGB16_SNORM,
    RGBA2                              = odingl.RGBA2,
    RGBA4                              = odingl.RGBA4,
    RGB5_A1                            = odingl.RGB5_A1,
    RGBA8                              = odingl.RGBA8,
    RGBA8_SNORM                        = odingl.RGBA8_SNORM,
    RGB10_A2                           = odingl.RGB10_A2,
    RGB10_A2UI                         = odingl.RGB10_A2UI,
    RGBA12                             = odingl.RGBA12,
    RGBA16                             = odingl.RGBA16,
    SRGB8                              = odingl.SRGB8,
    SRGB8_ALPHA8                       = odingl.SRGB8_ALPHA8,
    R16F                               = odingl.R16F,
    RG16F                              = odingl.RG16F,
    RGB16F                             = odingl.RGB16F,
    RGBA16F                            = odingl.RGBA16F,
    R32F                               = odingl.R32F,
    RG32F                              = odingl.RG32F,
    RGB32F                             = odingl.RGB32F,
    RGBA32F                            = odingl.RGBA32F,
    R11F_G11F_B10F                     = odingl.R11F_G11F_B10F,
    RGB9_E5                            = odingl.RGB9_E5,
    R8I                                = odingl.R8I,
    R8UI                               = odingl.R8UI,
    R16I                               = odingl.R16I,
    R16UI                              = odingl.R16UI,
    R32I                               = odingl.R32I,
    R32UI                              = odingl.R32UI,
    RG8I                               = odingl.RG8I,
    RG8UI                              = odingl.RG8UI,
    RG16I                              = odingl.RG16I,
    RG16UI                             = odingl.RG16UI,
    RG32I                              = odingl.RG32I,
    RG32UI                             = odingl.RG32UI,
    RGB8I                              = odingl.RGB8I,
    RGB8UI                             = odingl.RGB8UI,
    RGB16I                             = odingl.RGB16I,
    RGB16UI                            = odingl.RGB16UI,
    RGB32I                             = odingl.RGB32I,
    RGB32UI                            = odingl.RGB32UI,
    RGBA8I                             = odingl.RGBA8I,
    RGBA8UI                            = odingl.RGBA8UI,
    RGBA16I                            = odingl.RGBA16I,
    RGBA16UI                           = odingl.RGBA16UI,
    RGBA32I                            = odingl.RGBA32I,
    RGBA32UI                           = odingl.RGBA32UI,

    //Compressed
    COMPRESSED_RED                     = odingl.COMPRESSED_RED,
    COMPRESSED_RG                      = odingl.COMPRESSED_RG,
    COMPRESSED_RGB                     = odingl.COMPRESSED_RGB,
    COMPRESSED_RGBA                    = odingl.COMPRESSED_RGBA,
    COMPRESSED_SRGB                    = odingl.COMPRESSED_SRGB,
    COMPRESSED_SRGB_ALPHA              = odingl.COMPRESSED_SRGB_ALPHA,
    COMPRESSED_RED_RGTC1               = odingl.COMPRESSED_RED_RGTC1,
    COMPRESSED_SIGNED_RED_RGTC1        = odingl.COMPRESSED_SIGNED_RED_RGTC1,
    COMPRESSED_RG_RGTC2                = odingl.COMPRESSED_RG_RGTC2,
    COMPRESSED_SIGNED_RG_RGTC2         = odingl.COMPRESSED_SIGNED_RG_RGTC2,
    COMPRESSED_RGBA_BPTC_UNORM         = odingl.COMPRESSED_RGBA_BPTC_UNORM,
    COMPRESSED_SRGB_ALPHA_BPTC_UNORM   = odingl.COMPRESSED_SRGB_ALPHA_BPTC_UNORM,
    COMPRESSED_RGB_BPTC_SIGNED_FLOAT   = odingl.COMPRESSED_RGB_BPTC_SIGNED_FLOAT,
    COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT = odingl.COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT,
}

Pixel_Data_Format :: enum i32 {
    Red                                = odingl.RED,
    RG                                 = odingl.RG,
    RGB                                = odingl.RGB,
    BGR                                = odingl.BGR,
    RGBA                               = odingl.RGBA,
    BGRA                               = odingl.BGRA,
    Red_Integer                        = odingl.RED_INTEGER,
    RG_Integer                         = odingl.RG_INTEGER,
    RGB_Integer                        = odingl.RGB_INTEGER,
    BGR_Integer                        = odingl.BGR_INTEGER,
    RGBA_Integer                       = odingl.RGBA_INTEGER,
    BGRA_Integer                       = odingl.BGRA_INTEGER,
    Stencil_Index                      = odingl.STENCIL_INDEX,
    Depth_Component                    = odingl.DEPTH_COMPONENT,
    Depth_Stencil                      = odingl.DEPTH_STENCIL,
}

Texture2D_Data_Type :: enum i32 {
    Unsigned_Byte               = odingl.UNSIGNED_BYTE,
    Byte                        = odingl.BYTE,
    Unsigned_Short              = odingl.UNSIGNED_SHORT,
    Short                       = odingl.SHORT,
    Unsigned_Int                = odingl.UNSIGNED_INT,
    Int                         = odingl.INT,
    Float                       = odingl.FLOAT,
    Unsigned_Byte_3_3_2         = odingl.UNSIGNED_BYTE_3_3_2,
    Unsigned_Byte_2_3_3_rev     = odingl.UNSIGNED_BYTE_2_3_3_REV,
    Unsigned_Short_5_6_5        = odingl.UNSIGNED_SHORT_5_6_5,
    Unsigned_Short_5_6_5_rev    = odingl.UNSIGNED_SHORT_5_6_5_REV,
    Unsigned_Short_4_4_4_4      = odingl.UNSIGNED_SHORT_4_4_4_4,
    Unsigned_Short_4_4_4_4_rev  = odingl.UNSIGNED_SHORT_4_4_4_4_REV,
    Unsigned_Short_5_5_5_1      = odingl.UNSIGNED_SHORT_5_5_5_1,
    Unsigned_Short_1_5_5_5_rev  = odingl.UNSIGNED_SHORT_1_5_5_5_REV,
    Unsigned_Int_8_8_8_8        = odingl.UNSIGNED_INT_8_8_8_8,
    Unsigned_Int_8_8_8_8_rev    = odingl.UNSIGNED_INT_8_8_8_8_REV,
    Unsigned_Int_10_10_10_2     = odingl.UNSIGNED_INT_10_10_10_2,
    Unsigned_Int_2_10_10_10_rev = odingl.UNSIGNED_INT_2_10_10_10_REV,
}

Texture_Parameter :: enum i32 {
    Depth_Stencil_Texture_Mode = odingl.DEPTH_STENCIL_TEXTURE_MODE,
    Base_Level                 = odingl.TEXTURE_BASE_LEVEL,
    Compare_Func               = odingl.TEXTURE_COMPARE_FUNC,
    Compare_Mode               = odingl.TEXTURE_COMPARE_MODE,
    Lod_Bias                   = odingl.TEXTURE_LOD_BIAS,
    Min_Filter                 = odingl.TEXTURE_MIN_FILTER,
    Mag_Filter                 = odingl.TEXTURE_MAG_FILTER,
    Min_Lod                    = odingl.TEXTURE_MIN_LOD,
    Max_Lod                    = odingl.TEXTURE_MAX_LOD,
    Max_Level                  = odingl.TEXTURE_MAX_LEVEL,
    Swizzle_R                  = odingl.TEXTURE_SWIZZLE_R,
    Swizzle_G                  = odingl.TEXTURE_SWIZZLE_G,
    Swizzle_B                  = odingl.TEXTURE_SWIZZLE_B,
    Swizzle_A                  = odingl.TEXTURE_SWIZZLE_A,
    Wrap_S                     = odingl.TEXTURE_WRAP_S,
    Wrap_T                     = odingl.TEXTURE_WRAP_T,
    Wrap_R                     = odingl.TEXTURE_WRAP_R,
    Texture_Border_Color       = odingl.TEXTURE_BORDER_COLOR,
}

Texture_Parameter_Value :: enum i32 {
    Nearest                = odingl.NEAREST,
    Linear                 = odingl.LINEAR,
    Nearest_Mipmap_Nearest = odingl.NEAREST_MIPMAP_NEAREST,
    Linear_Mipmap_Nearest  = odingl.LINEAR_MIPMAP_NEAREST,
    Nearest_Mipmap_Linear  = odingl.NEAREST_MIPMAP_LINEAR,
    Linear_Mipmap_Linear   = odingl.LINEAR_MIPMAP_LINEAR,

    Repeat                 = odingl.REPEAT,
    Clamp_To_Edge          = odingl.CLAMP_TO_EDGE,
    Clamp_To_Border        = odingl.CLAMP_TO_BORDER,

    Mirrored_Repeat        = odingl.MIRRORED_REPEAT,
}



Polygon_Face :: enum u32 {
    Front          = odingl.FRONT,
    Back           = odingl.BACK,
    Front_And_Back = odingl.FRONT_AND_BACK,
}

Polygon_Mode :: enum u32 {
    Point = odingl.POINT,
    Line  = odingl.LINE,
    Fill  = odingl.FILL,
}