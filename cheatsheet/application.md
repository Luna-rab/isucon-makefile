- [モデル見直し](#モデル見直し)
    - [ループ内で find や where を見つけたら外に出す](#ループ内で-find-や-where-を見つけたら外に出す)
    - [ループ内ループは特に気をつける](#ループ内ループは特に気をつける)

## モデル見直し
### ループ内で find や where を見つけたら外に出す
```php
foreach ($sheet['rows'] as $rowIndex => $cols) {
    $Id = $cols[$itemLineIdIndex];
    if (!$Id) {
        $itemLine = $itemLines->find($Id);
```
↓↓↓
```php
// ループ内で探索するために辞書化しておく
$itemLineDict = $itemLines->keyBy('id')->all();

foreach ($sheet['rows'] as $rowIndex => $cols) {
    $Id = $cols[$itemLineIdIndex];
    if (!$Id) {
        $itemLine = $itemLineDict[$Id] ?? null;
```

### ループ内ループは特に気をつける
```php
foreach ($itemNames as $itemName) {
    foreach ($dataValues as $index => $data) {
        $Id = $itemLines->where('origin_item_id', $textId)->where('version_id', $versionId)->first()?->id;
```
↓↓↓
```php
// ループ内で探索に使うキーを生成する関数
$lineKeyFunc = fn($textId, $versionId) => "{$textId}]=[{$versionId}"; // textId(string)で使われなさそうな文字列で連結
foreach ($itemNames as $itemName) {
    // ループ内で探索するために辞書化しておく
    $itemLineIdDict = $itemLines->mapWithKeys(function ($itemLine) use ($lineKeyFunc) {
        return [$lineKeyFunc($itemLine->origin_item_id, $itemLine->version_id) => $itemLine->id];
    })->all();
    foreach ($dataValues as $index => $data) {
        $Id = $itemLineIdDict[$lineKeyFunc($textId, $versionId)] ?? null;
```
