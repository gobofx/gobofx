//! Module assembly: `prelude.wgsl` + the plugin's shader file, as every host builds it.

use crate::PRELUDE;

/// Number of lines the prelude contributes, so diagnostics can report plugin-relative lines.
pub fn prelude_lines() -> usize {
    PRELUDE.lines().count()
}

/// The full WGSL source for one pass: prelude, a separator comment, then the plugin file verbatim.
pub fn assemble(plugin_source: &str) -> String {
    let mut s = String::with_capacity(PRELUDE.len() + plugin_source.len() + 64);
    s.push_str(PRELUDE);
    if !s.ends_with('\n') {
        s.push('\n');
    }
    s.push_str(plugin_source);
    s
}

/// Map a line number in the assembled source to a line number in the plugin file (1-based).
/// Lines inside the prelude map to `None`.
pub fn plugin_line(assembled_line: usize) -> Option<usize> {
    let p = prelude_lines();
    if assembled_line > p {
        Some(assembled_line - p)
    } else {
        None
    }
}
