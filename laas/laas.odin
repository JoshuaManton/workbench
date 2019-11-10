package laas

using import "core:fmt"
import "core:strconv"

/*

=> laas: Lexer as a Service

todo(josh): write description
note(josh): laas never allocates, tokens are just slices of the source text

=> API

	// makes a lexer by value, identical to `Lexer{some_text, 0, 0, 0, nil}`
	make_lexer :: proc(text: string) -> Lexer

	// advances lexer and fills the passed `Token` pointer with the next token.
	// Returns a `bool` indicating whether this is a valid token (true) or we have reached the end of the stream (false)
	get_next_token :: proc(lexer: ^Lexer, token: ^Token) -> bool

	// returns the next token without advancing the lexer
	peek :: proc(lexer: ^Lexer, out_token: ^Token) -> bool

=> Usage

import "shared:laas"

main :: proc() {
	some_string : string = /* ... */;
	lexer := laas.make_lexer(some_string);
	token: laas.Token;
	for laas.get_next_token(&lexer, &token) {
		// ...
	}
}

*/

Lexer :: struct {
    lexer_text: string,

    lex_idx:  int,
    lex_char: int,
    lex_line: int,

    userdata: any,
}

Identifier :: struct {
    value: string,
}

Number :: struct {
    int_value: i64,
    unsigned_int_value: u64,
    float_value: f64,
    has_a_dot: bool,
}

String :: struct {
    value: string,
}

Symbol :: struct {
    value: rune,
}

New_Line :: struct {
}

EOF :: struct {

}

Token :: struct {
    slice_of_text: string,

    kind: union {
        Identifier,
        Number,
        String,
        Symbol,
        New_Line,
        EOF,
    },
}

make_lexer :: inline proc(text: string) -> Lexer {
	return Lexer{text, 0, 0, 0, nil};
}

get_next_token :: proc(using lexer: ^Lexer, token: ^Token, ignore_newline := false, loc := #caller_location) -> bool {
	token := token;
	_token: Token;
	if token == nil {
		token = &_token;
	}

	if lex_idx >= len(lexer_text) {
		token^ = Token{"", EOF{}};
		return false;
	}
	for _is_whitespace(lexer_text[lex_idx]) {
		if !_inc(lexer) {
			token^ = Token{"", EOF{}};
			return false;
		}
	}

	token^ = Token{};
	token_start_char := lex_char;
	token_start_line := lex_line;

	r := (cast(rune)lexer_text[lex_idx]);
	switch r {
		case '"': {
			if !_inc(lexer) {
				panic(fmt.tprint("End of text from within string"));
				return false;
			}
			start := lex_idx;
			escaped := false;
			for lexer_text[lex_idx] != '"' || escaped {
				escaped = lexer_text[lex_idx] == '\\';

				if !_inc(lexer) {
					panic(fmt.tprint("End of text from within string"));
					return false;
				}
			}

			token_text := lexer_text[start:lex_idx];
			token^ = Token{token_text, String{token_text}};
		}

		case '!'..'/', ':'..'@', '['..'`', '{'..'~': {
			token^ = Token{lexer_text[lex_idx:lex_idx+1], Symbol{r}};
		}

		case '\n': {
			token^ = Token{lexer_text[lex_idx:lex_idx], New_Line{}};
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
			token^ = Token{token_text, Identifier{token_text}};
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
			token^ = Token{token_text, Number{int_val, unsigned_int_val, float_val, found_a_dot}};
		}

		case: {
			fmt.println("Unknown token:", cast(rune)lexer_text[lex_idx], "at line", token_start_line, "column", token_start_char, "loc:", loc);
			assert(false);
		}
	}

	_inc(lexer);

	for ignore_newline {
		if _, is_newline := token.kind.(New_Line); !is_newline {
			break;
		}
		ok := get_next_token(lexer, token, ignore_newline);
		if !ok {
			token ^= {};
			return false;
		}
	}

	assert(token.kind != nil);
	return true;
}

is_token :: proc(lexer: ^Lexer, $T: typeid) -> bool {
	t: Token;
	ok := peek(lexer, &t);
	if !ok do return false;
	_, ok2 := t.kind.(T);
	return ok2;
}

peek :: proc(lexer: ^Lexer, out_token: ^Token, ignore_newline := false) -> bool {
	lexer_copy := lexer^;
	get_next_token(&lexer_copy, out_token, ignore_newline);
	_, is_end := out_token.kind.(EOF);
	return !is_end;
}

eat :: proc(lexer: ^Lexer) -> bool {
	t: Token;
	ok := get_next_token(lexer, &t);
	return ok;
}

expect :: proc(lexer: ^Lexer, $T: typeid) -> (T, bool) {
	t: Token;
	ok := get_next_token(lexer, &t);
	if !ok do return {}, false;

	return t.kind.(T);
}

expect_symbol :: proc(lexer: ^Lexer, r: rune) {
	t: Token;
	ok := get_next_token(lexer, &t);
	if !ok {
		assert(false, tprint("EOF"));
	}
	if s, ok := t.kind.(Symbol); ok {
		if s.value == r {
			return;
		}
		assert(false, tprint("Expected ", r, ", got ", s.value));
	}
	else {
		assert(false, tprint("Expected symbol, got ", t));
	}
}

expect_f32 :: proc(lexer: ^Lexer) -> f32 {
	t: Token;
	ok := get_next_token(lexer, &t);
	if !ok {
		assert(false, tprint("EOF"));
	}
	if n, ok := t.kind.(Number); ok {
		return cast(f32)n.float_value;
	}
	assert(false, tprint("Expected f32, got ", t));
	return 0;
}

expect_string :: proc(lexer: ^Lexer) -> string {
	t: Token;
	ok := get_next_token(lexer, &t);
	if !ok {
		assert(false, tprint("EOF"));
	}
	if n, ok := t.kind.(String); ok {
		return n.value;
	}
	assert(false, tprint("Expected string, got ", t));
	return "";
}

_is_whitespace :: inline proc(r: u8) -> bool {
	switch cast(rune)r {
		case ' ', '\r', '\t': {
			return true;
		}
		//case '\n': return false;
	}
	return false;
}

_dec :: inline proc(using lexer: ^Lexer) {
	lex_idx -= 1;
	lex_char -= 1;
}

_inc :: proc(using lexer: ^Lexer, location := #caller_location) -> bool {
	if lex_idx >= len(lexer_text) do
		printf(tprint(location));
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
	token: Token;
	for get_next_token(&lexer, &token) {
		fmt.println(token);
	}
}