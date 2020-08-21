package allocators

import "core:fmt"
import "core:mem"

buffer_allocate :: proc(buffer: []byte, offset: ^int, $T: typeid, panic_on_oom := false) -> ^T {
    ptr := buffer_allocate_size(buffer, offset, size_of(T), align_of(T), panic_on_oom);
    return cast(^T)ptr;
}

buffer_allocate_size :: proc(buffer: []byte, offset: ^int, size: int, alignment: int, panic_on_oom := false) -> rawptr {
    // Don't allow allocations of zero size. This would likely return a
    // pointer to a different allocation, causing many problems.
    if size == 0 {
        return nil;
    }

    // todo(josh): The `align_forward()` call and the `start + size` below
    // that could overflow if the `size` or `align` parameters are super huge

    start := mem.align_forward_int(offset^, alignment);

    // Don't allow allocations that would extend past the end of the buffer.
    if (start + size) > len(buffer) {
        if panic_on_oom {
            panic("buffer_allocate ran out of memory");
        }
        return nil;
    }

    offset^ = start + size;
    ptr := &buffer[start];
    mem.zero(ptr, size);
    return ptr;
}