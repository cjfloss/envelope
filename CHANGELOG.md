#  (2015-02-22)

## Bug Fixes

- **Database:** map categories using name instead of id
  ([97c1a25b](https://github.com/nlaplante/envelope/commit/97c1a25b6444b836fcadf049856db8810d4150df),
   [#40](https://github.com/nlaplante/envelope/issues/40))
- **Header bar:** remove export button
 ([431dc7a6](https://github.com/nlaplante/envelope/commit/431dc7a6986586450e7b9ca503f4e9abd194a949),
  [#43](https://github.com/nlaplante/envelope/issues/43))
  
#  (2015-02-18)

## Bug Fixes

- **Application name:** Update .desktop name to Envelope
  ([f0f0ff39](https://github.com/nlaplante/envelope/commit/f0f0ff39578343bbc60696c4eef38d8b24b4f7d3),
   [#39](https://github.com/nlaplante/envelope/issues/39))
- **TransactionView:**
  - remove currency from cell after editing amount
  ([8d4530e2](https://github.com/nlaplante/envelope/commit/8d4530e209ff868cceef5c32c5d97c3c08eaf144),
   [#41](https://github.com/nlaplante/envelope/issues/41))
- **Search:**
   - change placeholder text when selecting category
   ([0c423a3c](https://github.com/nlaplante/envelope/commit/0c423a3cf7f4718ecdfa13eb69a67ef17b50f1e2),
    [#19](https://github.com/nlaplante/envelope/issues/19))

## Features

- **Search:**
  - remove ellipsis in placeholder text
  ([983fd617](https://github.com/nlaplante/envelope/commit/983fd6179cfb14b49abf4dc056fc36c79cd1d2c2))
  - make search bar wider
  ([a766150f](https://github.com/nlaplante/envelope/commit/a766150fce823d96b1e17bc36cf60231eb719eae))

#  (2015-02-08)

## Features

  - **TransactionView:** refilter view
    ([c9ea0b23](https://github.com/nlaplante/envelope/commit/c9ea0b23ab777f62a88e84ee9ec84e0c2f394447))

## Bug Fixes

  - **TransactionView:** use correct iter when column is sorted
    ([7798e063](https://github.com/nlaplante/envelope/commit/7798e063dc461b323fc738290ce7e073b3c2c982),
     [#30](https://github.com/nlaplante/envelope/issues/30))

#  (2015-02-07)

## Features

  - **BudgetManager:** handle null category for uncategorized transactions
    ([86ac9749](https://github.com/nlaplante/envelope/commit/86ac9749af33beda476cbafaf50e456ef62e7f32))
  - **Database:** add query for current uncategorized transactions
    ([49a03a8a](https://github.com/nlaplante/envelope/commit/49a03a8a4b929012c84f5d8b301900c7c392b8d9))
  - **Settings:** handle uncategorized sidebar selected item
    ([641b71e8](https://github.com/nlaplante/envelope/commit/641b71e8c2a794f8b4a3a3c4df42251c0db3c26a))
  - **Sidebar:** uncategorized item shows current uncategorized transactions
    ([dbcc71ab](https://github.com/nlaplante/envelope/commit/dbcc71ab21b31720c374fca7af5353823fb47a6b))  

#  (2015-02-04)

## Features

- **MainWindow:** remove Gtk.Revealer
  ([89b0a675](https://github.com/nlaplante/envelope/commit/89b0a675a5489332199bd66de6d47c14d5ed945c))
- **TransactionView:**
  - set sane minimum column widths
  ([dc983a59](https://github.com/nlaplante/envelope/commit/dc983a594df6edc15530a8a500bfd98e071635d8))
  - ellipsize content when resizing columns
  ([116cf16d](https://github.com/nlaplante/envelope/commit/116cf16d8e93b6384b248d79b7f5ba796cf0a825))
  - use fixed row height (perf)
  ([3b0eb11f](https://github.com/nlaplante/envelope/commit/3b0eb11fc9c3929a7c0e4ffc0ee4b7ce1d6b57aa))


## Documentation

- **README:** add contributing section



---
<sub><sup>*Generated with [git-changelog](https://github.com/rafinskipg/git-changelog). If you have any problem or suggestion, create an issue.* :) **Thanks** </sub></sup>
