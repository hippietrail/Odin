// File contains implementations of the Orca API that are defined as macros in Orca.

package orca

import "core:fmt"

////////////////////////////////////////////////////////////////////////////////
// Helpers for logging, asserting and aborting.
////////////////////////////////////////////////////////////////////////////////

log_error :: proc "contextless" (msg: cstring, loc := #caller_location) {
	log_ext(
		.ERROR,
		cstring(raw_data(loc.procedure)),
		cstring(raw_data(loc.file_path)),
		loc.line,
		msg,
	)
}

log_errorf :: proc(format: string, args: ..any, loc := #caller_location) {
	log_ext(
		.ERROR,
		cstring(raw_data(loc.procedure)),
		cstring(raw_data(loc.file_path)),
		loc.line,
		fmt.ctprintf(format, ..args),
	)
}

log_warning :: proc "contextless" (msg: cstring, loc := #caller_location) {
	log_ext(
		.WARNING,
		cstring(raw_data(loc.procedure)),
		cstring(raw_data(loc.file_path)),
		loc.line,
		msg,
	)
}

log_warningf :: proc(format: string, args: ..any, loc := #caller_location) {
	log_ext(
		.WARNING,
		cstring(raw_data(loc.procedure)),
		cstring(raw_data(loc.file_path)),
		loc.line,
		fmt.ctprintf(format, ..args),
	)
}

log_info :: proc "contextless" (msg: cstring, loc := #caller_location) {
	log_ext(
		.INFO,
		cstring(raw_data(loc.procedure)),
		cstring(raw_data(loc.file_path)),
		loc.line,
		msg,
	)
}

log_infof :: proc(format: string, args: ..any, loc := #caller_location) {
	log_ext(
		.INFO,
		cstring(raw_data(loc.procedure)),
		cstring(raw_data(loc.file_path)),
		loc.line,
		fmt.ctprintf(format, ..args),
	)
}

abort :: proc "contextless" (msg: cstring, loc := #caller_location) {
	abort_ext(
		cstring(raw_data(loc.procedure)),
		cstring(raw_data(loc.file_path)),
		loc.line,
		msg,
	)
}

abortf :: proc(format: string, args: ..any, loc := #caller_location) {
	abort_ext(
		cstring(raw_data(loc.procedure)),
		cstring(raw_data(loc.file_path)),
		loc.line,
		fmt.ctprintf(format, ..args),
	)
}

////////////////////////////////////////////////////////////////////////////////
// Types and helpers for doubly-linked lists.
////////////////////////////////////////////////////////////////////////////////

// Get the entry for a given list element.
list_entry :: proc "contextless" (elt: ^list_elt, $T: typeid, $member: string) -> ^T {
	return container_of(elt, T, member)
}

// Get the next entry in a list.
list_next_entry :: proc "contextless" (list: ^list, elt: ^list_elt, $T: typeid, $member: string) -> ^T {
	if elt.next != list.last {
		return list_entry(elt.next, T, member)
	}

	return nil
}

// Get the previous entry in a list.
list_prev_entry :: proc "contextless" (list: ^list, elt: ^list_elt, $T: typeid, $member: string) -> ^T {
	if elt.prev != list.last {
		return list_entry(elt.prev, T, member)
	}

	return nil
}

// Same as `list_entry` but `elt` might be `nil`.
list_checked_entry :: proc "contextless" (elt: ^list_elt, $T: typeid, $member: string) -> ^T {
	if elt != nil {
		return list_entry(elt, T, member)
	}

	return nil
}

list_first_entry :: proc "contextless" (list: ^list, $T: typeid, $member: string) -> ^T {
	return list_checked_entry(list.first, T, member)
}

list_last_entry :: proc "contextless" (list: ^list, $T: typeid, $member: string) -> ^T {
	return list_checked_entry(list.last, T, member)
}

// Example:
//
// 	_elt: ^list_elt
// 	for elt in oc.list_for(list, &_elt, int, "elt") {
// 	}
list_for :: proc "contextless" (list: ^list, elt: ^^list_elt, $T: typeid, $member: string) -> (^T, bool) {
	if elt == nil {
		assert_fail(#file, #procedure, #line, "elt != nil", "misuse of `list_for`, expected `elt` to not be nil")
	}

	if elt^ == nil {
		elt^ = list.first
		entry := list_checked_entry(elt^, T, member)
		return entry, entry != nil
	}

	elt^ = elt^.next
	entry := list_checked_entry(elt^, T, member)
	return entry, entry != nil
}

list_iter :: list_for

list_for_reverse :: proc "contextless" (list: ^list, elt: ^^list_elt, $T: typeid, $member: string) -> (^T, bool) {
	if elt^ == nil {
		elt^ = list.last
		entry := list_checked_entry(elt^, T, member)
		return entry, entry != nil
	}

	elt^ = elt^.prev
	entry := list_checked_entry(elt^, T, member)
	return entry, entry != nil
}

list_iter_reverse :: list_for_reverse

list_pop_front_entry :: proc "contextless" (list: ^list, $T: typeid, $member: string) -> ^T {
	if list_empty(list^) {
		return nil
	}

	return list_entry(list_pop_front(list), T, member)
}

list_pop_back_entry :: proc "contextless" (list: ^list, $T: typeid, $member: string) -> ^T {
	if list_empty(list^) {
		return nil
	}

	return list_entry(list_pop_back(list), T, member)
}

////////////////////////////////////////////////////////////////////////////////
// Base allocator and memory arenas.
////////////////////////////////////////////////////////////////////////////////

arena_push_type :: proc "contextless" (arena: ^arena, $T: typeid) -> ^T {
	return (^T)(arena_push_aligned(arena, size_of(T), align_of(T)))
}

arena_push_array :: proc "contextless" (arena: ^arena, $T: typeid, count: u64) -> []T {
	return (^T)(arena_push_aligned(arena, size_of(T) * count, align_of(T)))[:count]
}

scratch_end :: arena_scope_end

////////////////////////////////////////////////////////////////////////////////
// String slices and string lists.
////////////////////////////////////////////////////////////////////////////////

str8_list_first :: proc "contextless" (sl: ^str8_list) -> str8 {
	if list_empty(sl.list) {
		return ""
	}

	return list_first_entry(&sl.list, str8_elt, "listElt")._string
}

str8_list_last :: proc "contextless" (sl: ^str8_list) -> str8 {
	if list_empty(sl.list) {
		return ""
	}

	return list_last_entry(&sl.list, str8_elt, "listElt")._string
}

str8_list_for :: proc "contextless" (list: ^str8_list, elt: ^^list_elt) -> (^str8_elt, bool) {
	return list_for(&list.list, elt, str8_elt, "listElt")
}

str8_list_iter :: str8_list_for

str8_list_empty :: proc "contextless" (list: str8_list) -> bool {
	return list_empty(list.list)
}

str16_list_first :: proc "contextless" (sl: ^str16_list) -> str16 {
	if list_empty(sl.list) {
		return {}
	}

	return list_first_entry(&sl.list, str16_elt, "listElt")._string
}

str16_list_last :: proc "contextless" (sl: ^str16_list) -> str16 {
	if list_empty(sl.list) {
		return {}
	}

	return list_last_entry(&sl.list, str16_elt, "listElt")._string
}

str16_list_for :: proc "contextless" (list: ^str16_list, elt: ^^list_elt) -> (^str16_elt, bool) {
	return list_for(&list.list, elt, str16_elt, "listElt")
}

str32_list_first :: proc "contextless" (sl: ^str32_list) -> str32 {
	if list_empty(sl.list) {
		return {}
	}

	return list_first_entry(&sl.list, str32_elt, "listElt")._string
}

str32_list_last :: proc "contextless" (sl: ^str32_list) -> str32 {
	if list_empty(sl.list) {
		return {}
	}

	return list_last_entry(&sl.list, str32_elt, "listElt")._string
}

str32_list_for :: proc "contextless" (list: ^str32_list, elt: ^^list_elt) -> (^str32_elt, bool) {
	return list_for(&list.list, elt, str32_elt, "listElt")
}

@(deferred_none=ui_box_end)
ui_container :: proc "contextless" (name: string, flags: ui_flags = {}) -> ^ui_box {
	return ui_box_begin_str8(name, flags)
}

@(deferred_none=ui_end_frame)
ui_frame :: proc "contextless" (frame_size: [2]f32, style: ui_style, mask: ui_style_mask) {
	ui_begin_frame(frame_size, style, mask)
}

@(deferred_none=ui_panel_end)
ui_panel :: proc "contextless" (name: cstring, flags: ui_flags) {
	ui_panel_begin(name, flags)
}

@(deferred_none=ui_menu_end)
ui_menu :: proc "contextless" (name: cstring) {
	ui_menu_begin(name)
}

@(deferred_none=ui_menu_bar_end)
ui_menu_bar :: proc "contextless" (name: cstring) {
	ui_menu_bar_begin(name)
}
