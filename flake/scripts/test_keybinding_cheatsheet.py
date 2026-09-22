#!/usr/bin/env python3
"""Fixture tests for keybinding-cheatsheet.py -- the parsers and chord
normalizer issue #371 required.

A wrong parse reads exactly like a correct one: the sheet's whole job is to
say what a key does on these hosts, and a chord that normalizes wrongly
(e.g. `^[J` collapsing into `^[j`, a pasted table's header cell becoming a
key) ships a confident lie about someone's keymap. The render side is
worst of all -- markdown of markdown -- so these tests pin the decoded
Chord, not just the rendered string, wherever the distinction matters.

The last class reads the real repo modules. The parser regexes are coupled
to those files' exact shapes (the attrset block in kitty-config.nix, the
`-C`-wrapped ble-bind callbacks in blesh.nix), and that coupling is what
will silently rot if a module is reformatted; a green parse here is the
drift alarm. Pure stdlib, no fleet state, no network. Runs via `just
keybindings-test`, part of `just preflight` and CI.
"""
import importlib.util
import os
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
# the hyphen in the module's filename rules out a plain `import`
_spec = importlib.util.spec_from_file_location(
    'keybinding_cheatsheet', os.path.join(HERE, 'keybinding-cheatsheet.py'))
kbc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(kbc)


def chord(spec, **kwargs):
    return kbc.parse_chord(spec, **kwargs)


class ChordNormalizationTests(unittest.TestCase):
    def test_notations_converge_on_one_chord(self):
        # ctrl+shift+s across kitty and emacs-with-shift encodings
        self.assertEqual(chord('ctrl+shift+s').canonical(), chord('kitty_mod+s').canonical())
        self.assertEqual(chord('C-S-s').canonical(), chord('ctrl+shift+s').canonical())

    def test_ctrl_right_across_encodings(self):
        want = chord('ctrl+right').canonical()
        self.assertEqual(chord(r'\e[1;5C').canonical(), want)
        self.assertEqual(chord('^[[1;5C').canonical(), want)
        self.assertEqual(chord('^[Oc').canonical(), want)   # app-mode ctrl+arrow

    def test_emacs_chords(self):
        self.assertEqual(chord('C-r').canonical(), chord('^R').canonical())
        self.assertEqual(chord('M-x').render(), 'Alt+X')
        self.assertEqual(chord('M-/').render(), 'Alt+/')

    def test_esc_uppercase_letter_carries_shift(self):
        # xterm: Meta+Shift+k sends ESC K -- must NOT collapse into ESC k
        self.assertNotEqual(chord('^[K').canonical(), chord('^[k').canonical())
        self.assertEqual(chord('^[K').render(), 'Alt+Shift+K')

    def test_named_control_and_rxvt_forms(self):
        self.assertEqual(chord('^M').render(), 'Enter')
        self.assertEqual(chord('^?').render(), 'Backspace')
        self.assertEqual(chord('^[[Z').render(), 'Shift+Tab')
        self.assertEqual(chord('^[OH').render(), 'Home')     # app-mode home
        # rxvt-style: CSI 3 ^ is ctrl-delete, matching the zsh4humans
        # translation '^[3\\^' -> '^[[3;5~' in initial-bindings.zsh
        self.assertEqual(chord(r'^[[3\^').canonical(), chord('^[[3;5~').canonical())

    def test_kitty_mod_resolves_against_config(self):
        self.assertEqual(chord('kitty_mod+s').render(), 'Ctrl+Shift+S')
        self.assertEqual(chord('kitty_mod+s', kitty_mod='ctrl+alt').render(), 'Ctrl+Alt+S')

    def test_render_forms(self):
        self.assertEqual(chord('cmd+c').render(), 'Cmd+C')
        self.assertEqual(chord('super+t').render(), 'Super+T')
        self.assertEqual(chord('enter').render(), 'Enter')
        self.assertEqual(chord('^[[3~').render(), 'Delete')

    def test_undecodable_sequence_survives_as_raw(self):
        c = chord('^[OX')            # SS3 X is not a key this decoder knows
        self.assertFalse(c.decoded)
        self.assertEqual(c.render(), '^[OX')

    def test_non_keys_are_rejected(self):
        # pasted-table header cells must not parse as chords
        self.assertIsNone(chord('Shortcut'))
        self.assertIsNone(chord('Action'))
        self.assertIsNone(chord('copy_to_clipboard'))


class KittySourceTests(unittest.TestCase):
    DEFINITION_PY = ("map('kitty_mod+enter', 'new_window_with_cwd',\n"
                     "    long_text='Open a new window')\n"
                     "map('ctrl+c', 'copy_or_interrupt')\n")

    def test_parses_map_entries_with_kitty_mod_resolved(self):
        out = kbc.parse_kitty_source(self.DEFINITION_PY, 'kitty', 'upstream test')
        self.assertEqual([(b.chord.render(), b.action) for b in out],
                         [('Ctrl+Shift+Enter', 'new_window_with_cwd'),
                          ('Ctrl+C', 'copy_or_interrupt')])

    def test_long_text_becomes_description(self):
        out = kbc.parse_kitty_source(self.DEFINITION_PY, 'kitty', 'upstream test')
        self.assertEqual(out[0].notes, 'Open a new window')


class MarkdownTableTests(unittest.TestCase):
    PIPE_TABLE = ("| Shortcut | Action |\n"
                  "| --- | --- |\n"
                  "| ctrl+shift+c | copy_to_clipboard |\n"
                  "| ctrl+shift+f5 | load_config_file |\n")

    def test_pipe_table_header_skipped(self):
        out = kbc.parse_markdown_table(self.PIPE_TABLE, 'kitty', 'upstream test')
        self.assertEqual(len(out), 2)
        self.assertNotIn('Shortcut', [b.chord.render() for b in out])

    def test_action_column_on_either_side(self):
        reversed_rows = "| ctrl+shift+c | copy_to_clipboard |\n" \
                        "| paste_from_clipboard | ctrl+shift+v |\n"
        out = kbc.parse_markdown_table(reversed_rows, 'kitty', 'upstream test')
        self.assertEqual(len(out), 2)

    def test_aligned_plain_text(self):
        # kitty's own docs paste as "Action  shortcut"; with the key last,
        # the wrap-around rule makes the other cell the action
        text = "Copy to clipboard  ctrl+shift+c\nPaste from clipboard  ctrl+shift+v\n"
        out = kbc.parse_markdown_table(text, 'kitty', 'upstream test')
        self.assertEqual(sorted(b.chord.render() for b in out),
                         ['Ctrl+Shift+C', 'Ctrl+Shift+V'])
        self.assertEqual(sorted(b.action for b in out),
                         ['Copy to clipboard', 'Paste from clipboard'])

    def test_html_table(self):
        text = ('<table><tr><th>Shortcut</th><th>Action</th></tr>'
                '<tr><td>ctrl+shift+c</td><td>copy_to_clipboard</td></tr></table>')
        out = kbc.parse_html_table(text, 'kitty', 'upstream test')
        self.assertEqual([(b.chord.render(), b.action) for b in out],
                         [('Ctrl+Shift+C', 'copy_to_clipboard')])

    def test_sniffer(self):
        self.assertEqual(kbc.sniff_format("map('kitty_mod+s', 'copy_to_clipboard')"),
                         'kitty-source')
        self.assertEqual(kbc.sniff_format('<table><tr></tr></table>'), 'html-table')
        self.assertEqual(kbc.sniff_format("ble-bind -f C-v -"), 'ble-bind')
        self.assertEqual(kbc.sniff_format("'bindkey' '^[[H' 'beginning-of-line'"), 'bindkey')
        self.assertEqual(kbc.sniff_format('| a | b |\n'), 'markdown-table')


class BindkeyTests(unittest.TestCase):
    # the shape mirrors config/initial-bindings.zsh: a Manjaro-style block
    # wiped by the zsh4humans `bindkey -d`, then `-s` translations and
    # widget bindings in the quoted-word form
    FIXTURE = """
    bindkey '^[[2~' overwrite-mode                                  # Insert
    bindkey "${terminfo[khome]}" beginning-of-line
    'bindkey' '-d'
    'bindkey' '-e'
    'bindkey' '^A'      'beginning-of-line'
    'bindkey' '-s' '^T' '^A'
    'bindkey' '^[[H'    'beginning-of-line'
    'bindkey' '^[[1;5C' 'forward-word'
    'bindkey' -r "^v"
"""

    def parsed(self):
        return kbc.parse_bindkey(self.FIXTURE, 'zsh', 'upstream test')

    def by_render(self):
        return {b.chord.render(): b for b in self.parsed()}

    def test_bindkey_d_wipes_everything_before_it(self):
        # overwrite-mode was bound only before `-d`: dead in the live config,
        # so it must be absent, not merely overridden
        self.assertNotIn('Insert', self.by_render())

    def test_dynamic_terminfo_key_skipped(self):
        self.assertNotIn('beginning-of-line',
                         [b.chord.render() for b in self.parsed()])

    def test_widget_binding_survives_the_wipe(self):
        rows = self.by_render()
        self.assertEqual(rows['Home'].action, 'beginning-of-line')

    def test_send_translation_resolves_one_hop(self):
        # ^T sends ^A, which is itself bound to beginning-of-line, and ^T's
        # own canonical (ctrl+t) differs from its target's (ctrl+a), so the
        # translation row survives and carries the resolution
        row = self.by_render()['Ctrl+T']
        self.assertTrue(row.unbound)
        self.assertEqual(row.notes, 'sends ^A -> beginning-of-line')

    def test_unbind_is_a_tombstone(self):
        self.assertTrue(self.by_render()['Ctrl+V'].unbound)


class BleBindTests(unittest.TestCase):
    # the shape mirrors blesh.nix: ble-bind riding inside -C callbacks and a
    # two-command blehook string
    FIXTURE = """
                ble-import -d \\
                    -C 'ble-bind -m emacs   -x C-r "__atuin_history --keymap-mode=emacs"' \\
                    -C 'ble-bind -m vi_imap -x C-r "__atuin_history --keymap-mode=vim-insert"' \\
                    fzf-key-bindings.bash
                blehook ATTACH+='ble-bind -m emacs -f C-v -; ble-bind -m vi_imap -f C-v -'
"""

    def test_callbacks_and_hook_all_found(self):
        out = kbc.parse_ble_bind(self.FIXTURE, 'bash', 'upstream test')
        self.assertEqual(len(out), 4)

    def test_modes_and_actions(self):
        by = {(b.mode, b.chord.render()): b for b in
              kbc.parse_ble_bind(self.FIXTURE, 'bash', 'upstream test')}
        self.assertEqual(by[('emacs', 'Ctrl+R')].action,
                         '__atuin_history --keymap-mode=emacs')
        self.assertEqual(by[('vi_imap', 'Ctrl+R')].action,
                         '__atuin_history --keymap-mode=vim-insert')

    def test_dash_widget_is_an_unbind(self):
        by = {(b.mode, b.chord.render()): b for b in
              kbc.parse_ble_bind(self.FIXTURE, 'bash', 'upstream test')}
        self.assertTrue(by[('emacs', 'Ctrl+V')].unbound)
        self.assertTrue(by[('vi_imap', 'Ctrl+V')].unbound)


class MergeRenderTests(unittest.TestCase):
    def binding(self, spec, action, source):
        return kbc.Binding('kitty', '', chord(spec), action, source)

    def test_repo_override_wins(self):
        upstream = [self.binding('ctrl+shift+s', 'noop', 'upstream docs')]
        repo = [self.binding('kitty_mod+s', 'copy_to_clipboard', 'repo nix')]
        merged = kbc.merge(upstream, repo)
        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0].action, 'copy_to_clipboard')
        self.assertTrue(merged[0].source.startswith('repo'))

    def test_repo_unbind_replaces_upstream_row(self):
        upstream = [kbc.Binding('zsh', 'main', chord('^v'),
                                'paste_from_clipboard', 'upstream docs')]
        repo = [kbc.Binding('zsh', 'main', chord('^v'), None, 'repo nix')]
        sheet = kbc.render_markdown('zsh', kbc.merge(upstream, repo))
        self.assertIn('*(unbound)*', sheet)
        self.assertNotIn('paste_from_clipboard', sheet)

    def test_upstream_only_rows_survive(self):
        upstream = [self.binding('ctrl+shift+f5', 'load_config_file', 'upstream docs')]
        sheet = kbc.render_markdown('kitty', kbc.merge(upstream, []))
        self.assertIn('Ctrl+Shift+F5', sheet)
        self.assertIn('load_config_file', sheet)

    def test_send_rows_render_their_translation_as_the_action(self):
        sheet = kbc.parse_bindkey("'bindkey' '-s' '^[OM' '^M'\n", 'zsh', 't')
        rendered = kbc.render_markdown('zsh', sheet)
        self.assertIn('`sends ^M`', rendered)
        self.assertNotIn('*(unbound)*', rendered)

    def test_modes_render_as_sections(self):
        bindings = [kbc.Binding('bash', 'emacs', chord('C-r'), 'atuin', 't'),
                    kbc.Binding('bash', 'vi_imap', chord('C-r'), 'atuin-vim', 't')]
        sheet = kbc.render_markdown('bash', bindings)
        self.assertIn('## mode: emacs', sheet)
        self.assertIn('## mode: vi_imap', sheet)


class RepoReaderTests(unittest.TestCase):
    """The regexes in the read_repo_* readers are coupled to the exact shapes
    of the declaring modules -- this is the drift alarm for when one of those
    files is reformatted without the parser following."""

    def test_kitty_overrides(self):
        out = kbc.read_repo_kitty()
        by_render = {b.chord.render(): b.action for b in out}
        self.assertEqual(by_render.get('Ctrl+Shift+S'), 'copy_to_clipboard')
        self.assertEqual(by_render.get('Ctrl+Shift+V'), 'paste_from_clipboard')
        self.assertEqual(by_render.get('Cmd+C'), 'copy_or_interrupt')
        self.assertEqual(by_render.get('Cmd+V'), 'paste_from_clipboard')

    def test_zsh_overrides_honour_the_bindkey_d_wipe(self):
        out = kbc.read_repo_zsh()
        by_render = {b.chord.render(): b for b in out}
        self.assertEqual(by_render['Home'].action, 'beginning-of-line')
        self.assertTrue(by_render['Ctrl+V'].unbound)      # freed for zellij
        self.assertTrue(by_render['Alt+V'].unbound)
        self.assertNotIn('Insert', by_render)             # Manjaro block is dead

    def test_bash_overrides(self):
        out = kbc.read_repo_bash()
        by = {(b.mode, b.chord.render()): b for b in out}
        self.assertIn('__atuin_history', by[('emacs', 'Ctrl+R')].action)
        self.assertIn('__atuin_history', by[('vi_imap', 'Ctrl+R')].action)
        self.assertTrue(by[('emacs', 'Ctrl+V')].unbound)
        self.assertTrue(by[('vi_imap', 'Ctrl+V')].unbound)


if __name__ == '__main__':
    unittest.main()
