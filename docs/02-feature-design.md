# Type-ahead recursive search — design

## The Nautilus behaviour being copied

In GNOME Files (Nautilus), a focused window that is not editing text treats the
first printable keystroke as the beginning of a search: the search bar opens,
the character lands in it, and the view is replaced by matches found by walking
the current folder **and its subfolders**. `Escape` closes the search and
restores the folder listing.

## What Thunar 4.18 does instead

Thunar already has everything except the trigger:

* `Ctrl+F` (`THUNAR_WINDOW_ACTION_SEARCH`) calls
  `thunar_window_action_search()` → `thunar_window_start_open_location (window, SEARCH_PREFIX)`.
* `SEARCH_PREFIX` is the literal string `"Search: "`. Putting it at the front of
  the location bar's `ThunarPathEntry` text is what switches the window into
  search mode: `thunar_path_entry_changed()` recognises it through
  `thunar_util_is_a_search_query()`, flips the entry into `search_mode` and calls
  `thunar_window_update_search()`, which hands the query behind the prefix to
  `thunar_standard_view_set_searching()`.
* How deep the search goes is already a user preference,
  `misc-recursive-search` (*Local Files Only* / *Always* / *Never*), surfaced as
  **Include subfolders** in *Preferences → Advanced → Search*.
* `Escape` is already bound to `THUNAR_WINDOW_ACTION_CANCEL_SEARCH`.

Without `Ctrl+F`, a keystroke in a view reaches the GTK widget underneath
(`GtkTreeView` for the detailed list, `ExoIconView` for the icon and compact
views) and starts that widget's *interactive search*: a small popup that moves
the cursor to the next matching name **in the current folder only**.

So the feature is a new trigger, not a new search.

## Where the trigger is installed

`thunar_window_type_ahead_search()` in `thunar/thunar-window.c`, connected to the
window's `key-press-event`.

A `key-press-event` handler on a `GtkWindow` added with `g_signal_connect()` runs
*before* `gtk_window_key_press_event()` — the class closure — which is what
activates accelerators and then forwards the event to the focused widget. That
ordering is exactly what is needed: the handler sees the keystroke before any
view's interactive search can claim it, and it can decline and let everything
proceed as usual by returning `GDK_EVENT_PROPAGATE`.

Putting it on the window rather than on `ThunarStandardView` matters for
fidelity: in Nautilus it is the *window* that is listening, so typing works with
the keyboard focus on the shortcuts/tree side pane, on the toolbar, or nowhere in
particular — not only inside the file view.

Connection order within the window's own handlers is also deliberate. The
handler is connected in `thunar_window_init()` *after* the call to
`thunar_window_location_toolbar_create()`, which is where
`thunar_window_check_uca_key_activation` gets connected. Signal handlers run in
connection order, so a custom action bound to a plain letter still wins.

## Decision table

| Key press | Result |
| --- | --- |
| `a`…`z`, `A`…`Z`, `0`…`9`, punctuation, non-ASCII printables | starts the search, or appends to a running one |
| Second and later characters | appended; the focus is pulled back to the search entry |
| `Space` | ignored — it toggles the selection in the views |
| `Escape`, `Delete`, `F2`, `F5`, arrows, `Tab`, … | ignored — not printable |
| anything with `Ctrl`/`Alt`/`Super` | ignored |
| `Shift` + a key | acts on the shifted character (`A`) |
| a key matching an accelerator in the window's accel group | ignored, the accelerator fires |
| a key matching a custom action (UCA) shortcut | ignored, the custom action fires |
| `/`, `~` | ignored — these keep opening the location bar / home path |
| any key while a `GtkEditable` or `GtkTextView` has the focus | ignored — covers the location bar, the search entry itself and inline renaming |
| any key while the preference is off | ignored — upstream behaviour (interactive search) returns |

## Implementation notes

* **Which character.** `gdk_keyval_to_unicode (event->keyval)` rather than the
  deprecated `event->string`; the keyval already carries the shift level, and the
  result is filtered with `g_unichar_isprint()` / `iscntrl()` / `isspace()`.
* **Starting a search.** `thunar_window_start_open_location (window, "Search: x")`.
  That reuses the `Ctrl+F` path verbatim, including the "switch to the detailed
  view while searching" workaround for `ExoIconView` slowness and the saving of
  the view type so cancelling restores it.
* **Extending a search.** When `window->is_searching` is already `TRUE` the
  handler does *not* call `thunar_window_start_open_location()` again — that
  would re-run the view-type workaround and record the detailed view as the view
  to restore, losing the user's icon view. It calls
  `thunar_location_bar_request_entry()` with `"Search: " + current query + the new
  character` instead, which sets the entry text, puts the caret at the end and
  gives it the keyboard focus; the entry's `changed` handler drives the search
  from there. The current query is read from `window->search_query`, the copy the
  window already maintains in `thunar_window_update_search()`, so no assumption
  is made about which widget the location bar currently holds.
* **The search toolbar item.** `thunar_window_set_search_button_active()` keeps
  the toggle button in sync, blocking `thunar_window_action_search` around the
  call the same way the three existing call sites do.
* **No new string parsing.** The handler never inspects the entry text; it only
  ever prepends `SEARCH_PREFIX`.

## The preference

`misc-type-ahead-search`, a boolean on `ThunarPreferences`, default `TRUE`,
stored by xfconf at `/misc-type-ahead-search` in the `thunar` channel. Thunar's
preference objects map GObject properties onto xfconf generically, so no schema
or extra registration is involved.

In *Preferences → Advanced → Search* it appears as a **Search as you type** check
box directly above **Include subfolders**, which is the setting that decides how
deep the resulting search goes.

Turning it off from the command line:

```
xfconf-query -c thunar -p /misc-type-ahead-search -t bool -s false
```

## Known limitations

* Thunar's search is a live directory walk (`ThunarJob`), not an index. On a very
  large tree the first keystroke can therefore start a long-running job; that is
  upstream's search behaviour, unchanged. Thunar 4.18 defaults *Include
  subfolders* to **Always**; setting it to *Local Files Only* keeps the walk off
  network mounts, and *Never* reduces the search to the current folder while
  still opening the search entry.
* A single-character accelerator added by the user after the window was built is
  still honoured, because the accel group is queried on every key press; a custom
  action shortcut is honoured because that handler runs first.
* The feature deliberately does not try to also keep the old interactive search
  reachable under another key; `Ctrl+F` and typing now lead to the same place.
