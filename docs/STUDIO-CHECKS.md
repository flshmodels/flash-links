# Studio checks

Status: not yet run in a live Studio session. Record the Studio version, date and outcome when running these checks.

1. Install `FlashLinks.rbxmx` in a separate test place. Check that the toolbar button opens and closes the dock panel.
2. Try light and dark themes and a narrow dock. Fields, result text and status should remain readable and scrollable.
3. Test selection-only and nested scopes where supported, including overlapping roots and a removed object. Compare the counts with Explorer.
4. Try the valid and invalid inputs listed in the README. A rejected operation should leave the place unchanged.
5. Start a play test. The plugin must refuse scans/edits, then work again after the test stops.
6. Disable or reload the plugin. The dock panel and toolbar should disappear without leftover connections or errors.

7. Create ObjectValues with nil, valid external-scope and detached targets; test the unset toggle. Check a Beam or Weld with missing and identical endpoints. Confirm findings never edit properties and clicking a removed owner asks for a rescan. Rescan repeatedly and check that old rows are hidden rather than accumulated.
