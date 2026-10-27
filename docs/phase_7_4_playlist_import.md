# Phase 7.4 — Playlist Import Documentation

## 4-Tier Matching Strategy
When importing a playlist (JSON or M3U), tracks are matched against the local library using a strict 4-tier strategy:
1. **Stable Track Hash**: Matching `title|artist|album|duration` normalize hash.
2. **Exact Audio Path**: Matching exact local audio or file path.
3. **Title + Artist Match**: Matching normalized title and artist.
4. **Title Match**: Fallback match on track title.

## Import Workflow
- Shows preview of matched vs missing tracks before importing.
- Creates new playlist entry with zero duplicate track generation.
