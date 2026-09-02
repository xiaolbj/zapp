const std = @import("std");

pub const Target = enum {
    application_name,
    search,
    remote_image_url,
};

pub const capacity = 256;

/// Fixed-capacity UTF-8 single-line editor state shared by every text field.
/// Platform events are routed to the Model's active Target before mutating it.
pub const State = struct {
    buffer: [capacity]u8 = @splat(0),
    length: usize = 0,
    cursor: usize = 0,
    selection_anchor: usize = 0,
    composition_buffer: [capacity]u8 = @splat(0),
    composition_length: usize = 0,
    submission_count: u32 = 0,

    pub fn init(initial_text: []const u8) State {
        var state: State = .{};
        state.insertSingleLine(initial_text);
        return state;
    }

    pub fn text(self: *const State) []const u8 {
        return self.buffer[0..self.length];
    }

    pub fn hasSelection(self: *const State) bool {
        return self.cursor != self.selection_anchor;
    }

    pub fn selectionStart(self: *const State) usize {
        return @min(self.cursor, self.selection_anchor);
    }

    pub fn selectionEnd(self: *const State) usize {
        return @max(self.cursor, self.selection_anchor);
    }

    pub fn selectedText(self: *const State) []const u8 {
        return self.buffer[self.selectionStart()..self.selectionEnd()];
    }

    pub fn composition(self: *const State) []const u8 {
        return self.composition_buffer[0..self.composition_length];
    }

    pub fn focus(self: *State) void {
        self.cursor = self.length;
        self.selection_anchor = self.cursor;
    }

    pub fn blur(self: *State) void {
        self.composition_length = 0;
    }

    pub fn clear(self: *State) void {
        self.length = 0;
        self.cursor = 0;
        self.selection_anchor = 0;
        self.composition_length = 0;
    }

    pub fn insertSingleLine(self: *State, inserted: []const u8) void {
        self.deleteSelection();
        var index: usize = 0;
        while (index < inserted.len) {
            const sequence_length = utf8SequenceLength(inserted[index]);
            if (inserted[index] == '\r' or inserted[index] == '\n') break;
            if (index + sequence_length > inserted.len or self.length + sequence_length > self.buffer.len) break;
            var tail = self.length;
            while (tail > self.cursor) : (tail -= 1) {
                self.buffer[tail + sequence_length - 1] = self.buffer[tail - 1];
            }
            @memcpy(
                self.buffer[self.cursor .. self.cursor + sequence_length],
                inserted[index .. index + sequence_length],
            );
            self.length += sequence_length;
            self.cursor += sequence_length;
            self.selection_anchor = self.cursor;
            index += sequence_length;
        }
    }

    pub fn backspace(self: *State) void {
        if (self.hasSelection()) {
            self.deleteSelection();
            return;
        }
        if (self.cursor == 0) return;
        self.deleteRange(previousCodepoint(self.text(), self.cursor), self.cursor);
    }

    pub fn deleteSelection(self: *State) void {
        if (!self.hasSelection()) return;
        self.deleteRange(self.selectionStart(), self.selectionEnd());
    }

    pub fn moveCursor(self: *State, direction: i8, selecting: bool) void {
        if (!selecting and self.hasSelection()) {
            self.setCursor(if (direction < 0) self.selectionStart() else self.selectionEnd(), false);
            return;
        }
        const target = if (direction < 0)
            previousCodepoint(self.text(), self.cursor)
        else
            nextCodepoint(self.text(), self.cursor);
        self.setCursor(target, selecting);
    }

    pub fn setCursor(self: *State, target: usize, selecting: bool) void {
        self.cursor = codepointBoundaryAtOrBefore(self.text(), @min(target, self.length));
        if (!selecting) self.selection_anchor = self.cursor;
    }

    pub fn selectAll(self: *State) void {
        self.selection_anchor = 0;
        self.cursor = self.length;
    }

    pub fn setComposition(self: *State, composition_text: []const u8) void {
        self.composition_length = 0;
        var index: usize = 0;
        while (index < composition_text.len) {
            if (composition_text[index] == '\r' or composition_text[index] == '\n') break;
            const sequence_length = utf8SequenceLength(composition_text[index]);
            if (index + sequence_length > composition_text.len or
                self.composition_length + sequence_length > self.composition_buffer.len) break;
            @memcpy(
                self.composition_buffer[self.composition_length .. self.composition_length + sequence_length],
                composition_text[index .. index + sequence_length],
            );
            self.composition_length += sequence_length;
            index += sequence_length;
        }
    }

    pub fn commitComposition(self: *State, composition_text: []const u8) void {
        self.composition_length = 0;
        self.insertSingleLine(composition_text);
    }

    pub fn cancelComposition(self: *State) void {
        self.composition_length = 0;
    }

    pub fn submit(self: *State) void {
        self.submission_count +%= 1;
    }

    fn deleteRange(self: *State, start: usize, end: usize) void {
        const safe_start = @min(start, self.length);
        const safe_end = @min(@max(end, safe_start), self.length);
        const removed = safe_end - safe_start;
        var index = safe_end;
        while (index < self.length) : (index += 1) {
            self.buffer[index - removed] = self.buffer[index];
        }
        self.length -= removed;
        self.cursor = safe_start;
        self.selection_anchor = safe_start;
    }
};

fn utf8SequenceLength(first: u8) usize {
    return if (first < 0x80)
        1
    else if (first & 0xE0 == 0xC0)
        2
    else if (first & 0xF0 == 0xE0)
        3
    else if (first & 0xF8 == 0xF0)
        4
    else
        1;
}

fn previousCodepoint(text: []const u8, cursor: usize) usize {
    if (cursor == 0) return 0;
    var index = @min(cursor, text.len) - 1;
    while (index > 0 and text[index] & 0xC0 == 0x80) index -= 1;
    return index;
}

fn nextCodepoint(text: []const u8, cursor: usize) usize {
    if (cursor >= text.len) return text.len;
    var index = cursor + 1;
    while (index < text.len and text[index] & 0xC0 == 0x80) index += 1;
    return index;
}

fn codepointBoundaryAtOrBefore(text: []const u8, requested: usize) usize {
    var index = @min(requested, text.len);
    while (index > 0 and index < text.len and text[index] & 0xC0 == 0x80) index -= 1;
    return index;
}

test "independent editor states do not leak text cursor or composition" {
    var application_name: State = .{};
    var search: State = .{};
    application_name.insertSingleLine("应用");
    application_name.setComposition("ming");
    search.insertSingleLine("日志");
    try std.testing.expectEqualStrings("应用", application_name.text());
    try std.testing.expectEqualStrings("ming", application_name.composition());
    try std.testing.expectEqualStrings("日志", search.text());
    try std.testing.expectEqualStrings("", search.composition());
}

test "cursor requests snap to UTF-8 codepoint boundaries" {
    var state: State = .{};
    state.insertSingleLine("A中B");
    state.setCursor(2, false);
    try std.testing.expectEqual(@as(usize, 1), state.cursor);
    state.moveCursor(1, false);
    try std.testing.expectEqual(@as(usize, 4), state.cursor);
}

test "clear preserves submission history but resets editing state" {
    var state: State = .{};
    state.insertSingleLine("query");
    state.submit();
    state.clear();
    try std.testing.expectEqualStrings("", state.text());
    try std.testing.expectEqual(@as(u32, 1), state.submission_count);
}
