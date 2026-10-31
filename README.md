# Flash Links

Review unset or detached object references in Studio. Click a finding to select the object that owns the reference. The plugin does not repair, delete or rewrite anything.

## Install

1. Download this repository as a ZIP and extract it. No package installation is needed to use the plugin.
2. In a separate Studio test place, use Explorer's **Insert from File** action to insert `FlashLinks.rbxmx`.
3. Select the root Script named `FlashLinks` (it has four child ModuleScripts) and choose **Save as Local Plugin**.
4. Remove the imported Script from the place. Open **Flash Links → Links** on the Plugins toolbar.

The plugin runs in edit mode. Scans and edits are refused during a play test.

## Use it

Choose **Scan selection and descendants** or **Scan Workspace**. Use **Report unset references** to include or exclude empty fields. Findings remain a snapshot when you change the selection; scan again after editing the place.

## What it reads

| Objects | Properties |
| --- | --- |
| ObjectValue | Value |
| Model with a PrimaryPart | PrimaryPart |
| Beam, Trail | Attachment0, Attachment1 |
| JointInstance (including Weld/Motor6D), WeldConstraint, NoCollisionConstraint | Part0, Part1 |
| HingeConstraint, BallSocketConstraint, RopeConstraint, RodConstraint, SpringConstraint, RigidConstraint | Attachment0, Attachment1 |

Models without a PrimaryPart are ignored: one is not required for every Model. One-attachment force/alignment constraints are outside this whitelist, rather than being reported for having no second attachment. The scanner does not reflect over every property or read script source.

## Reading findings

| Code | Meaning |
| --- | --- |
| UNSET | No target is assigned. It may be intentionally empty or filled at runtime. |
| DETACHED | The target is not the current DataModel or one of its descendants. |
| WRONG_TYPE | A read target does not match the expected class. Roblox normally enforces property types; this rule is also covered using plain test records. |
| OUTSIDE_MODEL | A Model's PrimaryPart points outside that Model. |
| SAME_ENDPOINT | Both endpoints use the same non-nil object. Review the intended setup. |

A reference to an object **outside the scanned selection but still in the game is valid**. When Roblox clears a reference after a target is destroyed, this tool sees the empty field; it cannot recover the old identity or distinguish that case from a deliberately empty reference.

## Limits

- At most 500 roots and 20000 discovered objects. Services may be scanned; the DataModel root itself is refused. Traversal is iterative and deduplicates overlapping roots.
- At most 100 findings are displayed, with the complete finding count retained. A scope over the object limit stops with an explanation instead of an incomplete clean result.
- No string-path checks, asset-ID validation, package resolution, automatic fixes, runtime behavior analysis or external requests.
- A finding is a reason to inspect an object, not proof of a broken game. Scan after edits to refresh stale results.

## Inputs and outputs

`Adapter.scan(roots, reportUnset)` takes Studio roots and an unset-field option. It returns `{scanned, checked, findings, total}`. `Rules.analyze(records, reportUnset, maxResults)` classifies plain reference records, caps displayed results and keeps the full count. Selection changes are the only action the result buttons perform; there is no Apply button or undo recording.

See Roblox's [ObjectValue reference](https://create.roblox.com/docs/reference/engine/classes/ObjectValue) and [Model reference](https://create.roblox.com/docs/reference/engine/classes/Model).

## Development and tests

Source is in `src`. The dock panel follows Studio's theme. There are no runtime packages, external assets, file uploads, telemetry or network requests. The UI and scope helpers are shared with the other Flash plugins; each repository has its own copy so it can be installed independently.

Rebuild with Python 3.11+:

```sh
python build.py
python -m unittest discover -s tests -v
```

Run the Luau checks with Lune 0.11.1:

```sh
lune run tests/run
```

GitHub Actions compiles every source file, runs scope/rule/adapter checks with fake Studio objects, verifies the packaged source and checks reproducible builds. The editing plugins also test undo-recording commit/cancel behavior with a fake history service. Lune is installed on the CI runner, not on your PC.

**The dock widget, local-plugin installation and real Studio engine behavior have not been verified live.** See [Studio checks](docs/STUDIO-CHECKS.md). A passing automated test is not a live Studio compatibility guarantee.

MIT licensed; see [LICENSE](LICENSE).
