2026-07-13

- Moved policy completely into rule.nim.
- Removed window.sync() from normal workflows.
- Determined that command chaining eliminated previous timing issues.
- WM responsibility to be reduced to primitives, borders and state.


## Window Query Semantics

Managed client
    A client currently owned by Windowchef.

Visible client
    A managed client with mapped == true.

All clients
    Every managed client, regardless of mapped state.

Default scope
    Collection queries operate on visible clients.

--all
    Expands the query scope to every managed client.

Classname
    Exact match against the canonical Windowchef classname.

...
