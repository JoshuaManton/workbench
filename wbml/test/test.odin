package wbml

using import "core:fmt"
using import "../../math"

      import wbml ".."

main :: proc() {
	run_tests();
}

run_tests :: proc() {
	Int_Enum :: enum int {
		Foo,
		Bar,
		Baz,
	};

	Byte_Enum :: enum u8 {
		Qwe,
		Asd,
		Zxc,
	};

	Foo :: struct {
		x, y, z: f32,
	};
	Bar :: struct {
		str: string,
		big_bool: b32,
	};

	Nightmare :: struct {
		some_int: int,
		some_string: string,
		some_float: f64,
		some_bool: bool,
		some_union: union {
			string,
			int,
		},
		union_foo: union {
			Foo,
			Bar,
		},
		union_bar: union {
			Foo,
			Bar,
		},
		some_unserialized_thing: int "wbml_noserialize",
		enum1: Int_Enum,
		enum2: Byte_Enum,
		some_nested_thing: struct {
			asd: f32,
			super_nested: struct {
				blah: string,
			},
			some_array: [4]string,
			dyn_array: [dynamic]bool,
			slice: []struct {
				x, y: f64,
			},
		},
		empty_dynamic_array: [dynamic]Foo,
		missing_dynamic_array: [dynamic]Foo,
		empty_slice: []Foo,
		missing_slice: []Foo,
	};

	source :=
`{
	some_int 123
	some_string "henlo lizer"
	some_float 123.400
	some_bool true
	some_union .string "foo"
	union_foo .Foo {
		x 1
		y 4
		z 9
	}
	union_bar .Bar {
		str "bar string"
		big_bool true
	}
	enum1 Baz
	enum2 Asd
	some_nested_thing {
		asd 432.500
		super_nested {
			blah "super nested string"
		}
		some_array [
			"123"
			"qwe"
			"asd"
			"zxc"
		]
		dyn_array [
			true
			false
			false
			true
		]
		slice [
			{
				x 12.000
				y 34.000
			}
			{
				x 43.000
				y 21.000
			}
		]
	}

	empty_dynamic_array [

	]

	empty_slice [

	]
}`;

	a := wbml.deserialize_to_value(Nightmare, transmute([]u8)source);

	assert(a.some_int == 123, tprint(a.some_int));
	assert(a.some_string == "henlo lizer", tprint(a.some_string));
	assert(a.some_float == 123.4, tprint(a.some_float));
	assert(a.some_bool == true, tprint(a.some_bool));

	assert(a.enum1 == .Baz, tprint(a.enum1));
	assert(a.enum2 == .Asd, tprint(a.enum2));

	if str, ok := a.some_union.(string); ok {
		assert(str == "foo", tprint(str));
	}
	else {
		assert(false, tprint("some_union wasn't a string: ", a.some_union));
	}

	if foo, ok := a.union_foo.(Foo); ok {
		assert(foo.x == 1, tprint(foo));
		assert(foo.y == 4, tprint(foo));
		assert(foo.z == 9, tprint(foo));
	}
	else {
		assert(false, tprint("union_foo wasn't a Foo: ", a.union_foo));
	}

	if bar, ok := a.union_bar.(Bar); ok {
		assert(bar.str == "bar string", tprint(bar));
		assert(bar.big_bool == true, tprint(bar));
	}
	else {
		assert(false, tprint("union_bar wasn't a Bar: ", a.union_bar));
	}

	assert(a.some_unserialized_thing == 0);

	assert(a.some_nested_thing.asd == 432.500, tprintf("%.8f", a.some_nested_thing.asd));
	assert(a.some_nested_thing.super_nested.blah == "super nested string", tprint(a.some_nested_thing.super_nested.blah));

	assert(len(a.some_nested_thing.some_array) == 4, tprint(len(a.some_nested_thing.some_array)));
	assert(a.some_nested_thing.some_array[0] == "123", tprint(a.some_nested_thing.some_array[0]));
	assert(a.some_nested_thing.some_array[1] == "qwe", tprint(a.some_nested_thing.some_array[1]));
	assert(a.some_nested_thing.some_array[2] == "asd", tprint(a.some_nested_thing.some_array[2]));
	assert(a.some_nested_thing.some_array[3] == "zxc", tprint(a.some_nested_thing.some_array[3]));

	assert(len(a.some_nested_thing.dyn_array) == 4, tprint(len(a.some_nested_thing.dyn_array)));
	assert(a.some_nested_thing.dyn_array[0] == true, tprint(a.some_nested_thing.dyn_array[0]));
	assert(a.some_nested_thing.dyn_array[1] == false, tprint(a.some_nested_thing.dyn_array[1]));
	assert(a.some_nested_thing.dyn_array[2] == false, tprint(a.some_nested_thing.dyn_array[2]));
	assert(a.some_nested_thing.dyn_array[3] == true, tprint(a.some_nested_thing.dyn_array[3]));

	assert(len(a.some_nested_thing.slice) == 2, tprint(len(a.some_nested_thing.slice)));
	assert(a.some_nested_thing.slice[0].x == 12, tprint(a.some_nested_thing.slice[0].x));
	assert(a.some_nested_thing.slice[0].y == 34, tprint(a.some_nested_thing.slice[0].y));
	assert(a.some_nested_thing.slice[1].x == 43, tprint(a.some_nested_thing.slice[1].x));
	assert(a.some_nested_thing.slice[1].y == 21, tprint(a.some_nested_thing.slice[1].y));

	assert(a.empty_dynamic_array == nil, tprint(a.empty_dynamic_array));
	assert(len(a.empty_dynamic_array) == 0, tprint(len(a.empty_dynamic_array)));
	assert(a.empty_slice == nil, tprint(a.empty_slice));
	assert(len(a.empty_slice) == 0, tprint(len(a.empty_slice)));


	a_text := wbml.serialize(&a);
	defer delete(a_text);
	println(a_text);
	b := wbml.deserialize(Nightmare, transmute([]u8)a_text);

	assert(a.some_int == b.some_int);
	assert(a.some_string == b.some_string);
	assert(a.some_float == b.some_float);
	assert(a.some_bool == b.some_bool);

	assert(a.enum1 == b.enum1);
	assert(a.enum2 == b.enum2);

	if str, ok := b.some_union.(string); ok {
		assert(str == a.some_union.(string));
	}
	else {
		assert(false, tprint("some_union wasn't a string: ", b.some_union));
	}

	if foo, ok := b.union_foo.(Foo); ok {
		assert(foo.x == a.union_foo.(Foo).x);
		assert(foo.y == a.union_foo.(Foo).y);
		assert(foo.z == a.union_foo.(Foo).z);
	}
	else {
		assert(false, tprint("union_foo wasn't a Foo: ", b.union_foo));
	}

	if bar, ok := b.union_bar.(Bar); ok {
		assert(bar.str      == a.union_bar.(Bar).str);
		assert(bar.big_bool == a.union_bar.(Bar).big_bool);
	}
	else {
		assert(false, tprint("union_foo wasn't a Foo: ", b.union_foo));
	}

	assert(a.some_nested_thing.asd == b.some_nested_thing.asd);
	assert(a.some_nested_thing.super_nested.blah == b.some_nested_thing.super_nested.blah);

	assert(len(a.some_nested_thing.some_array) == len(b.some_nested_thing.some_array));
	assert(len(a.some_nested_thing.some_array) == 4);
	assert(a.some_nested_thing.some_array[0] == b.some_nested_thing.some_array[0]);
	assert(a.some_nested_thing.some_array[1] == b.some_nested_thing.some_array[1]);
	assert(a.some_nested_thing.some_array[2] == b.some_nested_thing.some_array[2]);
	assert(a.some_nested_thing.some_array[3] == b.some_nested_thing.some_array[3]);

	assert(len(a.some_nested_thing.dyn_array) == len(b.some_nested_thing.dyn_array));
	assert(len(a.some_nested_thing.dyn_array) == 4);
	assert(a.some_nested_thing.dyn_array[0] == b.some_nested_thing.dyn_array[0]);
	assert(a.some_nested_thing.dyn_array[1] == b.some_nested_thing.dyn_array[1]);
	assert(a.some_nested_thing.dyn_array[2] == b.some_nested_thing.dyn_array[2]);
	assert(a.some_nested_thing.dyn_array[3] == b.some_nested_thing.dyn_array[3]);

	assert(len(a.some_nested_thing.slice) == len(b.some_nested_thing.slice));
	assert(len(a.some_nested_thing.slice) == 2);
	assert(a.some_nested_thing.slice[0].x == b.some_nested_thing.slice[0].x);
	assert(a.some_nested_thing.slice[0].y == b.some_nested_thing.slice[0].y);
	assert(a.some_nested_thing.slice[1].x == b.some_nested_thing.slice[1].x);
	assert(a.some_nested_thing.slice[1].y == b.some_nested_thing.slice[1].y);

	assert(a.empty_dynamic_array == nil, tprint(a.empty_dynamic_array));
	assert(len(a.empty_dynamic_array) == 0, tprint(len(a.empty_dynamic_array)));
	assert(a.empty_slice == nil, tprint(a.empty_slice));
	assert(len(a.empty_slice) == 0, tprint(len(a.empty_slice)));

	assert(b.empty_dynamic_array == nil, tprint(b.empty_dynamic_array));
	assert(len(b.empty_dynamic_array) == 0, tprint(len(b.empty_dynamic_array)));
	assert(b.empty_slice == nil, tprint(b.empty_slice));
	assert(len(b.empty_slice) == 0, tprint(len(b.empty_slice)));

	println("Tests done!");
}
