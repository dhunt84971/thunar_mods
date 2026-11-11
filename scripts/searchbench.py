#!/usr/bin/env python3
"""Compare recursive-search I/O strategies over a GIO location.

serial-dfs    : exactly what thunar_list_model_search_folder() does -- one
                thread, depth-first, recursing inline, and a folder's matches
                are only handed over once its whole subtree is done.
serial-bfs    : one thread, breadth-first queue, matches reported immediately.
parallel-bfs  : N threads pulling directories off a shared queue, matches
                reported immediately.
"""
import argparse, queue, sys, threading, time
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

# the attribute set Thunar's search walker asks for
THUNAR_ATTRS = ("standard::type,standard::target-uri,standard::display-name,"
                "standard::is-backup,standard::is-hidden,standard::name,recent::*")

class Stats:
    def __init__(self):
        self.lock = threading.Lock()
        self.dirs = 0
        self.files = 0
        self.matches = []
        self.first_match_at = None
        self.committed = []          # (elapsed, count) when matches become visible
        self.start = time.monotonic()
    def saw_dir(self):
        with self.lock: self.dirs += 1
    def saw_files(self, n):
        with self.lock: self.files += n
    def commit(self, names):
        if not names: return
        now = time.monotonic() - self.start
        with self.lock:
            if self.first_match_at is None:
                self.first_match_at = now
            self.matches.extend(names)
            self.committed.append((now, len(self.matches)))

def enumerate_dir(uri, attrs, cancellable):
    d = Gio.File.new_for_uri(uri)
    try:
        en = d.enumerate_children(attrs, Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable)
    except GLib.Error:
        return None, []
    kids, n = [], 0
    while True:
        try:
            info = en.next_file(cancellable)
        except GLib.Error:
            break
        if info is None:
            break
        n += 1
        kids.append((info.get_name(), info.get_display_name(),
                     info.get_file_type() == Gio.FileType.DIRECTORY,
                     info.get_is_hidden() or info.get_is_backup()))
    en.close(cancellable)
    return kids, n

def matches(term, display_name):
    return term in display_name.casefold()

def walk_serial_dfs(uri, term, attrs, st, deadline, show_hidden=False):
    """Thunar's pattern: recurse inline, commit this folder's hits last."""
    if time.monotonic() > deadline:
        return
    st.saw_dir()
    kids, n = enumerate_dir(uri, attrs, None)
    st.saw_files(n)
    found = []
    for name, disp, is_dir, hidden in kids:
        if hidden and not show_hidden:
            continue
        child = uri.rstrip("/") + "/" + GLib.uri_escape_string(name, None, False)
        if is_dir:
            walk_serial_dfs(child, term, attrs, st, deadline, show_hidden)
        if matches(term, disp or name):
            found.append(child)
        if time.monotonic() > deadline:
            break
    st.commit(found)   # <- only now, after the entire subtree

def walk_queue(uri, term, attrs, st, deadline, threads, show_hidden=False):
    """Breadth-first queue; matches committed as soon as the folder is read."""
    q = queue.Queue()
    q.put(uri)
    inflight = threading.Semaphore(0)
    done = threading.Event()
    pending = [1]
    plock = threading.Lock()

    def worker():
        while not done.is_set():
            try:
                u = q.get(timeout=0.2)
            except queue.Empty:
                continue
            if time.monotonic() <= deadline:
                st.saw_dir()
                kids, n = enumerate_dir(u, attrs, None)
                st.saw_files(n)
                found, newdirs = [], []
                for name, disp, is_dir, hidden in kids:
                    if hidden and not show_hidden:
                        continue
                    child = u.rstrip("/") + "/" + GLib.uri_escape_string(name, None, False)
                    if matches(term, disp or name):
                        found.append(child)
                    if is_dir:
                        newdirs.append(child)
                st.commit(found)
                with plock:
                    pending[0] += len(newdirs)
                for d in newdirs:
                    q.put(d)
            with plock:
                pending[0] -= 1
                if pending[0] <= 0:
                    done.set()
            q.task_done()

    ws = [threading.Thread(target=worker, daemon=True) for _ in range(threads)]
    for w in ws: w.start()
    while not done.is_set() and time.monotonic() <= deadline:
        time.sleep(0.05)
    done.set()
    for w in ws: w.join(timeout=1.0)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--uri", required=True)
    ap.add_argument("--query", required=True)
    ap.add_argument("--mode", choices=["serial-dfs", "serial-bfs", "parallel-bfs"], required=True)
    ap.add_argument("--threads", type=int, default=8)
    ap.add_argument("--seconds", type=float, default=60.0)
    ap.add_argument("--attrs", default=THUNAR_ATTRS)
    a = ap.parse_args()

    st = Stats()
    deadline = st.start + a.seconds
    term = a.query.casefold()
    if a.mode == "serial-dfs":
        walk_serial_dfs(a.uri, term, a.attrs, st, deadline)
    elif a.mode == "serial-bfs":
        walk_queue(a.uri, term, a.attrs, st, deadline, 1)
    else:
        walk_queue(a.uri, term, a.attrs, st, deadline, a.threads)
    el = time.monotonic() - st.start
    complete = el < a.seconds - 0.5
    print(f"mode={a.mode} threads={a.threads if a.mode=='parallel-bfs' else 1}")
    print(f"  elapsed            {el:7.1f} s{'  (COMPLETE)' if complete else '  (hit time limit)'}")
    print(f"  dirs visited       {st.dirs:7d}")
    print(f"  entries seen       {st.files:7d}")
    print(f"  dirs/sec           {st.dirs/el:7.1f}")
    print(f"  matches            {len(st.matches):7d}")
    fm = f"{st.first_match_at:.1f} s" if st.first_match_at is not None else "never"
    print(f"  first match at     {fm:>9}")
    for t, c in st.committed[:6]:
        print(f"    + at {t:6.1f} s  running total {c}")
    for m in st.matches[:8]:
        print(f"    {m.split('/')[-1]}")


if __name__ == "__main__":
    main()
