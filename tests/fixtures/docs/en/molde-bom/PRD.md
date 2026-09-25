# PRD: x

## 1. Overview

`live`

```
SOURCE --reads--> STORE --serves--> READER
```

## 2. Search

`live`

### Purpose

Find an item without knowing where it sits.

### Flow

Whoever is looking types, and the list filters on every keystroke. With no hit,
that same list offers the search across the whole archive.

### Rules

| When | The product guarantees |
|---|---|
| the query is under three letters | the list does not filter, and says why |
| the query matches nothing | an empty list, never an error |
