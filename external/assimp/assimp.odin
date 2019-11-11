package assimp

foreign import lib "assimp-vc141-mt.lib";

@(default_calling_convention="c")
foreign lib {
	@(link_name="aiImportFile")                import_file :: proc(pFile1:cstring, pFile2: u32) -> ^Scene ---;
	@(link_name="aiReleaseImport")             release_import :: proc(pScene: ^Scene) ---;
	@(link_name="aiImportFileFromMemory")      import_file_from_memory :: proc(pBuffer: ^byte, pLength: i32, pFlags: u32, pHint: ^byte) -> ^Scene ---;
	@(link_name="aiGetErrorString")			   get_error_string :: proc() -> cstring ---;
	//@(link_name="aiImportFileEx")              import_fileex :: proc(pFile:cstring,pFlags: u32,pFS: ^aiFileIO) -> ^Scene ---;
	//@(link_name="aiGetPredefinedLogStream")    get_predefined_log_stream :: proc(pStreams: Default_Log_Stream,file:cstring) -> aiLogStream ---;
	//@(link_name="aiAttachLogStream")           attach_log_stream :: proc(stream: ^aiLogStream) ---;
	//@(link_name="aiEnableVerboseLogging")      enable_verbose_logging :: proc(d: Bool) ---;
	//@(link_name="aiDetachLogStream")           detach_log_stream :: proc(stream: ^aiLogStream) -> Return ---;
	@(link_name="aiApplyPostProcessing")       apply_post_processing :: proc(pScene: ^Scene,pFlags: u32) -> ^Scene ---;
	@(link_name="aiIsExtensionSupported")      is_extension_supported :: proc(szExtension:cstring) -> Bool ---;
	@(link_name="aiGetExtensionList")          get_extension_list :: proc(szOut: ^String) ---;
	@(link_name="aiGetMemoryRequirements")     get_memory_requirements :: proc(pIn: ^Scene,info: ^Memory_Info) ---;
	@(link_name="aiSetImportPropertyInteger")  set_import_property_integer :: proc(szName:cstring,value: int) ---;
	@(link_name="aiSetImportPropertyFloat")    set_import_property_float :: proc(szName:cstring,value: f64) ---;
	@(link_name="aiSetImportPropertyString")   set_import_property_string :: proc(szName:cstring,st: ^String) ---;
	@(link_name="aiCreateQuaternionFromMatrix")create_quaternion_from_matrix :: proc(quat: ^Quaternion,mat: ^Matrix3x3) ---;
	@(link_name="aiDecomposeMatrix")           decompose_matrix :: proc(mat: ^Matrix4x4,scaling: ^Vector3D,rotation: ^Quaternion,position: ^Vector3D) ---;
	@(link_name="aiTransposeMatrix4")          transpose_matrix4 :: proc(mat: ^Matrix4x4) ---;
	@(link_name="aiTransposeMatrix3")          transpose_matrix3 :: proc(mat: ^Matrix3x3) ---;
	@(link_name="aiTransformVecByMatrix3")     transform_vec_by_matrix3 :: proc(vec: ^Vector3D,mat: ^Matrix3x3) ---;
	@(link_name="aiTransformVecByMatrix4")     transform_vec_by_matrix4 :: proc(vec: ^Vector3D,mat: ^Matrix4x4) ---;
	@(link_name="aiMultiplyMatrix4")           multiply_matrix4 :: proc(dst: ^Matrix4x4,src: ^Matrix4x4) ---;
	@(link_name="aiMultiplyMatrix3")           multiply_matrix3 :: proc(dst: ^Matrix3x3,src: ^Matrix3x3) ---;
	@(link_name="aiIdentityMatrix3")           identity_matrix3 :: proc(mat: ^Matrix3x3) ---;
	@(link_name="aiIdentityMatrix4")           identity_matrix4 :: proc(mat: ^Matrix4x4) ---;
	@(link_name="aiGetMaterialProperty")       get_material_property :: proc(pMat: ^Material,pKey:cstring,type: u32,index: u32,pPropOut: ^^Material_Property) -> Return ---;
	@(link_name="aiGetMaterialFloatArray")     get_material_floatArray :: proc(pMat: ^Material,pKey:cstring,type: u32,index: u32,pOut: ^f64,pMax: ^u32) -> Return ---;
	@(link_name="aiGetMaterialIntegerArray")   get_material_integerArray :: proc(pMat: ^Material,pKey:cstring,type: u32,index: u32,pOut: ^int,pMax: ^u32) -> Return ---;
	@(link_name="aiGetMaterialColor")          get_material_color :: proc(pMat: ^Material,pKey:cstring,type: u32,index: u32,pOut: ^Color4D) -> Return ---;
	@(link_name="aiGetMaterialString")         get_material_string :: proc(pMat: ^Material,pKey:cstring,type: u32,index: u32,pOut: ^String) -> Return ---;
	@(link_name="aiGetMaterialTextureCount")   get_material_textureCount :: proc(pMat: ^Material,type: Texture_Type) -> u32 ---;
	@(link_name="aiGetMaterialTexture")        get_material_texture :: proc(mat: ^Material,type: Texture_Type,index: u32,path: ^String,mapping: ^Texture_Mapping,uvindex: ^u32,blend: ^f64,op: ^Texture_Op,mapmode: ^Texture_Map_Mode) -> Return ---;
}

Vector_Key :: struct {
	time : f64,
	value : Vector3D,
}
Quat_Key :: struct {
	time : f64,
	value : Quaternion,
}
Anim_Behaviour :: enum u32 {
	Default  = 0x0,
	Constant = 0x1,
	Linear = 0x2,
	Repeat = 0x3
}

Node_Anim :: struct {
	node_name : String,
	num_position_keys : u32,
	position_keys : ^Vector_Key,
	num_rotation_keys : u32,
	rotation_keys : ^Quat_Key,
	num_scaling_keys : u32,
	scaling_keys : ^Vector_Key,
	pre_state : Anim_Behaviour,
	post_state : Anim_Behaviour,
}

Animation :: struct {
	name : String,
	duration : f64,
	ticks_per_second : f64,
	num_channels : u32,
	channels : ^^Node_Anim,
}

Bool :: enum int {
	False = 0,
	True = 1
}

String :: struct {
	length : u32,
	data : [1024]u8,
}

Return :: enum u32 {
	Success = 0x0,
	Failure = 0x1,
	Out_Of_Memory = 0x3
}

Origin :: enum u32 {
	Set = 0x0,
	Cur = 0x1,
	End = 0x2
}

Default_Log_Stream :: enum {
	File = 0x1,
	Stdout = 0x2,
	Stderr = 0x4,
	Debugger = 0x8
}

Memory_Info :: struct {
	textures : u32,
	materials : u32,
	meshes : u32,
	nodes : u32,
	animations : u32,
	cameras : u32,
	lights : u32,
	total : u32,
}

Camera :: struct {
	name : String,
	position : Vector3D,
	up : Vector3D,
	look_at : Vector3D,
	horizontal_fov : f32,
	clip_plane_near : f32,
	clip_plane_far : f32,
	aspect : f32,
}

Texture_Op :: enum u32 {
	Multiply = 0x0,
	Add = 0x1,
	Subtract = 0x2,
	Divide = 0x3,
	SmoothAdd = 0x4,
	SignedAdd = 0x5
}
Texture_Map_Mode :: enum u32 {
	Wrap = 0x0,
	Clamp = 0x1,
	Decal = 0x3,
	Mirror = 0x2
}
Texture_Mapping :: enum u32 {
	UV = 0x0,
	Sphere = 0x1,
	Cylinder = 0x2,
	Box = 0x3,
	Plane = 0x4,
	Other = 0x5
}

Texture_Type :: enum u32 {
	None = 0x0,
	Diffuse = 0x1,
	Specular = 0x2,
	Ambient = 0x3,
	Emissive = 0x4,
	Height = 0x5,
	Normals = 0x6,
	Shininess = 0x7,
	Opacity = 0x8,
	Displacement = 0x9,
	Lightmap = 0xA,
	Reflection = 0xB,
	Unknown = 0xC
}

Shading_Mode :: enum u32 {
	Flat = 0x1,
	Gouraud =   0x2,
	Phong = 0x3,
	Blinn = 0x4,
	Toon = 0x5,
	Oren_Nayar = 0x6,
	Minnaert = 0x7,
	Cook_Torrance = 0x8,
	No_Shading = 0x9,
	Fresnel = 0xa
}

Texture_Flags :: enum u32 {
	Invert = 0x1,
	Use_Alpha = 0x2,
	Ignore_Alpha = 0x4
}

Blend_Mode :: enum {
	Default = 0x0,
	Additive = 0x1
}

UV_Transform :: struct {
	translation : Vector2D,
	scaling : Vector2D,
	rotation : f32,
}

Property_Type_Info :: enum u32 {
	Float = 0x1,
	String = 0x3,
	Integer = 0x4,
	Buffer = 0x5
}

Material_Property :: struct {
	key : String,
	semantic : u32,
	index : u32,
	data_length : u32,
	type : Property_Type_Info,
	data : cstring,
}
Material :: struct {
	properties : ^^Material_Property,
	num_properties : u32,
	num_allocated : u32,
}

Light_Source_Type :: enum u32 {
	Undefined = 0x0,
	Directional = 0x1,
	Point = 0x2,
	Spot = 0x3
}

Light :: struct {
	name : String,
	type : Light_Source_Type,
	position : Vector3D,
	direction : Vector3D,
	attenuation_constant : f32,
	attenuation_linear : f32,
	attenuation_quadratic : f32,
	color_diffuse : Color3D,
	color_specular : Color3D,
	color_ambient : Color3D,
	angle_inner_cone : f32,
	angle_outer_cone : f32,
}

// todo(josh)
// aiFileIO :: struct {
// 	OpenProc : aiFileOpenProc,
// 	CloseProc : aiFileCloseProc,
// 	UserData : aiUserData,
// }
// aiFile :: struct {
// 	ReadProc : aiFileReadProc,
// 	WriteProc : aiFileWriteProc,
// 	TellProc : aiFileTellProc,
// 	FileSizeProc : aiFileTellProc,
// 	SeekProc : aiFileSeek,
// 	FlushProc : aiFileFlushProc,
// 	UserData : aiUserData,
// }

AI_MAX_FACE_INDICES :: 0x7fff;
AI_MAX_BONE_WEIGHTS :: 0x7fffffff;
AI_MAX_VERTICES :: 0x7fffffff;
AI_MAX_FACES :: 0x7fffffff;
AI_MAX_NUMBER_OF_COLOR_SETS :: 0x8;
AI_MAX_NUMBER_OF_TEXTURECOORDS :: 0x8;

Face :: struct {
	num_indices : u32,
	indices : ^u32,
}

Vertex_Weight :: struct {
	vertex_id : u32,
	weight : f32,
}

Bone :: struct {
	name : String,
	num_weights : u32,
	armature: ^Node,
	node: ^Node,
	weights : ^Vertex_Weight,
	offset_matrix : Matrix4x4,
}

Primitive_Type :: enum u32 {
	Point = 0x1,
	Line = 0x2,
	Triangle = 0x4,
	Polygon = 0x8
}

Anim_Mesh :: struct {
	vertices : ^Vector3D,
	normals : ^Vector3D,
	tangents : ^Vector3D,
	bitangents : ^Vector3D,
	colors : [AI_MAX_NUMBER_OF_COLOR_SETS]^Color4D,
	texture_coords : [AI_MAX_NUMBER_OF_TEXTURECOORDS]^Vector3D,
	num_vertices : u32,
}

Mesh :: struct {
	primitive_types : u32,
	num_vertices : u32,
	num_faces : u32,
	vertices : ^Vector3D,
	normals : ^Vector3D,
	tangents : ^Vector3D,
	bitangents : ^Vector3D,
	colors : [AI_MAX_NUMBER_OF_COLOR_SETS]^Color4D,
	texture_coords : [AI_MAX_NUMBER_OF_TEXTURECOORDS]^Vector3D,
	num_uv_components : [AI_MAX_NUMBER_OF_TEXTURECOORDS]u32,
	faces : ^Face,
	num_bones : u32,
	bones : ^^Bone,
	material_index : u32,
	name : String,
	num_anim_meshes : u32,
	anim_meshes : ^^Anim_Mesh,
	method : u32,
}

has_positions :: proc(using mesh : ^Mesh) -> bool {
	return vertices != nil && num_vertices > 0;
}

has_faces :: proc(using mesh : ^Mesh) -> bool {
	return faces != nil && num_faces > 0;
}

has_normals :: proc(using mesh : ^Mesh) -> bool {
	return normals != nil && num_vertices > 0;
}

has_tangent_and_bitangents :: proc(using mesh : ^Mesh) -> bool {
	return tangents != nil && bitangents != nil && num_vertices > 0;
}

has_vertex_colors :: proc(using mesh : ^Mesh, pIndex : u32) -> bool {
	if pIndex >= AI_MAX_NUMBER_OF_COLOR_SETS do
        return false;
    else do
        return colors[pIndex] != nil && num_vertices > 0;
}

has_texture_coords :: proc(using mesh : ^Mesh, pIndex : u32) -> bool {
	if pIndex >= AI_MAX_NUMBER_OF_TEXTURECOORDS do
        return false;
    else do
        return texture_coords[pIndex] != nil && num_vertices > 0;
}

Vector2D :: struct {
	x : f32,
	y : f32,
}

Vector3D :: struct {
	x : f32,
	y : f32,
	z : f32,
}

Quaternion :: struct {
	w : f32,
	x : f32,
	y : f32,
	z : f32,
}

Matrix3x3 :: struct {
	a1, a2, a3 : f32,
	b1, b2, b3 : f32,
	c1, c2, c3 : f32,
}

Matrix4x4 :: struct {
	a1, a2, a3, a4 : f32,
	b1, b2, b3, b4 : f32,
	c1, c2, c3, c4 : f32,
	d1, d2, d3, d4 : f32,
}

Plane :: struct {
	a : f32,
	b : f32,
	c : f32,
	d : f32,
}

Ray :: struct {
	pos : Vector3D,
	dir : Vector3D,
}

Color3D :: struct {
	r : f32,
	g : f32,
	b : f32,
}

Color4D :: struct {
	r : f32,
	g : f32,
	b : f32,
	a : f32,
}

Texel :: struct {
	b : byte,
}

Texture :: struct {
	width : u32,
	height : u32,
	ach_format_hint : [4]u8,
	pc_data : ^Texel,
}

Node :: struct {
	name : String,
	transformation : Matrix4x4,
	parent : ^Node,
	num_children : u32,
	children : ^^Node,
	num_meshes : int,
	meshes : ^u32,
}

Scene_Flags :: enum u32 {
	Incomplete = 0x1,
	Validated = 0x2,
	Validation_Warning = 0x4,
	Non_Verbose_Format = 0x8,
	Flags_Terrain = 0x10
}

Scene :: struct {
	flags : u32,
	root_node : ^Node,
	num_meshes : u32,
	meshes : ^^Mesh,
	num_materials : u32,
	materials : ^^Material,
	num_animations : u32,
	animations : ^^Animation,
	num_textures : u32,
	textures : ^^Texture,
	num_lights : u32,
	lights : ^^Light,
	num_cameras : u32,
	cameras : ^^Camera,
}

Post_Process_Steps :: enum u32 {
	Calc_Tangent_Space = 0x1,
	Join_Identical_Vertices = 0x2,
	Make_Left_Handed = 0x4,
	Triangulate = 0x8,
	Remove_Component = 0x10,
	Gen_Normals = 0x20,
	Gen_Smooth_Normals = 0x40,
	Split_Large_Meshes = 0x80,
	Pre_Transform_Vertices = 0x100,
	Limit_Bone_Weights = 0x200,
	Validate_Data_Structure = 0x400,
	Improve_Cache_Locality = 0x800,
	Remove_Redundant_Materials = 0x1000,
	Fix_Infacing_Normals = 0x2000,
	Sort_By_PType = 0x8000,
	Find_Degenerates = 0x10000,
	Find_Invalid_Data = 0x20000,
	Gen_UV_Coords = 0x40000,
	Transform_UV_Coords = 0x80000,
	Find_Instances = 0x100000,
	Optimize_Meshes = 0x200000,
	Optimize_Graph  = 0x400000,
	Flip_UVs = 0x800000,
	Flip_Winding_Order  = 0x1000000
}