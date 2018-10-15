package lexer

using import "core:fmt"
      import "core:os"
      import "core:strconv"

using import wb "shared:workbench"


main :: proc() {
	lexer := Lexer{`foo 123 1.0 , $ true    	false, "ffffoooooooozle" blabbaaa: 123.0`, {}};
	for {
		token, ok := get_next_token(&lexer);
		if !ok do break;

		fmt.println(token);
	}
}

Token_Identifier :: struct {
	value: string,
}

Token_Number :: struct {
	int_value: i64,
	float_value: f64,
	has_a_dot: bool,
}

Token_String :: struct {
	value: string,
}

Token_Bool :: struct {
	value: bool,
}

Token_Symbol :: struct {
	value: rune,
}

Token :: struct {
	kind: union {
		Token_Identifier,
		Token_Number,
		Token_String,
		Token_Bool,
		Token_Symbol,
	},
}

Lexer :: struct {
	lexer_text: string,

	using runtime_values: struct {
		lex_idx:  int,
		lex_char: int,
		lex_line: int,
	},
}

is_whitespace :: proc(r: u8) -> bool {
	switch cast(rune)r {
		case ' ', '\n', '\r', '\t': {
			return true;
		}
	}
	return false;
}

// todo(josh): remove this
dec :: proc(using lexer: ^Lexer) {
	lex_idx -= 1;
	lex_char -= 1;
}

inc :: proc(using lexer: ^Lexer) -> bool {
	r := lexer_text[lex_idx];
	lex_idx += 1;

	if r == '\n' {
		lex_char = 1;
		lex_line += 1;
	}
	else if r == '\t' {
		lex_char += 4;
	}
	else {
		lex_char += 1;
	}

	return lex_idx < len(lexer_text);
}

get_next_token :: proc(using lexer: ^Lexer, loc := #caller_location) -> (Token, bool) {
	if lex_idx >= len(lexer_text) do return {}, false;
	for is_whitespace(lexer_text[lex_idx]) {
		if !inc(lexer) do return {}, false;
	}

	token: Token;

	token_start_char := lex_char;
	token_start_line := lex_line;

	r := (cast(rune)lexer_text[lex_idx]);
	switch r {
		// case : { }

		case '!'..'/', ':'..'@', '['..'`', '{'..'~': {
			token = Token{Token_Symbol{r}};
		}

		case '\"': {
			if !inc(lexer) {
				panic(tprint("End of text from within string"));
				return {}, false;
			}
			start := lex_idx;
			escaped := false;
			for lexer_text[lex_idx] != '"' || escaped {
				escaped = lexer_text[lex_idx] == '\\';

				if !inc(lexer) {
					panic(tprint("End of text from within string"));
					return {}, false;
				}
			}

			token = Token{Token_String{lexer_text[start:lex_idx]}};
		}

		case 'A'..'Z', 'a'..'z', '_': {
			start := lex_idx;
			ident_loop:
			for {
				switch lexer_text[lex_idx] {
					case 'A'..'Z', 'a'..'z', '0'..'9', '_': {
						if !inc(lexer) {
							break ident_loop;
						}
					}
					case: {
						break ident_loop;
					}
				}
			}
			token_text := lexer_text[start:lex_idx];
			dec(lexer);
			token = Token{Token_Identifier{token_text}};
		}

		case '0'..'9', '.': {
			start := lex_idx;
			found_a_dot := false;
			// todo(josh): handle case with two dots in a float
			number_loop:
			for {
				switch lexer_text[lex_idx] {
					case '.': {
						assert(found_a_dot == false);
						found_a_dot = true;

						fallthrough;
					}
					case '0'..'9': {
						if !inc(lexer) {
							break number_loop;
						}
					}
					case: {
						break number_loop;
					}
				}
			}

			token_text := lexer_text[start:lex_idx];

			int_val: i64;
			float_val: f64;
			if found_a_dot {
				float_val = strconv.parse_f64(token_text);
				int_val = cast(i64)float_val;
			}
			else {
				int_val = strconv.parse_i64(token_text);
				float_val = cast(f64)int_val;
			}

			dec(lexer);

			token = Token{Token_Number{int_val, float_val, found_a_dot}};
		}

		case: {
			fmt.println("Unknown token:", cast(rune)lexer_text[lex_idx], "at line", token_start_line, "column", token_start_char);
			assert(false);
		}
	}

	inc(lexer);

	assert(token.kind != nil);
	return token, true;
}