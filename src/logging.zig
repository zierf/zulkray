const std = @import("std");
const datetime = @import("datetime");

const Self = @This();

pub const LoggingScopes = enum {
    Default,
    Application,
    Vulkan,

    pub fn asLiteral(self: *const @This()) @Type(.enum_literal) {
        return switch (self.*) {
            .Default => std.log.default_log_scope,
            .Application => .APP,
            .Vulkan => .VK,
        };
    }
};

pub const applog = std.log.scoped(LoggingScopes.Application.asLiteral());
pub const vklog = std.log.scoped(LoggingScopes.Vulkan.asLiteral());

pub fn logMessage(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    // ignore all non-error logging from sources other than
    // the default and listed scopes
    const scope_name = switch (scope) {
        LoggingScopes.Application.asLiteral(),
        LoggingScopes.Vulkan.asLiteral(),
        => @tagName(scope),
        LoggingScopes.Default.asLiteral() => "",
        else => blk: {
            if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err)) {
                break :blk @tagName(scope);
            } else {
                return;
            }
        },
    };

    const scope_width = std.fmt.comptimePrint("{d}", .{comptime maxScopeStringLenght()});
    const loglevel_width = std.fmt.comptimePrint("{d}", .{comptime maxLogLevelStringLenght()});

    // print the message to stderr, silently ignoring any errors
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr_file = std.io.getStdErr();
    const stderr = stderr_file.writer();

    // calls `getOrEnableAnsiEscapeSupport` and checks env vars
    // will be deprecated after writergate in favor of `std.Io.tty.Config.detect`
    const tty_config = std.io.tty.detectConfig(stderr_file);

    const message_color: std.io.tty.Color = switch (level) {
        .debug, .info => switch (scope) {
            // different color for messages from vulkan layers
            LoggingScopes.Vulkan.asLiteral() => .cyan,
            else => .reset,
        },
        .warn => .yellow,
        .err => .red,
    };

    tty_config.setColor(stderr, message_color) catch {};

    // print prefix
    nosuspend stderr.print("[{rfc3339}] {s: <" ++ scope_width ++ "} {s: <" ++ loglevel_width ++ "} ", .{
        datetime.DateTime.now(),
        scope_name,
        comptime level.asText(),
    }) catch return;
    // print original message after prefix
    nosuspend stderr.print(format, args) catch return;

    tty_config.setColor(stderr, .reset) catch {};

    nosuspend stderr.print("\n", .{}) catch return;
}

/// Calculate the maximum string width for stringified scope enum.
fn maxScopeStringLenght() usize {
    comptime var max_scope_len: usize = 0;

    inline for (std.meta.fields(LoggingScopes)) |tag| {
        const scope_tag: LoggingScopes = comptime @enumFromInt(tag.value);

        if (scope_tag == LoggingScopes.Default) {
            continue;
        }

        const scope_text_length = comptime @tagName(scope_tag.asLiteral()).len;

        max_scope_len = @max(max_scope_len, scope_text_length);
    }

    return max_scope_len;
}

/// Calculate the maximum string width for stringified log levels.
fn maxLogLevelStringLenght() usize {
    comptime var max_loglevel_len: usize = 0;

    inline for (std.meta.fields(std.log.Level)) |tag| {
        const level_tag: std.log.Level = comptime @enumFromInt(tag.value);
        const level_text_length = comptime level_tag.asText().len;

        max_loglevel_len = @max(max_loglevel_len, level_text_length);
    }

    return max_loglevel_len;
}
