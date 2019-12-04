package gpu

when !#defined(GPU_BACKEND) {
	GPU_BACKEND :: "OPENGL";
	OPENGL_VERSION_MAJOR :: 4;
	OPENGL_VERSION_MINOR :: 3;
}

BONES_PER_VERTEX :: 4;

init :: proc(set_proc_address: proc(rawptr, cstring)) {
	when GPU_BACKEND == "OPENGL" {
		init_opengl(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, set_proc_address);
	}
	else {
		#panic()
	}
}

deinit :: proc() {
}
