package workbench

import "core:fmt"

Static_List :: struct(Cap: int, Type: typeid) {
    data: []Type,

    count: int,
    array: [Cap]Type,
}

append :: proc(using list: $T/^Static_List($Cap, $Type), thing: Type) -> ^Type {
    assert(count < Cap);
    count += 1;
    data = array[:count];
    data[count-1] = thing;
    result := &list.data[count-1];
    return result;
}

add :: proc(using list: $T/^Static_List($Cap, $Type)) -> ^Type {
    assert(count < Cap);
    count += 1;
    data = array[:count];
    ptr := &data[count-1];
    ptr^ = {};
    return ptr;
}

pop :: proc(using list: $T/^Static_List($Cap, $Type)) -> (Type, bool) {
    if count == 0 do return {}, false;
    thing := array[count-1];
    count -= 1;
    data = array[:count];
    return thing, true;
}

clear :: proc(using list: $T/^Static_List($Cap, $Type)) {
    count = 0;
    data = {};
}

unordered_remove :: proc(using list: $T/^Static_List($Cap, $Type), index: int) {
    data[index] = data[len(data)-1];
    pop(list);
}



Static_String :: struct(Length: int) {
    str: string,
    array: [Length]byte,
}

ssprint :: proc(ss: ^Static_String($Cap), s: string) -> string {
    ss.str = bprint(&ss.array[:], s);
    if len(ss.str != len(s)) {
        fmt.println("Static_String not big enough to hold value being printed to it: ", s);
    }
    return ss.str;
}