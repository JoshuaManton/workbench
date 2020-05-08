package workbench

when DEVELOPER {

import "core:strings"

import "platform"

Message_Popup :: struct {
    message: string,
    t: f32,
}

messages: [dynamic]Message_Popup;

message_popup :: proc(message: string) {
    append(&messages, Message_Popup{strings.clone(message), 0});
}

update_message_popups :: proc(dt: f32) {
    SPEED :: 0.5;
    SIZE  :: 0.5;
    for idx := len(messages)-1; idx >= 0; idx -= 1 {
        m := &messages[idx];
        m.t += dt * SPEED;

        if m.t > 1 {
            delete(m.message);
            unordered_remove(&messages, idx);
            continue;
        }

        window_width  := platform.main_window.width;
        window_height := platform.main_window.height;
        string_width := get_string_width(.Pixel, get_font("roboto"), m.message, SIZE);
        posx := window_width/2 - (string_width/2);
        posy := window_height * 0.4 - (window_height * 0.1 * m.t);
        alpha := 1-pow(m.t, 3);
        im_text(.Pixel, get_font("roboto"), m.message, Vec2{posx+3, posy+3}, {0, 0, 0, alpha}, SIZE);
        im_text(.Pixel, get_font("roboto"), m.message, Vec2{posx, posy},     {1, 1, 1, alpha}, SIZE);
    }
}

}