package workbench

UUID :: struct {
	_1, _2: u64,
}

get_new_uuid :: inline proc() -> UUID {
	uuid := UUID{random_u64(), random_u64()};
	return uuid;
}

uuid_equals :: inline proc(a, b: UUID) -> bool {
	return a._1 == b._1 && a._2 == b._2;
}