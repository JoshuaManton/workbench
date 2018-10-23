package lexer

import "core:fmt"
import "core:strings"
import "core:strconv"

/*

laas: Lexer as a Service

=> API

	make_lexer :: inline proc(text: string) -> Lexer // just makes a lexer, identical to `Lexer{some_text, 0, 0, 0}`

	get_next_token :: proc(lexer: ^Lexer) -> (Token, bool) // advances lexer and returns a `Token` and a `bool` indicating whether this is a valid token (true) or we have reached the end of the stream (false)

=> Usage

import "shared:laas"

main :: proc() {
	some_string : string = /* ... */;
	lexer := laas.make_lexer(some_string);
	for {
		token, ok := laas.get_next_token(&lexer);
		if !ok do break;

		// ...
	}
}

*/

Lexer :: struct {
	lexer_text: string,

	lex_idx:  int,
	lex_char: int,
	lex_line: int,
}

Token_Identifier :: struct {

	// note(josh): value is allocated
	value: string,

}

Token_Number :: struct {
	int_value: i64,
	unsigned_int_value: u64,
	float_value: f64,
	has_a_dot: bool,
}

Token_String :: struct {

	// note(josh): value is allocated

	value: string,

}

Token_Symbol :: struct {
	value: rune,
}

Token :: struct {
	// note(josh): not allocated, this is a slice of the text the user passed into make_lexer(), do not free the text if you need this field to stay valid
	slice_of_text: string,

	kind: union {
		Token_Identifier,
		Token_Number,
		Token_String,
		Token_Symbol,
	},
}

make_lexer :: inline proc(text: string) -> Lexer {
	return Lexer{text, 0, 0, 0};
}

get_next_token :: proc(using lexer: ^Lexer, loc := #caller_location) -> (Token, bool) {
	if lex_idx >= len(lexer_text) do return {}, false;
	for _is_whitespace(lexer_text[lex_idx]) {
		if !_inc(lexer) do return {}, false;
	}

	token: Token;
	token_start_char := lex_char;
	token_start_line := lex_line;

	r := (cast(rune)lexer_text[lex_idx]);
	switch r {
		case '"': {
			if !_inc(lexer) {
				panic(fmt.tprint("End of text from within string"));
				return {}, false;
			}
			start := lex_idx;
			escaped := false;
			for lexer_text[lex_idx] != '"' || escaped {
				escaped = lexer_text[lex_idx] == '\\';

				if !_inc(lexer) {
					panic(fmt.tprint("End of text from within string"));
					return {}, false;
				}
			}

			token_text := lexer_text[start:lex_idx];
			token = Token{token_text, Token_String{strings.new_string(token_text)}};
		}

		case '!'..'/', ':'..'@', '['..'`', '{'..'~': {
			token = Token{lexer_text[lex_idx:lex_idx], Token_Symbol{r}};
		}

		case 'A'..'Z', 'a'..'z', '_': {
			start := lex_idx;
			ident_loop:
			for {
				switch lexer_text[lex_idx] {
					case 'A'..'Z', 'a'..'z', '0'..'9', '_': {
						if !_inc(lexer) {
							break ident_loop;
						}
					}
					case: {
						break ident_loop;
					}
				}
			}
			token_text := lexer_text[start:lex_idx];
			_dec(lexer);
			token = Token{token_text, Token_Identifier{strings.new_string(token_text)}};
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
						if !_inc(lexer) {
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
			unsigned_int_val: u64;
			float_val: f64;
			if found_a_dot {
				float_val = strconv.parse_f64(token_text);
				int_val = cast(i64)float_val;
				unsigned_int_val = cast(u64)float_val;
			}
			else {
				unsigned_int_val = strconv.parse_u64(token_text);
				int_val = strconv.parse_i64(token_text);
				float_val = cast(f64)int_val;
			}

			_dec(lexer);

			token = Token{token_text, Token_Number{int_val, unsigned_int_val, float_val, found_a_dot}};
		}

		case: {
			fmt.println("Unknown token:", cast(rune)lexer_text[lex_idx], "at line", token_start_line, "column", token_start_char);
			assert(false);
		}
	}

	_inc(lexer);

	assert(token.kind != nil);
	return token, true;
}

_is_whitespace :: inline proc(r: u8) -> bool {
	switch cast(rune)r {
		case ' ', '\n', '\r', '\t': {
			return true;
		}
	}
	return false;
}

_dec :: inline proc(using lexer: ^Lexer) {
	lex_idx -= 1;
	lex_char -= 1;
}

_inc :: proc(using lexer: ^Lexer) -> bool {
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

main :: proc() {
	lexer := make_lexer(`foo 123 1.0 , $ true    	false, "ffffoooooooozle" blabbaaa: 123.0`);
	for {
		token, ok := get_next_token(&lexer);
		if !ok do break;

		fmt.println(token);
	}
}