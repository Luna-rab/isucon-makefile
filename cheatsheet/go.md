### SQL

## SELECT N+1

```
var livestreamTagModels []*LivestreamTagModel
if err := tx.SelectContext(ctx, &livestreamTagModels, "SELECT * FROM livestream_tags WHERE livestream_id = ?", livestreamModel.ID); err != nil {
    return Livestream{}, err
}
tags := make([]Tag, len(livestreamTagModels))
for i := range livestreamTagModels {
    tagModel := TagModel{}
    if err := tx.GetContext(ctx, &tagModel, "SELECT * FROM tags WHERE id = ?", livestreamTagModels[i].TagID); err != nil {
        return Livestream{}, err
    }

    tags[i] = Tag{
        ID:   tagModel.ID,
        Name: tagModel.Name,
    }
}
```

↓↓↓

```
var tags []Tag
if err := tx.SelectContext(ctx, &tags, "SELECT * FROM tags t JOIN livestream_tags lt ON lt.tag_id = t.id WHERE lt.livestream_id = ?", livestreamModel.ID); err != nil {
    return Livestream{}, err
}
```

## DELETE N+1

```
for _, ngword := range ngwords {
	// ライブコメント一覧取得
	var livecomments []*LivecommentModel
	if err := tx.SelectContext(ctx, &livecomments, "SELECT * FROM livecomments"); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, "failed to get livecomments: "+err.Error())
	}
	for _, livecomment := range livecomments {
		query := `
		DELETE FROM livecomments
		WHERE
		id = ? AND
		livestream_id = ? AND
		(SELECT COUNT(*)
		FROM
		(SELECT ? AS text) AS texts
		INNER JOIN
		(SELECT CONCAT('%', ?, '%')	AS pattern) AS patterns
		ON texts.text LIKE patterns.pattern) >= 1;
		`
		if _, err := tx.ExecContext(ctx, query, livecomment.ID, livestreamID, livecomment.Comment, ngword.Word); err != nil {
			return echo.NewHTTPError(http.StatusInternalServerError, "failed to delete old livecomments that hit spams: "+err.Error())
		}
	}
}
```

↓↓↓

```
for _, ngword := range ngwords {
    query := `
    DELETE FROM livecomments
    WHERE
    livestream_id = ? AND
    comment LIKE CONCAT('%', ?, '%')
    `
    if _, err := tx.ExecContext(ctx, query, livestreamID, ngword.Word); err != nil {
        return echo.NewHTTPError(http.StatusInternalServerError, "failed to delete old livecomments that hit spams: "+err.Error())
    }
}
```
