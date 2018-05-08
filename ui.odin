using import "core:math.odin"
import "core:fmt.odin"

import "shared:workbench/wb.odin"

ui.button("button", font_other, wb.WHITE, wb.BLACK, Vec2{0.1, 0.8}, Vec2{0.1, 0.9}, Vec2{0.3, 0.9}, Vec2{0.3, 0.8});
button :: proc(text: string, font: wb.Font, text_color: Vec4, background_color: Vec4, p0, p1, p2, p3: Vec2) {

}