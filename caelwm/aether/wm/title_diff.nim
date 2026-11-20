## Semantic title transitions derived from successive authoritative metadata
## collections. The daemon owns X observation; this module only compares the
## effective title and client identity already collected by that observation.

type
  ObservedTitle* = object
    winid*: string
    token*: string
    title*: string
    available*: bool

  TitleChanged* = object
    winid*: string
    token*: string
    oldTitle*: string
    newTitle*: string

proc diffTitleChanges*(previous, current: openArray[ObservedTitle]): seq[TitleChanged] =
  for updated in current:
    if not updated.available:
      continue
    for old in previous:
      if old.winid != updated.winid or old.token != updated.token or
          not old.available or old.title == updated.title:
        continue
      result.add(TitleChanged(
        winid: updated.winid,
        token: updated.token,
        oldTitle: old.title,
        newTitle: updated.title
      ))
      break
