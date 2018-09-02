package workbench

// Event :: struct {
// 	callbacks: [dynamic]proc(),
// }
// Event1 :: struct($t1: typeid) {
// 	callbacks: [dynamic]proc(t1),
// }
// Event2 :: struct($t1: typeid, $t2: typeid) {
// 	callbacks: [dynamic]proc(t1, t2),
// }
// Event3 :: struct($t1: typeid, $t2: typeid, $t3: typeid) {
// 	callbacks: [dynamic]proc(t1, t2, t3),
// }



// make_event      :: proc[make_event_none, make_event1, make_event2, make_event3];
// make_event_none :: inline proc()                             -> Event              do return Event{};
// make_event1     :: inline proc(t1: type)                     -> Event1(t1)         do return Event1(t1){};
// make_event2     :: inline proc(t1: type, t2: type)           -> Event2(t1, t2)     do return Event2(t1, t2){};
// make_event3     :: inline proc(t1: type, t2: type, t3: type) -> Event3(t1, t2, t3) do return Event3(t1, t2, t3){};



// subscribe :: proc(event: $T/^$S, callback: $P) {
// 	append(&event.callbacks, callback);
// }

// unsubscribe :: proc(event: $T/^$S, callback: $P) {
// 	for c, i in event.callbacks {
// 		if c == callback {
// 			remove(&event.callbacks, i);
// 			return;
// 		}
// 	}
// }



// fire_event :: proc[fire_event_none, fire_event1, fire_event2, fire_event3];
// fire_event_none :: proc(event: $T/^$S) {
// 	for callback in event.callbacks {
// 		callback();
// 	}
// }
// fire_event1 :: proc(event: $T/^$S, arg1: $P1) {
// 	for callback in event.callbacks {
// 		callback(arg1);
// 	}
// }
// fire_event2 :: proc(event: $T/^$S, arg1: $P1, arg2: $P2) {
// 	for callback in event.callbacks {
// 		callback(arg1, arg2);
// 	}
// }
// fire_event3 :: proc(event: $T/^$S, arg1: $P1, arg2: $P2, arg3: $P3) {
// 	for callback in event.callbacks {
// 		callback(arg1, arg2, arg3);
// 	}
// }